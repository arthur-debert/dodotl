-- Triggers module initialization
-- Registers all built-in triggers with the registry system

local file_name = require("dodot.triggers.file_name")
local directory = require("dodot.triggers.directory")
local extension = require("dodot.triggers.extension")

local M = {}

-- Example Stub Trigger (keeping for backward compatibility)
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
    -- Phase 3.1 deliverable: File-based triggers
    registry.add("file_name", file_name.FileNameTrigger)
    registry.add("directory", directory.DirectoryTrigger)
    registry.add("extension", extension.ExtensionTrigger)

    -- Keep stub for backward compatibility
    registry.add("stub_file_name_trigger", StubFileNameTrigger)
end

return M
