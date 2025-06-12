-- Unit tests for the registry system
-- Demonstrates unit testing patterns for dodot

local test_utils = require("spec.helpers.test_utils")

describe("dodot.utils.registry", function()
    local registry_module

    before_each(function()
        registry_module = require("dodot.utils.registry")
    end)

    describe("registry creation", function()
        it("should create a new registry instance", function()
            local registry = registry_module.new()

            assert.is_table(registry)
            assert.is_table(registry.items)
        end)

        it("should create independent registry instances", function()
            local registry1 = registry_module.new()
            local registry2 = registry_module.new()

            assert.is_not.equals(registry1, registry2)
            assert.is_not.equals(registry1.items, registry2.items)
        end)
    end)

    -- NOTE: Full registry API tests will be implemented in Phase 1.4
    -- when the registry system is fully developed

    describe("registry placeholder behavior", function()
        it("should have items table initialized", function()
            local registry = registry_module.new()
            assert.is_table(registry.items)
            assert.are.same({}, registry.items)
        end)
    end)
end)
