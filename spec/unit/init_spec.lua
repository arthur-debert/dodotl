-- Basic test for dodot main module
-- This validates that the testing framework is working correctly

describe("dodot main module", function()
    local dodot

    before_each(function()
        dodot = require("dodot.init")
    end)

    it("should have a version", function()
        assert.is_not_nil(dodot.VERSION)
        assert.equals("0.1.1", dodot.VERSION)
    end)

    it("should be a valid module", function()
        assert.is_table(dodot)
    end)
end)
