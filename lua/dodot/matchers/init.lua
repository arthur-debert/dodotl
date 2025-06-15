-- Matchers module initialization
-- Registers all built-in matchers with the registry system

local basic_matcher = require("dodot.matchers.basic_matcher")
local registry = require("dodot.matchers.registry")

local M = {}

-- Create default matcher configurations according to design spec
local function create_default_matchers()
    local default_configs = {
        -- Fixed-name matchers (highest priority)
        {
            matcher_name = "alias_files_matcher",
            trigger_name = "file_name",
            power_up_name = "shell_profile",
            priority = 10,
            options = {
                pattern = "alias.*",
                action_type = "source"
            }
        },
        {
            matcher_name = "profile_files_matcher",
            trigger_name = "file_name",
            power_up_name = "shell_profile",
            priority = 15,
            options = {
                pattern = "profile.*",
                action_type = "source"
            }
        },
        {
            matcher_name = "vars_files_matcher",
            trigger_name = "file_name",
            power_up_name = "shell_profile",
            priority = 20,
            options = {
                pattern = "vars.*",
                action_type = "export_vars"
            }
        },
        {
            matcher_name = "env_files_matcher",
            trigger_name = "file_name",
            power_up_name = "shell_profile",
            priority = 25,
            options = {
                pattern = "env.*",
                action_type = "export_vars"
            }
        },
        {
            matcher_name = "bin_directory_matcher",
            trigger_name = "directory",
            power_up_name = "shell_add_path",
            priority = 30,
            options = {
                pattern = "bin"
            }
        },
        {
            matcher_name = "brewfile_matcher",
            trigger_name = "file_name",
            power_up_name = "brew",
            priority = 35,
            options = {
                pattern = "Brewfile"
            }
        },
        {
            matcher_name = "install_scripts_matcher",
            trigger_name = "file_name",
            power_up_name = "script_runner",
            priority = 40,
            options = {
                pattern = "install.*",
                order = 100 -- Run after Brewfile
            }
        },
        -- Catch-all symlink matchers (lower priority)
        {
            matcher_name = "home_directory_matcher",
            trigger_name = "directory",
            power_up_name = "symlink",
            priority = 90,
            options = {
                pattern = "HOME",
                target_dir = "~"
            }
        },
        {
            matcher_name = "home_directory_lowercase_matcher",
            trigger_name = "directory",
            power_up_name = "symlink",
            priority = 91,
            options = {
                pattern = "home",
                target_dir = "~"
            }
        },
        {
            matcher_name = "config_directory_matcher",
            trigger_name = "directory",
            power_up_name = "symlink",
            priority = 95,
            options = {
                pattern = "*", -- Match any directory not caught by higher priority matchers
                target_dir = "~/.config"
            }
        },
        {
            matcher_name = "dotfiles_matcher",
            trigger_name = "file_name",
            power_up_name = "symlink",
            priority = 100,
            options = {
                pattern = ".*", -- Match any files not caught by higher priority matchers (dot files)
                target_dir = "~"
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
        -- Fixed-name matchers (high priority)
        {
            matcher_name = "alias_files_matcher",
            trigger_name = "file_name",
            power_up_name = "shell_profile",
            priority = 10,
            options = {
                pattern = "alias.*",
                action_type = "source"
            }
        },
        {
            matcher_name = "vars_files_matcher",
            trigger_name = "file_name",
            power_up_name = "shell_profile",
            priority = 20,
            options = {
                pattern = "vars.*",
                action_type = "export_vars"
            }
        },
        {
            matcher_name = "env_files_matcher",
            trigger_name = "file_name",
            power_up_name = "shell_profile",
            priority = 25,
            options = {
                pattern = "env.*",
                action_type = "export_vars"
            }
        },
        {
            matcher_name = "profile_files_matcher",
            trigger_name = "file_name",
            power_up_name = "shell_profile",
            priority = 26,
            options = {
                pattern = "profile.*",
                action_type = "source"
            }
        },
        {
            matcher_name = "bin_dirs_matcher",
            trigger_name = "directory",
            power_up_name = "shell_add_path",
            priority = 30,
            options = {
                pattern = "bin"
            }
        },
        {
            matcher_name = "brewfile_matcher",
            trigger_name = "file_name",
            power_up_name = "brew",
            priority = 35,
            options = {
                pattern = "Brewfile"
            }
        },
        {
            matcher_name = "install_scripts_matcher",
            trigger_name = "file_name",
            power_up_name = "script_runner",
            priority = 40,
            options = {
                pattern = "install.*",
                order = 100
            }
        },
        -- Catch-all symlink matchers (lower priority)
        {
            matcher_name = "home_directory_matcher",
            trigger_name = "directory",
            power_up_name = "symlink",
            priority = 85,
            options = {
                pattern = "HOME",
                target_dir = "~"
            }
        },
        {
            matcher_name = "config_dirs_matcher",
            trigger_name = "directory",
            power_up_name = "symlink",
            priority = 90,
            options = {
                pattern = "nvim",
                target_dir = "~/.config"
            }
        },
        {
            matcher_name = "dotfiles_matcher",
            trigger_name = "file_name",
            power_up_name = "symlink",
            priority = 95,
            options = {
                pattern = ".git*", -- Match .gitconfig, .gitignore, etc.
                target_dir = "~"
            }
        }
    }, nil
end

return M
