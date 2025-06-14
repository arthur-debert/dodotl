-- lua/dodot/core/get_firing_triggers.lua
local libs = require("dodot.libs")
local types = require("dodot.types")
local errors = require("dodot.errors")
local pl_path = require("pl.path")
local pl_dir = require("pl.dir") -- For pl_dir.getfiles

local M = {}

local function get_matchers()
    if not libs.is_initialized() then libs.init() end

    -- Use the matcher system to get configured matchers
    local matchers = require("dodot.matchers")
    return matchers.get_simulated_matchers()
end

function M.get_firing_triggers(packs)
    if not libs.is_initialized() then libs.init() end

    local all_trigger_matches = {}
    local matcher_configs, err = get_matchers()
    if err then return nil, err end
    if not matcher_configs or #matcher_configs == 0 then return {}, nil end

    for _, pack in ipairs(packs) do
        -- Get both files and directories for comprehensive matching
        local pack_files, list_err = pl_dir.getfiles(pack.path)
        if list_err then
            print("Warning: Could not list files for pack " .. pack.path .. ": " .. tostring(list_err))
            pack_files = {}
        end
        if not pack_files then pack_files = {} end

        local pack_dirs, dir_err = pl_dir.getdirectories(pack.path)
        if dir_err then
            print("Warning: Could not list directories for pack " .. pack.path .. ": " .. tostring(dir_err))
            pack_dirs = {}
        end
        if not pack_dirs then pack_dirs = {} end

        -- Combine files and directories for matching
        local all_items = {}
        for _, file_path in ipairs(pack_files) do
            -- pl_dir.getfiles returns full paths, don't join with pack.path again
            table.insert(all_items, file_path)
        end
        for _, dir_path in ipairs(pack_dirs) do
            -- Skip current and parent directory entries
            local dir_basename = pl_path.basename(dir_path)
            if dir_basename ~= "." and dir_basename ~= ".." then
                -- pl_dir.getdirectories returns full paths, use them directly
                table.insert(all_items, dir_path)
            end
        end

        for _, item_path in ipairs(all_items) do
            for _, matcher_config in ipairs(matcher_configs) do
                local trigger_class, trigger_err = libs.triggers.get(matcher_config.trigger_name)
                if trigger_err then return nil, trigger_err end
                if not trigger_class then
                    return nil,
                        errors.create("TRIGGER_NOT_FOUND", "Trigger not found: " .. matcher_config.trigger_name)
                end

                -- Create trigger instance with configuration from matcher
                local trigger_instance
                if matcher_config.trigger_name == "file_name" and matcher_config.options and matcher_config.options.pattern then
                    -- For file_name triggers, create instance with pattern from matcher options
                    trigger_instance = trigger_class.new(matcher_config.options.pattern)
                elseif matcher_config.trigger_name == "directory" and matcher_config.options and matcher_config.options.pattern then
                    -- For directory triggers, create instance with pattern from matcher options
                    trigger_instance = trigger_class.new(matcher_config.options.pattern)
                elseif matcher_config.trigger_name == "extension" and matcher_config.options and matcher_config.options.extensions then
                    -- For extension triggers, create instance with extensions from matcher options
                    trigger_instance = trigger_class.new(matcher_config.options.extensions)
                elseif type(trigger_class.match) == "function" then
                    -- For stub triggers that don't need configuration, use the class directly
                    trigger_instance = trigger_class
                else
                    return nil,
                        errors.create("INVALID_TRIGGER_CONFIG",
                            {
                                trigger_name = matcher_config.trigger_name,
                                reason = "don't know how to create instance for trigger type"
                            })
                end

                if not trigger_instance or type(trigger_instance.match) ~= "function" then
                    return nil,
                        errors.create("INVALID_TRIGGER_CONFIG",
                            { trigger_name = matcher_config.trigger_name, reason = "missing match function" })
                end

                local matched, metadata = trigger_instance:match(item_path, pack.path)
                if matched then
                    local trigger_match = {
                        trigger_name = matcher_config.trigger_name,
                        file_path = item_path,
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
    return all_trigger_matches, nil
end

return M
