-- dodot - A dotfile manager
-- Main module entry point

local M = {}

-- Module version
M.VERSION = "0.1.1"

-- Import logging module
local logging = require("dodot.logging")
logging.setup_logging()
-- Log the version

-- Import core modules (will be implemented in later phases)
-- local libs = require("dodot.libs")
-- local core = require("dodot.core")

-- Main API will be implemented here
-- This serves as the public interface for the dodot library

return M
