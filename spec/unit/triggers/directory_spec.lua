-- Tests for DirectoryTrigger

describe("DirectoryTrigger", function()
    local directory = require("dodot.triggers.directory")
    local DirectoryTrigger = directory.DirectoryTrigger

    describe("new", function()
        it("should create a trigger with valid pattern", function()
            local trigger = DirectoryTrigger.new("config/*")
            assert.is_not_nil(trigger)
            assert.equals("config/*", trigger.pattern)
            assert.equals("directory", trigger.type)
        end)

        it("should accept empty pattern for root directory", function()
            local trigger = DirectoryTrigger.new("")
            assert.is_not_nil(trigger)
            assert.equals("", trigger.pattern)
        end)

        it("should reject nil pattern", function()
            local trigger, err = DirectoryTrigger.new(nil)
            assert.is_nil(trigger)
            assert.is_not_nil(err)
            assert.matches("requires a pattern", err)
        end)
    end)

    describe("match", function()
        local trigger

        before_each(function()
            trigger = DirectoryTrigger.new("config")
        end)

        it("should match files in the specified directory", function()
            local matches, metadata = trigger:match("config/file.txt", "/pack")
            assert.is_true(matches)
            assert.is_not_nil(metadata)
            assert.equals("config", metadata.matched_pattern)
            assert.equals("config", metadata.directory)
            assert.equals("config/file.txt", metadata.full_path)
        end)

        it("should not match files in different directories", function()
            local matches, metadata = trigger:match("other/file.txt", "/pack")
            assert.is_false(matches)
            assert.is_nil(metadata)
        end)

        it("should handle files in root directory", function()
            local root_trigger = DirectoryTrigger.new("")
            local matches, metadata = root_trigger:match("file.txt", "/pack")
            assert.is_true(matches)
            assert.is_not_nil(metadata)
            assert.equals("", metadata.directory)
        end)

        it("should handle nil file path", function()
            local matches, metadata = trigger:match(nil, "/pack")
            assert.is_false(matches)
            assert.is_nil(metadata)
        end)

        it("should handle wildcard patterns", function()
            local wildcard_trigger = DirectoryTrigger.new("config/*")

            local matches = wildcard_trigger:match("config/vim/file.txt", "/pack")
            assert.is_true(matches)

            local matches = wildcard_trigger:match("config/nvim/init.lua", "/pack")
            assert.is_true(matches)

            local matches = wildcard_trigger:match("other/file.txt", "/pack")
            assert.is_false(matches)
        end)

        it("should handle double wildcard patterns", function()
            local deep_trigger = DirectoryTrigger.new("config/**")

            local matches = deep_trigger:match("config/vim/file.txt", "/pack")
            assert.is_true(matches)

            local matches = deep_trigger:match("config/nvim/lua/init.lua", "/pack")
            assert.is_true(matches)

            local matches = deep_trigger:match("config/file.txt", "/pack")
            assert.is_true(matches)

            local matches = deep_trigger:match("other/file.txt", "/pack")
            assert.is_false(matches)
        end)

        it("should handle question mark wildcard", function()
            local q_trigger = DirectoryTrigger.new("confi?")

            local matches = q_trigger:match("config/file.txt", "/pack")
            assert.is_true(matches)

            local matches = q_trigger:match("confis/file.txt", "/pack")
            assert.is_true(matches)

            local matches = q_trigger:match("configure/file.txt", "/pack")
            assert.is_false(matches)
        end)

        it("should handle nested directory patterns", function()
            local nested_trigger = DirectoryTrigger.new("**/config")

            local matches = nested_trigger:match("home/user/config/file.txt", "/pack")
            assert.is_true(matches)

            local matches = nested_trigger:match("config/file.txt", "/pack")
            assert.is_true(matches)

            local matches = nested_trigger:match("deep/path/config/file.txt", "/pack")
            assert.is_true(matches)

            local matches = nested_trigger:match("other/file.txt", "/pack")
            assert.is_false(matches)
        end)

        it("should handle relative paths correctly when pack_path is provided", function()
            local matches, metadata = trigger:match("/pack/config/file.txt", "/pack")
            assert.is_true(matches)
            assert.is_not_nil(metadata)
            assert.equals("config", metadata.directory)
        end)
    end)

    describe("validate", function()
        it("should validate trigger with valid pattern", function()
            local trigger = DirectoryTrigger.new("config")
            local valid, err = trigger:validate()
            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should validate complex patterns", function()
            local patterns = { "config/*", "**/bin", "src/**/*.lua", "test?" }
            for _, pattern in ipairs(patterns) do
                local trigger = DirectoryTrigger.new(pattern)
                local valid, err = trigger:validate()
                assert.is_true(valid, "Pattern should be valid: " .. pattern .. " (error: " .. tostring(err) .. ")")
                assert.is_nil(err)
            end
        end)
    end)
end)
