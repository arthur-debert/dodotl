-- Unit tests for the error codes module
-- Tests error code consistency and validation

describe("dodot.errors.codes", function()
    local codes

    before_each(function()
        codes = require("dodot.errors.codes")
    end)

    describe("module structure", function()
        it("should have required structure", function()
            assert.is_table(codes)
            assert.is_table(codes.codes)
            assert.is_table(codes.messages)
        end)

        it("should have non-empty codes array", function()
            assert.is_true(#codes.codes > 0)
        end)

        it("should have non-empty messages table", function()
            local count = 0
            for _, _ in pairs(codes.messages) do
                count = count + 1
            end
            assert.is_true(count > 0)
        end)
    end)

    describe("code consistency", function()
        it("should have message for every code", function()
            for _, code in ipairs(codes.codes) do
                assert.is_not_nil(codes.messages[code], "Code '" .. code .. "' has no message")
                assert.is_string(codes.messages[code], "Message for '" .. code .. "' is not a string")
            end
        end)

        it("should have code for every message", function()
            for message_code, _ in pairs(codes.messages) do
                local found = false
                for _, code in ipairs(codes.codes) do
                    if code == message_code then
                        found = true
                        break
                    end
                end
                assert.is_true(found, "Message for '" .. message_code .. "' has no code definition")
            end
        end)

        it("should have no duplicate codes", function()
            local seen = {}
            for _, code in ipairs(codes.codes) do
                assert.is_nil(seen[code], "Duplicate code: " .. code)
                seen[code] = true
            end
        end)
    end)

    describe("code format validation", function()
        it("should have properly formatted codes", function()
            for _, code in ipairs(codes.codes) do
                -- Should be UPPERCASE_WITH_UNDERSCORES
                assert.matches("^[A-Z_]+$", code, "Code '" .. code .. "' is not properly formatted")

                -- Should not start or end with underscore
                assert.is_not.matches("^_", code, "Code '" .. code .. "' starts with underscore")
                assert.is_not.matches("_$", code, "Code '" .. code .. "' ends with underscore")

                -- Should not have consecutive underscores
                assert.is_not.matches("__", code, "Code '" .. code .. "' has consecutive underscores")
            end
        end)

        it("should have descriptive codes", function()
            for _, code in ipairs(codes.codes) do
                -- Should be at least 3 characters
                assert.is_true(#code >= 3, "Code '" .. code .. "' is too short")

                -- Should be no more than 50 characters
                assert.is_true(#code <= 50, "Code '" .. code .. "' is too long")
            end
        end)
    end)

    describe("message format validation", function()
        it("should have actionable messages", function()
            for code, message in pairs(codes.messages) do
                -- Should be non-empty
                assert.is_true(#message > 0, "Message for '" .. code .. "' is empty")

                -- Should not end with period (for consistency)
                assert.is_not.matches("%.$", message, "Message for '" .. code .. "' ends with period")

                -- Should start with uppercase letter
                assert.matches("^[A-Z]", message, "Message for '" .. code .. "' doesn't start with uppercase")
            end
        end)
    end)

    describe("error categories", function()
        it("should have registry error codes", function()
            local registry_codes = {
                "REGISTRY_KEY_NOT_STRING",
                "REGISTRY_KEY_EMPTY",
                "REGISTRY_KEY_EXISTS",
                "REGISTRY_KEY_NOT_FOUND",
                "REGISTRY_VALUE_NIL"
            }

            for _, code in ipairs(registry_codes) do
                local found = false
                for _, defined_code in ipairs(codes.codes) do
                    if defined_code == code then
                        found = true
                        break
                    end
                end
                assert.is_true(found, "Registry code '" .. code .. "' not found")
            end
        end)

        it("should have configuration error codes", function()
            local config_codes = {
                "MISSING_DOTFILES_ROOT",
                "INVALID_DOTFILES_ROOT",
                "MALFORMED_CONFIG_FILE"
            }

            for _, code in ipairs(config_codes) do
                local found = false
                for _, defined_code in ipairs(codes.codes) do
                    if defined_code == code then
                        found = true
                        break
                    end
                end
                assert.is_true(found, "Configuration code '" .. code .. "' not found")
            end
        end)

        it("should have file system error codes", function()
            local fs_codes = {
                "PERMISSION_DENIED",
                "FILE_NOT_FOUND",
                "SYMLINK_FAILED",
                "FSYNTH_OPERATION_FAILED"
            }

            for _, code in ipairs(fs_codes) do
                local found = false
                for _, defined_code in ipairs(codes.codes) do
                    if defined_code == code then
                        found = true
                        break
                    end
                end
                assert.is_true(found, "File system code '" .. code .. "' not found")
            end
        end)
    end)

    describe("message format strings", function()
        it("should have format strings for parameterized messages", function()
            -- Messages that should have format parameters
            local parameterized = {
                "PACK_NOT_FOUND",
                "PERMISSION_DENIED",
                "FILE_NOT_FOUND",
                "INVALID_PACK_PATH",
                "REGISTRY_KEY_EXISTS",
                "REGISTRY_KEY_NOT_FOUND"
            }

            for _, code in ipairs(parameterized) do
                local message = codes.messages[code]
                assert.is_not_nil(message, "Message for '" .. code .. "' not found")
                assert.matches("%%s", message, "Message for '" .. code .. "' should have %s format string")
            end
        end)

        it("should not have format strings for non-parameterized messages", function()
            -- Messages that should not have format parameters
            local non_parameterized = {
                "MISSING_DOTFILES_ROOT",
                "REGISTRY_KEY_NOT_STRING",
                "REGISTRY_KEY_EMPTY",
                "REGISTRY_VALUE_NIL"
            }

            for _, code in ipairs(non_parameterized) do
                local message = codes.messages[code]
                assert.is_not_nil(message, "Message for '" .. code .. "' not found")
                assert.is_not.matches("%%s", message, "Message for '" .. code .. "' should not have %s format string")
            end
        end)
    end)
end)
