-- FileNameTrigger implementation
-- Matches files based on filename patterns with globbing support

local M = {}

local function create_glob_pattern(pattern)
    -- Convert shell-style globbing to Lua pattern
    -- * -> .*
    -- ? -> .
    -- [abc] -> [abc] (unchanged)
    -- Escape special Lua pattern characters: ( ) . % + - * ? [ ^ $
    local lua_pattern = pattern:gsub("[%(%)%.%%+%-*%?%[%^%$]", function(c)
        if c == "*" then
            return ".*"
        elseif c == "?" then
            return "."
        else
            return "%" .. c -- Escape other special characters
        end
    end)
    return "^" .. lua_pattern .. "$"
end

local FileNameTrigger = {
    type = "file_name",

    -- Match function that checks if a file path matches the pattern
    match = function(self, file_path, pack_path)
        if not file_path then
            return false, nil
        end

        -- Extract just the filename from the full path
        local filename = file_path:match("([^/\\]+)$") or file_path

        -- Test against the glob pattern
        local matches = filename:match(self.lua_pattern) ~= nil

        local metadata = nil
        if matches then
            metadata = {
                matched_pattern = self.pattern,
                filename = filename,
                full_path = file_path
            }
        end

        return matches, metadata
    end,

    -- Validate the trigger configuration
    validate = function(self)
        if not self.pattern or self.pattern == "" then
            return false, "FileNameTrigger pattern cannot be empty"
        end

        -- Test that the pattern compiles to a valid Lua pattern
        local success, err = pcall(string.match, "test", self.lua_pattern)
        if not success then
            return false, "Invalid glob pattern: " .. self.pattern .. " (Lua pattern error: " .. tostring(err) .. ")"
        end

        return true, nil
    end
}

-- Initialize the trigger with pattern configuration
function FileNameTrigger.new(pattern)
    if not pattern or pattern == "" then
        return nil, "FileNameTrigger requires a non-empty pattern"
    end

    local instance = {
        type = "file_name",
        pattern = pattern,
        lua_pattern = create_glob_pattern(pattern)
    }
    setmetatable(instance, { __index = FileNameTrigger })
    return instance
end

M.FileNameTrigger = FileNameTrigger

return M
