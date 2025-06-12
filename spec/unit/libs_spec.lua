-- Unit tests for the libs module
-- Tests registry integration and initialization

local test_utils = require("spec.helpers.test_utils")

describe("dodot.libs", function()
    local libs

    before_each(function()
        -- Fresh require to reset state
        package.loaded["dodot.libs"] = nil
        libs = require("dodot.libs")
    end)

    after_each(function()
        -- Clean up state
        package.loaded["dodot.libs"] = nil
    end)

    describe("initial state", function()
        it("should start with uninitialized registries", function()
            assert.is_nil(libs.triggers)
            assert.is_nil(libs.actions)
            assert.is_nil(libs.powerups)
            assert.is_false(libs.is_initialized())
        end)
    end)

    describe("initialization", function()
        it("should initialize all registries successfully", function()
            local success, err = libs.init()

            assert.is_true(success)
            assert.is_nil(err)
            assert.is_not_nil(libs.triggers)
            assert.is_not_nil(libs.actions)
            assert.is_not_nil(libs.powerups)
            assert.is_true(libs.is_initialized())
        end)

        it("should create functional registry instances", function()
            libs.init()

            -- Test that registries have the expected API
            assert.is_function(libs.triggers.add)
            assert.is_function(libs.triggers.get)
            assert.is_function(libs.triggers.list)

            assert.is_function(libs.actions.add)
            assert.is_function(libs.actions.get)
            assert.is_function(libs.actions.list)

            assert.is_function(libs.powerups.add)
            assert.is_function(libs.powerups.get)
            assert.is_function(libs.powerups.list)
        end)

        it("should create independent registry instances", function()
            libs.init()

            assert.is_not.equals(libs.triggers, libs.actions)
            assert.is_not.equals(libs.actions, libs.powerups)
            assert.is_not.equals(libs.triggers, libs.powerups)
        end)
    end)

    describe("get_registry method", function()
        before_each(function()
            libs.init()
        end)

        it("should return triggers registry", function()
            local registry, err = libs.get_registry("triggers")

            assert.equals(libs.triggers, registry)
            assert.is_nil(err)
        end)

        it("should return actions registry", function()
            local registry, err = libs.get_registry("actions")

            assert.equals(libs.actions, registry)
            assert.is_nil(err)
        end)

        it("should return powerups registry", function()
            local registry, err = libs.get_registry("powerups")

            assert.equals(libs.powerups, registry)
            assert.is_nil(err)
        end)

        it("should handle unknown registry names", function()
            local registry, err = libs.get_registry("unknown")

            assert.is_nil(registry)
            assert.equals("Unknown registry: unknown", err)
        end)
    end)

    describe("get_stats method", function()
        it("should handle uninitialized state", function()
            local stats, err = libs.get_stats()

            assert.is_nil(stats)
            assert.equals("Registries not initialized", err)
        end)

        it("should return stats for initialized registries", function()
            libs.init()
            local stats, err = libs.get_stats()

            assert.is_not_nil(stats)
            assert.is_nil(err)
            assert.is_number(stats.triggers)
            assert.is_number(stats.actions)
            assert.is_number(stats.powerups)
            assert.is_number(stats.total)
            assert.equals(stats.triggers + stats.actions + stats.powerups, stats.total)
        end)

        it("should show 0 counts for empty registries", function()
            libs.init()
            local stats, err = libs.get_stats()

            -- Since init modules are placeholders, should be 0
            assert.equals(0, stats.triggers)
            assert.equals(0, stats.actions)
            assert.equals(0, stats.powerups)
            assert.equals(0, stats.total)
        end)
    end)

    describe("integration with registry API", function()
        before_each(function()
            libs.init()
        end)

        it("should allow adding items to registries", function()
            local success, err = libs.triggers.add("test_trigger", { type = "test" })

            assert.is_true(success)
            assert.is_nil(err)

            local value, get_err = libs.triggers.get("test_trigger")
            assert.is_table(value)
            assert.equals("test", value.type)
            assert.is_nil(get_err)
        end)

        it("should maintain separate registry state", function()
            libs.triggers.add("item", "trigger_value")
            libs.actions.add("item", "action_value")
            libs.powerups.add("item", "powerup_value")

            local trigger_value, _ = libs.triggers.get("item")
            local action_value, _ = libs.actions.get("item")
            local powerup_value, _ = libs.powerups.get("item")

            assert.equals("trigger_value", trigger_value)
            assert.equals("action_value", action_value)
            assert.equals("powerup_value", powerup_value)
        end)
    end)
end)
