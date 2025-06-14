-- MatcherRegistry implementation
-- Manages collections of matchers and provides validation

local errors = require("dodot.errors")

local M = {}

local MatcherRegistry = {
    type = "matcher_registry",

    -- Add a matcher to the registry
    add = function(self, matcher)
        if not matcher then
            return false, "Cannot add nil matcher"
        end

        if not matcher.matcher_name then
            return false, "Matcher must have a matcher_name"
        end

        -- Check for duplicates
        if self.matchers[matcher.matcher_name] then
            return false, "Matcher with name '" .. matcher.matcher_name .. "' already exists"
        end

        -- Validate the matcher
        local valid, err = matcher:validate()
        if not valid then
            return false, "Invalid matcher: " .. err
        end

        self.matchers[matcher.matcher_name] = matcher
        return true, nil
    end,

    -- Remove a matcher from the registry
    remove = function(self, matcher_name)
        if not matcher_name then
            return false, "Matcher name is required"
        end

        if not self.matchers[matcher_name] then
            return false, "Matcher '" .. matcher_name .. "' not found"
        end

        self.matchers[matcher_name] = nil
        return true, nil
    end,

    -- Get a matcher by name
    get = function(self, matcher_name)
        if not matcher_name then
            return nil, "Matcher name is required"
        end

        local matcher = self.matchers[matcher_name]
        if not matcher then
            return nil, "Matcher '" .. matcher_name .. "' not found"
        end

        return matcher, nil
    end,

    -- List all matchers
    list = function(self)
        local result = {}
        for name, matcher in pairs(self.matchers) do
            table.insert(result, matcher)
        end
        return result
    end,

    -- Get all matchers as configs for the pipeline
    get_all_configs = function(self)
        local configs = {}
        for name, matcher in pairs(self.matchers) do
            table.insert(configs, matcher:to_config())
        end

        -- Sort by priority (higher priority first)
        table.sort(configs, function(a, b)
            return (a.priority or 10) > (b.priority or 10)
        end)

        return configs
    end,

    -- Validate all matchers against available triggers and power-ups
    validate_all = function(self, trigger_registry, powerup_registry)
        local errors_found = {}

        for name, matcher in pairs(self.matchers) do
            -- Validate basic matcher structure
            local valid, err = matcher:validate()
            if not valid then
                table.insert(errors_found, "Matcher '" .. name .. "': " .. err)
            else
                -- Validate trigger exists
                if trigger_registry and not trigger_registry:has(matcher.trigger_name) then
                    table.insert(errors_found,
                        "Matcher '" .. name .. "': trigger '" .. matcher.trigger_name .. "' not found")
                end

                -- Validate power-up exists
                if powerup_registry and not powerup_registry:has(matcher.power_up_name) then
                    table.insert(errors_found,
                        "Matcher '" .. name .. "': power-up '" .. matcher.power_up_name .. "' not found")
                end
            end
        end

        if #errors_found > 0 then
            return false, table.concat(errors_found, "; ")
        end

        return true, nil
    end,

    -- Get the number of matchers
    count = function(self)
        local count = 0
        for _ in pairs(self.matchers) do
            count = count + 1
        end
        return count
    end,

    -- Clear all matchers
    clear = function(self)
        self.matchers = {}
    end
}

-- Create a new MatcherRegistry instance
function MatcherRegistry.new()
    local instance = {
        type = "matcher_registry",
        matchers = {}
    }

    setmetatable(instance, { __index = MatcherRegistry })
    return instance
end

M.MatcherRegistry = MatcherRegistry

return M
