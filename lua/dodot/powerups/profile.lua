-- ProfilePowerup implementation
-- Manages shell profile modifications (environment variables, aliases, PATH, etc.)

local pl_path = require("pl.path")
local M = {}

-- Shell detection and profile file mapping
local SHELL_PROFILES = {
    bash = { ".bashrc", ".bash_profile" },
    zsh = { ".zshrc", ".zprofile" },
    fish = { ".config/fish/config.fish" },
    csh = { ".cshrc" },
    tcsh = { ".tcshrc" },
    ksh = { ".kshrc" }
}

local function detect_shell()
    -- Try to detect shell from SHELL environment variable
    local shell_path = os.getenv("SHELL")
    if shell_path then
        local shell_name = pl_path.basename(shell_path)
        if SHELL_PROFILES[shell_name] then
            return shell_name
        end
    end

    -- Default to bash if detection fails
    return "bash"
end

local function get_profile_file(shell, profile_preference)
    local profiles = SHELL_PROFILES[shell]
    if not profiles or #profiles == 0 then
        return nil
    end

    -- Use preference if specified and valid
    if profile_preference then
        for _, profile in ipairs(profiles) do
            if profile:match(profile_preference) then
                return profile
            end
        end
    end

    -- Return first (primary) profile file
    return profiles[1]
end

local function expand_home_path(path)
    if path:match("^~/") then
        local home = os.getenv("HOME") or "~"
        return pl_path.join(home, path:sub(3))
    end
    return path
end

local ProfilePowerup = {
    name = "shell_profile",   -- Changed name
    type = "profile_powerup", -- Internal type can remain if desired, or align too

    -- Process matched files and generate profile modification actions
    process = function(self, matched_files, pack_path, options)
        if not matched_files or #matched_files == 0 then
            return {}, nil -- No files to process
        end

        options = options or {} -- Ensure options table exists

        -- Validate action_type upfront
        if options.action_type then
            local valid_actions = { "source", "append", "export_vars" }
            local valid = false
            for _, valid_action in ipairs(valid_actions) do
                if options.action_type == valid_action then
                    valid = true
                    break
                end
            end
            if not valid then
                return nil, "Unsupported action_type: " .. options.action_type
            end
        end

        -- Parse options
        local shell = options.shell or detect_shell()
        local profile_file_name = get_profile_file(shell, options.profile_preference)

        if not profile_file_name then
            return nil, "Unsupported shell: " .. shell
        end

        local method = options.action_type or "source" -- Renamed for clarity within data
        local home = os.getenv("HOME") or "~"
        local target_profile_path = pl_path.join(home, profile_file_name)
        local order = options.order or 50 -- Default order, e.g., 50

        local actions = {}

        for _, file_info in ipairs(matched_files) do
            local source_path = file_info.path
            local relative_path = pl_path.relpath(source_path, pack_path)
            local description = "Manage shell profile for " .. source_path .. " in " .. shell

            local action_data = {
                method = method,
                source_file = source_path,
                profile_file = target_profile_path,
                shell = shell,
                order = order,
            }

            if method == "export_vars" then
                action_data.export_prefix = options.export_prefix or ""
                description = "Export variables from " .. source_path .. " into " .. shell .. " profile"
            elseif method == "append" then
                description = "Append " .. source_path .. " to " .. shell .. " profile"
            else -- source
                description = "Source " .. source_path .. " into " .. shell .. " profile"
            end

            local action = {
                type = "shell_source",
                description = description,
                data = action_data,
                metadata = {
                    powerup_name = self.name, -- Use the new name
                    relative_source = relative_path,
                    original_metadata = file_info.metadata
                }
            }
            table.insert(actions, action)
        end

        return actions, nil
    end,

    -- Validate the power-up configuration and files
    validate = function(self, matched_files, pack_path, options)
        -- Validate basic parameters
        if not pack_path or pack_path == "" then
            return false, "ProfilePowerup requires a valid pack_path"
        end

        if matched_files and type(matched_files) ~= "table" then
            return false, "ProfilePowerup matched_files must be a table"
        end

        -- Validate options
        if options then
            if type(options) ~= "table" then
                return false, "ProfilePowerup options must be a table"
            end

            if options.shell and type(options.shell) ~= "string" then
                return false, "ProfilePowerup shell must be a string"
            end

            if options.shell and not SHELL_PROFILES[options.shell] then
                return false, "ProfilePowerup unsupported shell: " .. options.shell
            end

            if options.action_type and type(options.action_type) ~= "string" then
                return false, "ProfilePowerup action_type must be a string"
            end

            local valid_actions = { "source", "append", "export_vars" }
            if options.action_type then
                local valid = false
                for _, valid_action in ipairs(valid_actions) do
                    if options.action_type == valid_action then
                        valid = true
                        break
                    end
                end
                if not valid then
                    return false, "ProfilePowerup action_type must be one of: " .. table.concat(valid_actions, ", ")
                end
            end

            if options.profile_preference and type(options.profile_preference) ~= "string" then
                return false, "ProfilePowerup profile_preference must be a string"
            end

            if options.export_prefix and type(options.export_prefix) ~= "string" then
                return false, "ProfilePowerup export_prefix must be a string"
            end

            if options.order ~= nil and type(options.order) ~= "number" then
                return false, "ProfilePowerup order must be a number"
            end
        end

        -- Validate each file
        if matched_files then
            for i, file_info in ipairs(matched_files) do
                if type(file_info) ~= "table" then
                    return false, "ProfilePowerup file " .. i .. " must be a table"
                end

                if not file_info.path or type(file_info.path) ~= "string" then
                    return false, "ProfilePowerup file " .. i .. " must have a path string"
                end

                -- Check if file is within pack_path
                local relative = pl_path.relpath(file_info.path, pack_path)
                if relative:match("^%.%.") then
                    return false, "ProfilePowerup file " .. file_info.path .. " is outside pack_path " .. pack_path
                end
            end
        end

        return true, nil
    end
}

-- Create a new ProfilePowerup instance
function ProfilePowerup.new()
    local instance = {
        name = "shell_profile",  -- Changed name
        type = "profile_powerup" -- Internal type can remain
    }

    setmetatable(instance, { __index = ProfilePowerup })
    return instance
end

M.ProfilePowerup = ProfilePowerup
M.SHELL_PROFILES = SHELL_PROFILES -- Export for testing

return M
