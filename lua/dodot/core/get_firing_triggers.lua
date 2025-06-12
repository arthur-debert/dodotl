-- lua/dodot/core/get_firing_triggers.lua
local libs = require("dodot.libs")
local types = require("dodot.types")
local errors = require("dodot.errors")
local pl_path = require("pl.path")
local pl_dir = require("pl.dir") -- For pl_dir.getfiles

local M = {}

local function get_simulated_matchers()
    if not libs.is_initialized() then libs.init() end

    if not libs.triggers.has("stub_file_name_trigger") then
        return nil, errors.create("UNKNOWN_ERROR_CODE", "Stub trigger 'stub_file_name_trigger' not found in registry.")
    end
    if not libs.powerups.has("stub_symlink_powerup") then
        return nil, errors.create("UNKNOWN_ERROR_CODE", "Stub powerup 'stub_symlink_powerup' not found in registry.")
    end

    return {
        {
            matcher_name = "stub_matcher_1",
            trigger_name = "stub_file_name_trigger",
            power_up_name = "stub_symlink_powerup",
            priority = 10,
            options = { simulated_option = true }
        }
    }, nil
end

function M.get_firing_triggers(packs)
    if not libs.is_initialized() then libs.init() end

    local all_trigger_matches = {}
    local simulated_matchers, err = get_simulated_matchers()
    if err then return nil, err end
    if not simulated_matchers or #simulated_matchers == 0 then return {}, nil end -- Adjusted check

    for _, pack in ipairs(packs) do
        local pack_files, list_err = pl_dir.getfiles(pack.path)
        if list_err then
            print("Warning: Could not list files for pack " .. pack.path .. ": " .. tostring(list_err))
            -- Skip to next pack iteration by restructuring
        else
            if not pack_files then pack_files = {} end
            for _, file_name in ipairs(pack_files) do
                local full_file_path = pl_path.join(pack.path, file_name)
                for _, matcher_config in ipairs(simulated_matchers) do
                    local trigger_instance, trigger_err = libs.triggers.get(matcher_config.trigger_name)
                    if trigger_err then return nil, trigger_err end
                    if not trigger_instance then
                        return nil, errors.create("TRIGGER_NOT_FOUND", "Trigger not found: " .. matcher_config.trigger_name)
                    end

                    if type(trigger_instance.match) ~= "function" then
                        return nil, errors.create("INVALID_TRIGGER_CONFIG", {trigger_name = matcher_config.trigger_name, reason = "missing match function"})
                    end

                    local matched, metadata = trigger_instance:match(full_file_path, pack.path)
                    if matched then
                        local trigger_match = {
                            trigger_name = matcher_config.trigger_name,
                            file_path = full_file_path,
                            pack_path = pack.path,
                            metadata = metadata,
                            power_up_name = matcher_config.power_up_name,
                            priority = matcher_config.priority,
                            options = matcher_config.options,
                        }
                        table.insert(all_trigger_matches, trigger_match)
                    end
                end
            end
        end
    end
    return all_trigger_matches, nil
end

return M
