-- Tests for ScriptRunnerPowerup
-- script_runner_spec.lua

describe("ScriptRunnerPowerup", function()
    local script_runner = require("dodot.powerups.script_runner")
    local powerup

    before_each(function()
        powerup = script_runner.ScriptRunnerPowerup.new()
    end)

    describe("new", function()
        it("should create a new instance", function()
            assert.is_not_nil(powerup)
            assert.equals("script_runner", powerup.name)
            assert.equals("script_runner_powerup", powerup.type)
        end)
    end)

    describe("validate", function()
        it("should validate with valid parameters", function()
            local matched_files = {
                { path = "/pack/install.sh", metadata = {} }
            }
            local pack_path = "/pack"
            local options = {}

            local valid, err = powerup:validate(matched_files, pack_path, options)
            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should validate with empty matched_files", function()
            local valid, err = powerup:validate({}, "/pack", {})
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

        it("should validate options table", function()
            local valid, err = powerup:validate({}, "/pack", { args = { "--verbose" }, env = { TEST = "1" }, order = 50 })
            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should reject invalid options.args", function()
            local valid, err = powerup:validate({}, "/pack", { args = "invalid" })
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("must be a table", err)
        end)

        it("should reject invalid options.env", function()
            local valid, err = powerup:validate({}, "/pack", { env = "invalid" })
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("must be a table", err)
        end)

        it("should reject invalid options.order", function()
            local valid, err = powerup:validate({}, "/pack", { order = "invalid" })
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("must be a number", err)
        end)
    end)

    describe("process", function()
        it("should return empty actions if no matched_files", function()
            local actions, err = powerup:process({}, "/pack", {})
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(0, #actions)
        end)

        it("should generate script_run action for install script", function()
            local matched_files = {
                { path = "/pack/install.sh", metadata = {} }
            }
            local pack_path = "/pack"
            local options = {}

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(1, #actions)

            local action = actions[1]
            assert.equals("script_run", action.type)
            assert.is_string(action.description)
            assert.matches("Execute install script", action.description)
            assert.is_table(action.data)
            assert.equals("/pack/install.sh", action.data.script_path)
            assert.equals("/pack", action.data.working_dir)
            assert.is_table(action.data.args)
            assert.equals(0, #action.data.args)   -- Default empty args
            assert.is_table(action.data.env)
            assert.equals(0, #action.data.env)    -- Default empty env
            assert.equals(100, action.data.order) -- Default order
            assert.equals("script_runner", action.metadata.powerup_name)
            assert.equals("install.sh", action.metadata.relative_source)
            assert.equals("/pack", action.metadata.pack_path)
            assert.equals("install", action.metadata.script_type)
        end)

        it("should handle custom options", function()
            local matched_files = {
                { path = "/pack/install.sh", metadata = {} }
            }
            local pack_path = "/pack"
            local options = {
                args = { "--verbose", "--force" },
                env = { DEBUG = "1", FORCE = "true" },
                order = 150
            }

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(1, #actions)

            local action = actions[1]
            assert.equals("script_run", action.type)
            assert.is_table(action.data)
            assert.equals("/pack/install.sh", action.data.script_path)
            assert.same({ "--verbose", "--force" }, action.data.args)
            assert.same({ DEBUG = "1", FORCE = "true" }, action.data.env)
            assert.equals(150, action.data.order)
        end)

        it("should handle multiple install scripts", function()
            local matched_files = {
                { path = "/pack/install.sh",   metadata = {} },
                { path = "/pack/install.bash", metadata = {} }
            }
            local pack_path = "/pack"
            local options = {}

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(2, #actions)

            -- Check that both files generated actions
            assert.equals("/pack/install.sh", actions[1].data.script_path)
            assert.equals("/pack/install.bash", actions[2].data.script_path)
        end)
    end)
end)
