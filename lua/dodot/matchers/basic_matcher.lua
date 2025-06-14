-- BasicMatcher implementation
-- Connects triggers to power-ups with configuration

local M = {}

local BasicMatcher = {
    type = "basic_matcher",

    -- Validate the matcher configuration
    validate = function(self)
        if not self.matcher_name or self.matcher_name == "" then
            return false, "BasicMatcher requires a non-empty matcher_name"
        end

        if not self.trigger_name or self.trigger_name == "" then
            return false, "BasicMatcher requires a non-empty trigger_name"
        end

        if not self.power_up_name or self.power_up_name == "" then
            return false, "BasicMatcher requires a non-empty power_up_name"
        end

        if self.priority and (type(self.priority) ~= "number" or self.priority < 0) then
            return false, "BasicMatcher priority must be a non-negative number"
        end

        if self.options and type(self.options) ~= "table" then
            return false, "BasicMatcher options must be a table"
        end

        return true, nil
    end,

    -- Get the matcher configuration as expected by the pipeline
    to_config = function(self)
        return {
            matcher_name = self.matcher_name,
            trigger_name = self.trigger_name,
            power_up_name = self.power_up_name,
            priority = self.priority or 10, -- default priority
            options = self.options or {}    -- default empty options
        }
    end
}

-- Create a new BasicMatcher instance
function BasicMatcher.new(config)
    if not config then
        return nil, "BasicMatcher requires configuration"
    end

    local instance = {
        type = "basic_matcher",
        matcher_name = config.matcher_name,
        trigger_name = config.trigger_name,
        power_up_name = config.power_up_name,
        priority = config.priority,
        options = config.options
    }

    setmetatable(instance, { __index = BasicMatcher })

    -- Validate the instance
    local valid, err = instance:validate()
    if not valid then
        return nil, err
    end

    return instance
end

M.BasicMatcher = BasicMatcher

return M
