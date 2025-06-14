-- SymlinkPowerup implementation
-- Creates symlinks from pack files to target directories

local pl_path = require("pl.path")
local M = {}

local SymlinkPowerup = {
    name = "symlink",
    type = "symlink_powerup",

    -- Process matched files and generate symlink actions
    process = function(self, matched_files, pack_path, options)
        if not matched_files or #matched_files == 0 then
            return {}, nil -- No files to process
        end

        -- Default options
        local target_dir = options and options.target_dir or "~"
        local create_dirs = options and options.create_dirs
        if create_dirs == nil then create_dirs = true end -- default to true

        local actions = {}

        for _, file_info in ipairs(matched_files) do
            local source_path = file_info.path
            local relative_path = pl_path.relpath(source_path, pack_path)

            -- Handle different target directory patterns
            local target_path
            if target_dir == "~" then
                -- Symlink to home directory
                target_path = pl_path.join(os.getenv("HOME") or "~", "." .. pl_path.basename(source_path))
            elseif target_dir:match("^~/") then
                -- Symlink to subdirectory of home
                local sub_path = target_dir:sub(3) -- remove "~/"
                target_path = pl_path.join(os.getenv("HOME") or "~", sub_path, pl_path.basename(source_path))
            else
                -- Absolute or relative target directory
                target_path = pl_path.join(target_dir, pl_path.basename(source_path))
            end

            -- Create the symlink action
            local action = {
                type = "symlink",
                source_path = source_path,
                target_path = target_path,
                create_dirs = create_dirs,
                metadata = {
                    powerup = "symlink",
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
            return false, "SymlinkPowerup requires a valid pack_path"
        end

        if matched_files and type(matched_files) ~= "table" then
            return false, "SymlinkPowerup matched_files must be a table"
        end

        -- Validate options
        if options then
            if type(options) ~= "table" then
                return false, "SymlinkPowerup options must be a table"
            end

            if options.target_dir and type(options.target_dir) ~= "string" then
                return false, "SymlinkPowerup target_dir must be a string"
            end

            if options.create_dirs ~= nil and type(options.create_dirs) ~= "boolean" then
                return false, "SymlinkPowerup create_dirs must be a boolean"
            end
        end

        -- Validate each file
        if matched_files then
            for i, file_info in ipairs(matched_files) do
                if type(file_info) ~= "table" then
                    return false, "SymlinkPowerup file " .. i .. " must be a table"
                end

                if not file_info.path or type(file_info.path) ~= "string" then
                    return false, "SymlinkPowerup file " .. i .. " must have a path string"
                end

                -- Check if file is within pack_path
                local relative = pl_path.relpath(file_info.path, pack_path)
                if relative:match("^%.%.") then
                    return false, "SymlinkPowerup file " .. file_info.path .. " is outside pack_path " .. pack_path
                end
            end
        end

        return true, nil
    end
}

-- Create a new SymlinkPowerup instance
function SymlinkPowerup.new()
    local instance = {
        name = "symlink",
        type = "symlink_powerup"
    }

    setmetatable(instance, { __index = SymlinkPowerup })
    return instance
end

M.SymlinkPowerup = SymlinkPowerup

return M
