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
    -- Return real matcher configurations that should work with the test fixtures
    return {
        {
            matcher_name = "gitconfig_matcher",
            trigger_name = "file_name",
            power_up_name = "symlink",
            priority = 5,
            options = {
                pattern = ".gitconfig",
                target_dir = "~"
            }
        },
        {
            matcher_name = "gitignore_matcher",
            trigger_name = "file_name",
            power_up_name = "symlink",
            priority = 6,
            options = {
                pattern = ".gitignore",
                target_dir = "~"
            }
        },
        {
            matcher_name = "dotfiles_matcher",
            trigger_name = "file_name",
            power_up_name = "symlink",
            priority = 10,
            options = {
                pattern = ".git*", -- Match .gitconfig, .gitignore, etc.
                target_dir = "~"
            }
        },
        {
            matcher_name = "config_dirs_matcher",
            trigger_name = "directory",
            power_up_name = "symlink",
            priority = 15,
            options = {
                pattern = "nvim",
                target_dir = "~/.config"
            }
        },
        {
            matcher_name = "alias_files_matcher",
            trigger_name = "file_name",
            power_up_name = "shell_profile",
            priority = 20,
            options = {
                pattern = "alias.sh",
                action_type = "source"
            }
        },
        {
            matcher_name = "env_files_matcher",
            trigger_name = "file_name",
            power_up_name = "shell_profile",
            priority = 25,
            options = {
                pattern = "env.sh",
                action_type = "source"
            }
        },
        {
            matcher_name = "vars_files_matcher",
            trigger_name = "file_name",
            power_up_name = "shell_profile",
            priority = 30,
            options = {
                pattern = "vars.sh",
                action_type = "source"
            }
        },
        {
            matcher_name = "bin_dirs_matcher",
            trigger_name = "directory",
            power_up_name = "shell_add_path",
            priority = 35,
            options = {
                pattern = "bin"
            }
        }
    }, nil
end

return M
