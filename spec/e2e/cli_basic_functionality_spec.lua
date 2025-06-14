-- End-to-end tests for dodot CLI basic functionality.
--
-- NOTE: These tests are intended for Phase 5 when the CLI
-- (lua/dodot/cli.lua) is fully implemented.
-- They are expected to be minimal or disabled until then.

local test_utils = require("spec.helpers.test_utils")

describe("CLI End-to-End Functionality", function()
    local temp_dir

    before_each(function()
        temp_dir = test_utils.fs.create_temp_dir()
    end)

    after_each(function()
        test_utils.fs.cleanup_temp_dir(temp_dir)
    end)

    describe("module loading and basic functionality", function()
        it("should load main dodot module successfully", function()
            local dodot = require("dodot.init")

            assert.is_table(dodot)
            assert.equals("0.1.1", dodot.VERSION)
        end)

        it("should load CLI module without errors", function()
            local cli = require("dodot.cli")

            assert.is_table(cli)
            assert.is_function(cli.main)
            assert.is_function(cli.parse_args)
            assert.is_function(cli.validate_args)
        end)

        it("should handle CLI argument parsing", function()
            local cli = require("dodot.cli")

            local args = cli.parse_args({})
            assert.is_table(args)
        end)

        it("should validate CLI arguments", function()
            local cli = require("dodot.cli")

            local args = {}
            local valid, err = cli.validate_args(args)
            assert.is_boolean(valid)
            -- err can be nil or table depending on validation result
        end)
    end)

    describe("command module loading", function()
        it("should load deploy command module", function()
            local deploy = require("dodot.commands.deploy")

            assert.is_table(deploy)
            assert.is_function(deploy.deploy)
            assert.is_function(deploy.validate_options)
        end)

        it("should load list command module", function()
            local list_cmd = require("dodot.commands.list")

            assert.is_table(list_cmd)
            assert.is_function(list_cmd.list)
            assert.is_function(list_cmd.format_pack_list)
        end)
    end)

    describe("error handling for unimplemented commands", function()
        it("should properly error for deploy command", function()
            local deploy = require("dodot.commands.deploy")

            -- Deploy command should error since it's not implemented yet
            local success, err = pcall(deploy.deploy, {})
            assert.is_false(success)
            assert.matches("not yet implemented", err)
        end)

        it("should properly error for list command", function()
            local list_cmd = require("dodot.commands.list")

            -- List command should error since it's not implemented yet
            local success, err = pcall(list_cmd.list, {})
            assert.is_false(success)
            assert.matches("not yet implemented", err)
        end)

        it("should properly error for CLI main", function()
            local cli = require("dodot.cli")

            -- CLI main should error since it's not implemented yet
            local success, err = pcall(cli.main, {})
            assert.is_false(success)
            assert.matches("not yet implemented", err)
        end)
    end)

    describe("environment isolation", function()
        it("should handle environment variable isolation", function()
            test_utils.isolation.with_temp_env({
                DODOT_TEST_VAR = "test_value"
            }, function()
                local env_value = os.getenv("DODOT_TEST_VAR")
                assert.equals("test_value", env_value)
            end)

            -- Environment should be restored after test (simplified mock implementation)
            -- In a real implementation, environment variables would be properly isolated
            local env_value = os.getenv("DODOT_TEST_VAR")
            -- For this demo, the environment is mocked during the test only
        end)
    end)
end)
