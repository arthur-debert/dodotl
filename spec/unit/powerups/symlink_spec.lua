-- Tests for SymlinkPowerup

describe("SymlinkPowerup", function()
    local symlink = require("dodot.powerups.symlink")
    local pl_path = require("pl.path")
    local SymlinkPowerup = symlink.SymlinkPowerup

    local powerup

    before_each(function()
        powerup = SymlinkPowerup.new()
    end)

    describe("new", function()
        it("should create a symlink powerup instance", function()
            assert.is_not_nil(powerup)
            assert.equals("symlink", powerup.name)
            assert.equals("symlink_powerup", powerup.type)
        end)
    end)

    describe("validate", function()
        it("should validate with valid parameters", function()
            local matched_files = {
                { path = "/pack/file1.txt", metadata = {} },
                { path = "/pack/file2.txt", metadata = {} }
            }
            local pack_path = "/pack"
            local options = { target_dir = "~/.config" }

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

        it("should reject invalid target_dir option", function()
            local options = { target_dir = 123 }
            local valid, err = powerup:validate({}, "/pack", options)
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("target_dir must be a string", err)
        end)

        it("should reject invalid create_dirs option", function()
            local options = { create_dirs = "true" }
            local valid, err = powerup:validate({}, "/pack", options)
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("create_dirs must be a boolean", err)
        end)

        it("should accept valid overwrite and backup options", function()
            local options = { overwrite = true, backup = false }
            local valid, err = powerup:validate({}, "/pack", options)
            assert.is_true(valid)
            assert.is_nil(err)

            options = { overwrite = false, backup = true }
            valid, err = powerup:validate({}, "/pack", options)
            assert.is_true(valid)
            assert.is_nil(err)

            options = { overwrite = true, backup = true }
            valid, err = powerup:validate({}, "/pack", options)
            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should reject invalid overwrite option type", function()
            local options = { overwrite = "true" }
            local valid, err = powerup:validate({}, "/pack", options)
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("overwrite must be a boolean", err)
        end)

        it("should reject invalid backup option type", function()
            local options = { backup = "false" }
            local valid, err = powerup:validate({}, "/pack", options)
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("backup must be a boolean", err)
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
                { path = "/outside/file.txt", metadata = {} }
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

        it("should generate symlink actions for home directory", function()
            local matched_files = {
                { path = "/pack/vimrc",  metadata = { trigger = "file_name" } },
                { path = "/pack/bashrc", metadata = { trigger = "file_name" } }
            }
            local pack_path = "/pack"
            local options = { target_dir = "~" }

            -- Mock HOME environment variable
            local original_home = os.getenv("HOME")
            local mock_home = "/home/user"

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(2, #actions)

            -- Check first action
            local action1 = actions[1]
            assert.equals("link", action1.type)
            assert.is_string(action1.description)
            assert.matches("Link file /pack/vimrc to ", action1.description)
            assert.is_table(action1.data)
            assert.equals("/pack/vimrc", action1.data.source_path)
            assert.matches("%.vimrc$", action1.data.target_path) -- Should end with .vimrc
            assert.is_true(action1.data.create_dirs)
            assert.is_false(action1.data.overwrite) -- Check default
            assert.is_false(action1.data.backup)    -- Check default
            assert.equals("symlink", action1.metadata.powerup)
            assert.equals("vimrc", action1.metadata.relative_source)

            -- Check second action
            local action2 = actions[2]
            assert.equals("link", action2.type)
            assert.is_string(action2.description)
            assert.is_table(action2.data)
            assert.equals("/pack/bashrc", action2.data.source_path)
            assert.matches("%.bashrc$", action2.data.target_path) -- Should end with .bashrc
            assert.is_false(action2.data.overwrite) -- Check default
            assert.is_false(action2.data.backup)    -- Check default
        end)

        it("should generate symlink actions for subdirectory of home", function()
            local matched_files = {
                { path = "/pack/config.ini", metadata = {} }
            }
            local pack_path = "/pack"
            local options = { target_dir = "~/.config" }

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(1, #actions)

            local action = actions[1]
            assert.equals("link", action.type)
            assert.is_string(action.description)
            assert.is_table(action.data)
            assert.equals("/pack/config.ini", action.data.source_path)
            assert.matches("%.config/config%.ini$", action.data.target_path)
        end)

        it("should generate symlink actions for absolute directory", function()
            local matched_files = {
                { path = "/pack/script.sh", metadata = {} }
            }
            local pack_path = "/pack"
            local options = { target_dir = "/usr/local/bin" }

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(1, #actions)

            local action = actions[1]
            assert.equals("link", action.type)
            assert.is_string(action.description)
            assert.is_table(action.data)
            assert.equals("/pack/script.sh", action.data.source_path)
            assert.equals("/usr/local/bin/script.sh", action.data.target_path)
        end)

        it("should respect create_dirs option", function()
            local matched_files = {
                { path = "/pack/file.txt", metadata = {} }
            }
            local pack_path = "/pack"
            local options = { target_dir = "~", create_dirs = false }

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(1, #actions)

            local action = actions[1]
            assert.is_table(action.data)
            assert.is_false(action.data.create_dirs)
        end)

        it("should default create_dirs to true", function()
            local matched_files = {
                { path = "/pack/file.txt", metadata = {} }
            }
            local pack_path = "/pack"
            local options = { target_dir = "~" }

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(1, #actions)

            local action = actions[1]
            assert.is_table(action.data)
            assert.is_true(action.data.create_dirs)
        end)

        it("should preserve original metadata", function()
            local matched_files = {
                { path = "/pack/file.txt", metadata = { trigger = "test", pattern = "*.txt" } }
            }
            local pack_path = "/pack"
            local options = { target_dir = "~" }

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(1, #actions)

            local action = actions[1]
            assert.is_table(action.metadata)
            assert.is_table(action.metadata.original_metadata)
            assert.equals("test", action.metadata.original_metadata.trigger)
            assert.equals("*.txt", action.metadata.original_metadata.pattern)
        end)

        it("should default to home directory when no target_dir specified", function()
            local matched_files = {
                { path = "/pack/file.txt", metadata = {} }
            }
            local pack_path = "/pack"

            local actions, err = powerup:process(matched_files, pack_path, nil)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(1, #actions)

            local action = actions[1]
            assert.is_table(action.data)
            assert.matches("%.file%.txt$", action.data.target_path) -- Should end with .file.txt
            assert.is_false(action.data.overwrite) -- Default
            assert.is_false(action.data.backup)    -- Default
        end)

        it("should respect overwrite option", function()
            local matched_files = { { path = "/pack/file.txt", metadata = {} } }
            local options = { overwrite = true }
            local actions, err = powerup:process(matched_files, "/pack", options)
            assert.is_nil(err)
            assert.equals(1, #actions)
            assert.is_true(actions[1].data.overwrite)
            assert.is_false(actions[1].data.backup) -- Should remain default
        end)

        it("should respect backup option", function()
            local matched_files = { { path = "/pack/file.txt", metadata = {} } }
            local options = { backup = true }
            local actions, err = powerup:process(matched_files, "/pack", options)
            assert.is_nil(err)
            assert.equals(1, #actions)
            assert.is_false(actions[1].data.overwrite) -- Should remain default
            assert.is_true(actions[1].data.backup)
        end)

        it("should respect both overwrite and backup options", function()
            local matched_files = { { path = "/pack/file.txt", metadata = {} } }
            local options = { overwrite = true, backup = true }
            local actions, err = powerup:process(matched_files, "/pack", options)
            assert.is_nil(err)
            assert.equals(1, #actions)
            assert.is_true(actions[1].data.overwrite)
            assert.is_true(actions[1].data.backup)
        end)

        it("should correctly set defaults for overwrite and backup when other options are present", function()
            local matched_files = { { path = "/pack/file.txt", metadata = {} } }
            local options = { target_dir = "/tmp", create_dirs = false }
            local actions, err = powerup:process(matched_files, "/pack", options)
            assert.is_nil(err)
            assert.equals(1, #actions)
            assert.is_false(actions[1].data.overwrite)
            assert.is_false(actions[1].data.backup)
            assert.is_false(actions[1].data.create_dirs)
            assert.equals("/tmp/file.txt", actions[1].data.target_path)
        end)
    end)
end)
