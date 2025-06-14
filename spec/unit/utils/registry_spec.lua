-- Unit tests for the registry system
-- Comprehensive tests for the full registry API

local test_utils = require("spec.helpers.test_utils")

describe("dodot.utils.registry", function()
    local registry_module, registry

    before_each(function()
        registry_module = require("dodot.utils.registry")
        registry = registry_module.new()
    end)

    describe("registry creation", function()
        it("should create a new registry instance", function()
            assert.is_table(registry)
            assert.is_table(registry.items)
            assert.is_function(registry.add)
            assert.is_function(registry.get)
            assert.is_function(registry.remove)
            assert.is_function(registry.list)
            assert.is_function(registry.has)
            assert.is_function(registry.count)
            assert.is_function(registry.clear)
        end)

        it("should create independent registry instances", function()
            local registry1 = registry_module.new()
            local registry2 = registry_module.new()

            assert.is_not.equals(registry1, registry2)
            assert.is_not.equals(registry1.items, registry2.items)
        end)

        it("should start with empty registry", function()
            assert.are.same({}, registry.items)
            local count, _ = registry.count()
            assert.equals(0, count)
        end)
    end)

    describe("add method", function()
        it("should add items successfully", function()
            local success, err = registry.add("test_key", "test_value")

            assert.is_true(success)
            assert.is_nil(err)
            assert.equals("test_value", registry.items["test_key"])
        end)

        it("should reject non-string keys", function()
            local success, err = registry.add(123, "value")

            assert.is_false(success)
            assert.equals("Registry key must be a string", err)
        end)

        it("should reject empty string keys", function()
            local success, err = registry.add("", "value")

            assert.is_false(success)
            assert.equals("Registry key cannot be empty", err)
        end)

        it("should reject nil values", function()
            local success, err = registry.add("key", nil)

            assert.is_false(success)
            assert.equals("Registry value cannot be nil", err)
        end)

        it("should reject duplicate keys", function()
            registry.add("duplicate", "value1")
            local success, err = registry.add("duplicate", "value2")

            assert.is_false(success)
            assert.equals("Registry key 'duplicate' already exists", err)
            assert.equals("value1", registry.items["duplicate"])
        end)

        it("should accept various value types", function()
            assert.is_true(registry.add("string", "value"))
            assert.is_true(registry.add("number", 42))
            assert.is_true(registry.add("table", { a = 1 }))
            assert.is_true(registry.add("function", function() end))
            assert.is_true(registry.add("boolean", true))
        end)
    end)

    describe("get method", function()
        before_each(function()
            registry.add("test_key", "test_value")
            registry.add("table_key", { data = "test" })
        end)

        it("should retrieve existing items", function()
            local value, err = registry.get("test_key")

            assert.equals("test_value", value)
            assert.is_nil(err)
        end)

        it("should handle non-existent keys", function()
            local value, err = registry.get("non_existent")

            assert.is_nil(value)
            assert.equals("Registry key 'non_existent' not found", err)
        end)

        it("should reject non-string keys", function()
            local value, err = registry.get(123)

            assert.is_nil(value)
            assert.equals("Registry key must be a string", err)
        end)

        it("should return reference to table values", function()
            local value, err = registry.get("table_key")

            assert.is_table(value)
            assert.equals("test", value.data)
            assert.is_nil(err)
        end)
    end)

    describe("remove method", function()
        before_each(function()
            registry.add("remove_me", "value")
            registry.add("keep_me", "value")
        end)

        it("should remove existing items", function()
            local success, err = registry.remove("remove_me")

            assert.is_true(success)
            assert.is_nil(err)
            assert.is_nil(registry.items["remove_me"])
            assert.is_not_nil(registry.items["keep_me"])
        end)

        it("should handle non-existent keys", function()
            local success, err = registry.remove("non_existent")

            assert.is_false(success)
            assert.equals("Registry key 'non_existent' not found", err)
        end)

        it("should reject non-string keys", function()
            local success, err = registry.remove(123)

            assert.is_false(success)
            assert.equals("Registry key must be a string", err)
        end)
    end)

    describe("list method", function()
        it("should return empty list for empty registry", function()
            local keys, err = registry.list()

            assert.are.same({}, keys)
            assert.is_nil(err)
        end)

        it("should return all keys in sorted order", function()
            registry.add("zebra", "value")
            registry.add("alpha", "value")
            registry.add("beta", "value")

            local keys, err = registry.list()

            assert.are.same({ "alpha", "beta", "zebra" }, keys)
            assert.is_nil(err)
        end)
    end)

    describe("has method", function()
        before_each(function()
            registry.add("exists", "value")
        end)

        it("should return true for existing keys", function()
            local exists, err = registry.has("exists")

            assert.is_true(exists)
            assert.is_nil(err)
        end)

        it("should return false for non-existent keys", function()
            local exists, err = registry.has("non_existent")

            assert.is_false(exists)
            assert.is_nil(err)
        end)

        it("should reject non-string keys", function()
            local exists, err = registry.has(123)

            assert.is_false(exists)
            assert.equals("Registry key must be a string", err)
        end)
    end)

    describe("count method", function()
        it("should return 0 for empty registry", function()
            local count, err = registry.count()

            assert.equals(0, count)
            assert.is_nil(err)
        end)

        it("should return correct count after additions", function()
            registry.add("one", "value")
            registry.add("two", "value")
            registry.add("three", "value")

            local count, err = registry.count()

            assert.equals(3, count)
            assert.is_nil(err)
        end)

        it("should update count after removals", function()
            registry.add("one", "value")
            registry.add("two", "value")
            registry.remove("one")

            local count, err = registry.count()

            assert.equals(1, count)
            assert.is_nil(err)
        end)
    end)

    describe("clear method", function()
        it("should clear empty registry", function()
            local success, err = registry.clear()

            assert.is_true(success)
            assert.is_nil(err)
            local count, _ = registry.count()
            assert.equals(0, count)
        end)

        it("should clear registry with items", function()
            registry.add("one", "value")
            registry.add("two", "value")

            local success, err = registry.clear()

            assert.is_true(success)
            assert.is_nil(err)
            local count, _ = registry.count()
            assert.equals(0, count)
            assert.are.same({}, registry.items)
        end)
    end)

    describe("integration scenarios", function()
        it("should handle complex workflow", function()
            -- Add multiple items
            assert.is_true(registry.add("trigger1", { type = "file", pattern = "*.txt" }))
            assert.is_true(registry.add("trigger2", { type = "dir", pattern = "config/" }))
            assert.is_true(registry.add("powerup1", { name = "symlink", target = "home" }))

            -- Verify count
            local count, _ = registry.count()
            assert.equals(3, count)

            -- Check existence
            local exists, _ = registry.has("trigger1")
            assert.is_true(exists)

            -- Get specific item
            local trigger1, _ = registry.get("trigger1")
            assert.equals("file", trigger1.type)

            -- List all keys
            local keys, _ = registry.list()
            assert.are.same({ "powerup1", "trigger1", "trigger2" }, keys)

            -- Remove one item
            assert.is_true(registry.remove("trigger2"))
            local new_count, _ = registry.count()
            assert.equals(2, new_count)

            -- Clear all
            assert.is_true(registry.clear())
            local final_count, _ = registry.count()
            assert.equals(0, final_count)
        end)
    end)
end)
