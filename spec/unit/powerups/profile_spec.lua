-- Tests for ProfilePowerup

describe("ProfilePowerup", function()
    local profile = require("dodot.powerups.profile")
    local pl_path = require("pl.path")
    local ProfilePowerup = profile.ProfilePowerup
    local SHELL_PROFILES = profile.SHELL_PROFILES

    local powerup
    local original_shell
    local original_home

    before_each(function()
        powerup = ProfilePowerup.new()
        original_shell = os.getenv("SHELL")
        original_home = os.getenv("HOME")
        -- Set predictable environment for tests
        os.getenv = function(var)
            if var == "SHELL" then
                return "/bin/bash"
            elseif var == "HOME" then
                return "/home/user"
            else
                return original_home
            end
        end
    end)

    after_each(function()
        -- Restore original os.getenv
        os.getenv = function(var)
            if var == "SHELL" then
                return original_shell
            elseif var == "HOME" then
                return original_home
            else
                return nil
            end
        end
    end)

    describe("new", function()
        it("should create a profile powerup instance", function()
            assert.is_not_nil(powerup)
            assert.equals("profile", powerup.name)
            assert.equals("profile_powerup", powerup.type)
        end)
    end)

    describe("validate", function()
        it("should validate with valid parameters", function()
            local matched_files = {
                { path = "/pack/aliases.sh", metadata = {} },
                { path = "/pack/exports.sh", metadata = {} }
            }
            local pack_path = "/pack"
            local options = { shell = "bash", action_type = "source" }

            local valid, err = powerup:validate(matched_files, pack_path, options)
            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should validate with empty matched_files", function()
            local valid, err = powerup:validate({}, "/pack", {})
            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should validate with nil matched_files", function()
            local valid, err = powerup:validate(nil, "/pack", {})
            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should reject empty pack_path", function()
            local valid, err = powerup:validate({}, "", {})
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("valid pack_path", err)
        end)

        it("should reject nil pack_path", function()
            local valid, err = powerup:validate({}, nil, {})
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("valid pack_path", err)
        end)

        it("should reject non-table matched_files", function()
            local valid, err = powerup:validate("invalid", "/pack", {})
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("must be a table", err)
        end)

        it("should reject non-table options", function()
            local valid, err = powerup:validate({}, "/pack", "invalid")
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("options must be a table", err)
        end)

        it("should reject invalid shell option", function()
            local options = { shell = 123 }
            local valid, err = powerup:validate({}, "/pack", options)
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("shell must be a string", err)
        end)

        it("should reject unsupported shell", function()
            local options = { shell = "invalidshell" }
            local valid, err = powerup:validate({}, "/pack", options)
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("unsupported shell", err)
        end)

        it("should reject invalid action_type option", function()
            local options = { action_type = 123 }
            local valid, err = powerup:validate({}, "/pack", options)
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("action_type must be a string", err)
        end)

        it("should reject unsupported action_type", function()
            local options = { action_type = "invalid_action" }
            local valid, err = powerup:validate({}, "/pack", options)
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("action_type must be one of", err)
        end)

        it("should accept valid action_types", function()
            local valid_actions = { "source", "append", "export_vars" }
            for _, action in ipairs(valid_actions) do
                local options = { action_type = action }
                local valid, err = powerup:validate({}, "/pack", options)
                assert.is_true(valid, "Action should be valid: " .. action .. " (error: " .. tostring(err) .. ")")
                assert.is_nil(err)
            end
        end)

        it("should reject invalid profile_preference option", function()
            local options = { profile_preference = 123 }
            local valid, err = powerup:validate({}, "/pack", options)
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("profile_preference must be a string", err)
        end)

        it("should reject invalid export_prefix option", function()
            local options = { export_prefix = 123 }
            local valid, err = powerup:validate({}, "/pack", options)
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("export_prefix must be a string", err)
        end)

        it("should reject file without path", function()
            local matched_files = { { metadata = {} } }
            local valid, err = powerup:validate(matched_files, "/pack", {})
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("must have a path string", err)
        end)

        it("should reject file outside pack_path", function()
            local matched_files = {
                { path = "/outside/file.sh", metadata = {} }
            }
            local valid, err = powerup:validate(matched_files, "/pack", {})
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("outside pack_path", err)
        end)
    end)

    describe("process", function()
        it("should return empty actions for empty matched_files", function()
            local actions, err = powerup:process({}, "/pack", {})
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(0, #actions)
        end)

        it("should return empty actions for nil matched_files", function()
            local actions, err = powerup:process(nil, "/pack", {})
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(0, #actions)
        end)

        it("should generate source actions by default", function()
            local matched_files = {
                { path = "/pack/aliases.sh", metadata = {} }
            }
            local pack_path = "/pack"
            local options = { shell = "bash" }

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(1, #actions)

            local action = actions[1]
            assert.equals("profile_source", action.type)
            assert.equals("/pack/aliases.sh", action.source_file)
            assert.equals("/home/user/.bashrc", action.profile_file)
            assert.equals("bash", action.shell)
            assert.equals("profile", action.metadata.powerup)
            assert.equals("source", action.metadata.action_type)
            assert.equals("aliases.sh", action.metadata.relative_source)
        end)

        it("should generate append actions", function()
            local matched_files = {
                { path = "/pack/exports.sh", metadata = {} }
            }
            local pack_path = "/pack"
            local options = { shell = "zsh", action_type = "append" }

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(1, #actions)

            local action = actions[1]
            assert.equals("profile_append", action.type)
            assert.equals("/pack/exports.sh", action.source_file)
            assert.equals("/home/user/.zshrc", action.profile_file)
            assert.equals("zsh", action.shell)
            assert.equals("append", action.metadata.action_type)
        end)

        it("should generate export_vars actions", function()
            local matched_files = {
                { path = "/pack/env.txt", metadata = {} }
            }
            local pack_path = "/pack"
            local options = {
                shell = "bash",
                action_type = "export_vars",
                export_prefix = "MYAPP_"
            }

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(1, #actions)

            local action = actions[1]
            assert.equals("profile_export_vars", action.type)
            assert.equals("/pack/env.txt", action.source_file)
            assert.equals("/home/user/.bashrc", action.profile_file)
            assert.equals("bash", action.shell)
            assert.equals("MYAPP_", action.export_prefix)
            assert.equals("export_vars", action.metadata.action_type)
        end)

        it("should detect shell automatically", function()
            local matched_files = {
                { path = "/pack/setup.sh", metadata = {} }
            }
            local pack_path = "/pack"

            local actions, err = powerup:process(matched_files, pack_path, {})
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(1, #actions)

            local action = actions[1]
            assert.equals("bash", action.shell) -- Should detect bash from mocked SHELL
            assert.equals("/home/user/.bashrc", action.profile_file)
        end)

        it("should handle different shells", function()
            local shells = { "bash", "zsh", "fish" }
            for _, shell in ipairs(shells) do
                local matched_files = { { path = "/pack/test.sh", metadata = {} } }
                local options = { shell = shell }

                local actions, err = powerup:process(matched_files, "/pack", options)
                assert.is_nil(err, "Shell should be supported: " .. shell)
                assert.is_table(actions)
                assert.equals(1, #actions)

                local action = actions[1]
                assert.equals(shell, action.shell)

                -- Check profile file matches expected pattern
                local expected_profile = SHELL_PROFILES[shell][1]
                assert.matches(expected_profile:gsub("%.", "%%."), action.profile_file)
            end
        end)

        it("should handle multiple files", function()
            local matched_files = {
                { path = "/pack/aliases.sh",   metadata = { type = "aliases" } },
                { path = "/pack/functions.sh", metadata = { type = "functions" } }
            }
            local pack_path = "/pack"
            local options = { shell = "bash", action_type = "source" }

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(2, #actions)

            -- Check that both files generated actions
            assert.equals("/pack/aliases.sh", actions[1].source_file)
            assert.equals("/pack/functions.sh", actions[2].source_file)

            -- Check that original metadata is preserved
            assert.equals("aliases", actions[1].metadata.original_metadata.type)
            assert.equals("functions", actions[2].metadata.original_metadata.type)
        end)

        it("should reject unsupported action_type", function()
            local matched_files = { { path = "/pack/test.sh", metadata = {} } }
            local options = { action_type = "invalid" }

            local actions, err = powerup:process(matched_files, "/pack", options)
            assert.is_nil(actions)
            assert.is_not_nil(err)
            assert.matches("Unsupported action_type", err)
        end)

        it("should reject unsupported shell", function()
            local matched_files = { { path = "/pack/test.sh", metadata = {} } }
            local options = { shell = "invalidshell" }

            local actions, err = powerup:process(matched_files, "/pack", options)
            assert.is_nil(actions)
            assert.is_not_nil(err)
            assert.matches("Unsupported shell", err)
        end)

        it("should default export_prefix to empty string", function()
            local matched_files = { { path = "/pack/env.txt", metadata = {} } }
            local options = { action_type = "export_vars" }

            local actions, err = powerup:process(matched_files, "/pack", options)
            assert.is_nil(err)
            assert.equals(1, #actions)
            assert.equals("", actions[1].export_prefix)
        end)
    end)
end)
