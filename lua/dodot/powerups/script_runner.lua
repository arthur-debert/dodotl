-- Script Runner Power-up implementation
-- Handles install script execution and setup tasks

local pl_path = require("pl.path")
local M = {}

local ScriptRunnerPowerup = {
    name = "script_runner",
    type = "script_runner_powerup",

    -- Process matched install scripts and generate script_run actions
    process = function(self, matched_files, pack_path, options)
        if not matched_files or #matched_files == 0 then
            return {}, nil -- No files to process
        end

        options = options or {}
        local actions = {}

        for _, file_info in ipairs(matched_files) do
            local script_path = file_info.path
            local relative_path = pl_path.relpath(script_path, pack_path)

            -- Create script execution action
            local action = {
                type = "script_run",
                description = "Execute install script " .. script_path,
                data = {
                    script_path = script_path,
                    working_dir = pack_path,      -- Run script from pack directory
                    args = options.args or {},    -- Optional arguments
                    env = options.env or {},      -- Optional environment variables
                    order = options.order or 100, -- Default order (after Brewfile)
                },
                metadata = {
                    powerup_name = self.name,
                    relative_source = relative_path,
                    original_metadata = file_info.metadata,
                    pack_path = pack_path,
                    script_type = "install"
                }
            }
            table.insert(actions, action)
        end

        return actions, nil
    end,

    -- Validate the power-up configuration and files
    validate = function(self, matched_files, pack_path, options)
        if not pack_path or pack_path == "" then
            return false, self.name .. " requires a valid pack_path"
        end

        if matched_files and type(matched_files) ~= "table" then
            return false, self.name .. " matched_files must be a table if provided"
        end

        -- Validate that all matched files exist and are executable
        if matched_files then
            for _, file_info in ipairs(matched_files) do
                if not file_info.path or file_info.path == "" then
                    return false, self.name .. " requires valid file paths"
                end
                -- TODO: Add file existence and executable check when needed
            end
        end

        if options then
            if type(options) ~= "table" then
                return false, self.name .. " options must be a table"
            end
            if options.args and type(options.args) ~= "table" then
                return false, self.name .. " options.args must be a table"
            end
            if options.env and type(options.env) ~= "table" then
                return false, self.name .. " options.env must be a table"
            end
            if options.order and type(options.order) ~= "number" then
                return false, self.name .. " options.order must be a number"
            end
        end

        return true, nil
    end
}

function ScriptRunnerPowerup.new()
    local instance = {
        name = "script_runner",
        type = "script_runner_powerup",
    }
    setmetatable(instance, { __index = ScriptRunnerPowerup })
    return instance
end

M.ScriptRunnerPowerup = ScriptRunnerPowerup

return M
