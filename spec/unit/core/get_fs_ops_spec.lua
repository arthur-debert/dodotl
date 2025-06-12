-- spec/unit/core/get_fs_ops_spec.lua
local get_fs_ops = require("dodot.core.get_fs_ops")
local types = require("dodot.types") -- For Operation type structure if needed for clarity

describe("dodot.core.get_fs_ops", function()
  it("should return empty list if no actions are provided", function()
    local ops, err = get_fs_ops.get_fs_ops({})
    assert.is_nil(err)
    assert.are.same({}, ops)
  end)

  it("should return empty list if actions_list is nil", function()
    local ops, err = get_fs_ops.get_fs_ops(nil)
    assert.is_nil(err)
    assert.are.same({}, ops)
  end)

  it("should convert a known stub action ('link_stub') to a stub operation", function()
    local actions = {
      {
        type = "link_stub",
        description = "Test link stub action",
        data = { src = "a", dest = "b"},
        pack_source = "test_pack"
      }
    }
    local ops, err = get_fs_ops.get_fs_ops(actions)
    assert.is_nil(err, err and err.message or "nil error expected")
    assert.is_table(ops)
    assert.equals(1, #ops, "Expected 1 operation")

    if #ops == 1 then
      local op = ops[1]
      assert.equals("fsynth.op.symlink_stub", op.type)
      assert.equals("Test link stub action", op.description)
      assert.is_table(op.args)
      assert.are.same({src="a", dest="b"}, op.args)
    end
  end)

  it("should use default description if action description is missing for 'link_stub'", function()
    local actions = {
      {
        type = "link_stub",
        data = { src = "c", dest = "d"},
        pack_source = "test_pack2"
      }
    }
    local ops, err = get_fs_ops.get_fs_ops(actions)
    assert.is_nil(err)
    assert.equals(1, #ops)
    if #ops == 1 then
      assert.equals("Stub symlink operation from link_stub action", ops[1].description)
      assert.are.same({src="c", dest="d"}, ops[1].args)
    end
  end)

  it("should handle missing action.data gracefully for 'link_stub' (builder returns error)", function()
    -- The current builder for link_stub in get_fs_ops.lua is designed to return an error
    -- if action.data or action.data.src/dest is missing.
    -- pcall in get_fs_ops should catch this and print an error, resulting in no operations.
    local actions = {
      {
        type = "link_stub",
        description = "Action with missing data",
        pack_source = "test_pack_error"
        -- data is missing
      }
    }
    -- Note: This test relies on observing print output for the error from the builder,
    -- as get_fs_ops currently only prints pcall errors and doesn't propagate them.
    -- For a stricter test, get_fs_ops would need to be modified to return errors.
    -- For now, we just check that no operations are generated.

    local ops, err = get_fs_ops.get_fs_ops(actions)
    assert.is_nil(err) -- get_fs_ops itself doesn't return an error here
    assert.is_table(ops)
    assert.equals(0, #ops, "Expected 0 operations due to pcall failure in builder")
    -- To verify the print, one would need to capture stdout. That's outside basic busted.
  end)

  it("should handle unknown action types gracefully (prints warning, generates no ops)", function()
    local actions = {
      { type = "unknown_action_type", data = {}, description = "Unknown" }
    }
    local ops, err = get_fs_ops.get_fs_ops(actions)
    assert.is_nil(err)
    assert.is_table(ops)
    assert.equals(0, #ops, "Expected 0 operations for unknown action type")
    -- Test would ideally check for the print warning too.
  end)

  it("should skip malformed actions (e.g., missing type)", function()
    local actions = {
      { description = "Malformed action, no type" }
    }
    local ops, err = get_fs_ops.get_fs_ops(actions)
    assert.is_nil(err)
    assert.is_table(ops)
    assert.equals(0, #ops, "Expected 0 operations for malformed action")
  end)

end)
