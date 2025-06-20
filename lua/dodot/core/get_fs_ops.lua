-- lua/dodot/core/get_fs_ops.lua
local types = require("dodot.types")
local errors = require("dodot.errors")
local pl_path = require("pl.path")
local logger = require("lual").logger("dodot.core.get_fs_ops")

local M = {}

-- Constants for shell source paths
local DODOT_SHELL_BASE_DIR_NAME = "dodot/shell"
local ALIASES_SUBDIR_NAME = "aliases"
local PROFILE_SUBDIR_NAME = "profile_scripts"
local INIT_SCRIPT_NAME = "init.sh"

-- Helper to get home directory, trying multiple environment variables
local function get_home_directory()
    return os.getenv("HOME") or os.getenv("USERPROFILE")
end

local function build_shell_source_ops(action)
    local ops = {}

    if not action.data or not action.data.source_file then
        return nil, errors.create("INVALID_ACTION_DATA", { "shell_source", "Missing source_file in data" })
    end

    local home_dir = get_home_directory()
    if not home_dir then
        -- This error should now be defined in errors/codes.lua
        return nil, errors.create("MISSING_HOME_DIR", { "shell_source", "User home directory not found" })
    end

    local config_dir = os.getenv("XDG_CONFIG_HOME") or pl_path.join(home_dir, ".config")
    local full_base_path = pl_path.join(config_dir, DODOT_SHELL_BASE_DIR_NAME)

    local sub_dir_name = PROFILE_SUBDIR_NAME
    if action.data.source_file:match("alias") then
        sub_dir_name = ALIASES_SUBDIR_NAME
    end
    local target_subdir = pl_path.join(full_base_path, sub_dir_name)

    table.insert(ops, {
        type = "fsynth.op.ensure_dir",
        description = "Ensure dodot shell base directory exists: " .. full_base_path,
        args = { path = full_base_path, mode = "0755" }
    })
    table.insert(ops, {
        type = "fsynth.op.ensure_dir",
        description = "Ensure dodot shell target subdirectory exists: " .. target_subdir,
        args = { path = target_subdir, mode = "0755" }
    })

    local source_basename = pl_path.basename(action.data.source_file)
    local order_prefix = string.format("%02d", action.data.order or 50)
    local symlink_name = order_prefix .. "-" .. source_basename
    local symlink_path = pl_path.join(target_subdir, symlink_name)

    local absolute_source_file = action.data.source_file
    if action.pack_path and not pl_path.isabs(absolute_source_file) then
        absolute_source_file = pl_path.abspath(pl_path.join(action.pack_path, absolute_source_file))
    elseif not pl_path.isabs(absolute_source_file) then
        print("Warning: shell_source source_file is not absolute and no pack_path provided: " .. absolute_source_file)
    end

    table.insert(ops, {
        type = "fsynth.op.symlink",
        description = "Symlink shell script " .. absolute_source_file .. " to " .. symlink_path,
        args = { src = absolute_source_file, dest = symlink_path, force = true }
    })

    local init_script_path = pl_path.join(full_base_path, INIT_SCRIPT_NAME)
    local xdg_config_home_var = "${XDG_CONFIG_HOME:-$HOME/.config}"
    local script_base_dir_in_shell = xdg_config_home_var .. "/" .. DODOT_SHELL_BASE_DIR_NAME

    local init_content_parts = {
        "#!/bin/sh",
        "# Sources all scripts managed by dodot.",
        "# This script is auto-generated by dodot. Do not edit manually.",
        "",
        "__dodot_source_files_from_dir() {",
        "  local dir=\"$1\"",
        "  if [ -d \"$dir\" ]; then",
        "    for f in \"$dir\"/*; do", -- No quotes around * to allow globbing
        "      if [ -f \"$f\" ]; then",
        "        . \"$f\"",
        "      fi",
        "    done",
        "  fi",
        "}",
        "",
        "# Source aliases",
        "__dodot_source_files_from_dir \"" .. script_base_dir_in_shell .. "/" .. ALIASES_SUBDIR_NAME .. "\"",
        "",
        "# Source profile scripts",
        "__dodot_source_files_from_dir \"" .. script_base_dir_in_shell .. "/" .. PROFILE_SUBDIR_NAME .. "\"",
        "",
        "unset __dodot_source_files_from_dir" -- Clean up helper function
    }
    local init_content = table.concat(init_content_parts, "\n") .. "\n"

    table.insert(ops, {
        type = "fsynth.op.create_file",
        description = "Create/Update dodot init script: " .. init_script_path,
        args = { path = init_script_path, content = init_content, mode = "0755", overwrite = true }
    })
    return ops, nil
end

-- This dispatch table maps action types to functions that build fs operations.
local action_to_op_builder = {
    link_stub = function(action)
        -- Validate action.data structure for link_stub if needed
        if not action.data or not action.data.src or not action.data.dest then
            return nil, errors.create("INVALID_ACTION_DATA", { "link_stub", "Missing src or dest in data" })
        end
        return {
            {
                type = "fsynth.op.symlink_stub",
                description = action.description or "Stub symlink operation from link_stub action",
                args = action.data
            }
        }, nil -- No error
    end,

    link = function(action)
        -- Build operations for link action (symlinks)
        if not action.data or not action.data.source_path or not action.data.target_path then
            return nil, errors.create("INVALID_ACTION_DATA", { "link", "Missing source_path or target_path in data" })
        end

        local ops = {}

        -- Create parent directories if requested
        if action.data.create_dirs then
            local target_dir = pl_path.dirname(action.data.target_path)
            table.insert(ops, {
                type = "fsynth.op.ensure_dir",
                description = "Ensure parent directory exists: " .. target_dir,
                args = { path = target_dir, mode = "0755" }
            })
        end

        -- Create the symlink
        table.insert(ops, {
            type = "fsynth.op.symlink",
            description = action.description or ("Link " .. action.data.source_path .. " to " .. action.data.target_path),
            args = {
                src = action.data.source_path,
                dest = action.data.target_path,
                force = action.data.overwrite or false,
                backup = action.data.backup or false
            }
        })

        return ops, nil
    end,

    shell_add_path = function(action)
        logger.debug("building shell_add_path operations")
        -- Build operations for shell_add_path action
        if not action.data or not action.data.path_to_add or not action.data.shell then
            logger.debug("invalid shell_add_path action data: missing path_to_add or shell")
            return nil,
                errors.create("INVALID_ACTION_DATA", { "shell_add_path", "Missing path_to_add or shell in data" })
        end

        logger.debug("shell_add_path: path=%s, shell=%s", action.data.path_to_add, action.data.shell)
        local home_dir = get_home_directory()
        if not home_dir then
            logger.debug("shell_add_path: user home directory not found")
            return nil, errors.create("MISSING_HOME_DIR", { "shell_add_path", "User home directory not found" })
        end
        logger.debug("shell_add_path: home directory=%s", home_dir)

        -- Determine shell profile file
        local shell_profiles = {
            bash = ".bashrc",
            zsh = ".zshrc",
            fish = ".config/fish/config.fish",
        }

        local profile_file = shell_profiles[action.data.shell]
        if not profile_file then
            logger.debug("shell_add_path: unsupported shell: %s", action.data.shell)
            return nil,
                errors.create("UNSUPPORTED_SHELL", { "shell_add_path", "Unsupported shell: " .. action.data.shell })
        end
        logger.debug("shell_add_path: profile file=%s", profile_file)

        local profile_path = pl_path.join(home_dir, profile_file)
        logger.debug("shell_add_path: profile path=%s", profile_path)

        -- Create export command
        local path_cmd
        if action.data.prepend then
            path_cmd = "export PATH=\"" .. action.data.path_to_add .. ":$PATH\""
            logger.debug("shell_add_path: prepending to PATH")
        else
            path_cmd = "export PATH=\"$PATH:" .. action.data.path_to_add .. "\""
            logger.debug("shell_add_path: appending to PATH")
        end
        logger.debug("shell_add_path: PATH command=%s", path_cmd)

        -- Add comment for identification
        local path_addition = "\n# Added by dodot for PATH management\n" .. path_cmd .. "\n"

        local ops = {}
        logger.debug("shell_add_path: generating operations")

        -- Ensure parent directory exists (for fish config)
        if action.data.shell == "fish" then
            local config_dir = pl_path.dirname(profile_path)
            table.insert(ops, {
                type = "fsynth.op.ensure_dir",
                description = "Ensure fish config directory exists: " .. config_dir,
                args = { path = config_dir, mode = "0755" }
            })
        end

        -- Append PATH modification to profile
        table.insert(ops, {
            type = "fsynth.op.append_to_file",
            description = action.description or ("Add " .. action.data.path_to_add .. " to PATH in " .. profile_path),
            args = {
                path = profile_path,
                content = path_addition,
                create_if_missing = true,
                unique = true -- Don't add duplicate entries
            }
        })

        logger.debug("shell_add_path: generated %d operations", #ops)
        return ops, nil
    end,

    shell_source = build_shell_source_ops, -- Added shell_source builder

    -- Future action types would be added here
    -- brew_install = function(action) ... end,
    -- script_run = function(action) ... end,
}

function M.get_fs_ops(actions_list)
    logger.debug("get_fs_ops called with %d actions", actions_list and #actions_list or 0)
    local operations = {}
    if not actions_list then
        logger.debug("no actions provided, returning empty operations")
        return operations, nil
    end

    for i, action in ipairs(actions_list) do
        logger.debug("processing action %d: type=%s", i, action and action.type or "nil")
        if not action or not action.type then
            logger.debug("skipping malformed action %d (missing type or action itself is nil)", i)
        else
            local builder = action_to_op_builder[action.type]
            if builder then
                logger.debug("found builder for action type: %s", action.type)
                local success, result = pcall(builder, action)
                if success then
                    if type(result) == "table" and result.message and result.code then
                        logger.debug("error building ops for action type %s: %s", action.type, result.message)
                    elseif type(result) == "table" then
                        logger.debug("action type %s generated %d operations", action.type, #result)
                        for j, op in ipairs(result) do
                            logger.debug("adding operation %d: type=%s", j, op.type or "unknown")
                            table.insert(operations, op)
                        end
                        -- else: builder might validly return nil or non-table if no ops for valid action data
                    else
                        logger.debug("action type %s builder returned non-table result: %s", action.type, type(result))
                    end
                else
                    logger.debug("critical error in builder for action type %s: %s", action.type, tostring(result))
                end
            else
                logger.debug("no operation builder found for action type: %s", action.type)
            end
        end
    end
    logger.debug("get_fs_ops returning %d total operations", #operations)
    return operations, nil
end

return M
