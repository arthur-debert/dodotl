-- Tests for FileNameTrigger

describe("FileNameTrigger", function()
    local file_name = require("dodot.triggers.file_name")
    local FileNameTrigger = file_name.FileNameTrigger

    describe("new", function()
        it("should create a trigger with valid pattern", function()
            local trigger = FileNameTrigger.new("*.txt")
            assert.is_not_nil(trigger)
            assert.equals("*.txt", trigger.pattern)
            assert.equals("file_name", trigger.type)
        end)

        it("should reject empty pattern", function()
            local trigger, err = FileNameTrigger.new("")
            assert.is_nil(trigger)
            assert.is_not_nil(err)
            assert.matches("non%-empty pattern", err)
        end)

        it("should reject nil pattern", function()
            local trigger, err = FileNameTrigger.new(nil)
            assert.is_nil(trigger)
            assert.is_not_nil(err)
            assert.matches("non%-empty pattern", err)
        end)
    end)

    describe("match", function()
        local trigger

        before_each(function()
            trigger = FileNameTrigger.new("*.txt")
        end)

        it("should match files with .txt extension", function()
            local matches, metadata = trigger:match("test.txt", "/some/pack")
            assert.is_true(matches)
            assert.is_not_nil(metadata)
            assert.equals("*.txt", metadata.matched_pattern)
            assert.equals("test.txt", metadata.filename)
            assert.equals("test.txt", metadata.full_path)
        end)

        it("should match files with .txt extension in subdirectories", function()
            local matches, metadata = trigger:match("/path/to/file.txt", "/some/pack")
            assert.is_true(matches)
            assert.is_not_nil(metadata)
            assert.equals("file.txt", metadata.filename)
            assert.equals("/path/to/file.txt", metadata.full_path)
        end)

        it("should not match files with different extensions", function()
            local matches, metadata = trigger:match("test.md", "/some/pack")
            assert.is_false(matches)
            assert.is_nil(metadata)
        end)

        it("should handle nil file path", function()
            local matches, metadata = trigger:match(nil, "/some/pack")
            assert.is_false(matches)
            assert.is_nil(metadata)
        end)

        it("should handle question mark wildcard", function()
            local q_trigger = FileNameTrigger.new("test?.txt")

            local matches = q_trigger:match("test1.txt", "/pack")
            assert.is_true(matches)

            local matches = q_trigger:match("testa.txt", "/pack")
            assert.is_true(matches)

            local matches = q_trigger:match("test12.txt", "/pack")
            assert.is_false(matches)

            local matches = q_trigger:match("test.txt", "/pack")
            assert.is_false(matches)
        end)

        it("should handle multiple wildcards", function()
            local multi_trigger = FileNameTrigger.new("*config*")

            local matches = multi_trigger:match("my_config_file.txt", "/pack")
            assert.is_true(matches)

            local matches = multi_trigger:match("config", "/pack")
            assert.is_true(matches)

            local matches = multi_trigger:match("something_else", "/pack")
            assert.is_false(matches)
        end)

        it("should handle exact matches", function()
            local exact_trigger = FileNameTrigger.new("exactly_this_file.txt")

            local matches = exact_trigger:match("exactly_this_file.txt", "/pack")
            assert.is_true(matches)

            local matches = exact_trigger:match("not_this_file.txt", "/pack")
            assert.is_false(matches)
        end)

        it("should escape special Lua pattern characters", function()
            local special_trigger = FileNameTrigger.new("file(1).txt")

            local matches = special_trigger:match("file(1).txt", "/pack")
            assert.is_true(matches)

            local matches = special_trigger:match("file1.txt", "/pack")
            assert.is_false(matches)
        end)
    end)

    describe("validate", function()
        it("should validate trigger with valid pattern", function()
            local trigger = FileNameTrigger.new("*.txt")
            local valid, err = trigger:validate()
            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should validate complex patterns", function()
            local patterns = { "*.{txt,md}", "test_*.log", "config?.json", "**/test*" }
            for _, pattern in ipairs(patterns) do
                local trigger = FileNameTrigger.new(pattern)
                local valid, err = trigger:validate()
                assert.is_true(valid, "Pattern should be valid: " .. pattern .. " (error: " .. tostring(err) .. ")")
                assert.is_nil(err)
            end
        end)
    end)
end)
