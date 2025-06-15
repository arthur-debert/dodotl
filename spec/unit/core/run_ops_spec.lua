-- Tests for run_ops module (Phase 4: Operation Execution)

describe("run_ops", function()
    local run_ops = require("dodot.core.run_ops")
    local fsynth = require("fsynth")

    -- Helper to create test operations
    local function create_test_operations()
        return {
            {
                type = "fsynth.op.ensure_dir",
                description = "Create test directory",
                args = { path = "/tmp/test_dir", mode = "0755" }
            },
            {
                type = "fsynth.op.symlink",
                description = "Create test symlink",
                args = { src = "/tmp/test_src", dest = "/tmp/test_dest", force = true }
            },
            {
                type = "fsynth.op.create_file",
                description = "Create test file",
                args = { path = "/tmp/test_file.txt", content = "test content", mode = "0644" }
            }
        }
    end

    describe("validate_ops", function()
        it("should validate valid operations", function()
            local operations = create_test_operations()
            local valid, err = run_ops.validate_ops(operations)

            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should handle empty operations list", function()
            local valid, err = run_ops.validate_ops({})

            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should handle nil operations", function()
            local valid, err = run_ops.validate_ops(nil)

            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should detect invalid operation types", function()
            local operations = {
                {
                    type = "invalid.op.type",
                    description = "Invalid operation",
                    args = { some = "args" }
                }
            }

            local valid, err = run_ops.validate_ops(operations)

            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.equals("VALIDATION_FAILED", err.code)
        end)

        it("should validate symlink operations", function()
            local operations = {
                {
                    type = "fsynth.op.symlink",
                    description = "Test symlink",
                    args = { src = "/test/src", dest = "/test/dest", force = false }
                }
            }

            local valid, err = run_ops.validate_ops(operations)

            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should validate create_directory operations", function()
            local operations = {
                {
                    type = "fsynth.op.create_directory",
                    description = "Test directory creation",
                    args = { path = "/test/dir", mode = "0755" }
                }
            }

            local valid, err = run_ops.validate_ops(operations)

            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should validate ensure_dir operations", function()
            local operations = {
                {
                    type = "fsynth.op.ensure_dir",
                    description = "Test directory ensure",
                    args = { path = "/test/dir", mode = "0755" }
                }
            }

            local valid, err = run_ops.validate_ops(operations)

            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should validate append_to_file operations", function()
            local operations = {
                {
                    type = "fsynth.op.append_to_file",
                    description = "Test file append",
                    args = { path = "/test/file.txt", content = "new content", unique = true }
                }
            }

            local valid, err = run_ops.validate_ops(operations)

            assert.is_true(valid)
            assert.is_nil(err)
        end)
    end)

    describe("dry_run", function()
        it("should return preview for valid operations", function()
            local operations = create_test_operations()
            local preview, err = run_ops.dry_run(operations)

            assert.is_nil(err)
            assert.is_not_nil(preview)
            assert.equals(3, #preview)

            -- Check preview structure
            for i, item in ipairs(preview) do
                assert.equals(i, item.index)
                assert.is_not_nil(item.type)
                assert.is_not_nil(item.description)
                assert.is_true(item.would_execute)
            end
        end)

        it("should handle empty operations", function()
            local preview, err = run_ops.dry_run({})

            assert.is_nil(err)
            assert.is_not_nil(preview)
            assert.equals(0, #preview)
        end)

        it("should handle nil operations", function()
            local preview, err = run_ops.dry_run(nil)

            assert.is_nil(err)
            assert.is_not_nil(preview)
            assert.equals(0, #preview)
        end)
    end)

    describe("run_ops", function()
        it("should handle empty operations", function()
            local success, err = run_ops.run_ops({})

            assert.is_true(success)
            assert.is_nil(err)
        end)

        it("should handle nil operations", function()
            local success, err = run_ops.run_ops(nil)

            assert.is_true(success)
            assert.is_nil(err)
        end)

        it("should respect dry_run option", function()
            local operations = create_test_operations()
            local success, err = run_ops.run_ops(operations, { dry_run = true })

            assert.is_true(success)
            assert.is_nil(err)
        end)

        it("should fail on invalid operations", function()
            local operations = {
                {
                    type = "invalid.op.type",
                    description = "Invalid operation",
                    args = { some = "args" }
                }
            }

            local success, err = run_ops.run_ops(operations, { dry_run = true })

            assert.is_false(success)
            assert.is_not_nil(err)
            assert.equals("UNKNOWN_OPERATION_TYPE", err.code)
        end)

        -- Note: We avoid testing actual file system operations in unit tests
        -- as they would require filesystem setup/teardown and could be flaky
        -- Integration tests should cover actual execution scenarios
    end)

    describe("operation mapping", function()
        it("should map ensure_dir to create_directory", function()
            local operations = {
                {
                    type = "fsynth.op.ensure_dir",
                    description = "Test directory",
                    args = { path = "/test/dir", mode = "0755" }
                }
            }

            -- This tests that validation passes, which means mapping works
            local valid, err = run_ops.validate_ops(operations)
            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should handle symlink operations", function()
            local operations = {
                {
                    type = "fsynth.op.symlink",
                    description = "Test symlink",
                    args = { src = "/src", dest = "/dest", force = true }
                }
            }

            local valid, err = run_ops.validate_ops(operations)
            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should handle file creation operations", function()
            local operations = {
                {
                    type = "fsynth.op.create_file",
                    description = "Test file",
                    args = { path = "/test.txt", content = "content", mode = "0644" }
                }
            }

            local valid, err = run_ops.validate_ops(operations)
            assert.is_true(valid)
            assert.is_nil(err)
        end)
    end)
end)
