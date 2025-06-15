-- This module does test setup for looging
local M = {}

M.setup_logging = function()
    local lual = require("lual")

    -- Fix: Use the correct API method to enable internal debugging
    lual.config({
        level = lual.debug,
        pipelines = {
            {
                level = lual.debug,
                outputs = { lual.file({ path = "/tmp/dodot.log" }) }
            },
            {
                level = lual.debug,
                outputs = { { lual.console } },
                presenters = { lual.color }
            }
        },
        command_line_verbosity = {
            mapping = {
                verbose = "debug",
            },
            auto_detect = true,
        }
    })
    local logger = lual.logger("dodot")
    logger.set_level(lual.debug)
    logger.debug("Logging setup complete - file output enabled")
    return true
end

return M
