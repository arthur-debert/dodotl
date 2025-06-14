-- DirectoryTrigger implementation
-- Matches files based on directory path patterns, with options for filesystem checks.

local pl_path = require("pl.path") -- For path manipulation, though not strictly used in this version
local posix = require("posix")   -- For filesystem checks like access()
local M = {}

local function create_glob_pattern(pattern)
    -- Handle empty pattern (root directory)
    if pattern == "" then
        return "^$"
    end

    -- Convert shell-style globbing to Lua pattern
    -- * -> [^/]*  (match any character except path separator)
    -- ** -> .*   (match any character including path separators, including nothing)
    -- ? -> [^/]  (match single character except path separator)
    -- [abc] -> [abc] (unchanged)
    -- Escape special Lua pattern characters

    local lua_pattern = pattern

    -- Handle special cases for ** patterns
    -- **/ at start -> match zero or more dirs at start
    lua_pattern = lua_pattern:gsub("^%*%*/", "DOUBLESTAR_PREFIX")
    -- /** at end -> match zero or more dirs at end
    lua_pattern = lua_pattern:gsub("/%*%*$", "DOUBLESTAR_SUFFIX")
    -- /** in middle -> match zero or more dirs in middle
    lua_pattern = lua_pattern:gsub("/%*%*/", "DOUBLESTAR_MIDDLE")
    -- Remaining ** -> match any chars including /
    lua_pattern = lua_pattern:gsub("%*%*", "DOUBLESTAR_ANY")

    -- Handle single * and other patterns
    lua_pattern = lua_pattern:gsub("[%(%)%.%%+%-*%?%[%^%$]", function(c)
        if c == "*" then
            return "[^/]*"
        elseif c == "?" then
            return "[^/]"
        else
            return "%" .. c -- Escape other special characters
        end
    end)

    -- Replace DOUBLESTAR placeholders
    -- For patterns like "config/**", we need to match "config" and "config/anything"
    -- For patterns like "**/config", we need to match "config" and "anything/config"
    lua_pattern = lua_pattern:gsub("DOUBLESTAR_PREFIX", ".-/")  -- any chars ending with /
    lua_pattern = lua_pattern:gsub("DOUBLESTAR_SUFFIX", "/.*")  -- / followed by any chars
    lua_pattern = lua_pattern:gsub("DOUBLESTAR_MIDDLE", "/.*/") -- / followed by any chars followed by /
    lua_pattern = lua_pattern:gsub("DOUBLESTAR_ANY", ".*")      -- any chars

    return "^" .. lua_pattern .. "$"
end

local DirectoryTrigger = {
    type = "directory",

    -- Match function that checks if a file's directory matches the pattern
    match = function(self, file_path, pack_path) -- file_path here is the path to the directory itself
        if not file_path then
            return false, nil
        end

        -- The path to match against the glob pattern is file_path itself,
        -- made relative to pack_path if pack_path is a prefix.
        local path_to_glob_match = file_path
        if pack_path and file_path:sub(1, #pack_path) == pack_path then
            path_to_glob_match = file_path:sub(#pack_path + 1)
            -- Remove leading slash if present after making relative, for consistency
            if path_to_glob_match:sub(1,1) == "/" or path_to_glob_match:sub(1,1) == "\\" then
                 path_to_glob_match = path_to_glob_match:sub(2)
            end
        end
        -- If file_path was already relative or not under pack_path, path_to_glob_match remains file_path
        -- This logic might need refinement based on how DirectoryTrigger is used (e.g. with absolute paths from config)

        local glob_matches
        if self.pattern:match("%*%*") then
            glob_matches = self:match_double_wildcard(path_to_glob_match)
        else
            glob_matches = path_to_glob_match:match(self.lua_pattern) ~= nil
        end

        if not glob_matches then
            return false, nil
        end

        -- Filesystem checks (using the original absolute file_path for these)
        if self.options.must_exist then
            if not posix.access(file_path, "e") then
                return false, nil -- Directory does not exist
            end
        end

        if self.options.must_be_executable then
            if not posix.access(file_path, "x") then
                return false, nil -- Directory not executable
            end
        end

        -- If all checks pass
        local metadata = {
            matched_pattern = self.pattern,
            directory = path_to_glob_match, -- This is the part that matched the glob
            full_path = file_path,      -- The original full path
            options_used = self.options
        }
        return true, metadata
    end,

    -- Special matching for double wildcard patterns
    match_double_wildcard = function(self, dir_path)
        local pattern = self.pattern

        -- Handle **/path - matches path and anything/path
        if pattern:match("^%*%*/(.+)$") then
            local suffix = pattern:match("^%*%*/(.+)$")
            -- Create pattern for exact match or ending with /suffix
            local exact_pattern = "^" .. suffix:gsub("[%(%)%.%%+%-*%?%[%^%$]", "%%%1") .. "$"
            local ending_pattern = "^.-/" .. suffix:gsub("[%(%)%.%%+%-*%?%[%^%$]", "%%%1") .. "$"
            return (dir_path:match(exact_pattern) or dir_path:match(ending_pattern)) ~= nil
        end

        -- Handle path/** - matches path, path/anything, path/anything/more
        if pattern:match("^(.+)/%*%*$") then
            local prefix = pattern:match("^(.+)/%*%*$")
            -- Create pattern for exact match or starting with prefix/
            local exact_pattern = "^" .. prefix:gsub("[%(%)%.%%+%-*%?%[%^%$]", "%%%1") .. "$"
            local starting_pattern = "^" .. prefix:gsub("[%(%)%.%%+%-*%?%[%^%$]", "%%%1") .. "/.*"
            return (dir_path:match(exact_pattern) or dir_path:match(starting_pattern)) ~= nil
        end

        -- Handle other ** patterns by falling back to the generated pattern
        return dir_path:match(self.lua_pattern) ~= nil
    end,

    -- Validate the trigger configuration
    validate = function(self)
        if self.pattern == nil then -- Allow empty string for pattern (root)
            return false, "DirectoryTrigger pattern cannot be nil"
        end
        if type(self.pattern) ~= "string" then
             return false, "DirectoryTrigger pattern must be a string"
        end

        local success, err = pcall(string.match, "test", self.lua_pattern)
        if not success then
            return false, "Invalid directory pattern: " .. self.pattern .. " (Lua pattern error: " .. tostring(err) .. ")"
        end

        if self.options.must_exist ~= nil and type(self.options.must_exist) ~= "boolean" then
            return false, "DirectoryTrigger must_exist option must be a boolean"
        end
        if self.options.must_be_executable ~= nil and type(self.options.must_be_executable) ~= "boolean" then
            return false, "DirectoryTrigger must_be_executable option must be a boolean"
        end

        return true, nil
    end
}

function DirectoryTrigger.new(pattern, options)
    if pattern == nil then -- Empty string "" is allowed for root-like matching
        return nil, "DirectoryTrigger requires a non-nil pattern (use empty string for root directory)"
    end
     if type(pattern) ~= "string" then
        return nil, "DirectoryTrigger pattern must be a string"
    end

    options = options or {}

    local instance_options = {
        must_exist = options.must_exist == nil and true or options.must_exist,
        must_be_executable = options.must_be_executable or false
    }

    local instance = {
        type = "directory",
        pattern = pattern,
        options = instance_options,
        lua_pattern = create_glob_pattern(pattern)
    }
    setmetatable(instance, { __index = DirectoryTrigger })

    local valid, err_validate = instance:validate()
    if not valid then
        return nil, err_validate
    end

    return instance
end

M.DirectoryTrigger = DirectoryTrigger

return M
