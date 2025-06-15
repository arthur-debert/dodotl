-- Brew Power-up implementation
-- Handles Brewfile processing and package installation

local pl_path = require("pl.path")
local M = {}

local BrewPowerup = {
    name = "brew",
    type = "brew_powerup",

    -- Process matched Brewfiles and generate brew install actions
    process = function(self, matched_files, pack_path, options)
        if not matched_files or #matched_files == 0 then
            return {}, nil -- No files to process
        end

        options = options or {}
        local actions = {}

        for _, file_info in ipairs(matched_files) do
            local brewfile_path = file_info.path
            local relative_path = pl_path.relpath(brewfile_path, pack_path)

            -- For now, create a simple action that references the Brewfile
            -- In Phase 7.2, this would parse the Brewfile and create individual brew_install actions
            local action = {
                type = "brew_install",
                description = "Process Brewfile " .. brewfile_path,
                data = {
                    brewfile_path = brewfile_path,
                    -- TODO: In Phase 7.2, parse Brewfile and extract formulas
                    -- For now, just reference the file
                },
                metadata = {
                    powerup_name = self.name,
                    relative_source = relative_path,
                    original_metadata = file_info.metadata,
                    pack_path = pack_path
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

        -- Validate that all matched files exist and are readable
        if matched_files then
            for _, file_info in ipairs(matched_files) do
                if not file_info.path or file_info.path == "" then
                    return false, self.name .. " requires valid file paths"
                end
                -- TODO: Add file existence check when needed
            end
        end

        return true, nil
    end
}

function BrewPowerup.new()
    local instance = {
        name = "brew",
        type = "brew_powerup",
    }
    setmetatable(instance, { __index = BrewPowerup })
    return instance
end

M.BrewPowerup = BrewPowerup

return M
