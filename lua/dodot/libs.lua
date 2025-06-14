-- libs module for dodot
-- Initial registry setup for triggers, actions, and power-ups

local M = {}
local registry = require("dodot.utils.registry")

-- Registry instances
M.triggers = nil
M.actions = nil
M.powerups = nil

-- Initialize all registries
function M.init()
    -- Create registry instances
    M.triggers = registry.new()
    M.actions = registry.new()
    M.powerups = registry.new()

    -- Load built-in components
    local triggers_init = require("dodot.triggers.init")
    local actions_init = require("dodot.actions.init")
    local powerups_init = require("dodot.powerups.init")

    -- Register all built-in components
    triggers_init.register_triggers(M.triggers)
    actions_init.register_actions(M.actions)
    powerups_init.register_powerups(M.powerups)

    return true, nil
end

-- Get a specific registry by name
function M.get_registry(name)
    if name == "triggers" then
        return M.triggers, nil
    elseif name == "actions" then
        return M.actions, nil
    elseif name == "powerups" then
        return M.powerups, nil
    else
        return nil, "Unknown registry: " .. tostring(name)
    end
end

-- Check if registries are initialized
function M.is_initialized()
    return M.triggers ~= nil and M.actions ~= nil and M.powerups ~= nil
end

-- Get statistics about all registries
function M.get_stats()
    if not M.is_initialized() then
        return nil, "Registries not initialized"
    end

    local triggers_count, _ = M.triggers.count()
    local actions_count, _ = M.actions.count()
    local powerups_count, _ = M.powerups.count()

    return {
        triggers = triggers_count,
        actions = actions_count,
        powerups = powerups_count,
        total = triggers_count + actions_count + powerups_count
    }, nil
end

return M
