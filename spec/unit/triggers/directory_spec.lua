-- Tests for DirectoryTrigger

describe("DirectoryTrigger", function()
    local directory = require("dodot.triggers.directory")
    local DirectoryTrigger = directory.DirectoryTrigger
    local posix_mock = {} -- Mock for posix functions
    local _G_posix_original -- To store original posix if it exists

    before_each(function() {
        -- Mock posix globally for these tests
        _G_posix_original = _G.posix
        _G.posix = posix_mock
        posix_mock.access = function(path, mode)
            -- Default mock behavior: exists, not executable unless specified by test
            if mode == "e" then return true end
            if mode == "x" then return false end
            return false -- Should not happen with "e" or "x"
        end
    end)

    after_each(function() {
        -- Restore original posix
        _G.posix = _G_posix_original
    end)

    describe("new", function()
        it("should create a trigger with valid pattern and default options", function() {
            local trigger = DirectoryTrigger.new("config/*", {})
            assert.is_not_nil(trigger)
            assert.equals("config/*", trigger.pattern)
            assert.equals("directory", trigger.type)
            assert.is_true(trigger.options.must_exist)
            assert.is_false(trigger.options.must_be_executable)
        end)

        it("should store provided options", function() {
            local options = { must_exist = false, must_be_executable = true }
            local trigger = DirectoryTrigger.new("config", options)
            assert.is_not_nil(trigger)
            assert.is_false(trigger.options.must_exist)
            assert.is_true(trigger.options.must_be_executable)
        end)

        it("should accept empty pattern for root directory", function()
            local trigger = DirectoryTrigger.new("", {})
            assert.is_not_nil(trigger)
            assert.equals("", trigger.pattern)
        end)

        it("should reject nil pattern", function()
            local trigger, err = DirectoryTrigger.new(nil, {})
            assert.is_nil(trigger)
            assert.is_not_nil(err)
            assert.matches("requires a non%-nil pattern", err)
        end)

        it("should reject non-string pattern", function() {
            local trigger, err = DirectoryTrigger.new(123, {})
            assert.is_nil(trigger)
            assert.is_not_nil(err)
            assert.matches("pattern must be a string", err)
        end)
    end)

    describe("validate", function() {
        it("should validate trigger with valid pattern and options", function() {
            local trigger = DirectoryTrigger.new("config", { must_exist = true, must_be_executable = false })
            local valid, err = trigger:validate()
            assert.is_true(valid, "Validation failed: " .. tostring(err))
            assert.is_nil(err)
        end)

        it("should reject invalid must_exist option type", function() {
            local trigger = DirectoryTrigger.new("config", { must_exist = "true" })
            local valid, err = trigger:validate()
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("must_exist option must be a boolean", err)
        end)

        it("should reject invalid must_be_executable option type", function() {
            local trigger = DirectoryTrigger.new("config", { must_be_executable = "false" })
            local valid, err = trigger:validate()
            assert.is_false(valid)
            assert.is_not_nil(err)
            assert.matches("must_be_executable option must be a boolean", err)
        end)

        it("should validate complex patterns", function() {
            local patterns = { "config/*", "**/bin", "src/**/*.lua", "test?" }
            for _, pattern_str in ipairs(patterns) do
                local trigger = DirectoryTrigger.new(pattern_str, {})
                assert.is_not_nil(trigger, "Trigger creation failed for: " .. pattern_str)
                local valid, err = trigger:validate()
                assert.is_true(valid, "Pattern should be valid: " .. pattern_str .. " (error: " .. tostring(err) .. ")")
                assert.is_nil(err)
            end
        end)
    end)

    describe("match", function() {
        -- Note: file_path for DirectoryTrigger usually refers to the directory path itself being checked
        it("should match directory pattern when all checks pass (default options)", function() {
            local trigger = DirectoryTrigger.new("mybin", {}) -- must_exist=true, must_be_executable=false
            posix_mock.access = function(path, mode)
                if path == "/pack/mybin" and mode == "e" then return true end -- Exists
                return false
            end
            local matches, meta = trigger:match("/pack/mybin", "/pack")
            assert.is_true(matches)
            assert.is_not_nil(meta)
            assert.equals("mybin", meta.matched_pattern)
            assert.equals("mybin", meta.directory)
        end)

        it("should not match if glob matches but must_exist=true and dir does not exist", function() {
            local trigger = DirectoryTrigger.new("mybin", { must_exist = true })
            posix_mock.access = function(path, mode) return false end -- Does not exist

            local matches, _ = trigger:match("/pack/mybin", "/pack")
            assert.is_false(matches)
        end)

        it("should match if glob matches and must_exist=false, even if dir does not exist", function() {
            local trigger = DirectoryTrigger.new("mybin", { must_exist = false })
            posix_mock.access = function(path, mode) return false end -- Does not exist, but check is skipped

            local matches, _ = trigger:match("/pack/mybin", "/pack")
            assert.is_true(matches)
        end)

        it("should not match if glob matches, dir exists, but must_be_executable=true and dir not executable", function() {
            local trigger = DirectoryTrigger.new("mybin", { must_exist = true, must_be_executable = true })
            posix_mock.access = function(path, mode)
                if mode == "e" then return true end -- Exists
                if mode == "x" then return false end -- Not executable
                return false
            end
            local matches, _ = trigger:match("/pack/mybin", "/pack")
            assert.is_false(matches)
        end)

        it("should match if glob matches, dir exists, must_be_executable=true and dir is executable", function() {
            local trigger = DirectoryTrigger.new("mybin", { must_exist = true, must_be_executable = true })
            posix_mock.access = function(path, mode) return true end -- Exists and Executable

            local matches, _ = trigger:match("/pack/mybin", "/pack")
            assert.is_true(matches)
        end)

        it("should match if glob matches, dir exists, must_be_executable=false and dir not executable", function() {
            local trigger = DirectoryTrigger.new("mybin", { must_exist = true, must_be_executable = false })
            posix_mock.access = function(path, mode)
                if mode == "e" then return true end -- Exists
                if mode == "x" then return false end -- Not executable, but check is for false
                return false
            end
            local matches, _ = trigger:match("/pack/mybin", "/pack")
            assert.is_true(matches)
        end)

        it("should handle nil file_path", function() {
            local trigger = DirectoryTrigger.new("config", {})
            local matches, _ = trigger:match(nil, "/pack")
            assert.is_false(matches)
        end)

        it("should correctly match relative paths (glob part)", function() {
            -- Assuming file_path is /pack/config/path_to_match
            -- and pack_path is /pack
            -- then path_to_glob_match becomes config/path_to_match
            local trigger = DirectoryTrigger.new("config/*", {must_exist = false}) -- simplify FS checks
            local matches, meta = trigger:match("/pack/config/vim", "/pack")
            assert.is_true(matches)
            assert.equals("config/vim", meta.directory)
        end)

        it("should match files in root directory of pack (empty pattern)", function() {
            local trigger = DirectoryTrigger.new("", {must_exist = false})
            -- file_path for DirectoryTrigger is the directory itself.
            -- If we're checking the root of the pack, file_path would be pack_path.
            local matches, meta = trigger:match("/pack", "/pack")
            assert.is_true(matches)
            assert.equals("", meta.directory) -- Relative path of pack_path to pack_path is empty
        end)

        it("should match complex double wildcard patterns with FS checks", function() {
            local trigger = DirectoryTrigger.new("project/**/config", {must_exist = true, must_be_executable = false})
            posix_mock.access = function(path, mode)
                if path == "/pack/project/foo/bar/config" and mode == "e" then return true end
                return false
            end
            local matches, meta = trigger:match("/pack/project/foo/bar/config", "/pack")
            assert.is_true(matches)
            assert.equals("project/foo/bar/config", meta.directory)
        end)
    end)
end)
