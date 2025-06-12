-- Test that all required dependencies can be loaded
-- This verifies the dependency setup is working correctly

describe("dodot dependencies", function()
    describe("core lua dependencies", function()
        it("should load penlight", function()
            local pl_utils = require("pl.utils")
            assert.is_table(pl_utils)
        end)

        it("should load lual", function()
            local lual = require("lual")
            assert.is_table(lual)
        end)

        it("should load string-format-all", function()
            local format = require("string.format.all")
            assert.is_function(format)
        end)

        it("should load lua-toml", function()
            local toml = require("toml")
            assert.is_table(toml)
        end)

        it("should load dkjson", function()
            local json = require("dkjson")
            assert.is_table(json)
        end)

        it("should load lyaml", function()
            local yaml = require("lyaml")
            assert.is_table(yaml)
        end)
    end)

    describe("dodot-specific dependencies", function()
        it("should load melt", function()
            local melt = require("melt")
            assert.is_table(melt)
        end)

        it("should load fsynth (local development version)", function()
            local fsynth = require("fsynth")
            assert.is_table(fsynth)
        end)
    end)
end)
