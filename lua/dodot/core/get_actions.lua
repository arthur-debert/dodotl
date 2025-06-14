-- lua/dodot/core/get_actions.lua
local libs = require("dodot.libs")
local types = require("dodot.types")
local errors = require("dodot.errors")
local pl_path = require("pl.path")
local logger = require("lual").logger("dodot.core.actions")

local M = {}

local function group_trigger_matches(trigger_matches_list)
    logger.debug("group_trigger_matches called with %d trigger matches",
        trigger_matches_list and #trigger_matches_list or 0)
    local grouped = {}
    if not trigger_matches_list then
        logger.debug("no trigger matches provided, returning empty groups")
        return grouped
    end

    for _, match in ipairs(trigger_matches_list) do
        logger.debug("processing trigger match: %s → %s (file: %s)", match.trigger_name, match.power_up_name,
            match.file_path)
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
        logger.debug("calculated group key: %s", group_key)

        if not grouped[group_key] then
            logger.debug("creating new group for key: %s", group_key)
            grouped[group_key] = {
                power_up_name = match.power_up_name,
                pack_path = match.pack_path,
                options = match.options,
                matches_payload = {}
            }
        else
            logger.debug("adding to existing group: %s", group_key)
        end
        table.insert(grouped[group_key].matches_payload, {
            path = match.file_path,
            metadata = match.metadata,
            -- pack_source_name is determined per group later, not per individual file match payload here
        })
    end
    logger.debug("grouped trigger matches into %d groups",
        grouped and (function()
            local count = 0; for _ in pairs(grouped) do count = count + 1 end; return count
        end)() or 0)
    return grouped
end

function M.get_actions(trigger_matches_list)
    logger.debug("get_actions called with %d trigger matches", trigger_matches_list and #trigger_matches_list or 0)
    if not libs.is_initialized() then
        logger.debug("libs not initialized, calling libs.init()")
        libs.init()
    end
    local all_actions = {}
    logger.debug("grouping trigger matches by power-up and options")
    local grouped_matches = group_trigger_matches(trigger_matches_list)

    logger.debug("processing %d powerup groups",
        grouped_matches and
        (function()
            local count = 0; for _ in pairs(grouped_matches) do count = count + 1 end; return count
        end)() or 0)
    for _, group_info in pairs(grouped_matches) do
        logger.debug("processing powerup group: %s (pack: %s)", group_info.power_up_name, group_info.pack_path)
        local powerup_instance, pu_err = libs.powerups.get(group_info.power_up_name)
        if pu_err then
            logger.debug("error getting powerup %s: %s", group_info.power_up_name, pu_err)
            return nil, pu_err
        end
        if not powerup_instance then
            logger.debug("powerup not found: %s", group_info.power_up_name)
            return nil, errors.create("POWERUP_NOT_FOUND", group_info.power_up_name)
        end
        logger.debug("powerup instance found: %s", group_info.power_up_name)

        if type(powerup_instance.process) ~= "function" then
            logger.debug("powerup %s missing process function", group_info.power_up_name)
            return nil,
                errors.create("POWERUP_VALIDATION_FAILED",
                    { powerup_name = group_info.power_up_name, reason = "missing process function" })
        end

        -- Prepare files_for_powerup from matches_payload
        logger.debug("preparing %d files for powerup processing", #group_info.matches_payload)
        local files_for_powerup = {}
        for _, file_match_payload in ipairs(group_info.matches_payload) do
            logger.debug("adding file to powerup input: %s", file_match_payload.path)
            table.insert(files_for_powerup, { path = file_match_payload.path, metadata = file_match_payload.metadata })
        end

        -- Determine pack_source_name for this group (all files in a group are from the same pack_path)
        local pack_source_name_for_action = pl_path.basename(group_info.pack_path)
        logger.debug("pack source name for actions: %s", pack_source_name_for_action)

        logger.debug("calling powerup.process() for %s with %d files", group_info.power_up_name, #files_for_powerup)
        local generated_actions, err = powerup_instance:process(files_for_powerup, group_info.pack_path,
            group_info.options)
        if err then
            -- Wrap error from powerup into a dodot error object
            local err_message = (type(err) == "table" and err.message or tostring(err))
            logger.debug("powerup %s process failed: %s", group_info.power_up_name, err_message)
            return nil,
                errors.create("POWERUP_EXECUTION_FAILED",
                    { powerup_name = group_info.power_up_name, reason = err_message })
        end

        if generated_actions then -- Ensure generated_actions is not nil
            logger.debug("powerup %s generated %d actions", group_info.power_up_name, #generated_actions)
            for i, action_data in ipairs(generated_actions) do
                if not action_data.pack_source then
                    action_data.pack_source = pack_source_name_for_action
                end
                -- Potentially validate action_data against types.is_action if available
                table.insert(all_actions, action_data)
                logger.debug("action %d: type=%s, description=%s", i, action_data.type or "unknown",
                action_data.description or "no description")
            end
        else
            logger.debug("powerup %s generated no actions (nil result)", group_info.power_up_name)
        end
    end
    logger.debug("get_actions returning %d total actions", #all_actions)
    return all_actions, nil
end

return M
