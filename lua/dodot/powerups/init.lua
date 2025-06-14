-- Power-ups module initialization
-- Registers all built-in power-ups with the registry system

local M = {}

-- Example Stub PowerUp
local StubSymlinkPowerUp = {
    name = "symlink_stub",
    -- A conforming process function for a power-up
    process = function(self, matched_files, pack_path, options)
        -- self: the powerup instance
        -- matched_files: array of {path, metadata} as per API spec
        -- pack_path: path to the pack
        -- options: table of options for this powerup
        -- Returns: array_of_actions, error_message_or_nil
        return {}, nil -- Stub: returns no actions
    end,
    validate = function(self, matched_files, pack_path, options)
        return true, nil -- Stub: always valid
    end
}

-- Register all built-in power-ups
function M.register_powerups(registry)
    -- Phase 3.3-3.5 deliverables will add actual powerups like:
    -- - Symlink power-up
    -- - Profile power-up
    -- - Bin power-up
    registry.add("stub_symlink_powerup", StubSymlinkPowerUp)
end

return M
