-- Integration tests for Phase 4: Operation Execution
-- Tests the complete pipeline with actual filesystem operations

describe("Phase 4: Operation Execution Integration", function()
    local pl_path = require("pl.path")
    local pl_dir = require("pl.dir")
    local pl_file = require("pl.file")
    local test_dir = "/tmp/dodot_phase4_test"
    local dotfiles_dir = test_dir .. "/dotfiles"
    local home_dir = test_dir .. "/fake_home"

    -- Mock HOME environment variable
    local original_home

    setup(function()
        original_home = os.getenv("HOME")
        os.execute("rm -rf " .. test_dir)
        os.execute("mkdir -p " .. test_dir)
        os.execute("mkdir -p " .. dotfiles_dir)
        os.execute("mkdir -p " .. home_dir)
    end)

    teardown(function()
        if original_home then
            -- Can't directly set environment variable, but that's okay for test cleanup
        end
        os.execute("rm -rf " .. test_dir)
    end)

    before_each(function()
        -- Set fake HOME for filesystem operations
        -- Note: This won't affect get_home_directory() in get_fs_ops.lua
        -- For proper testing, we'd need to mock that function
        os.execute("rm -rf " .. dotfiles_dir .. "/*")
        os.execute("rm -rf " .. home_dir .. "/*")

        -- Create a minimal test pack structure
        os.execute("mkdir -p " .. dotfiles_dir .. "/testpack")
        pl_file.write(dotfiles_dir .. "/testpack/test.txt", "test content\n")
    end)

    describe("end-to-end pipeline", function()
        it("should execute the complete pipeline", function()
            -- Import modules
            local get_packs = require("dodot.core.get_packs")
            local get_firing_triggers = require("dodot.core.get_firing_triggers")
            local get_actions = require("dodot.core.get_actions")
            local get_fs_ops = require("dodot.core.get_fs_ops")
            local run_ops = require("dodot.core.run_ops")

            -- Step 1: Get packs
            local pack_candidates, err = get_packs.get_pack_candidates(dotfiles_dir)
            assert.is_nil(err)
            assert.is_not_nil(pack_candidates)

            local packs, err = get_packs.get_packs(pack_candidates)
            assert.is_nil(err)
            assert.is_not_nil(packs)
            assert.is_true(#packs > 0)

            -- Step 2: Get firing triggers
            local trigger_matches, err = get_firing_triggers.get_firing_triggers(packs)
            assert.is_nil(err)
            assert.is_not_nil(trigger_matches)

            -- Step 3: Generate actions
            local actions, err = get_actions.get_actions(trigger_matches)
            assert.is_nil(err)
            assert.is_not_nil(actions)

            -- Step 4: Create filesystem operations
            local operations, err = get_fs_ops.get_fs_ops(actions)
            assert.is_nil(err)
            assert.is_not_nil(operations)

            -- Step 5: Validate operations
            local valid, err = run_ops.validate_ops(operations)
            assert.is_true(valid)
            assert.is_nil(err)

            -- Step 6: Test dry run
            local preview, err = run_ops.dry_run(operations)
            assert.is_nil(err)
            assert.is_not_nil(preview)
            assert.equals(#operations, #preview)

            -- Step 7: Execute operations in dry run mode
            local success, err = run_ops.run_ops(operations, { dry_run = true })
            assert.is_true(success)
            assert.is_nil(err)
        end)
    end)

    describe("operation validation", function()
        it("should validate generated operations", function()
            local run_ops = require("dodot.core.run_ops")

            -- Test operations that should be valid
            local operations = {
                {
                    type = "fsynth.op.ensure_dir",
                    description = "Create directory",
                    args = { path = test_dir .. "/test_create", mode = "0755" }
                },
                {
                    type = "fsynth.op.create_file",
                    description = "Create file",
                    args = {
                        path = test_dir .. "/test_file.txt",
                        content = "test content",
                        mode = "0644",
                        overwrite = true
                    }
                }
            }

            local valid, err = run_ops.validate_ops(operations)
            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should detect invalid operations", function()
            local run_ops = require("dodot.core.run_ops")

            local operations = {
                {
                    type = "invalid.operation.type",
                    description = "Invalid operation",
                    args = { some = "args" }
                }
            }

            local valid, err = run_ops.validate_ops(operations)
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.equals("VALIDATION_FAILED", err.code)
        end)
    end)

    describe("dry run functionality", function()
        it("should provide operation preview", function()
            local run_ops = require("dodot.core.run_ops")

            local operations = {
                {
                    type = "fsynth.op.create_file",
                    description = "Test file creation",
                    args = { path = "/test/path.txt", content = "content" }
                }
            }

            local preview, err = run_ops.dry_run(operations)
            assert.is_nil(err)
            assert.is_not_nil(preview)
            assert.equals(1, #preview)

            local item = preview[1]
            assert.equals(1, item.index)
            assert.equals("fsynth.op.create_file", item.type)
            assert.equals("Test file creation", item.description)
            assert.is_true(item.would_execute)
        end)
    end)

    describe("error handling", function()
        it("should handle missing operations gracefully", function()
            local run_ops = require("dodot.core.run_ops")

            local success, err = run_ops.run_ops(nil)
            assert.is_true(success)
            assert.is_nil(err)

            local success, err = run_ops.run_ops({})
            assert.is_true(success)
            assert.is_nil(err)
        end)

        it("should handle validation errors", function()
            local run_ops = require("dodot.core.run_ops")

            local invalid_operations = {
                {
                    type = "completely.invalid.type",
                    description = "This should fail",
                    args = {}
                }
            }

            local success, err = run_ops.run_ops(invalid_operations, { dry_run = true })
            assert.is_false(success)
            assert.is_not_nil(err)
            assert.equals("UNKNOWN_OPERATION_TYPE", err.code)
        end)
    end)
end)
