-- lua/dodot/core/get_packs.lua
local pl_path = require("pl.path")
local pl_dir = require("pl.dir")
local types = require("dodot.types")
local errors = require("dodot.errors")
local logger = require("lual").logger("dodot.core.get_packs")

local M = {}

function M.get_pack_candidates(dotfiles_root)
    logger.debug("get_pack_candidates called with dotfiles_root: %s", dotfiles_root)

    if not pl_path.isdir(dotfiles_root) then
        logger.debug("dotfiles_root is not a directory: %s", dotfiles_root)
        return nil, errors.create("INVALID_DOTFILES_ROOT", dotfiles_root)
    end

    logger.debug("dotfiles_root is valid directory, scanning for pack candidates")
    local candidates = {}
    -- pl_dir.getdirectories returns a table of full paths to directories
    local full_paths_from_getdirectories, err_msg = pl_dir.getdirectories(dotfiles_root)
    logger.debug("pl_dir.getdirectories returned %d directories",
        full_paths_from_getdirectories and #full_paths_from_getdirectories or 0)

    if not full_paths_from_getdirectories then
        return nil,
            errors.create("PACK_ACCESS_DENIED",
                "Could not list directories in: " .. dotfiles_root .. (err_msg and (": " .. err_msg) or ""))
    end

    for _, full_path in ipairs(full_paths_from_getdirectories) do
        local basename = pl_path.basename(full_path)
        logger.debug("examining directory: %s (basename: %s)", full_path, basename)

        -- Filter out '.', '..', empty strings (basename shouldn't be empty), and hidden directories
        if basename ~= "." and basename ~= ".." and basename ~= "" and (string.sub(basename, 1, 1) ~= ".") then
            -- We already know it's a directory from getdirectories, and full_path is the correct path
            -- A final check if it is truly a directory (though getdirectories should guarantee this)
            if pl_path.isdir(full_path) then
                logger.debug("adding pack candidate: %s", full_path)
                table.insert(candidates, full_path)
            else
                logger.debug("skipping non-directory: %s", full_path)
            end
        else
            logger.debug("skipping filtered directory: %s (reason: dot directory or empty)", basename)
        end
    end
    logger.debug("get_pack_candidates returning %d candidates", #candidates)
    return candidates, nil
end

function M.get_packs(pack_candidate_paths)
    logger.debug("get_packs called with %d pack candidates", pack_candidate_paths and #pack_candidate_paths or 0)

    if pack_candidate_paths == nil then
        logger.debug("pack_candidate_paths is nil, returning error")
        return nil, errors.create("UNKNOWN_ERROR_CODE", "pack_candidate_paths cannot be nil")
    end

    local packs = {}
    for _, pack_path in ipairs(pack_candidate_paths) do
        local pack_name = pl_path.basename(pack_path) -- pack_name is the basename
        logger.debug("processing pack candidate: %s (name: %s)", pack_path, pack_name)

        local pack_obj = {
            path = pack_path, -- pack_path is the full path
            name = pack_name,
            config = nil,
        }

        if types.is_pack(pack_obj) then
            logger.debug("pack object is valid, adding to packs: %s", pack_name)
            table.insert(packs, pack_obj)
        else
            logger.debug("pack object failed validation: %s", pack_path)
            return nil,
                errors.create("UNKNOWN_ERROR_CODE",
                    "Internal error: Failed to create valid pack object for path: " .. pack_path)
        end
    end
    logger.debug("get_packs returning %d validated packs", #packs)
    return packs, nil
end

return M
