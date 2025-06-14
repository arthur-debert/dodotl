-- Tests for MatcherRegistry

describe("MatcherRegistry", function()
    local registry_module = require("dodot.matchers.registry")
    local basic_matcher = require("dodot.matchers.basic_matcher")
    local MatcherRegistry = registry_module.MatcherRegistry
    local BasicMatcher = basic_matcher.BasicMatcher

    local registry

    before_each(function()
        registry = MatcherRegistry.new()
    end)

    describe("new", function()
        it("should create an empty registry", function()
            assert.is_not_nil(registry)
            assert.equals(0, registry:count())
        end)
    end)

    describe("add", function()
        it("should add a valid matcher", function()
            local config = {
                matcher_name = "test_matcher",
                trigger_name = "file_name",
                power_up_name = "symlink"
            }
            local matcher = BasicMatcher.new(config)

            local success, err = registry:add(matcher)
            assert.is_true(success)
            assert.is_nil(err)
            assert.equals(1, registry:count())
        end)

        it("should reject nil matcher", function()
            local success, err = registry:add(nil)
            assert.is_false(success)
            assert.is_not_nil(err)
            assert.matches("Cannot add nil matcher", err)
        end)

        it("should reject matcher without name", function()
            local matcher = { validate = function() return true end }
            local success, err = registry:add(matcher)
            assert.is_false(success)
            assert.is_not_nil(err)
            assert.matches("must have a matcher_name", err)
        end)

        it("should reject duplicate matcher names", function()
            local config = {
                matcher_name = "duplicate_matcher",
                trigger_name = "file_name",
                power_up_name = "symlink"
            }

            local matcher1 = BasicMatcher.new(config)
            local matcher2 = BasicMatcher.new(config)

            local success1, err1 = registry:add(matcher1)
            assert.is_true(success1)
            assert.is_nil(err1)

            local success2, err2 = registry:add(matcher2)
            assert.is_false(success2)
            assert.is_not_nil(err2)
            assert.matches("already exists", err2)
        end)

        it("should reject invalid matcher", function()
            local invalid_matcher = {
                matcher_name = "invalid",
                validate = function() return false, "Invalid matcher" end
            }

            local success, err = registry:add(invalid_matcher)
            assert.is_false(success)
            assert.is_not_nil(err)
            assert.matches("Invalid matcher", err)
        end)
    end)

    describe("remove", function()
        it("should remove an existing matcher", function()
            local config = {
                matcher_name = "test_matcher",
                trigger_name = "file_name",
                power_up_name = "symlink"
            }
            local matcher = BasicMatcher.new(config)

            registry:add(matcher)
            assert.equals(1, registry:count())

            local success, err = registry:remove("test_matcher")
            assert.is_true(success)
            assert.is_nil(err)
            assert.equals(0, registry:count())
        end)

        it("should reject nil matcher name", function()
            local success, err = registry:remove(nil)
            assert.is_false(success)
            assert.is_not_nil(err)
            assert.matches("Matcher name is required", err)
        end)

        it("should reject non-existent matcher", function()
            local success, err = registry:remove("non_existent")
            assert.is_false(success)
            assert.is_not_nil(err)
            assert.matches("not found", err)
        end)
    end)

    describe("get", function()
        it("should get an existing matcher", function()
            local config = {
                matcher_name = "test_matcher",
                trigger_name = "file_name",
                power_up_name = "symlink"
            }
            local matcher = BasicMatcher.new(config)

            registry:add(matcher)

            local retrieved, err = registry:get("test_matcher")
            assert.is_not_nil(retrieved)
            assert.is_nil(err)
            assert.equals("test_matcher", retrieved.matcher_name)
        end)

        it("should return nil for non-existent matcher", function()
            local retrieved, err = registry:get("non_existent")
            assert.is_nil(retrieved)
            assert.is_not_nil(err)
        end)

        it("should reject nil matcher name", function()
            local retrieved, err = registry:get(nil)
            assert.is_nil(retrieved)
            assert.is_not_nil(err)
            assert.matches("Matcher name is required", err)
        end)
    end)

    describe("list", function()
        it("should return empty list for empty registry", function()
            local matchers = registry:list()
            assert.is_table(matchers)
            assert.equals(0, #matchers)
        end)

        it("should return all matchers", function()
            local config1 = {
                matcher_name = "matcher1",
                trigger_name = "file_name",
                power_up_name = "symlink"
            }
            local config2 = {
                matcher_name = "matcher2",
                trigger_name = "extension",
                power_up_name = "profile"
            }

            registry:add(BasicMatcher.new(config1))
            registry:add(BasicMatcher.new(config2))

            local matchers = registry:list()
            assert.equals(2, #matchers)
        end)
    end)

    describe("get_all_configs", function()
        it("should return configs sorted by priority", function()
            local config1 = {
                matcher_name = "low_priority",
                trigger_name = "file_name",
                power_up_name = "symlink",
                priority = 5
            }
            local config2 = {
                matcher_name = "high_priority",
                trigger_name = "extension",
                power_up_name = "profile",
                priority = 20
            }
            local config3 = {
                matcher_name = "default_priority",
                trigger_name = "directory",
                power_up_name = "bin"
                -- no priority specified, should default to 10
            }

            registry:add(BasicMatcher.new(config1))
            registry:add(BasicMatcher.new(config2))
            registry:add(BasicMatcher.new(config3))

            local configs = registry:get_all_configs()
            assert.equals(3, #configs)

            -- Should be sorted by priority (higher first)
            assert.equals("high_priority", configs[1].matcher_name)
            assert.equals(20, configs[1].priority)

            assert.equals("default_priority", configs[2].matcher_name)
            assert.equals(10, configs[2].priority)

            assert.equals("low_priority", configs[3].matcher_name)
            assert.equals(5, configs[3].priority)
        end)
    end)

    describe("validate_all", function()
        it("should validate all matchers successfully", function()
            local config = {
                matcher_name = "test_matcher",
                trigger_name = "file_name",
                power_up_name = "symlink"
            }
            registry:add(BasicMatcher.new(config))

            local valid, err = registry:validate_all()
            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should detect invalid matcher", function()
            -- Add a valid matcher first
            local valid_config = {
                matcher_name = "valid_matcher",
                trigger_name = "file_name",
                power_up_name = "symlink"
            }
            registry:add(BasicMatcher.new(valid_config))

            -- Add an invalid matcher directly to registry
            registry.matchers["invalid"] = {
                validate = function() return false, "Test error" end
            }

            local valid, err = registry:validate_all()
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("Test error", err)
        end)
    end)

    describe("count", function()
        it("should return correct count", function()
            assert.equals(0, registry:count())

            local config = {
                matcher_name = "test_matcher",
                trigger_name = "file_name",
                power_up_name = "symlink"
            }
            registry:add(BasicMatcher.new(config))

            assert.equals(1, registry:count())
        end)
    end)

    describe("clear", function()
        it("should clear all matchers", function()
            local config = {
                matcher_name = "test_matcher",
                trigger_name = "file_name",
                power_up_name = "symlink"
            }
            registry:add(BasicMatcher.new(config))

            assert.equals(1, registry:count())

            registry:clear()
            assert.equals(0, registry:count())
        end)
    end)
end)
