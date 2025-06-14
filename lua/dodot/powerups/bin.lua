-- BinPowerup implementation
-- Manages PATH modifications and executable symlinks

local pl_path = require("pl.path")
local M = {}

local function expand_home_path(path)
    if path:match("^~/") then
        local home = os.getenv("HOME") or "~"
        return pl_path.join(home, path:sub(3))
    end
    return path
end

local function get_default_bin_dir()
    local home = os.getenv("HOME") or "~"
    return pl_path.join(home, ".local", "bin")
end

local function is_executable_file(file_path)
    -- Basic heuristic: check if file has executable extension or no extension
    local basename = pl_path.basename(file_path)
    local ext = pl_path.extension(file_path)

    -- Files with no extension are often executables
    if ext == "" then
        return true
    end

    -- Common executable extensions
    local exec_extensions = { ".sh", ".py", ".pl", ".rb", ".js", ".lua" }
    for _, exec_ext in ipairs(exec_extensions) do
        if ext == exec_ext then
            return true
        end
    end

    return false
end

local BinPowerup = {
    name = "bin",
    type = "bin_powerup",

    -- Process matched files and generate bin actions
    process = function(self, matched_files, pack_path, options)
        if not matched_files or #matched_files == 0 then
            return {}, nil -- No files to process
        end

        -- Parse options
        local bin_dir = options and options.bin_dir or get_default_bin_dir()
        bin_dir = expand_home_path(bin_dir)

        local add_to_path = options and options.add_to_path
        if add_to_path == nil then add_to_path = true end -- default to true

        local make_executable = options and options.make_executable
        if make_executable == nil then make_executable = true end -- default to true

        local filter_executables = options and options.filter_executables
        if filter_executables == nil then filter_executables = true end -- default to true

        local actions = {}

        -- Filter files if requested
        local files_to_process = {}
        for _, file_info in ipairs(matched_files) do
            if not filter_executables or is_executable_file(file_info.path) then
                table.insert(files_to_process, file_info)
            end
        end

        -- Create symlink actions for each executable
        for _, file_info in ipairs(files_to_process) do
            local source_path = file_info.path
            local basename = pl_path.basename(source_path)
            local target_path = pl_path.join(bin_dir, basename)
            local relative_path = pl_path.relpath(source_path, pack_path)

            -- Create bin symlink action
            local symlink_action = {
                type = "bin_symlink",
                source_path = source_path,
                target_path = target_path,
                bin_dir = bin_dir,
                make_executable = make_executable,
                metadata = {
                    powerup = "bin",
                    action_type = "bin_symlink",
                    relative_source = relative_path,
                    original_metadata = file_info.metadata
                }
            }

            table.insert(actions, symlink_action)
        end

        -- Create PATH modification action if requested
        if add_to_path and #files_to_process > 0 then
            local path_action = {
                type = "bin_add_to_path",
                bin_dir = bin_dir,
                shell = options and options.shell or "bash",
                metadata = {
                    powerup = "bin",
                    action_type = "add_to_path",
                    files_count = #files_to_process
                }
            }

            table.insert(actions, path_action)
        end

        return actions, nil
    end,

    -- Validate the power-up configuration and files
    validate = function(self, matched_files, pack_path, options)
        -- Validate basic parameters
        if not pack_path or pack_path == "" then
            return false, "BinPowerup requires a valid pack_path"
        end

        if matched_files and type(matched_files) ~= "table" then
            return false, "BinPowerup matched_files must be a table"
        end

        -- Validate options
        if options then
            if type(options) ~= "table" then
                return false, "BinPowerup options must be a table"
            end

            if options.bin_dir and type(options.bin_dir) ~= "string" then
                return false, "BinPowerup bin_dir must be a string"
            end

            if options.add_to_path ~= nil and type(options.add_to_path) ~= "boolean" then
                return false, "BinPowerup add_to_path must be a boolean"
            end

            if options.make_executable ~= nil and type(options.make_executable) ~= "boolean" then
                return false, "BinPowerup make_executable must be a boolean"
            end

            if options.filter_executables ~= nil and type(options.filter_executables) ~= "boolean" then
                return false, "BinPowerup filter_executables must be a boolean"
            end

            if options.shell and type(options.shell) ~= "string" then
                return false, "BinPowerup shell must be a string"
            end
        end

        -- Validate each file
        if matched_files then
            for i, file_info in ipairs(matched_files) do
                if type(file_info) ~= "table" then
                    return false, "BinPowerup file " .. i .. " must be a table"
                end

                if not file_info.path or type(file_info.path) ~= "string" then
                    return false, "BinPowerup file " .. i .. " must have a path string"
                end

                -- Check if file is within pack_path
                local relative = pl_path.relpath(file_info.path, pack_path)
                if relative:match("^%.%.") then
                    return false, "BinPowerup file " .. file_info.path .. " is outside pack_path " .. pack_path
                end
            end
        end

        return true, nil
    end
}

-- Create a new BinPowerup instance
function BinPowerup.new()
    local instance = {
        name = "bin",
        type = "bin_powerup"
    }

    setmetatable(instance, { __index = BinPowerup })
    return instance
end

M.BinPowerup = BinPowerup

return M
