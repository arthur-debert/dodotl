-- Power-ups module initialization
-- Registers all built-in power-ups with the registry system

local symlink = require("dodot.powerups.symlink")
local profile = require("dodot.powerups.profile")
local bin = require("dodot.powerups.bin")

local M = {}

-- Example Stub PowerUp (keeping for backward compatibility)
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
    -- Phase 3.3: Symlink power-up
    registry.add("symlink", symlink.SymlinkPowerup)

    -- Phase 3.4: Profile power-up
    registry.add("profile", profile.ProfilePowerup)

    -- Phase 3.5: Bin power-up
    registry.add("bin", bin.BinPowerup)

    -- Keep stub for backward compatibility
    registry.add("stub_symlink_powerup", StubSymlinkPowerUp)
end

return M
