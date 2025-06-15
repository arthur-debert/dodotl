-- SymlinkPowerup implementation
-- Creates symlinks from pack files to target directories

local pl_path = require("pl.path")
local M = {}

-- Helper function to check if a path is a directory
local function is_directory(path)
    -- Try to use pl.path.isdir if available, otherwise use posix or fallback
    if pl_path.isdir then
        return pl_path.isdir(path)
    else
        -- Fallback using posix if available
        local posix = _G.posix
        if not posix then
            local success, posix_module = pcall(require, "posix")
            if success then
                posix = posix_module
            end
        end

        if posix and posix.stat then
            local stat = posix.stat(path)
            return stat and stat.type == "directory"
        end

        -- Final fallback: try to access as directory
        local f = io.open(path, "r")
        if f then
            f:close()
            return false -- It's a file
        end
        -- If we can't open it as a file, assume it might be a directory
        -- This is not foolproof but better than nothing
        return true
    end
end

local SymlinkPowerup = {
    name = "symlink",
    type = "symlink_powerup",

    -- Process matched files and generate symlink actions
    process = function(self, matched_files, pack_path, options)
        if not matched_files or #matched_files == 0 then
            return {}, nil -- No files to process
        end

        -- Default options
        options = options or {} -- Ensure options table exists
        local target_dir = options.target_dir or "~"
        local create_dirs = options.create_dirs
        if create_dirs == nil then create_dirs = true end -- default to true
        local overwrite = options.overwrite or false      -- default to false
        local backup = options.backup or false            -- default to false

        local actions = {}

        for _, file_info in ipairs(matched_files) do
            local source_path = file_info.path
            local relative_path = pl_path.relpath(source_path, pack_path)
            local basename = pl_path.basename(source_path)
            local is_dir = is_directory(source_path)

            -- Handle different target directory patterns
            local target_path
            if target_dir == "~" then
                -- Symlink to home directory
                local home = os.getenv("HOME") or "~"
                if is_dir then
                    -- For directories, use the original name without dot prefix
                    target_path = pl_path.join(home, basename)
                else
                    -- For files, add dot prefix (traditional dotfile behavior)
                    target_path = pl_path.join(home, "." .. basename)
                end
            elseif target_dir:match("^~/") then
                -- Symlink to subdirectory of home
                local sub_path = target_dir:sub(3) -- remove "~/"
                local home = os.getenv("HOME") or "~"
                -- In subdirectories, use original name for both files and directories
                target_path = pl_path.join(home, sub_path, basename)
            else
                -- Absolute or relative target directory
                -- Use original name for both files and directories
                target_path = pl_path.join(target_dir, basename)
            end

            -- Create the symlink action
            local item_type = is_dir and "directory" or "file"
            local action = {
                type = "link", -- Changed from "symlink"
                description = "Link " .. item_type .. " " .. source_path .. " to " .. target_path,
                data = {
                    source_path = source_path,
                    target_path = target_path,
                    create_dirs = create_dirs,
                    overwrite = overwrite,
                    backup = backup,
                    is_directory = is_dir, -- Add metadata about whether this is a directory
                },
                metadata = {
                    powerup = "symlink", -- Keep internal powerup name for metadata if desired
                    relative_source = relative_path,
                    original_metadata = file_info.metadata,
                    item_type = item_type,
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
            if options.overwrite ~= nil and type(options.overwrite) ~= "boolean" then
                return false, "SymlinkPowerup overwrite must be a boolean"
            end
            if options.backup ~= nil and type(options.backup) ~= "boolean" then
                return false, "SymlinkPowerup backup must be a boolean"
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
