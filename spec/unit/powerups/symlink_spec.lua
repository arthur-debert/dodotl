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
            assert.equals("symlink", action1.type)
            assert.equals("/pack/vimrc", action1.source_path)
            assert.matches("%.vimrc$", action1.target_path) -- Should end with .vimrc
            assert.is_true(action1.create_dirs)
            assert.equals("symlink", action1.metadata.powerup)
            assert.equals("vimrc", action1.metadata.relative_source)

            -- Check second action
            local action2 = actions[2]
            assert.equals("symlink", action2.type)
            assert.equals("/pack/bashrc", action2.source_path)
            assert.matches("%.bashrc$", action2.target_path) -- Should end with .bashrc
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
            assert.equals("symlink", action.type)
            assert.equals("/pack/config.ini", action.source_path)
            assert.matches("%.config/config%.ini$", action.target_path)
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
            assert.equals("symlink", action.type)
            assert.equals("/pack/script.sh", action.source_path)
            assert.equals("/usr/local/bin/script.sh", action.target_path)
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
            assert.is_false(action.create_dirs)
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
            assert.is_true(action.create_dirs)
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
            assert.matches("%.file%.txt$", action.target_path) -- Should end with .file.txt
        end)
    end)
end)
