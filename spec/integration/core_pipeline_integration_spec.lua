-- Integration tests for core pipeline
-- Demonstrates integration testing patterns for dodot

local test_utils = require("spec.helpers.test_utils")

describe("Core Pipeline Integration", function()
    local temp_dir

    before_each(function()
        temp_dir = test_utils.fs.create_temp_dir()
    end)

    after_each(function()
        test_utils.fs.cleanup_temp_dir(temp_dir)
    end)

    describe("pipeline data flow", function()
        it("should pass data between pipeline stages correctly", function()
            -- NOTE: This is a placeholder integration test
            -- Full implementation will be done in Phase 2 when pipeline stages are implemented

            local get_packs = require("dodot.core.get_packs")
            local get_firing_triggers = require("dodot.core.get_firing_triggers")
            local get_actions = require("dodot.core.get_actions")

            -- Test that modules can be loaded and called
            local pack_candidates, err1 = get_packs.get_pack_candidates(temp_dir)
            assert.is_table(pack_candidates)
            assert.is_nil(err1)

            local packs, err2 = get_packs.get_packs(pack_candidates)
            assert.is_table(packs)
            assert.is_nil(err2)

            local triggers, err3 = get_firing_triggers.get_firing_triggers(packs)
            assert.is_table(triggers)
            assert.is_nil(err3)

            local actions, err4 = get_actions.get_action_list(triggers)
            assert.is_table(actions)
            assert.is_nil(err4)
        end)
    end)

    describe("error propagation", function()
        it("should handle errors gracefully across pipeline stages", function()
            -- Test error handling between stages
            local get_packs = require("dodot.core.get_packs")

            -- Test with invalid input
            local result, err = get_packs.get_pack_candidates(nil)

            -- Should return empty result and no error for nil input (graceful handling)
            assert.is_table(result)
            assert.is_nil(err)
        end)
    end)

    describe("module dependency resolution", function()
        it("should load all core modules without errors", function()
            -- Test that all core modules can be loaded
            local modules = {
                "dodot.core.get_packs",
                "dodot.core.get_firing_triggers",
                "dodot.core.get_actions",
                "dodot.core.get_fs_ops",
                "dodot.core.list_packs",
                "dodot.core.run_ops"
            }

            for _, module_name in ipairs(modules) do
                local success, module_or_error = pcall(require, module_name)
                assert.is_true(success, "Failed to load module " .. module_name .. ": " .. tostring(module_or_error))
                assert.is_table(module_or_error, "Module " .. module_name .. " should return a table")
            end
        end)
    end)
end)
