-- Tests for ShellAddPathPowerup

describe("ShellAddPathPowerup", function()
    local bin_module = require("dodot.powerups.bin") -- module still named bin.lua
    local pl_path = require("pl.path")
    local ShellAddPathPowerup = bin_module.ShellAddPathPowerup

    local powerup
    local original_home

    before_each(function()
        powerup = ShellAddPathPowerup.new()
        original_home = os.getenv("HOME")
        -- Set predictable environment for tests
        os.getenv = function(var)
            if var == "HOME" then
                return "/home/user"
            elseif var == "SHELL" then
                return nil -- Default to nil so detect_shell falls back to "bash"
            else
                return nil
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
        it("should create a shell_add_path powerup instance", function()
            assert.is_not_nil(powerup)
            assert.equals("shell_add_path", powerup.name)
            assert.equals("shell_add_path_powerup", powerup.type)
        end)
    end)

    describe("validate", function()
        it("should validate with valid parameters (using pack_path)", function()
            local matched_files = { { path = "/pack/bin/tool", metadata = {} } } -- Simulating DirectoryTrigger result
            local pack_path = "/pack/bin"
            local options = { shell = "bash", prepend = true }
            local valid, err = powerup:validate(matched_files, pack_path, options)
            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should validate with valid parameters (using options.bin_dir)", function()
            local matched_files = {}  -- Can be empty if bin_dir is specified
            local pack_path = "/pack" -- Contextual pack_path
            local options = { bin_dir = "~/.local/bin", shell = "zsh" }
            local valid, err = powerup:validate(matched_files, pack_path, options)
            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should validate with empty matched_files if options.bin_dir is provided", function()
            local options = { bin_dir = "/usr/local/bin" }
            local valid, err = powerup:validate({}, "/pack", options)
            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should reject empty pack_path", function()
            local valid, err = powerup:validate({}, "", {})
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("requires a valid pack_path", err)
        end)

        it("should reject non-table options", function()
            local valid, err = powerup:validate({}, "/pack", "invalid")
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("options must be a table", err)
        end)

        it("should reject invalid bin_dir option type", function()
            local options = { bin_dir = 123 }
            local valid, err = powerup:validate({}, "/pack", options)
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("options.bin_dir must be a string", err)
        end)

        it("should reject invalid shell option type", function()
            local options = { shell = 123 }
            local valid, err = powerup:validate({}, "/pack", options)
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("options.shell must be a string", err)
        end)

        it("should reject invalid prepend option type", function()
            local options = { prepend = "true" }
            local valid, err = powerup:validate({}, "/pack", options)
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("options.prepend must be a boolean", err)
        end)
        -- Note: Validation for individual files (like path existence, type) is removed
        -- as this powerup now focuses on directories for PATH.
    end)

    describe("process", function()
        it("should return empty actions if no path_to_add can be determined", function()
            local actions, err = powerup:process({}, "/pack", {}) -- No matched_files and no options.bin_dir
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(0, #actions)
        end)

        it("should generate shell_add_path action using pack_path if matched_files present", function()
            local matched_files = { { path = "/my/dotfiles/common/bin/my_script", metadata = {} } }
            local pack_path = "/my/dotfiles/common/bin" -- This is the directory to add
            local options = { shell = "zsh" }

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(1, #actions)

            local action = actions[1]
            assert.equals("shell_add_path", action.type)
            assert.is_string(action.description)
            assert.matches("Add /my/dotfiles/common/bin to PATH", action.description)
            assert.is_table(action.data)
            assert.equals("/my/dotfiles/common/bin", action.data.path_to_add)
            assert.equals("zsh", action.data.shell)
            assert.is_false(action.data.prepend) -- Default
            assert.equals("shell_add_path", action.metadata.powerup_name)
        end)

        it("should generate shell_add_path action using options.bin_dir if provided", function()
            local matched_files = {}                -- Not used if bin_dir is present
            local pack_path = "/my/dotfiles/common" -- Contextual
            local options = { bin_dir = "~/.custom_bin", prepend = true }

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.equals(1, #actions)

            local action = actions[1]
            assert.equals("shell_add_path", action.type)
            assert.is_string(action.description)
            assert.matches("Prepend /home/user/.custom_bin to PATH", action.description)
            assert.is_table(action.data)
            assert.equals("/home/user/.custom_bin", action.data.path_to_add)
            assert.equals("bash", action.data.shell) -- Default shell
            assert.is_true(action.data.prepend)
        end)

        it("should prioritize options.bin_dir over pack_path from matched_files", function()
            local matched_files = { { path = "/pack/some_pack_bin/tool", metadata = {} } }
            local pack_path = "/pack/some_pack_bin"
            local options = { bin_dir = "/override/bin", shell = "fish" }

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.equals(1, #actions)
            local action = actions[1]
            assert.is_table(action.data)
            assert.equals("/override/bin", action.data.path_to_add)
            assert.equals("fish", action.data.shell)
        end)

        it("should expand tilde in options.bin_dir", function()
            local options = { bin_dir = "~/mybin" }
            local actions, err = powerup:process({}, "/pack", options)
            assert.is_nil(err)
            assert.equals(1, #actions)
            assert.is_table(actions[1].data)
            assert.equals("/home/user/mybin", actions[1].data.path_to_add)
        end)

        it("should default prepend to false", function()
            local options = { bin_dir = "/usr/local/sbin" }
            local actions, err = powerup:process({}, "/pack", options)
            assert.is_nil(err)
            assert.equals(1, #actions)
            assert.is_table(actions[1].data)
            assert.is_false(actions[1].data.prepend)
        end)

        it("should detect shell if not specified in options", function()
            -- Mock os.getenv("SHELL") to return /bin/zsh for this test
            local old_getenv = os.getenv
            os.getenv = function(var)
                if var == "SHELL" then
                    return "/bin/zsh"
                elseif var == "HOME" then
                    return "/home/user"
                else
                    return old_getenv(var)
                end
            end

            local options = { bin_dir = "/opt/bin" }
            local actions, err = powerup:process({}, "/pack", options)
            assert.is_nil(err)
            assert.equals(1, #actions)
            assert.is_table(actions[1].data)
            assert.equals("zsh", actions[1].data.shell)

            os.getenv = old_getenv -- Restore
        end)

        it("should handle nil options table gracefully", function()
            -- This will use pack_path derived from matched_files
            local matched_files = { { path = "/pack/bin/tool", metadata = {} } }
            local pack_path = "/pack/bin"
            local actions, err = powerup:process(matched_files, pack_path, nil)
            assert.is_nil(err)
            assert.equals(1, #actions)
            local action = actions[1]
            assert.is_table(action.data)
            assert.equals("/pack/bin", action.data.path_to_add)
            assert.equals("bash", action.data.shell) -- default
            assert.is_false(action.data.prepend)     -- default
        end)
    end)
end)
