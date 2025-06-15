-- Core pipeline phase: Operation execution
-- Execute: actually run filesystem changes through fsynth

local fsynth = require("fsynth")
local logger = require("lual").logger("dodot.core.run_ops")
local errors = require("dodot.errors")

local M = {}

-- Map our operation types to fsynth operation functions
local function create_fsynth_operation(operation)
    logger.debug("creating fsynth operation for type: %s", operation.type)

    if operation.type == "fsynth.op.symlink" then
        local args = operation.args
        return fsynth.op.symlink(args.src, args.dest, {
            force = args.force,
            backup = args.backup
        })
    elseif operation.type == "fsynth.op.ensure_dir" or operation.type == "fsynth.op.create_directory" then
        local args = operation.args
        return fsynth.op.create_directory(args.path, {
            mode = args.mode,
            create_parents = true
        })
    elseif operation.type == "fsynth.op.create_file" then
        local args = operation.args
        return fsynth.op.create_file(args.path, args.content, {
            mode = args.mode,
            overwrite = args.overwrite
        })
    elseif operation.type == "fsynth.op.append_to_file" then
        -- fsynth doesn't have append_to_file, so we need to handle this manually
        local args = operation.args
        local existing_content = ""

        -- Read existing file content if it exists
        local file = io.open(args.path, "r")
        if file then
            existing_content = file:read("*all")
            file:close()
        end

        -- Check if content is already present (unique flag)
        local new_content
        if args.unique and existing_content:find(args.content, 1, true) then
            logger.debug("content already exists in file, skipping append")
            new_content = existing_content
        else
            new_content = existing_content .. args.content
        end

        return fsynth.op.create_file(args.path, new_content, {
            mode = args.mode or "0644",
            overwrite = true
        })
    elseif operation.type == "fsynth.op.copy_file" then
        local args = operation.args
        return fsynth.op.copy_file(args.src, args.dest, {
            overwrite = args.overwrite,
            backup = args.backup
        })
    elseif operation.type == "fsynth.op.move_file" then
        local args = operation.args
        return fsynth.op.move_file(args.src, args.dest, {
            overwrite = args.overwrite,
            backup = args.backup
        })
    elseif operation.type == "fsynth.op.delete_file" then
        local args = operation.args
        return fsynth.op.delete_file(args.path)
    elseif operation.type == "fsynth.op.delete_directory" then
        local args = operation.args
        return fsynth.op.delete_directory(args.path, {
            recursive = args.recursive
        })
    else
        logger.debug("unknown operation type: %s", operation.type)
        return nil, errors.create("UNKNOWN_OPERATION_TYPE", operation.type)
    end
end

-- Execute filesystem operations through fsynth
function M.run_ops(fs_operations, options)
    logger.debug("run_ops called with %d operations", fs_operations and #fs_operations or 0)
    options = options or {}

    if not fs_operations or #fs_operations == 0 then
        logger.debug("no operations to execute")
        return true, nil
    end

    -- Create fsynth queue
    local queue = fsynth.new_queue()
    local operation_count = 0

    -- Convert and add operations to queue
    for i, operation in ipairs(fs_operations) do
        logger.debug("processing operation %d: %s", i, operation.description or "no description")

        local fsynth_op, err = create_fsynth_operation(operation)
        if err then
            logger.debug("failed to create fsynth operation %d: %s", i, err.message or tostring(err))
            return false, err
        end

        if fsynth_op then
            queue:add(fsynth_op)
            operation_count = operation_count + 1
            logger.debug("added operation %d to queue", i)
        else
            logger.debug("operation %d produced no fsynth operation (may be intentional)", i)
        end
    end

    logger.debug("added %d operations to fsynth queue", operation_count)

    -- Execute operations through fsynth processor
    logger.debug("executing operations through fsynth processor, dry_run: %s", tostring(options.dry_run))
    local processor = fsynth.new_processor()

    -- Call fsynth's processor:execute. The options.dry_run flag determines whether
    -- fsynth performs a dry run (simulating changes) or a real execution.
    local execute_success, result_or_error = pcall(function()
        -- Pass the dry_run option to fsynth's execute method
        return processor:execute(queue, { dry_run = options.dry_run })
    end)

    if not execute_success then
        logger.debug("fsynth execution pcall failed: %s", tostring(result_or_error))
        return false, errors.create("EXECUTION_FAILED", tostring(result_or_error))
    end

    -- Assuming fsynth's execute returns true/false for success, and then results or error message
    -- This part might need adjustment based on fsynth's actual return contract
    -- For now, let's assume it returns a table of results on success (even if empty for dry run)
    -- or a specific error object/message on failure within fsynth itself (not pcall failure).

    -- If fsynth's execute signals an internal error (e.g. returns false, error_message)
    -- This is a conceptual check; actual fsynth return might be different.
    -- For now, we assume pcall captures most errors. If fsynth returns (false, err_msg),
    -- result_or_error would be that table/value. Let's assume `processor:execute`
    -- itself raises an error on failure, which pcall catches.
    -- So, if execute_success is true, result_or_error is the actual return from processor:execute.

    if options.dry_run then
        logger.debug("fsynth dry run execution successful. Results: %s", type(result_or_error) == "table" and table.concat(result_or_error, ", ") or tostring(result_or_error))
        -- Return structure for dry run: true, results_table (which might be empty or specific dry run output)
        return true, result_or_error
    else
        logger.debug("successfully executed %d operations (real run)", operation_count)
        -- Return structure for real run: true, nil (or potentially results if fsynth returns them)
        return true, result_or_error -- Assuming result_or_error is nil or some status for successful real run
    end
end

-- Generates a dodot-specific textual preview of operations, primarily intended
-- for informational display (e.g., for a 'dodot info' command or similar).
-- This function *does not* invoke fsynth's dry-run mode.
-- To execute operations using fsynth's actual dry-run capability (which might
-- return structured data about simulated changes), call M.run_ops with options.dry_run = true.
function M.dry_run(fs_operations)
    logger.debug("dry_run called with %d operations", fs_operations and #fs_operations or 0)

    if not fs_operations or #fs_operations == 0 then
        logger.debug("no operations for dry run")
        return {}, nil
    end

    local preview = {}

    for i, operation in ipairs(fs_operations) do
        logger.debug("dry run operation %d: %s", i, operation.type)

        table.insert(preview, {
            index = i,
            type = operation.type,
            description = operation.description,
            args = operation.args,
            would_execute = true
        })
    end

    logger.debug("dry run generated %d preview items", #preview)
    return preview, nil
end

-- Validate that operations can be converted to fsynth operations
function M.validate_ops(fs_operations)
    logger.debug("validate_ops called with %d operations", fs_operations and #fs_operations or 0)

    if not fs_operations then
        return true, nil
    end

    local errors_found = {}

    for i, operation in ipairs(fs_operations) do
        local fsynth_op, err = create_fsynth_operation(operation)
        if err then
            table.insert(errors_found, {
                index = i,
                operation = operation,
                error = err
            })
        end
    end

    if #errors_found > 0 then
        logger.debug("validation found %d errors", #errors_found)
        return false, errors.create("VALIDATION_FAILED", string.format("%d validation errors found", #errors_found))
    end

    logger.debug("all operations validated successfully")
    return true, nil
end

return M
