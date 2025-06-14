-- lua/dodot/core/get_firing_triggers.lua
local libs = require("dodot.libs")
local types = require("dodot.types")
local errors = require("dodot.errors")
local pl_path = require("pl.path")
local pl_dir = require("pl.dir") -- For pl_dir.getfiles
local logger = require("lual").logger("dodot.core.get_firing_triggers")

local M = {}

local function get_matchers()
    logger.debug("get_matchers called")
    if not libs.is_initialized() then
        logger.debug("libs not initialized, calling libs.init()")
        libs.init()
    end

    -- Use the matcher system to get configured matchers
    logger.debug("loading matchers module")
    local matchers = require("dodot.matchers")
    local result = matchers.get_simulated_matchers()
    logger.debug("get_simulated_matchers returned %d matchers", result and #result or 0)
    return result
end

function M.get_firing_triggers(packs)
    logger.debug("get_firing_triggers called with %d packs", packs and #packs or 0)
    if not libs.is_initialized() then
        logger.debug("libs not initialized, calling libs.init()")
        libs.init()
    end

    local all_trigger_matches = {}
    logger.debug("getting matcher configurations")
    local matcher_configs, err = get_matchers()
    if err then
        logger.debug("error getting matchers: %s", err)
        return nil, err
    end
    if not matcher_configs or #matcher_configs == 0 then
        logger.debug("no matcher configs found, returning empty result")
        return {}, nil
    end
    logger.debug("found %d matcher configurations", #matcher_configs)

    for _, pack in ipairs(packs) do
        logger.debug("processing pack: %s (path: %s)", pack.name, pack.path)

        -- Get both files and directories for comprehensive matching
        logger.debug("scanning files in pack: %s", pack.path)
        local pack_files, list_err = pl_dir.getfiles(pack.path)
        if list_err then
            logger.debug("warning: could not list files for pack %s: %s", pack.path, tostring(list_err))
            pack_files = {}
        end
        if not pack_files then pack_files = {} end
        logger.debug("found %d files in pack %s", #pack_files, pack.name)

        logger.debug("scanning directories in pack: %s", pack.path)
        local pack_dirs, dir_err = pl_dir.getdirectories(pack.path)
        if dir_err then
            logger.debug("warning: could not list directories for pack %s: %s", pack.path, tostring(dir_err))
            pack_dirs = {}
        end
        if not pack_dirs then pack_dirs = {} end
        logger.debug("found %d directories in pack %s", #pack_dirs, pack.name)

        -- Combine files and directories for matching
        logger.debug("combining files and directories for matching")
        local all_items = {}
        for _, file_path in ipairs(pack_files) do
            -- pl_dir.getfiles returns full paths, don't join with pack.path again
            logger.debug("adding file to matching list: %s", file_path)
            table.insert(all_items, file_path)
        end
        for _, dir_path in ipairs(pack_dirs) do
            -- Skip current and parent directory entries
            local dir_basename = pl_path.basename(dir_path)
            if dir_basename ~= "." and dir_basename ~= ".." then
                -- pl_dir.getdirectories returns full paths, use them directly
                logger.debug("adding directory to matching list: %s", dir_path)
                table.insert(all_items, dir_path)
            else
                logger.debug("skipping special directory: %s", dir_basename)
            end
        end
        logger.debug("total items to check for triggers: %d", #all_items)

        for _, item_path in ipairs(all_items) do
            logger.debug("checking item for trigger matches: %s", item_path)
            for _, matcher_config in ipairs(matcher_configs) do
                logger.debug("testing matcher: %s → %s", matcher_config.trigger_name, matcher_config.power_up_name)
                local trigger_class, trigger_err = libs.triggers.get(matcher_config.trigger_name)
                if trigger_err then
                    logger.debug("error getting trigger class %s: %s", matcher_config.trigger_name, trigger_err)
                    return nil, trigger_err
                end
                if not trigger_class then
                    logger.debug("trigger class not found: %s", matcher_config.trigger_name)
                    return nil,
                        errors.create("TRIGGER_NOT_FOUND", "Trigger not found: " .. matcher_config.trigger_name)
                end

                -- Create trigger instance with configuration from matcher
                logger.debug("creating trigger instance for %s", matcher_config.trigger_name)
                local trigger_instance
                if matcher_config.trigger_name == "file_name" and matcher_config.options and matcher_config.options.pattern then
                    -- For file_name triggers, create instance with pattern from matcher options
                    logger.debug("creating file_name trigger with pattern: %s", matcher_config.options.pattern)
                    trigger_instance = trigger_class.new(matcher_config.options.pattern)
                elseif matcher_config.trigger_name == "directory" and matcher_config.options and matcher_config.options.pattern then
                    -- For directory triggers, create instance with pattern from matcher options
                    logger.debug("creating directory trigger with pattern: %s", matcher_config.options.pattern)
                    trigger_instance = trigger_class.new(matcher_config.options.pattern)
                elseif matcher_config.trigger_name == "extension" and matcher_config.options and matcher_config.options.extensions then
                    -- For extension triggers, create instance with extensions from matcher options
                    logger.debug("creating extension trigger with extensions: %s",
                        table.concat(matcher_config.options.extensions, ", "))
                    trigger_instance = trigger_class.new(matcher_config.options.extensions)
                elseif type(trigger_class.match) == "function" then
                    -- For stub triggers that don't need configuration, use the class directly
                    logger.debug("using trigger class directly (stub trigger)")
                    trigger_instance = trigger_class
                else
                    logger.debug("don't know how to create instance for trigger type: %s", matcher_config.trigger_name)
                    return nil,
                        errors.create("INVALID_TRIGGER_CONFIG",
                            {
                                trigger_name = matcher_config.trigger_name,
                                reason = "don't know how to create instance for trigger type"
                            })
                end

                if not trigger_instance or type(trigger_instance.match) ~= "function" then
                    logger.debug("invalid trigger instance or missing match function for %s", matcher_config
                        .trigger_name)
                    return nil,
                        errors.create("INVALID_TRIGGER_CONFIG",
                            { trigger_name = matcher_config.trigger_name, reason = "missing match function" })
                end

                logger.debug("calling match on trigger %s for item: %s", matcher_config.trigger_name, item_path)
                local matched, metadata = trigger_instance:match(item_path, pack.path)
                if matched then
                    logger.debug("MATCH FOUND! %s → %s (item: %s)", matcher_config.trigger_name,
                        matcher_config.power_up_name, item_path)
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
                else
                    logger.debug("no match for %s on item: %s", matcher_config.trigger_name, item_path)
                end
            end
        end
    end
    logger.debug("get_firing_triggers returning %d trigger matches", #all_trigger_matches)
    return all_trigger_matches, nil
end

return M
