-- spec/integration/core_pipeline_integration_spec.lua
local get_packs_module = require("dodot.core.get_packs")
local get_firing_triggers_module = require("dodot.core.get_firing_triggers")
local get_actions_module = require("dodot.core.get_actions")
local get_fs_ops_module = require("dodot.core.get_fs_ops")
local libs = require("dodot.libs")
local test_utils = require("spec.helpers.test_utils")
local pl_path = require("pl.path")
local pl_file = require("pl.file")

describe("Core Pipeline Integration", function()
    local temp_dotfiles_root

    before_each(function()
        -- Ensure registries are initialized with stubs
        if not libs.is_initialized() then
            local ok, err = libs.init()
            assert(ok, "libs.init() failed: " .. (err and err.message or "unknown error"))
        end
        temp_dotfiles_root = test_utils.fs.create_temp_dir()
    end)

    after_each(function()
        if temp_dotfiles_root then
            -- Use the correct helper name found in previous subtasks
            test_utils.fs.cleanup_temp_dir(temp_dotfiles_root)
            temp_dotfiles_root = nil
        end
    end)

    it("should run the pipeline end-to-end with stubs, resulting in no operations", function()
        -- 1. Setup: Create a pack with a file
        local pack1_path = pl_path.join(temp_dotfiles_root, "pack1")
        assert(pl_path.mkdir(pack1_path), "Failed to create pack1 directory")
        local file_in_pack1 = pl_path.join(pack1_path, "some_file.txt")
        assert(pl_file.write(file_in_pack1, "hello world", true), "Failed to create file_in_pack1") -- ensure create

        -- 2. Stage 1: Get Packs
        local pack_candidates, err_pc = get_packs_module.get_pack_candidates(temp_dotfiles_root)
        assert.is_nil(err_pc, err_pc and err_pc.message or "get_pack_candidates error")
        assert.is_table(pack_candidates)
        assert.equals(1, #pack_candidates)
        assert.equals(pack1_path, pack_candidates[1])

        local packs, err_p = get_packs_module.get_packs(pack_candidates)
        assert.is_nil(err_p, err_p and err_p.message or "get_packs error")
        assert.is_table(packs)
        assert.equals(1, #packs)
        if #packs == 1 then -- Guard access to packs[1]
            assert.equals("pack1", packs[1].name)
            assert.equals(pack1_path, packs[1].path)
        end

        -- 3. Stage 2: Get Firing Triggers
        -- With current stubs (stub_file_name_trigger doesn't match by default), this should be empty.
        local trigger_matches, err_ft = get_firing_triggers_module.get_firing_triggers(packs)
        assert.is_nil(err_ft, err_ft and err_ft.message or "get_firing_triggers error")
        assert.is_table(trigger_matches)
        assert.equals(0, #trigger_matches, "Expected no trigger matches with stub trigger")

        -- 4. Stage 3: Get Actions
        -- With no trigger matches, this should be empty.
        local actions, err_ga = get_actions_module.get_actions(trigger_matches)
        assert.is_nil(err_ga, err_ga and err_ga.message or "get_actions error")
        assert.is_table(actions)
        assert.equals(0, #actions, "Expected no actions with no trigger matches")

        -- 5. Stage 4: Get FS Operations
        -- With no actions, this should be empty.
        local operations, err_gfo = get_fs_ops_module.get_fs_ops(actions)
        assert.is_nil(err_gfo, err_gfo and err_gfo.message or "get_fs_ops error")
        assert.is_table(operations)
        assert.equals(0, #operations, "Expected no operations with no actions")
    end)

    it("should handle pipeline with no packs found", function()
        -- 1. Stage 1: Get Packs (from an empty dotfiles root)
        local pack_candidates, err_pc = get_packs_module.get_pack_candidates(temp_dotfiles_root)
        assert.is_nil(err_pc)
        assert.are.same({}, pack_candidates)

        local packs, err_p = get_packs_module.get_packs(pack_candidates)
        assert.is_nil(err_p)
        assert.are.same({}, packs)

        -- 2. Stage 2: Get Firing Triggers
        local trigger_matches, err_ft = get_firing_triggers_module.get_firing_triggers(packs)
        assert.is_nil(err_ft)
        assert.are.same({}, trigger_matches)

        -- ... and so on, all subsequent stages should also produce empty lists.
        local actions, err_ga = get_actions_module.get_actions(trigger_matches)
        assert.is_nil(err_ga)
        assert.are.same({}, actions)

        local operations, err_gfo = get_fs_ops_module.get_fs_ops(actions)
        assert.is_nil(err_gfo)
        assert.are.same({}, operations)
    end)
end)
