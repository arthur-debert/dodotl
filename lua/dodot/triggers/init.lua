-- Triggers module initialization
-- Registers all built-in triggers with the registry system

local M = {}

-- Example Stub Trigger
local StubFileNameTrigger = {
    type = "file_name_stub",
    -- A conforming match function for a trigger
    match = function(self, file_path, pack_path)
        -- self: the trigger instance itself
        -- file_path: path to the file being checked
        -- pack_path: path to the pack the file belongs to
        -- Returns: boolean (matched), metadata_table (optional)
        return false, nil -- Stub implementation: never matches
    end,
    validate = function(self)
        return true, nil -- Stub implementation: always valid
    end
}

-- Register all built-in triggers
function M.register_triggers(registry)
    -- Phase 3.1 deliverable will add actual triggers like:
    -- - FileNameTrigger with globbing support
    -- - DirectoryTrigger
    -- - ExtensionTrigger
    registry.add("stub_file_name_trigger", StubFileNameTrigger)
end

return M
