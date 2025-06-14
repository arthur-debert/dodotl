-- Tests for BasicMatcher

describe("BasicMatcher", function()
    local basic_matcher = require("dodot.matchers.basic_matcher")
    local BasicMatcher = basic_matcher.BasicMatcher

    describe("new", function()
        it("should create a matcher with valid configuration", function()
            local config = {
                matcher_name = "test_matcher",
                trigger_name = "file_name",
                power_up_name = "symlink",
                priority = 15,
                options = { test = true }
            }

            local matcher = BasicMatcher.new(config)
            assert.is_not_nil(matcher)
            assert.equals("test_matcher", matcher.matcher_name)
            assert.equals("file_name", matcher.trigger_name)
            assert.equals("symlink", matcher.power_up_name)
            assert.equals(15, matcher.priority)
            assert.same({ test = true }, matcher.options)
        end)

        it("should create a matcher with minimal configuration", function()
            local config = {
                matcher_name = "minimal_matcher",
                trigger_name = "extension",
                power_up_name = "profile"
            }

            local matcher = BasicMatcher.new(config)
            assert.is_not_nil(matcher)
            assert.equals("minimal_matcher", matcher.matcher_name)
            assert.equals("extension", matcher.trigger_name)
            assert.equals("profile", matcher.power_up_name)
            assert.is_nil(matcher.priority)
            assert.is_nil(matcher.options)
        end)

        it("should reject nil configuration", function()
            local matcher, err = BasicMatcher.new(nil)
            assert.is_nil(matcher)
            assert.is_not_nil(err)
            assert.matches("requires configuration", err)
        end)

        it("should reject empty matcher_name", function()
            local config = {
                matcher_name = "",
                trigger_name = "file_name",
                power_up_name = "symlink"
            }

            local matcher, err = BasicMatcher.new(config)
            assert.is_nil(matcher)
            assert.is_not_nil(err)
            assert.matches("non%-empty matcher_name", err)
        end)

        it("should reject missing trigger_name", function()
            local config = {
                matcher_name = "test_matcher",
                power_up_name = "symlink"
            }

            local matcher, err = BasicMatcher.new(config)
            assert.is_nil(matcher)
            assert.is_not_nil(err)
            assert.matches("non%-empty trigger_name", err)
        end)

        it("should reject missing power_up_name", function()
            local config = {
                matcher_name = "test_matcher",
                trigger_name = "file_name"
            }

            local matcher, err = BasicMatcher.new(config)
            assert.is_nil(matcher)
            assert.is_not_nil(err)
            assert.matches("non%-empty power_up_name", err)
        end)

        it("should reject invalid priority", function()
            local config = {
                matcher_name = "test_matcher",
                trigger_name = "file_name",
                power_up_name = "symlink",
                priority = -1
            }

            local matcher, err = BasicMatcher.new(config)
            assert.is_nil(matcher)
            assert.is_not_nil(err)
            assert.matches("non%-negative number", err)
        end)

        it("should reject non-table options", function()
            local config = {
                matcher_name = "test_matcher",
                trigger_name = "file_name",
                power_up_name = "symlink",
                options = "invalid"
            }

            local matcher, err = BasicMatcher.new(config)
            assert.is_nil(matcher)
            assert.is_not_nil(err)
            assert.matches("must be a table", err)
        end)
    end)

    describe("validate", function()
        it("should validate a valid matcher", function()
            local config = {
                matcher_name = "test_matcher",
                trigger_name = "file_name",
                power_up_name = "symlink"
            }

            local matcher = BasicMatcher.new(config)
            local valid, err = matcher:validate()
            assert.is_true(valid)
            assert.is_nil(err)
        end)
    end)

    describe("to_config", function()
        it("should generate correct config for pipeline", function()
            local config = {
                matcher_name = "test_matcher",
                trigger_name = "file_name",
                power_up_name = "symlink",
                priority = 20,
                options = { pattern = "*.txt" }
            }

            local matcher = BasicMatcher.new(config)
            local pipeline_config = matcher:to_config()

            assert.equals("test_matcher", pipeline_config.matcher_name)
            assert.equals("file_name", pipeline_config.trigger_name)
            assert.equals("symlink", pipeline_config.power_up_name)
            assert.equals(20, pipeline_config.priority)
            assert.same({ pattern = "*.txt" }, pipeline_config.options)
        end)

        it("should provide defaults for missing values", function()
            local config = {
                matcher_name = "minimal_matcher",
                trigger_name = "extension",
                power_up_name = "profile"
            }

            local matcher = BasicMatcher.new(config)
            local pipeline_config = matcher:to_config()

            assert.equals(10, pipeline_config.priority) -- default
            assert.same({}, pipeline_config.options)    -- default
        end)
    end)
end)
