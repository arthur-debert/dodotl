-- lua/dodot/core/get_packs.lua
local pl_path = require("pl.path")
local pl_dir = require("pl.dir")
local types = require("dodot.types")
local errors = require("dodot.errors")

local M = {}

function M.get_pack_candidates(dotfiles_root)
    if not pl_path.isdir(dotfiles_root) then
        return nil, errors.create("INVALID_DOTFILES_ROOT", dotfiles_root)
    end

    local candidates = {}
    -- pl_dir.getdirectories returns a table of full paths to directories
    local full_paths_from_getdirectories, err_msg = pl_dir.getdirectories(dotfiles_root)

    if not full_paths_from_getdirectories then
        return nil, errors.create("PACK_ACCESS_DENIED", "Could not list directories in: " .. dotfiles_root .. (err_msg and (": " .. err_msg) or ""))
    end

    for _, full_path in ipairs(full_paths_from_getdirectories) do
        local basename = pl_path.basename(full_path)

        -- Filter out '.', '..', empty strings (basename shouldn't be empty), and hidden directories
        if basename ~= "." and basename ~= ".." and basename ~= "" and (string.sub(basename, 1, 1) ~= ".") then
            -- We already know it's a directory from getdirectories, and full_path is the correct path
            -- A final check if it is truly a directory (though getdirectories should guarantee this)
            if pl_path.isdir(full_path) then
                 table.insert(candidates, full_path)
            end
        end
    end
    return candidates, nil
end

function M.get_packs(pack_candidate_paths)
    if pack_candidate_paths == nil then
        return nil, errors.create("UNKNOWN_ERROR_CODE", "pack_candidate_paths cannot be nil")
    end

    local packs = {}
    for _, pack_path in ipairs(pack_candidate_paths) do
        local pack_name = pl_path.basename(pack_path) -- pack_name is the basename
        local pack_obj = {
            path = pack_path, -- pack_path is the full path
            name = pack_name,
            config = nil,
        }

        if types.is_pack(pack_obj) then
            table.insert(packs, pack_obj)
        else
            return nil, errors.create("UNKNOWN_ERROR_CODE", "Internal error: Failed to create valid pack object for path: " .. pack_path)
        end
    end
    return packs, nil
end

return M
