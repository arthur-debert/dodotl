-- Unit tests for the error handling system
-- Tests error creation, validation, and utilities

local test_utils = require("spec.helpers.test_utils")

describe("dodot.errors", function()
    local errors

    before_each(function()
        errors = require("dodot.errors.init")
    end)

    describe("error creation", function()
        it("should create basic error objects", function()
            local err = errors.create("MISSING_DOTFILES_ROOT")

            assert.is_table(err)
            assert.equals("MISSING_DOTFILES_ROOT", err.code)
            assert.equals("DOTFILES_ROOT not set. Set environment variable or use --dotfiles-root", err.message)
            assert.is_nil(err.data)
            assert.is_nil(err.context)
        end)

        it("should create errors with single data parameter", function()
            local err = errors.create("PACK_NOT_FOUND", "/invalid/path")

            assert.equals("PACK_NOT_FOUND", err.code)
            assert.equals("Pack not found: /invalid/path", err.message)
            assert.equals("/invalid/path", err.data)
        end)

        it("should create errors with table data", function()
            local err = errors.create("SYMLINK_FAILED", { "/source", "/target" })

            assert.equals("SYMLINK_FAILED", err.code)
            assert.equals("Failed to create symlink from /source to /target", err.message)
            assert.are.same({ "/source", "/target" }, err.data)
        end)

        it("should create errors with context", function()
            local context = { operation = "deploy", pack = "vim-config" }
            local err = errors.create("PERMISSION_DENIED", "/protected/file", context)

            assert.equals("PERMISSION_DENIED", err.code)
            assert.equals("Permission denied accessing: /protected/file", err.message)
            assert.equals("/protected/file", err.data)
            assert.are.same(context, err.context)
        end)

        it("should reject invalid error codes", function()
            assert.has_error(function()
                errors.create("INVALID_CODE")
            end, "Unknown error code: INVALID_CODE")
        end)

        it("should reject non-string error codes", function()
            assert.has_error(function()
                errors.create(123)
            end, "Error code must be a string")
        end)
    end)

    describe("error code validation", function()
        it("should validate existing error codes", function()
            assert.is_true(errors.is_valid_code("MISSING_DOTFILES_ROOT"))
            assert.is_true(errors.is_valid_code("PACK_NOT_FOUND"))
            assert.is_true(errors.is_valid_code("REGISTRY_KEY_EXISTS"))
        end)

        it("should reject invalid error codes", function()
            assert.is_false(errors.is_valid_code("INVALID_CODE"))
            assert.is_false(errors.is_valid_code(""))
            assert.is_false(errors.is_valid_code(nil))
            assert.is_false(errors.is_valid_code(123))
        end)
    end)

    describe("get_codes method", function()
        it("should return all valid error codes", function()
            local codes = errors.get_codes()

            assert.is_table(codes)
            assert.is_true(#codes > 0)

            -- Check that some expected codes exist
            local has_registry_error = false
            local has_config_error = false
            for _, code in ipairs(codes) do
                if code == "REGISTRY_KEY_NOT_FOUND" then
                    has_registry_error = true
                elseif code == "MISSING_DOTFILES_ROOT" then
                    has_config_error = true
                end
            end
            assert.is_true(has_registry_error)
            assert.is_true(has_config_error)
        end)

        it("should return a copy that can't modify the original", function()
            local codes1 = errors.get_codes()
            local codes2 = errors.get_codes()

            -- Modify the first copy
            table.insert(codes1, "TEST_CODE")

            -- Second copy should be unaffected
            assert.is_not.equals(#codes1, #codes2)
        end)
    end)

    describe("get_message_template method", function()
        it("should return message templates for valid codes", function()
            local template, err = errors.get_message_template("PACK_NOT_FOUND")

            assert.equals("Pack not found: %s", template)
            assert.is_nil(err)
        end)

        it("should handle invalid codes", function()
            local template, err = errors.get_message_template("INVALID_CODE")

            assert.is_nil(template)
            assert.is_table(err)
            assert.equals("UNKNOWN_ERROR_CODE", err.code)
        end)
    end)

    describe("is_error method", function()
        it("should identify valid error objects", function()
            local err = errors.create("PACK_NOT_FOUND", "/test/path")

            assert.is_true(errors.is_error(err))
        end)

        it("should reject invalid objects", function()
            assert.is_false(errors.is_error(nil))
            assert.is_false(errors.is_error("string"))
            assert.is_false(errors.is_error(123))
            assert.is_false(errors.is_error({}))
            assert.is_false(errors.is_error({ code = "VALID", message = 123 }))           -- invalid message type
            assert.is_false(errors.is_error({ code = "INVALID_CODE", message = "test" })) -- invalid code
        end)
    end)

    describe("format_error method", function()
        it("should format basic errors", function()
            local err = errors.create("PACK_NOT_FOUND", "/test/path")
            local formatted = errors.format_error(err)

            assert.equals("Error: Pack not found: /test/path", formatted)
        end)

        it("should format errors with context when requested", function()
            local context = { operation = "deploy", pack = "vim" }
            local err = errors.create("PERMISSION_DENIED", "/test/file", context)
            local formatted = errors.format_error(err, true)

            assert.matches("Error: Permission denied accessing: /test/file", formatted)
            assert.matches("Context:", formatted)
            assert.matches("operation=deploy", formatted)
            assert.matches("pack=vim", formatted)
        end)

        it("should handle invalid error objects", function()
            local formatted = errors.format_error("not an error")

            assert.equals("Invalid error object", formatted)
        end)
    end)

    describe("serialize_context method", function()
        it("should serialize table context", function()
            local context = { operation = "deploy", pack = "vim", count = 3 }
            local serialized = errors.serialize_context(context)

            -- Should contain all key-value pairs (order may vary)
            assert.matches("operation=deploy", serialized)
            assert.matches("pack=vim", serialized)
            assert.matches("count=3", serialized)
        end)

        it("should handle non-table context", function()
            assert.equals("test string", errors.serialize_context("test string"))
            assert.equals("42", errors.serialize_context(42))
            assert.equals("true", errors.serialize_context(true))
        end)
    end)

    describe("error data formatting", function()
        it("should handle format strings correctly", function()
            local err = errors.create("INVALID_TRIGGER_CONFIG", { "pack.toml", "missing field" })

            assert.equals("Invalid trigger in pack.toml: missing field", err.message)
        end)

        it("should handle single format parameter", function()
            local err = errors.create("FILE_NOT_FOUND", "/missing/file.txt")

            assert.equals("File not found: /missing/file.txt", err.message)
        end)

        it("should handle errors with no format parameters", function()
            local err = errors.create("MISSING_DOTFILES_ROOT")

            assert.equals("DOTFILES_ROOT not set. Set environment variable or use --dotfiles-root", err.message)
        end)
    end)

    describe("integration with test helpers", function()
        it("should work with test_utils.errors.assert_error_code", function()
            local err = errors.create("PACK_NOT_FOUND", "/test/path")

            -- This should not throw
            test_utils.errors.assert_error_code("PACK_NOT_FOUND", nil, err)
        end)

        it("should work with test_utils.errors.assert_success", function()
            local result = { data = "test" }

            -- This should not throw
            test_utils.errors.assert_success(result, nil)
        end)
    end)

    describe("error code consistency", function()
        it("should have valid codes module", function()
            local codes_module = errors.validate_codes()

            assert.is_table(codes_module)
            assert.is_table(codes_module.codes)
            assert.is_table(codes_module.messages)
        end)

        it("should have all registry error codes available", function()
            -- Test that registry-related error codes are available
            assert.is_true(errors.is_valid_code("REGISTRY_KEY_NOT_STRING"))
            assert.is_true(errors.is_valid_code("REGISTRY_KEY_EMPTY"))
            assert.is_true(errors.is_valid_code("REGISTRY_KEY_EXISTS"))
            assert.is_true(errors.is_valid_code("REGISTRY_KEY_NOT_FOUND"))
            assert.is_true(errors.is_valid_code("REGISTRY_VALUE_NIL"))
        end)
    end)
end)
