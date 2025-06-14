-- Actions module initialization
-- Registers all built-in actions with the registry system

local M = {}

-- Link Action - Creates symlinks for files/directories
local LinkAction = {
    type = "link",
    description = "Create a symlink to a file or directory",
    data_schema = {
        source_path = "string",  -- Source file/directory path
        target_path = "string",  -- Target symlink path
        create_dirs = "boolean", -- Whether to create parent directories
        overwrite = "boolean",   -- Whether to overwrite existing files
        backup = "boolean",      -- Whether to backup existing files
    },
    validate = function(self, action_data)
        if not action_data.source_path or action_data.source_path == "" then
            return false, "Link action requires source_path"
        end
        if not action_data.target_path or action_data.target_path == "" then
            return false, "Link action requires target_path"
        end
        return true, nil
    end,
}

-- Shell Source Action - Sources scripts into shell profile
local ShellSourceAction = {
    type = "shell_source",
    description = "Source a script into the user's shell profile",
    data_schema = {
        method = "string",        -- "source", "append", or "export_vars"
        source_file = "string",   -- File to source
        profile_file = "string",  -- Target profile file
        shell = "string",         -- Shell type (bash, zsh, etc.)
        order = "number",         -- Execution order
        export_prefix = "string", -- Prefix for export_vars method (optional)
    },
    validate = function(self, action_data)
        if not action_data.source_file or action_data.source_file == "" then
            return false, "Shell source action requires source_file"
        end
        if not action_data.profile_file or action_data.profile_file == "" then
            return false, "Shell source action requires profile_file"
        end
        if not action_data.shell or action_data.shell == "" then
            return false, "Shell source action requires shell"
        end
        local valid_methods = { "source", "append", "export_vars" }
        local method_valid = false
        for _, method in ipairs(valid_methods) do
            if action_data.method == method then
                method_valid = true
                break
            end
        end
        if not method_valid then
            return false, "Shell source action method must be one of: " .. table.concat(valid_methods, ", ")
        end
        return true, nil
    end,
}

-- Shell Add Path Action - Adds directories to PATH
local ShellAddPathAction = {
    type = "shell_add_path",
    description = "Add a directory to the shell's PATH",
    data_schema = {
        path_to_add = "string", -- Directory to add to PATH
        shell = "string",       -- Shell type (bash, zsh, etc.)
        prepend = "boolean",    -- Whether to prepend (true) or append (false)
    },
    validate = function(self, action_data)
        if not action_data.path_to_add or action_data.path_to_add == "" then
            return false, "Shell add path action requires path_to_add"
        end
        if not action_data.shell or action_data.shell == "" then
            return false, "Shell add path action requires shell"
        end
        return true, nil
    end,
}

-- Brew Install Action - Installs Homebrew packages
local BrewInstallAction = {
    type = "brew_install",
    description = "Install a Homebrew formula",
    data_schema = {
        formula = "string", -- Formula name to install
        options = "table",  -- Install options (optional)
        cask = "boolean",   -- Whether this is a cask (optional)
    },
    validate = function(self, action_data)
        if not action_data.formula or action_data.formula == "" then
            return false, "Brew install action requires formula"
        end
        return true, nil
    end,
}

-- Script Run Action - Executes scripts
local ScriptRunAction = {
    type = "script_run",
    description = "Execute a script",
    data_schema = {
        script_path = "string", -- Script to execute
        args = "table",         -- Arguments to pass (optional)
        working_dir = "string", -- Working directory (optional)
        env = "table",          -- Environment variables (optional)
    },
    validate = function(self, action_data)
        if not action_data.script_path or action_data.script_path == "" then
            return false, "Script run action requires script_path"
        end
        return true, nil
    end,
}

-- Example Stub Action (for backward compatibility)
local StubLinkAction = {
    type = "link_stub",
    description = "A stub action for linking files",
    data_schema = {
        src = "string",
        dest = "string",
        meta = "table",
    },
    validate = function(self, action_data)
        return true, nil -- Stub always validates
    end,
}

-- Register all built-in actions
function M.register_actions(registry)
    -- Core actions that match the design document
    registry.add("link", LinkAction)
    registry.add("shell_source", ShellSourceAction)
    registry.add("shell_add_path", ShellAddPathAction)
    registry.add("brew_install", BrewInstallAction)
    registry.add("script_run", ScriptRunAction)

    -- Keep stub for backward compatibility
    registry.add("link_stub", StubLinkAction)
end

return M
