-- Matchers module initialization
-- Registers all built-in matchers with the registry system

local basic_matcher = require("dodot.matchers.basic_matcher")
local registry = require("dodot.matchers.registry")

local M = {}

-- Create default matcher configurations
local function create_default_matchers()
    local default_configs = {
        {
            matcher_name = "vim_config_matcher",
            trigger_name = "file_name",
            power_up_name = "symlink",
            priority = 20,
            options = {
                pattern = "*.vim",
                target_dir = "~/.vim"
            }
        },
        {
            matcher_name = "dotfile_matcher",
            trigger_name = "file_name",
            power_up_name = "symlink",
            priority = 15,
            options = {
                pattern = ".*rc",
                target_dir = "~"
            }
        },
        {
            matcher_name = "config_dir_matcher",
            trigger_name = "directory",
            power_up_name = "symlink",
            priority = 10,
            options = {
                pattern = "config/**",
                target_dir = "~/.config"
            }
        }
    }

    local matchers = {}
    for _, config in ipairs(default_configs) do
        local matcher = basic_matcher.BasicMatcher.new(config)
        if matcher then
            table.insert(matchers, matcher)
        end
    end

    return matchers
end

-- Create and configure a default matcher registry
function M.create_default_registry()
    local matcher_registry = registry.MatcherRegistry.new()

    local default_matchers = create_default_matchers()
    for _, matcher in ipairs(default_matchers) do
        matcher_registry:add(matcher)
    end

    return matcher_registry
end

-- Get matcher configurations for the pipeline (compatible with existing code)
function M.get_matcher_configs(matcher_registry)
    matcher_registry = matcher_registry or M.create_default_registry()
    return matcher_registry:get_all_configs()
end

-- Register all built-in matchers with the component registry
function M.register_matchers(registry)
    -- Register the BasicMatcher type for extensibility
    registry.add("basic_matcher", basic_matcher.BasicMatcher)
end

-- For backward compatibility with get_firing_triggers.lua
function M.get_simulated_matchers()
    -- Return the original stub configuration for backward compatibility
    return {
        {
            matcher_name = "stub_matcher_1",
            trigger_name = "stub_file_name_trigger", -- use existing stub for now
            power_up_name = "stub_symlink_powerup",  -- use existing stub for now
            priority = 10,                           -- original priority for compatibility
            options = { simulated_option = true }    -- original options for compatibility
        }
    }, nil
end

return M
