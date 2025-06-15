-- Integration tests for Phase 4: Operation Execution
-- Tests the complete pipeline with actual filesystem operations

describe("Phase 4: Operation Execution Integration", function()
    local pl_path = require("pl.path")
    local pl_dir = require("pl.dir")
    local pl_file = require("pl.file")
    local get_fs_ops_module = require("dodot.core.get_fs_ops") -- Added for home dir mocking
    local run_ops = require("dodot.core.run_ops") -- Added for convenience
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
        get_fs_ops_module.set_test_home_directory(home_dir) -- Set test home directory

        -- Create a minimal test pack structure
        os.execute("mkdir -p " .. dotfiles_dir .. "/testpack")
        pl_file.write(dotfiles_dir .. "/testpack/test.txt", "test content\n")
    end)

    after_each(function()
        get_fs_ops_module.set_test_home_directory(nil) -- Reset test home directory
    end)

    describe("end-to-end pipeline", function()
        it("should execute the complete pipeline", function()
            -- Import modules
            local get_packs = require("dodot.core.get_packs")
            local get_firing_triggers = require("dodot.core.get_firing_triggers")
            local get_actions = require("dodot.core.get_actions")
            -- local get_fs_ops = require("dodot.core.get_fs_ops") -- Already available as get_fs_ops_module
            -- local run_ops = require("dodot.core.run_ops") -- Already available as run_ops

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
            local operations, err = get_fs_ops_module.get_fs_ops(actions) -- Use module alias
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
            -- local run_ops = require("dodot.core.run_ops") -- Already available

            local success, err = run_ops.run_ops(nil)
            assert.is_true(success)
            assert.is_nil(err)

            local success, err = run_ops.run_ops({})
            assert.is_true(success)
            assert.is_nil(err)
        end)

        it("should handle validation errors", function()
            -- local run_ops = require("dodot.core.run_ops") -- Already available

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

    describe("Actual Filesystem Operations", function()
        it("should create a basic symlink", function()
            local source_file = dotfiles_dir .. "/testpack/test_symlink_src.txt"
            pl_file.write(source_file, "symlink source content")
            local target_link = home_dir .. "/linked_test_file.txt"

            local actions = {
                {
                    type = "link",
                    pack_path = dotfiles_dir .. "/testpack", -- pack_path might be used by get_fs_ops
                    data = {
                        source_path = source_file,
                        target_path = target_link,
                        create_dirs = true -- Ensure parent dir of target_link is created if needed
                    },
                    description = "Test symlink creation"
                }
            }

            local operations, err = get_fs_ops_module.get_fs_ops(actions)
            assert.is_nil(err)
            assert.is_not_nil(operations)
            assert.is_true(#operations > 0, "Expected operations to be generated")

            local success, exec_err = run_ops.run_ops(operations, { dry_run = false })
            assert.is_true(success, "run_ops failed: " .. (exec_err and exec_err.message or "unknown error"))
            assert.is_nil(exec_err)

            assert.is_true(pl_path.exists(target_link), "Target link does not exist: " .. target_link)
            assert.is_true(pl_path.islink(target_link), "Target is not a symlink: " .. target_link)
            assert.equals(source_file, pl_path.readlink(target_link), "Symlink does not point to the correct source")
        end)

        it("should execute shell_source operation", function()
            -- Setup: Create a dummy script file
            local script_name = "my_test_script.sh"
            local dummy_script_content = "#!/bin/sh\necho 'hello from test script'"
            local source_script_path = dotfiles_dir .. "/testpack/" .. script_name
            pl_file.write(source_script_path, dummy_script_content)

            local actions = {
                {
                    type = "shell_source",
                    pack_path = dotfiles_dir .. "/testpack",
                    data = {
                        source_file = script_name, -- Relative to pack_path
                        order = 50
                    },
                    description = "Test shell_source operation"
                }
            }

            local operations, err = get_fs_ops_module.get_fs_ops(actions)
            assert.is_nil(err)
            assert.is_not_nil(operations)

            local success, exec_err = run_ops.run_ops(operations, { dry_run = false })
            assert.is_true(success, "run_ops failed for shell_source: " .. (exec_err and exec_err.message or "unknown"))
            assert.is_nil(exec_err)

            -- Assertions
            local dodot_shell_base = home_dir .. "/.config/dodot/shell"
            local init_script_path = dodot_shell_base .. "/init.sh"
            assert.is_true(pl_path.exists(init_script_path), "init.sh was not created")

            -- Determine if it's an alias or profile script based on name (my_test_script.sh is not an alias)
            local target_symlink_subdir = "profile_scripts"
            local expected_symlink_name = "50-" .. script_name
            local symlink_path = dodot_shell_base .. "/" .. target_symlink_subdir .. "/" .. expected_symlink_name
            assert.is_true(pl_path.exists(symlink_path), "Symlink for script was not created: " .. symlink_path)
            assert.is_true(pl_path.islink(symlink_path), "Script symlink is not a link: " .. symlink_path)
            -- Source path needs to be absolute for readlink comparison
            local absolute_source_script_path = pl_path.abspath(source_script_path)
            assert.equals(absolute_source_script_path, pl_path.readlink(symlink_path), "Script symlink points to wrong source")

            -- Verify init.sh content
            local init_content = pl_file.read(init_script_path)
            assert.is_not_nil(init_content)
            assert.is_true(string.find(init_content, "dodot/shell/profile_scripts") ~= nil, "init.sh does not source profile_scripts")
            assert.is_true(string.find(init_content, "dodot/shell/aliases") ~= nil, "init.sh does not source aliases")
        end)

        it("should execute shell_add_path operation", function()
            -- Setup: Create a dummy bin directory
            local my_bin_path = dotfiles_dir .. "/testpack/my_bin"
            os.execute("mkdir -p " .. my_bin_path)
            local shell_type = "zsh" -- Test with zsh

            local actions = {
                {
                    type = "shell_add_path",
                    data = {
                        path_to_add = my_bin_path,
                        shell = shell_type,
                        prepend = false
                    },
                    description = "Test shell_add_path operation"
                }
            }

            local operations, err = get_fs_ops_module.get_fs_ops(actions)
            assert.is_nil(err)
            assert.is_not_nil(operations)

            local success, exec_err = run_ops.run_ops(operations, { dry_run = false })
            assert.is_true(success, "run_ops failed for shell_add_path: " .. (exec_err and exec_err.message or "unknown"))
            assert.is_nil(exec_err)

            -- Assertions
            local zshrc_path = home_dir .. "/.zshrc"
            assert.is_true(pl_path.exists(zshrc_path), ".zshrc was not created")

            local zshrc_content = pl_file.read(zshrc_path)
            assert.is_not_nil(zshrc_content)
            local expected_path_line = "export PATH=\"$PATH:" .. my_bin_path .. "\""
            assert.is_true(string.find(zshrc_content, expected_path_line, 1, true) ~= nil,
                ".zshrc does not contain correct PATH export. Expected:\n" .. expected_path_line .. "\nGot:\n" .. zshrc_content)
            assert.is_true(string.find(zshrc_content, "# Added by dodot for PATH management") ~= nil,
                ".zshrc does not contain dodot comment")
        end)
    end)
end)
