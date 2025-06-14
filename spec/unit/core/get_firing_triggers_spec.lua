-- spec/unit/core/get_firing_triggers_spec.lua
local get_firing_triggers = require("dodot.core.get_firing_triggers")
local libs = require("dodot.libs")
local pl_path = require("pl.path")
local pl_file = require("pl.file")
local test_utils = require("spec.helpers.test_utils")
local types = require("dodot.types") -- For Pack type structure if needed for clarity

describe("dodot.core.get_firing_triggers", function()
  local temp_dir

  before_each(function()
    if not libs.is_initialized() then libs.init() end
    temp_dir = test_utils.fs.create_temp_dir()
  end)

  after_each(function()
    if temp_dir then
      test_utils.fs.cleanup_temp_dir(temp_dir) -- Corrected to cleanup
    end
  end)

  it("should return empty list if no packs are provided", function()
    local matches, err = get_firing_triggers.get_firing_triggers({})
    assert.is_nil(err)
    assert.are.same({}, matches)
  end)

  it("should return empty list if packs have no files", function()
    local pack1_path = pl_path.join(temp_dir, "pack1_empty")
    assert(pl_path.mkdir(pack1_path), "Failed to create temp pack dir")

    local packs = { { path = pack1_path, name = "pack1_empty", config = nil } }
    local matches, err = get_firing_triggers.get_firing_triggers(packs)

    assert.is_nil(err, err and err.message or "nil error expected")
    assert.is_table(matches)
    assert.equals(0, #matches, "Expected 0 matches for pack with no files")
  end)

  it("should return empty list if stub trigger (default: no match) is used", function()
    local pack1_path = pl_path.join(temp_dir, "pack1")
    assert(pl_path.mkdir(pack1_path), "Failed to create temp pack dir")
    local file_path = pl_path.join(pack1_path, "file.txt")
    assert(pl_file.write(file_path, "content", true), "Failed to create temp file") -- ensure create

    local packs = { { path = pack1_path, name = "pack1", config = nil } }
    local matches, err = get_firing_triggers.get_firing_triggers(packs)

    assert.is_nil(err, err and err.message or "nil error expected")
    assert.is_table(matches)
    assert.equals(0, #matches, "Expected 0 matches as default matchers should not match this file")
  end)

  it("should return a trigger match if a matcher's trigger matches", function()
    -- We need to mock matchers.get_simulated_matchers to return a controlled BasicMatcher instance
    local mock_matchers_module = require("dodot.matchers")
    local mock_basic_matcher = require("dodot.matchers.basic_matcher")
    local mock_file_name_trigger = require("dodot.triggers.file_name")

    -- Create a real FileNameTrigger that will match our specific file
    local matching_trigger_instance, terr = mock_file_name_trigger.FileNameTrigger.new({ patterns = "specific_match.txt" })
    assert.is_not_nil(matching_trigger_instance, "Failed to create FileNameTrigger: " .. tostring(terr))

    -- Create a BasicMatcher instance with this trigger
    local matcher_instance, merr = mock_basic_matcher.BasicMatcher.new({
        matcher_name = "test_specific_matcher",
        trigger_type = "file_name",
        trigger_options = { patterns = "specific_match.txt" },
        power_up_name = "test_powerup",
        power_up_options = { some_option = true },
        priority = 100
    })
    assert.is_not_nil(matcher_instance, "Failed to create BasicMatcher: " .. tostring(merr))
    -- Ensure the trigger inside is correctly instantiated (mocking libs.triggers.get for BasicMatcher.new)
    local original_libs_triggers_get = libs.triggers.get
    libs.triggers.get = function(trigger_type)
        if trigger_type == "file_name" then return mock_file_name_trigger end
        return original_libs_triggers_get(trigger_type) -- fallback for other types if any
    end
    -- Re-create matcher instance with the proper mock for its internal trigger creation
    matcher_instance, merr = mock_basic_matcher.BasicMatcher.new({
        matcher_name = "test_specific_matcher",
        trigger_type = "file_name",
        trigger_options = { patterns = "specific_match.txt" },
        power_up_name = "test_powerup",
        power_up_options = { some_option = true },
        priority = 100
    })
    assert.is_not_nil(matcher_instance, "Failed to create BasicMatcher (with mock): " .. tostring(merr))
    assert.equals("file_name", matcher_instance.trigger.type)
    libs.triggers.get = original_libs_triggers_get -- Restore immediately


    -- Spy on and mock get_simulated_matchers
    -- Ensure matchers_module is the actual table returned by require
    assert.is_table(mock_matchers_module, "mock_matchers_module is not a table")
    assert.is_function(mock_matchers_module.get_simulated_matchers, "get_simulated_matchers is not a function on module")
    spy.on(mock_matchers_module, "get_simulated_matchers")
    mock_matchers_module.get_simulated_matchers:returns({ matcher_instance }, nil)


    local pack1_path = pl_path.join(temp_dir, "pack_match_test")
    assert(pl_path.mkdir(pack1_path), "Failed to create temp pack dir")
    local file_to_match = pl_path.join(pack1_path, "specific_match.txt")
    local other_file = pl_path.join(pack1_path, "other_file.txt")
    assert(pl_file.write(file_to_match, "content match", true), "Failed to create matching file")
    assert(pl_file.write(other_file, "content other", true), "Failed to create other file")

    local packs = { { path = pack1_path, name = "pack_match_test", config = nil } }
    local matches, err = get_firing_triggers.get_firing_triggers(packs)

    assert.is_nil(err, err and err.message or "nil error expected")
    assert.is_table(matches)
    assert.equals(1, #matches, "Expected 1 match")

    if #matches == 1 then
      local match_result = matches[1]
      assert.equals(matcher_instance.trigger.type, match_result.trigger_name)
      assert.equals(file_to_match, match_result.file_path)
      assert.equals(pack1_path, match_result.pack_path)
      assert.is_table(match_result.metadata)
      assert.is_not_nil(match_result.metadata.matched_pattern)
      assert.equals(matcher_instance.power_up_name, match_result.power_up_name)
      assert.equals(matcher_instance.priority, match_result.priority)
      assert.same(matcher_instance.options, match_result.options)
    end

    -- Restore spy
    spy.restore(mock_matchers_module.get_simulated_matchers)
  end)

  -- This test case is now obsolete as trigger fetching/validation is part of matcher creation/validation
  -- it("should handle error if a configured trigger is not in the registry", function()
  --     assert.is_true(true, "Test obsolete: Trigger validation handled by BasicMatcher")
  -- end)

-- end) -- This end was orphaned by commenting out the test above it.
      -- The following lines seem to be remnants of a test and are not inside an 'it' block.
      -- Removing them to fix syntax error.
      -- assert.is_true(true, "Skipping direct test for missing trigger in registry (covered by get_simulated_matchers init)")
  -- end) -- This end is also part of the remnant.

end)
