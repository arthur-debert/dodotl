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

-- Helper to detect shell (can be shared or moved to a common utility)
local function detect_shell()
    local shell_path = os.getenv("SHELL")
    if shell_path then
        return pl_path.basename(shell_path)
    end
    return "bash" -- Default if not detectable
end

local ShellAddPathPowerup = {
    name = "shell_add_path",
    type = "shell_add_path_powerup", -- Or just "powerup"

    process = function(self, matched_files, pack_path, options)
        options = options or {}

        local path_to_add
        if options.bin_dir then
            path_to_add = expand_home_path(options.bin_dir)
        elseif matched_files and #matched_files > 0 then
            -- Assuming if matched_files are present, pack_path represents the directory to add
            -- This is typical for a DirectoryTrigger matching a "bin" directory within a pack
            path_to_add = pack_path
        else
            -- No explicit bin_dir and no matched_files to infer pack_path from for PATH addition
            return {}, nil -- Or return an error: "No directory specified to add to PATH"
        end

        if not path_to_add then
             return {}, nil -- Should not happen if logic above is correct, but as a safeguard
        end

        local shell = options.shell or detect_shell()
        local prepend = options.prepend or false -- Default to false

        local description = "Add " .. path_to_add .. " to PATH for " .. shell .. " shell"
        if prepend then
            description = "Prepend " .. path_to_add .. " to PATH for " .. shell .. " shell"
        end

        local action = {
            type = "shell_add_path",
            description = description,
            data = {
                path_to_add = path_to_add,
                shell = shell,
                prepend = prepend,
            },
            metadata = {
                powerup_name = self.name,
                pack_path_context = pack_path, -- Store original pack_path for context
                 -- If matched_files were used to determine path_to_add, you might include info from them
                original_options = options
            }
        }
        return {action}, nil
    end,

    validate = function(self, matched_files, pack_path, options)
        -- pack_path is crucial if it's used as the path_to_add
        -- If options.bin_dir is the only way to specify path, pack_path might be less critical for this powerup
        -- However, it's good for context and consistency with other powerups.
        if not pack_path or pack_path == "" then
            return false, self.name .. " requires a valid pack_path for context"
        end

        -- matched_files might be empty if options.bin_dir is used.
        if matched_files and type(matched_files) ~= "table" then
            return false, self.name .. " matched_files must be a table if provided"
        end

        if options then
            if type(options) ~= "table" then
                return false, self.name .. " options must be a table"
            end
            if options.bin_dir and type(options.bin_dir) ~= "string" then
                return false, self.name .. " options.bin_dir must be a string"
            end
            if options.shell and type(options.shell) ~= "string" then
                return false, self.name .. " options.shell must be a string"
            end
            if options.prepend ~= nil and type(options.prepend) ~= "boolean" then
                return false, self.name .. " options.prepend must be a boolean"
            end
        end

        -- If not using options.bin_dir, and matched_files is empty, it's potentially an issue.
        if not (options and options.bin_dir) and (not matched_files or #matched_files == 0) then
            -- This validation depends on how path_to_add is decided.
            -- If pack_path itself (derived from matched_files trigger) is the primary source,
            -- then matched_files being empty (without options.bin_dir) means no path.
            -- For now, process handles this by returning empty actions.
            -- A stricter validation could be:
            -- return false, self.name .. " requires options.bin_dir or matched files to determine path"
        end

        -- Individual file validation (from original BinPowerup) is removed as this powerup
        -- no longer processes individual files for symlinking. It only cares about the directory.

        return true, nil
    end
}

function ShellAddPathPowerup.new()
    local instance = {
        name = "shell_add_path",
        type = "shell_add_path_powerup", -- Or just "powerup"
    }
    setmetatable(instance, { __index = ShellAddPathPowerup })
    return instance
end

M.ShellAddPathPowerup = ShellAddPathPowerup

return M
