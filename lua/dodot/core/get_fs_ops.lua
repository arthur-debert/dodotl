-- lua/dodot/core/get_fs_ops.lua
local types = require("dodot.types")
local errors = require("dodot.errors")

local M = {}

-- This dispatch table maps action types to functions that build fs operations.
local action_to_op_builder = {
    link_stub = function(action)
        -- Validate action.data structure for link_stub if needed
        if not action.data or not action.data.src or not action.data.dest then
            return nil, errors.create("INVALID_ACTION_DATA", {action_type = "link_stub", reason = "Missing src or dest in data"})
        end
        return {
            {
                type = "fsynth.op.symlink_stub",
                description = action.description or "Stub symlink operation from link_stub action",
                args = action.data
            }
        }, nil -- No error
    end,
    -- In the future, other action types like "copy_file", "ensure_dir" would have entries here.
    -- e.g.,
    -- copy_file = function(action)
    --     return {{ type = "fsynth.op.copy_file", args = action.data }}, nil
    -- end,
}

function M.get_fs_ops(actions_list)
    local operations = {}
    if not actions_list then return operations, nil end

    for _, action in ipairs(actions_list) do
        if not action or not action.type then
            print("Warning: Skipping malformed action (missing type or action itself is nil).")
        else
            local builder = action_to_op_builder[action.type]
            if builder then
                local success, result = pcall(builder, action)
                if success then
                    if type(result) == "table" and result.message and result.code then
                        print("Error building ops for action type " .. action.type .. ": " .. result.message)
                    elseif type(result) == "table" then
                        for _, op in ipairs(result) do
                            table.insert(operations, op)
                        end
                    -- else: builder might validly return nil or non-table if no ops for valid action data
                    end
                else
                    print("Critical error in builder for action type " .. action.type .. ": " .. tostring(result))
                end
            else
                print("Warning: No operation builder found for action type: " .. action.type)
            end
        end
    end
    return operations, nil
end

return M
