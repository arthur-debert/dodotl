-- Registry system for dodot
-- Handles extensible registration of triggers, actions, and power-ups

local M = {}

-- Create a new registry instance
function M.new()
    local registry = {
        items = {},
    }

    -- Add an item to the registry
    function registry.add(key, value)
        if type(key) ~= "string" then
            return false, "Registry key must be a string"
        end

        if key == "" then
            return false, "Registry key cannot be empty"
        end

        if registry.items[key] ~= nil then
            return false, "Registry key '" .. key .. "' already exists"
        end

        if value == nil then
            return false, "Registry value cannot be nil"
        end

        registry.items[key] = value
        return true, nil
    end

    -- Get an item from the registry
    function registry.get(key)
        if type(key) ~= "string" then
            return nil, "Registry key must be a string"
        end

        local value = registry.items[key]
        if value == nil then
            return nil, "Registry key '" .. key .. "' not found"
        end

        return value, nil
    end

    -- Remove an item from the registry
    function registry.remove(key)
        if type(key) ~= "string" then
            return false, "Registry key must be a string"
        end

        if registry.items[key] == nil then
            return false, "Registry key '" .. key .. "' not found"
        end

        registry.items[key] = nil
        return true, nil
    end

    -- List all keys in the registry
    function registry.list()
        local keys = {}
        for key, _ in pairs(registry.items) do
            table.insert(keys, key)
        end
        table.sort(keys) -- Return sorted keys for consistent ordering
        return keys, nil
    end

    -- Check if a key exists in the registry
    function registry.has(key)
        if type(key) ~= "string" then
            return false, "Registry key must be a string"
        end

        return registry.items[key] ~= nil, nil
    end

    -- Get the count of items in the registry
    function registry.count()
        local count = 0
        for _, _ in pairs(registry.items) do
            count = count + 1
        end
        return count, nil
    end

    -- Clear all items from the registry
    function registry.clear()
        registry.items = {}
        return true, nil
    end

    return registry
end

return M
