-- Actions module initialization
-- Registers all built-in actions with the registry system

local M = {}

-- Example Stub Action
local StubLinkAction = {
    type = "link_stub",
    description = "A stub action for linking files.",
    -- Other fields like 'data_schema' or validation logic might be here in full actions
}

-- Register all built-in actions
function M.register_actions(registry)
    -- Phase 3+ deliverables will add specific actions
    -- e.g., registry.add("symlink", SymlinkAction)
    registry.add("stub_link_action", StubLinkAction)
end

return M
