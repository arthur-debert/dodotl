-- ExtensionTrigger implementation
-- Matches files based on file extension patterns

local M = {}

local ExtensionTrigger = {
    type = "extension",

    -- Match function that checks if a file extension matches
    match = function(self, file_path, pack_path)
        if not file_path then
            return false, nil
        end

        -- Extract filename from path
        local filename = file_path:match("([^/\\]+)$") or file_path

        -- Extract extension (everything after the last dot, including the dot)
        local extension = filename:match("(%.[^%.]+)$")
        if not extension then
            -- No extension found
            return false, nil
        end

        -- Convert to lowercase for case-insensitive matching
        extension = extension:lower()

        -- Check if extension matches any of the configured extensions
        for _, target_ext in ipairs(self.extensions) do
            if extension == target_ext then
                local metadata = {
                    matched_extension = extension,
                    filename = filename,
                    full_path = file_path
                }
                return true, metadata
            end
        end

        return false, nil
    end,

    -- Validate the trigger configuration
    validate = function(self)
        if not self.extensions or #self.extensions == 0 then
            return false, "ExtensionTrigger must have at least one extension"
        end

        for i, ext in ipairs(self.extensions) do
            if type(ext) ~= "string" or ext == "" then
                return false, "Extension " .. i .. " must be a non-empty string"
            end

            if not ext:match("^%.") then
                return false, "Extension " .. i .. " must start with a dot: " .. ext
            end
        end

        return true, nil
    end
}

-- Initialize the trigger with extension configuration
function ExtensionTrigger.new(extensions)
    if not extensions then
        return nil, "ExtensionTrigger requires extension configuration"
    end

    -- Handle single extension as string or table of extensions
    local ext_list = {}
    if type(extensions) == "string" then
        ext_list = { extensions }
    elseif type(extensions) == "table" then
        ext_list = extensions
    else
        return nil, "ExtensionTrigger extensions must be string or table"
    end

    if #ext_list == 0 then
        return nil, "ExtensionTrigger requires at least one extension"
    end

    -- Normalize extensions (add leading dot if missing, convert to lowercase)
    local normalized_extensions = {}
    for _, ext in ipairs(ext_list) do
        if type(ext) ~= "string" or ext == "" then
            return nil, "All extensions must be non-empty strings"
        end

        local normalized = ext:lower()
        if not normalized:match("^%.") then
            normalized = "." .. normalized
        end
        table.insert(normalized_extensions, normalized)
    end

    local instance = {
        type = "extension",
        extensions = normalized_extensions,
        original_config = extensions
    }
    setmetatable(instance, { __index = ExtensionTrigger })
    return instance
end

M.ExtensionTrigger = ExtensionTrigger

return M
