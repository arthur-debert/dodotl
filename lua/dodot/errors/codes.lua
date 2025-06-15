-- Error codes and message templates for dodot
-- All errors must have unique codes defined here

local M = {
    codes = {
        -- Registry Errors
        "REGISTRY_KEY_NOT_STRING",
        "REGISTRY_KEY_EMPTY",
        "REGISTRY_KEY_EXISTS",
        "REGISTRY_KEY_NOT_FOUND",
        "REGISTRY_VALUE_NIL",

        -- Configuration Errors
        "MISSING_DOTFILES_ROOT",
        "INVALID_DOTFILES_ROOT",
        "MALFORMED_CONFIG_FILE",

        -- Pack Errors
        "PACK_NOT_FOUND",
        "PACK_ACCESS_DENIED",
        "PACK_IGNORED",
        "INVALID_PACK_PATH",

        -- Trigger/Matcher Errors
        "INVALID_TRIGGER_CONFIG",
        "TRIGGER_VALIDATION_FAILED",
        "TRIGGER_NOT_FOUND",
        "MATCHER_CONFLICT",

        -- Power-up Errors
        "POWERUP_NOT_FOUND",
        "POWERUP_VALIDATION_FAILED",
        "POWERUP_EXECUTION_FAILED",

        -- File System Errors
        "PERMISSION_DENIED",
        "FILE_NOT_FOUND",
        "SYMLINK_FAILED",
        "FSYNTH_OPERATION_FAILED",
        "INVALID_ACTION_DATA",
        "UNKNOWN_OPERATION_TYPE",
        "EXECUTION_FAILED",
        "VALIDATION_FAILED",
        -- "MISSING_HOME_DIR", -- Removed duplicate, will keep the one under System Errors for clarity

        -- CLI Errors
        "INVALID_COMMAND_ARGS",
        "MISSING_REQUIRED_ARG",

        -- System Errors
        "DUPLICATE_ERROR_CODE",
        "UNKNOWN_ERROR_CODE",
        "INVALID_ERROR_DATA",
        "MISSING_HOME_DIR", -- Added new error code
        "UNSUPPORTED_SHELL" -- Added for shell_add_path action
    },

    messages = {
        -- Registry Errors
        REGISTRY_KEY_NOT_STRING = "Registry key must be a string",
        REGISTRY_KEY_EMPTY = "Registry key cannot be empty",
        REGISTRY_KEY_EXISTS = "Registry key '%s' already exists",
        REGISTRY_KEY_NOT_FOUND = "Registry key '%s' not found",
        REGISTRY_VALUE_NIL = "Registry value cannot be nil",

        -- Configuration Errors
        MISSING_DOTFILES_ROOT = "DOTFILES_ROOT not set. Set environment variable or use --dotfiles-root",
        INVALID_DOTFILES_ROOT = "Invalid dotfiles root directory: %s",
        MALFORMED_CONFIG_FILE = "Malformed configuration file: %s",

        -- Pack Errors
        PACK_NOT_FOUND = "Pack not found: %s",
        PACK_ACCESS_DENIED = "Access denied to pack: %s",
        PACK_IGNORED = "Pack ignored due to ignore pattern: %s",
        INVALID_PACK_PATH = "Pack path does not exist: %s",

        -- Trigger/Matcher Errors
        INVALID_TRIGGER_CONFIG = "Invalid trigger in %s: %s",
        TRIGGER_VALIDATION_FAILED = "Trigger validation failed for %s: %s",
        TRIGGER_NOT_FOUND = "Trigger not found: %s",
        MATCHER_CONFLICT = "Matcher conflict between %s and %s",

        -- Power-up Errors
        POWERUP_NOT_FOUND = "Power-up not found: %s",
        POWERUP_VALIDATION_FAILED = "Power-up validation failed for %s: %s",
        POWERUP_EXECUTION_FAILED = "Power-up execution failed: %s",

        -- File System Errors
        PERMISSION_DENIED = "Permission denied accessing: %s",
        FILE_NOT_FOUND = "File not found: %s",
        SYMLINK_FAILED = "Failed to create symlink from %s to %s",
        FSYNTH_OPERATION_FAILED = "File system operation failed: %s",
        INVALID_ACTION_DATA = "Invalid action data for type %s: %s",
        UNKNOWN_OPERATION_TYPE = "Unknown operation type: %s",
        EXECUTION_FAILED = "Execution failed: %s",
        VALIDATION_FAILED = "Validation failed: %s",
        -- MISSING_HOME_DIR = "User home directory could not be determined.", -- Removed shorter message

        -- CLI Errors
        INVALID_COMMAND_ARGS = "Invalid command arguments: %s",
        MISSING_REQUIRED_ARG = "Missing required argument: %s",

        -- System Errors
        DUPLICATE_ERROR_CODE = "Error code '%s' already exists",
        UNKNOWN_ERROR_CODE = "Unknown error code: %s",
        INVALID_ERROR_DATA = "Invalid error data for code %s: %s",
        MISSING_HOME_DIR =
        "User home directory could not be determined. Failed to find HOME or USERPROFILE environment variables",
        UNSUPPORTED_SHELL = "Unsupported shell type: %s"
    }
}

-- Validate that all codes have messages and vice versa
local function validate_codes()
    local errors = {}

    -- Check that all codes have messages
    for _, code in ipairs(M.codes) do
        if not M.messages[code] then
            table.insert(errors, "Code '" .. code .. "' has no message")
        end
    end

    -- Check that all messages have codes
    for code, _ in pairs(M.messages) do
        local found = false
        for _, defined_code in ipairs(M.codes) do
            if defined_code == code then
                found = true
                break
            end
        end
        if not found then
            table.insert(errors, "Message for '" .. code .. "' has no code definition")
        end
    end

    -- Check for duplicate codes
    local seen = {}
    for _, code in ipairs(M.codes) do
        if seen[code] then
            table.insert(errors, "Duplicate code: " .. code)
        end
        seen[code] = true
    end

    return errors
end

-- Run validation on module load
local validation_errors = validate_codes()
if #validation_errors > 0 then
    error("Error code validation failed:\n" .. table.concat(validation_errors, "\n"))
end

return M
