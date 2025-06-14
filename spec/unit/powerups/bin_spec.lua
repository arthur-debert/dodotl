-- Tests for BinPowerup

describe("BinPowerup", function()
    local bin = require("dodot.powerups.bin")
    local pl_path = require("pl.path")
    local BinPowerup = bin.BinPowerup

    local powerup
    local original_home

    before_each(function()
        powerup = BinPowerup.new()
        original_home = os.getenv("HOME")
        -- Set predictable environment for tests
        os.getenv = function(var)
            if var == "HOME" then
                return "/home/user"
            else
                return original_home
            end
        end
    end)

    after_each(function()
        -- Restore original os.getenv
        os.getenv = function(var)
            if var == "HOME" then
                return original_home
            else
                return nil
            end
        end
    end)

    describe("new", function()
        it("should create a bin powerup instance", function()
            assert.is_not_nil(powerup)
            assert.equals("bin", powerup.name)
            assert.equals("bin_powerup", powerup.type)
        end)
    end)

    describe("validate", function()
        it("should validate with valid parameters", function()
            local matched_files = {
                { path = "/pack/script.sh", metadata = {} },
                { path = "/pack/tool",      metadata = {} }
            }
            local pack_path = "/pack"
            local options = { bin_dir = "~/.local/bin" }

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

        it("should reject invalid bin_dir option", function()
            local options = { bin_dir = 123 }
            local valid, err = powerup:validate({}, "/pack", options)
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("bin_dir must be a string", err)
        end)

        it("should reject invalid add_to_path option", function()
            local options = { add_to_path = "true" }
            local valid, err = powerup:validate({}, "/pack", options)
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("add_to_path must be a boolean", err)
        end)

        it("should reject invalid make_executable option", function()
            local options = { make_executable = "true" }
            local valid, err = powerup:validate({}, "/pack", options)
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("make_executable must be a boolean", err)
        end)

        it("should reject invalid filter_executables option", function()
            local options = { filter_executables = "true" }
            local valid, err = powerup:validate({}, "/pack", options)
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("filter_executables must be a boolean", err)
        end)

        it("should reject invalid shell option", function()
            local options = { shell = 123 }
            local valid, err = powerup:validate({}, "/pack", options)
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("shell must be a string", err)
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
                { path = "/outside/script.sh", metadata = {} }
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

        it("should generate bin symlink actions for executables", function()
            local matched_files = {
                { path = "/pack/script.sh", metadata = {} },
                { path = "/pack/tool",      metadata = {} } -- no extension, should be considered executable
            }
            local pack_path = "/pack"
            local options = { bin_dir = "~/.local/bin" }

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(3, #actions) -- 2 symlinks + 1 PATH action

            -- Check first symlink action
            local action1 = actions[1]
            assert.equals("bin_symlink", action1.type)
            assert.equals("/pack/script.sh", action1.source_path)
            assert.equals("/home/user/.local/bin/script.sh", action1.target_path)
            assert.equals("/home/user/.local/bin", action1.bin_dir)
            assert.is_true(action1.make_executable)
            assert.equals("bin", action1.metadata.powerup)
            assert.equals("bin_symlink", action1.metadata.action_type)
            assert.equals("script.sh", action1.metadata.relative_source)

            -- Check second symlink action
            local action2 = actions[2]
            assert.equals("bin_symlink", action2.type)
            assert.equals("/pack/tool", action2.source_path)
            assert.equals("/home/user/.local/bin/tool", action2.target_path)

            -- Check PATH action
            local action3 = actions[3]
            assert.equals("bin_add_to_path", action3.type)
            assert.equals("/home/user/.local/bin", action3.bin_dir)
            assert.equals("bash", action3.shell) -- default shell
            assert.equals("bin", action3.metadata.powerup)
            assert.equals("add_to_path", action3.metadata.action_type)
            assert.equals(2, action3.metadata.files_count)
        end)

        it("should filter non-executable files when filter_executables is true", function()
            local matched_files = {
                { path = "/pack/script.sh",  metadata = {} }, -- executable
                { path = "/pack/readme.txt", metadata = {} }, -- not executable
                { path = "/pack/tool",       metadata = {} }  -- executable (no extension)
            }
            local pack_path = "/pack"
            local options = { filter_executables = true }

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(3, #actions) -- 2 symlinks + 1 PATH action (readme.txt filtered out)

            -- Verify only executables are processed
            assert.equals("/pack/script.sh", actions[1].source_path)
            assert.equals("/pack/tool", actions[2].source_path)
        end)

        it("should include all files when filter_executables is false", function()
            local matched_files = {
                { path = "/pack/script.sh",  metadata = {} },
                { path = "/pack/readme.txt", metadata = {} },
                { path = "/pack/tool",       metadata = {} }
            }
            local pack_path = "/pack"
            local options = { filter_executables = false }

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(4, #actions) -- 3 symlinks + 1 PATH action (all files included)
        end)

        it("should use default bin directory when not specified", function()
            local matched_files = {
                { path = "/pack/script.sh", metadata = {} }
            }
            local pack_path = "/pack"

            local actions, err = powerup:process(matched_files, pack_path, {})
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(2, #actions) -- 1 symlink + 1 PATH action

            local action = actions[1]
            assert.equals("/home/user/.local/bin/script.sh", action.target_path)
            assert.equals("/home/user/.local/bin", action.bin_dir)
        end)

        it("should expand tilde in bin_dir", function()
            local matched_files = {
                { path = "/pack/script.sh", metadata = {} }
            }
            local pack_path = "/pack"
            local options = { bin_dir = "~/bin" }

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(2, #actions)

            local action = actions[1]
            assert.equals("/home/user/bin/script.sh", action.target_path)
            assert.equals("/home/user/bin", action.bin_dir)
        end)

        it("should respect make_executable option", function()
            local matched_files = {
                { path = "/pack/script.sh", metadata = {} }
            }
            local pack_path = "/pack"
            local options = { make_executable = false }

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(2, #actions)

            local action = actions[1]
            assert.is_false(action.make_executable)
        end)

        it("should skip PATH action when add_to_path is false", function()
            local matched_files = {
                { path = "/pack/script.sh", metadata = {} }
            }
            local pack_path = "/pack"
            local options = { add_to_path = false }

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(1, #actions) -- Only symlink action, no PATH action

            local action = actions[1]
            assert.equals("bin_symlink", action.type)
        end)

        it("should use specified shell for PATH action", function()
            local matched_files = {
                { path = "/pack/script.sh", metadata = {} }
            }
            local pack_path = "/pack"
            local options = { shell = "zsh" }

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(2, #actions)

            local path_action = actions[2]
            assert.equals("bin_add_to_path", path_action.type)
            assert.equals("zsh", path_action.shell)
        end)

        it("should handle multiple executable types", function()
            local matched_files = {
                { path = "/pack/script.sh",  metadata = {} },
                { path = "/pack/program.py", metadata = {} },
                { path = "/pack/tool.lua",   metadata = {} },
                { path = "/pack/binary",     metadata = {} } -- no extension
            }
            local pack_path = "/pack"
            local options = { filter_executables = true }

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(5, #actions) -- 4 symlinks + 1 PATH action

            -- All should be considered executable
            assert.equals("bin_symlink", actions[1].type)
            assert.equals("bin_symlink", actions[2].type)
            assert.equals("bin_symlink", actions[3].type)
            assert.equals("bin_symlink", actions[4].type)
            assert.equals("bin_add_to_path", actions[5].type)
        end)

        it("should preserve original metadata", function()
            local matched_files = {
                { path = "/pack/script.sh", metadata = { type = "shell", version = "1.0" } }
            }
            local pack_path = "/pack"

            local actions, err = powerup:process(matched_files, pack_path, {})
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(2, #actions)

            local action = actions[1]
            assert.is_table(action.metadata.original_metadata)
            assert.equals("shell", action.metadata.original_metadata.type)
            assert.equals("1.0", action.metadata.original_metadata.version)
        end)

        it("should skip PATH action when no files to process", function()
            local matched_files = {
                { path = "/pack/readme.txt", metadata = {} } -- not executable
            }
            local pack_path = "/pack"
            local options = { filter_executables = true } -- will filter out readme.txt

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(0, #actions) -- No actions since no executables
        end)
    end)
end)
