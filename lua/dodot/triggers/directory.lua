-- DirectoryTrigger implementation
-- Matches files based on directory path patterns

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
    match = function(self, file_path, pack_path)
        if not file_path then
            return false, nil
        end

        -- Get the directory part of the file path
        local dir_path = file_path:match("(.*/)")
        if not dir_path then
            -- File is in root directory
            dir_path = ""
        else
            -- Remove trailing slash
            dir_path = dir_path:sub(1, -2)
        end

        -- Make path relative to pack_path if it's an absolute path within the pack
        if pack_path and dir_path:sub(1, #pack_path) == pack_path then
            dir_path = dir_path:sub(#pack_path + 2) -- +2 to skip the following /
            if not dir_path then
                dir_path = ""
            end
        end

        -- Special handling for ** patterns
        local matches = false
        if self.pattern:match("%*%*") then
            matches = self:match_double_wildcard(dir_path)
        else
            -- Test against the regular glob pattern
            matches = dir_path:match(self.lua_pattern) ~= nil
        end

        local metadata = nil
        if matches then
            metadata = {
                matched_pattern = self.pattern,
                directory = dir_path,
                full_path = file_path
            }
        end

        return matches, metadata
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
        if not self.pattern then
            return false, "DirectoryTrigger pattern cannot be nil"
        end

        -- Test that the pattern compiles to a valid Lua pattern
        local success, err = pcall(string.match, "test", self.lua_pattern)
        if not success then
            return false,
                "Invalid directory pattern: " .. self.pattern .. " (Lua pattern error: " .. tostring(err) .. ")"
        end

        return true, nil
    end
}

-- Initialize the trigger with pattern configuration
function DirectoryTrigger.new(pattern)
    if pattern == nil then
        return nil, "DirectoryTrigger requires a pattern (use empty string for root directory)"
    end

    local instance = {
        type = "directory",
        pattern = pattern,
        lua_pattern = create_glob_pattern(pattern)
    }
    setmetatable(instance, { __index = DirectoryTrigger })
    return instance
end

M.DirectoryTrigger = DirectoryTrigger

return M
