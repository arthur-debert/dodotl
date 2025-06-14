-- FileNameTrigger implementation
-- Matches files based on filename patterns with globbing support,
-- case sensitivity, recursion, and exclusion patterns.

local pl_path = require("pl.path")
local M = {}

-- Helper function to create a Lua pattern from a glob pattern
local function create_lua_pattern(glob_pattern, case_sensitive)
    local p = glob_pattern
    -- Escape Lua magic characters, except for * and ? which are glob wildcards
    p = p:gsub("[%(%)%.%%%+%-%[%]%^%$]", "%%%1")
    -- Convert glob wildcards to Lua patterns
    p = p:gsub("%*", ".*") -- '*' matches any sequence of characters
    p = p:gsub("%?", ".")  -- '?' matches any single character

    -- Handle directory separators carefully if patterns can include them
    -- For now, assume patterns are typically for filenames or simple relative paths.
    -- If a pattern contains '/', it implies path structure.
    -- If not, it matches against the basename or relative path based on recursion.

    if not case_sensitive then
        p = p:lower() -- Convert pattern to lowercase if case-insensitive
    end
    return "^" .. p .. "$"
end

local FileNameTrigger = {
    type = "file_name",

    match = function(self, file_path, pack_path)
        if not file_path or not pack_path then
            return false, nil
        end

        local relative_path = pl_path.relpath(file_path, pack_path)
        if relative_path == "" or relative_path:match("^%.%./") then -- file outside pack or is pack itself
            return false, nil
        end

        local path_to_match
        if not self.options.recursive then
            -- Non-recursive: only match if file is directly in pack_path
            if relative_path:find("[/\\]") then -- Checks if it's in a subdirectory
                return false, nil
            end
            path_to_match = pl_path.basename(file_path) -- Match against basename
        else
            -- Recursive: match against relative path
            path_to_match = relative_path
        end

        local str_to_match = path_to_match
        if not self.options.case_sensitive then
            str_to_match = str_to_match:lower()
        end

        local matched_pattern_value = nil
        local main_match = false

        for i, compiled_pattern in ipairs(self.compiled_patterns) do
            if str_to_match:match(compiled_pattern) then
                main_match = true
                matched_pattern_value = self.patterns[i] -- Store the original glob pattern
                break
            end
        end

        if not main_match then
            return false, nil
        end

        -- Check exclude patterns
        if self.compiled_exclude_patterns and #self.compiled_exclude_patterns > 0 then
            for _, compiled_exclude_pattern in ipairs(self.compiled_exclude_patterns) do
                if str_to_match:match(compiled_exclude_pattern) then
                    return false, nil -- Matched an exclude pattern
                end
            end
        end

        local metadata = {
            matched_pattern = matched_pattern_value,
            filename = pl_path.basename(file_path), -- Always provide basename
            relative_path = relative_path,
            full_path = file_path,
            options_used = self.options
        }
        return true, metadata
    end,

    validate = function(self)
        if not self.patterns or type(self.patterns) ~= "table" or #self.patterns == 0 then
            return false, "FileNameTrigger requires a non-empty table of patterns"
        end
        for i, pattern_str in ipairs(self.patterns) do
            if type(pattern_str) ~= "string" or pattern_str == "" then
                return false, "Pattern at index " .. i .. " must be a non-empty string"
            end
            local success, err = pcall(create_lua_pattern, pattern_str, self.options.case_sensitive)
            if not success then
                return false, "Invalid glob pattern '" .. pattern_str .. "': " .. tostring(err)
            end
        end

        if self.options.exclude_patterns then
            if type(self.options.exclude_patterns) ~= "table" then
                return false, "FileNameTrigger exclude_patterns must be a table of strings"
            end
            for i, pattern_str in ipairs(self.options.exclude_patterns) do
                if type(pattern_str) ~= "string" or pattern_str == "" then
                    return false, "Exclude pattern at index " .. i .. " must be a non-empty string"
                end
                local success, err = pcall(create_lua_pattern, pattern_str, self.options.case_sensitive)
                if not success then
                    return false, "Invalid exclude glob pattern '" .. pattern_str .. "': " .. tostring(err)
                end
            end
        end

        if self.options.case_sensitive ~= nil and type(self.options.case_sensitive) ~= "boolean" then
            return false, "FileNameTrigger case_sensitive option must be a boolean"
        end
        if self.options.recursive ~= nil and type(self.options.recursive) ~= "boolean" then
            return false, "FileNameTrigger recursive option must be a boolean"
        end

        return true, nil
    end
}

function FileNameTrigger.new(patterns, options)
    options = options or {} -- Ensure options table exists

    -- Handle single pattern string for backward compatibility or convenience
    local patterns_table = patterns
    if type(patterns) == "string" then
        patterns_table = { patterns }
    end

    if not patterns_table or type(patterns_table) ~= "table" or #patterns_table == 0 then
        return nil, "FileNameTrigger requires a non-empty pattern or table of patterns"
    end
    for i, pattern_str in ipairs(patterns_table) do
        if type(pattern_str) ~= "string" or pattern_str == "" then
            return nil, "Pattern at index " .. i .. " must be a non-empty string"
        end
    end

    local instance_options = {
        case_sensitive = options.case_sensitive == nil and true or options.case_sensitive,
        recursive = options.recursive or false,
        exclude_patterns = options.exclude_patterns or {}
    }

    -- Defer validation to validate() method to allow tests to create instances with invalid options
    -- Only do basic validation that's needed for compilation
    local exclude_patterns_for_compilation = {}
    if type(instance_options.exclude_patterns) == "table" then
        for _, p_str in ipairs(instance_options.exclude_patterns) do
            if type(p_str) == "string" and p_str ~= "" then
                table.insert(exclude_patterns_for_compilation, p_str)
            end
        end
    end

    local compiled_patterns = {}
    for _, p_str in ipairs(patterns_table) do
        -- Use default case sensitivity for compilation if invalid option provided
        local case_sensitive_for_compilation
        if type(instance_options.case_sensitive) == "boolean" then
            case_sensitive_for_compilation = instance_options.case_sensitive
        else
            case_sensitive_for_compilation = true
        end
        table.insert(compiled_patterns, create_lua_pattern(p_str, case_sensitive_for_compilation))
    end

    local compiled_exclude_patterns = {}
    for _, p_str in ipairs(exclude_patterns_for_compilation) do
        -- Use default case sensitivity for compilation if invalid option provided
        local case_sensitive_for_compilation
        if type(instance_options.case_sensitive) == "boolean" then
            case_sensitive_for_compilation = instance_options.case_sensitive
        else
            case_sensitive_for_compilation = true
        end
        table.insert(compiled_exclude_patterns, create_lua_pattern(p_str, case_sensitive_for_compilation))
    end

    local instance = {
        type = "file_name",
        patterns = patterns_table,
        options = instance_options,
        compiled_patterns = compiled_patterns,
        compiled_exclude_patterns = compiled_exclude_patterns,
    }
    setmetatable(instance, { __index = FileNameTrigger })

    -- Don't validate during construction - let validate() method handle it
    -- This allows tests to create instances with invalid options for testing
    return instance
end

M.FileNameTrigger = FileNameTrigger

return M
