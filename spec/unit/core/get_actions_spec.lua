-- spec/unit/core/get_actions_spec.lua
local get_actions = require("dodot.core.get_actions")
local libs = require("dodot.libs")
local types = require("dodot.types") -- For Action type structure if needed for clarity
local test_utils = require("spec.helpers.test_utils") -- If any utils are needed

describe("dodot.core.get_actions", function()
  before_each(function()
    if not libs.is_initialized() then libs.init() end
  end)

  it("should return empty list if no trigger matches are provided", function()
    local actions, err = get_actions.get_actions({})
    assert.is_nil(err)
    assert.are.same({}, actions)
  end)

  it("should return empty list for stub powerup (default: no actions)", function()
    local trigger_matches = {
      {
        trigger_name = "stub_file_name_trigger",
        file_path = "/tmp/pack1/file.txt", -- Using temp-like paths for realism
        pack_path = "/tmp/pack1",
        metadata = { some_meta = "value" },
        power_up_name = "stub_symlink_powerup",
        priority = 10,
        options = { simulated_option = true }
      }
    }
    local actions, err = get_actions.get_actions(trigger_matches)
    assert.is_nil(err, err and err.message or "nil error expected")
    assert.is_table(actions)
    assert.equals(0, #actions, "Expected 0 actions as stub powerup returns none by default")
  end)

  it("should return actions if stub powerup is overridden to produce them", function()
    local original_powerup = libs.powerups.get("stub_symlink_powerup")
    assert.is_not_nil(original_powerup, "Stub powerup not found for overriding")
    local original_process_func = original_powerup.process

    original_powerup.process = function(self, files_for_powerup, pack_path_arg, options_arg)
      local generated_actions = {}
      for _, file_info in ipairs(files_for_powerup) do
        table.insert(generated_actions, {
          type = "link_stub", -- Use the registered stub action type
          description = "Action for " .. require("pl.path").basename(file_info.path),
          data = { src = file_info.path, dest = "/target/" .. require("pl.path").basename(file_info.path), meta = file_info.metadata },
          -- pack_source will be filled by get_actions if not provided here
        })
      end
      return generated_actions, nil
    end

    local trigger_matches = {
      {
        trigger_name = "stub_file_name_trigger",
        file_path = "/tmp/pack_actions/file1.txt",
        pack_path = "/tmp/pack_actions",
        metadata = { meta1 = "val1" },
        power_up_name = "stub_symlink_powerup",
        priority = 10,
        options = { powerup_opt = "enabled" }
      },
      {
        trigger_name = "stub_file_name_trigger",
        file_path = "/tmp/pack_actions/file2.txt",
        pack_path = "/tmp/pack_actions", -- Same pack, same powerup, same options -> one group
        metadata = { meta2 = "val2" },
        power_up_name = "stub_symlink_powerup",
        priority = 10,
        options = { powerup_opt = "enabled" }
      }
    }
    local actions, err = get_actions.get_actions(trigger_matches)

    assert.is_nil(err, err and err.message or "nil error expected")
    assert.is_table(actions)
    assert.equals(2, #actions, "Expected 2 actions, one for each file")

    if #actions == 2 then
      assert.equals("link_stub", actions[1].type)
      assert.matches("file1.txt", actions[1].description)
      assert.equals("/tmp/pack_actions/file1.txt", actions[1].data.src)
      assert.equals("pack_actions", actions[1].pack_source)
      assert.are.same({meta1 = "val1"}, actions[1].data.meta)


      assert.equals("link_stub", actions[2].type)
      assert.matches("file2.txt", actions[2].description)
      assert.equals("/tmp/pack_actions/file2.txt", actions[2].data.src)
      assert.equals("pack_actions", actions[2].pack_source)
      assert.are.same({meta2 = "val2"}, actions[2].data.meta)
    end

    -- Restore original process function
    original_powerup.process = original_process_func
  end)

  it("should group matches correctly and call powerup once per group", function()
    local original_powerup = libs.powerups.get("stub_symlink_powerup")
    local original_process_func = original_powerup.process
    local call_count = 0
    local received_file_counts = {}

    original_powerup.process = function(self, files, pack_path, opts)
        call_count = call_count + 1
        table.insert(received_file_counts, #files)
        return {}, nil -- Return no actions for simplicity
    end

    local trigger_matches = {
        -- Group 1: packA, opts1
        { power_up_name = "stub_symlink_powerup", pack_path = "/packA", file_path = "/packA/f1", options = {opt="A"} },
        { power_up_name = "stub_symlink_powerup", pack_path = "/packA", file_path = "/packA/f2", options = {opt="A"} },
        -- Group 2: packB, opts1
        { power_up_name = "stub_symlink_powerup", pack_path = "/packB", file_path = "/packB/f3", options = {opt="A"} },
        -- Group 3: packA, opts2 (different options)
        { power_up_name = "stub_symlink_powerup", pack_path = "/packA", file_path = "/packA/f4", options = {opt="B"} },
    }
    local _, err = get_actions.get_actions(trigger_matches)
    assert.is_nil(err)
    assert.equals(3, call_count, "Powerup process should be called 3 times for 3 distinct groups")
    table.sort(received_file_counts) -- Sort counts as group processing order is not guaranteed
    assert.are.same({1,1,2}, received_file_counts, "Expected file counts per group call")

    original_powerup.process = original_process_func -- Restore
  end)

end)
