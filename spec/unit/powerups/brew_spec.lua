-- Tests for BrewPowerup
-- brew_spec.lua

describe("BrewPowerup", function()
    local brew = require("dodot.powerups.brew")
    local powerup

    before_each(function()
        powerup = brew.BrewPowerup.new()
    end)

    describe("new", function()
        it("should create a new instance", function()
            assert.is_not_nil(powerup)
            assert.equals("brew", powerup.name)
            assert.equals("brew_powerup", powerup.type)
        end)
    end)

    describe("validate", function()
        it("should validate with valid parameters", function()
            local matched_files = {
                { path = "/pack/Brewfile", metadata = {} }
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
    end)

    describe("process", function()
        it("should return empty actions if no matched_files", function()
            local actions, err = powerup:process({}, "/pack", {})
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(0, #actions)
        end)

        it("should generate brew_install action for Brewfile", function()
            local matched_files = {
                { path = "/pack/Brewfile", metadata = {} }
            }
            local pack_path = "/pack"
            local options = {}

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(1, #actions)

            local action = actions[1]
            assert.equals("brew_install", action.type)
            assert.is_string(action.description)
            assert.matches("Process Brewfile", action.description)
            assert.is_table(action.data)
            assert.equals("/pack/Brewfile", action.data.brewfile_path)
            assert.equals("brew", action.metadata.powerup_name)
            assert.equals("Brewfile", action.metadata.relative_source)
            assert.equals("/pack", action.metadata.pack_path)
        end)

        it("should handle multiple Brewfiles", function()
            local matched_files = {
                { path = "/pack/Brewfile",      metadata = {} },
                { path = "/pack/Brewfile.work", metadata = {} }
            }
            local pack_path = "/pack"
            local options = {}

            local actions, err = powerup:process(matched_files, pack_path, options)
            assert.is_nil(err)
            assert.is_table(actions)
            assert.equals(2, #actions)

            -- Check that both files generated actions
            assert.equals("/pack/Brewfile", actions[1].data.brewfile_path)
            assert.equals("/pack/Brewfile.work", actions[2].data.brewfile_path)
        end)
    end)
end)
