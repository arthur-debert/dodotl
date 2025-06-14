-- lua/dodot/core/get_actions.lua
local libs = require("dodot.libs")
local types = require("dodot.types")
local errors = require("dodot.errors")
local pl_path = require("pl.path")

local M = {}

local function group_trigger_matches(trigger_matches_list)
    local grouped = {}
    if not trigger_matches_list then return grouped end

    for _, match in ipairs(trigger_matches_list) do
        local options_key_parts = {}
        if match.options and type(match.options) == "table" then
            -- Sort keys for consistent options_key
            local sorted_option_keys = {}
            for k, _ in pairs(match.options) do table.insert(sorted_option_keys, k) end
            table.sort(sorted_option_keys)
            for _, k in ipairs(sorted_option_keys) do
                table.insert(options_key_parts, tostring(k) .. "=" .. tostring(match.options[k]))
            end
        end
        local options_key = table.concat(options_key_parts, ";")
        local group_key = match.power_up_name .. "::" .. match.pack_path .. "::" .. options_key

        if not grouped[group_key] then
            grouped[group_key] = {
                power_up_name = match.power_up_name,
                pack_path = match.pack_path,
                options = match.options,
                matches_payload = {}
            }
        end
        table.insert(grouped[group_key].matches_payload, {
            path = match.file_path,
            metadata = match.metadata,
            -- pack_source_name is determined per group later, not per individual file match payload here
        })
    end
    return grouped
end

function M.get_actions(trigger_matches_list)
    if not libs.is_initialized() then libs.init() end
    local all_actions = {}
    local grouped_matches = group_trigger_matches(trigger_matches_list)

    for _, group_info in pairs(grouped_matches) do
        local powerup_instance, pu_err = libs.powerups.get(group_info.power_up_name)
        if pu_err then return nil, pu_err end
        if not powerup_instance then
            return nil, errors.create("POWERUP_NOT_FOUND", group_info.power_up_name)
        end

        if type(powerup_instance.process) ~= "function" then
            return nil, errors.create("POWERUP_VALIDATION_FAILED", {powerup_name = group_info.power_up_name, reason = "missing process function"})
        end

        -- Prepare files_for_powerup from matches_payload
        local files_for_powerup = {}
        for _, file_match_payload in ipairs(group_info.matches_payload) do
            table.insert(files_for_powerup, { path = file_match_payload.path, metadata = file_match_payload.metadata })
        end

        -- Determine pack_source_name for this group (all files in a group are from the same pack_path)
        local pack_source_name_for_action = pl_path.basename(group_info.pack_path)

        local generated_actions, err = powerup_instance:process(files_for_powerup, group_info.pack_path, group_info.options)
        if err then
            -- Wrap error from powerup into a dodot error object
            local err_message = (type(err) == "table" and err.message or tostring(err))
            return nil, errors.create("POWERUP_EXECUTION_FAILED", {powerup_name = group_info.power_up_name, reason = err_message})
        end

        if generated_actions then -- Ensure generated_actions is not nil
            for _, action_data in ipairs(generated_actions) do
                if not action_data.pack_source then
                    action_data.pack_source = pack_source_name_for_action
                end
                -- Potentially validate action_data against types.is_action if available
                table.insert(all_actions, action_data)
            end
        end
    end
    return all_actions, nil
end

return M
