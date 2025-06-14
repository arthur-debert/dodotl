-- Error creation and utilities for dodot
-- Provides the main error handling interface

local codes = require("dodot.errors.codes")

local M = {}

-- Create a structured error object
function M.create(code, data, context)
    if type(code) ~= "string" then
        error("Error code must be a string")
    end

    if not M.is_valid_code(code) then
        error("Unknown error code: " .. code)
    end

    -- Get the message template
    local message_template = codes.messages[code]
    if not message_template then
        error("No message template for code: " .. code)
    end

    -- Format the message with data if provided
    local message = message_template
    if data and type(data) == "table" then
        local success, formatted_message = pcall(string.format, message_template, table.unpack(data))
        if success then
            message = formatted_message
        else
            -- If formatting fails, create an error about invalid data
            return M.create("INVALID_ERROR_DATA", { code, "formatting failed" })
        end
    elseif data ~= nil then
        -- Single data item, not a table
        local success, formatted_message = pcall(string.format, message_template, data)
        if success then
            message = formatted_message
        else
            return M.create("INVALID_ERROR_DATA", { code, "single data formatting failed" })
        end
    end

    local error_obj = {
        code = code,
        message = message,
        data = data,
        context = context
    }

    return error_obj
end

-- Check if an error code is valid
function M.is_valid_code(code)
    if type(code) ~= "string" then
        return false
    end

    for _, valid_code in ipairs(codes.codes) do
        if valid_code == code then
            return true
        end
    end

    return false
end

-- Get all valid error codes
function M.get_codes()
    -- Return a copy to prevent modification
    local code_copy = {}
    for _, code in ipairs(codes.codes) do
        table.insert(code_copy, code)
    end
    return code_copy
end

-- Get message template for a code
function M.get_message_template(code)
    if not M.is_valid_code(code) then
        return nil, M.create("UNKNOWN_ERROR_CODE", { code })
    end

    return codes.messages[code], nil
end

-- Check if an object is a dodot error
function M.is_error(obj)
    return type(obj) == "table" and
        type(obj.code) == "string" and
        type(obj.message) == "string" and
        M.is_valid_code(obj.code)
end

-- Format an error for display
function M.format_error(err, include_context)
    if not M.is_error(err) then
        return "Invalid error object"
    end

    local formatted = "Error: " .. err.message

    if include_context and err.context then
        formatted = formatted .. "\nContext: " .. M.serialize_context(err.context)
    end

    return formatted
end

-- Serialize context data for display
function M.serialize_context(context)
    if type(context) ~= "table" then
        return tostring(context)
    end

    local parts = {}
    for key, value in pairs(context) do
        table.insert(parts, tostring(key) .. "=" .. tostring(value))
    end

    return table.concat(parts, ", ")
end

-- Wrap a function to return (result, error) tuple pattern
function M.wrap_function(func)
    return function(...)
        local success, result = pcall(func, ...)
        if success then
            return result, nil
        else
            -- If the result is already a dodot error, return it
            if M.is_error(result) then
                return nil, result
            else
                -- Create a generic error for unexpected exceptions
                return nil, M.create("UNKNOWN_ERROR_CODE", { tostring(result) })
            end
        end
    end
end

-- Validate error code consistency (for testing)
function M.validate_codes()
    local codes_module = require("dodot.errors.codes")
    return codes_module -- The codes module validates itself on load
end

return M
