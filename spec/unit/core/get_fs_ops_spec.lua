-- spec/unit/core/get_fs_ops_spec.lua
local get_fs_ops = require("dodot.core.get_fs_ops")
local types = require("dodot.types") -- For Operation type structure if needed for clarity
local pl_path = require("pl.path") -- For path joining in expected results

describe("dodot.core.get_fs_ops", function()
  local original_getenv

  before_each(function()
    original_getenv = os.getenv
    -- Mock os.getenv for HOME and XDG_CONFIG_HOME to ensure consistent paths
    _G.os.getenv = function(var_name)
      if var_name == "HOME" then
        return "/testhome"
      elseif var_name == "XDG_CONFIG_HOME" then
        return "/testhome/.testconfig" -- Simulate XDG_CONFIG_HOME being set
      end
      return original_getenv(var_name) -- Passthrough for other vars
    end
  end)

  after_each(function()
    _G.os.getenv = original_getenv -- Restore original os.getenv
  end)

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

  describe("shell_source action type", function()
    local DODOT_SHELL_BASE_DIR_NAME = "dodot/shell"
    local ALIASES_SUBDIR_NAME = "aliases"
    local PROFILE_SUBDIR_NAME = "profile_scripts"
    local INIT_SCRIPT_NAME = "init.sh"

    it("should generate correct ops for a profile script", function()
      local xdg_config_dir = "/testhome/.testconfig" -- From mock
      local dodot_base_shell_path = pl_path.join(xdg_config_dir, DODOT_SHELL_BASE_DIR_NAME)
      local profile_subdir_path = pl_path.join(dodot_base_shell_path, PROFILE_SUBDIR_NAME)
      local init_script_path = pl_path.join(dodot_base_shell_path, INIT_SCRIPT_NAME)

      local actions = {
        {
          type = "shell_source",
          description = "Source my custom profile script",
          pack_path = "/testhome/pack1", -- For resolving relative source_file
          data = {
            source_file = "my_script.sh", -- Relative to pack_path
            order = 30
          }
        }
      }
      local ops, err = get_fs_ops.get_fs_ops(actions)
      assert.is_nil(err, err and err.message or "get_fs_ops returned an error")
      assert.is_table(ops)
      assert.equals(4, #ops, "Expected 4 operations for shell_source")

      -- Op 1: Ensure base dir
      assert.same({
        type = "fsynth.op.ensure_dir",
        description = "Ensure dodot shell base directory exists: " .. dodot_base_shell_path,
        args = { path = dodot_base_shell_path, mode = "0755" }
      }, ops[1])

      -- Op 2: Ensure profile subdir
      assert.same({
        type = "fsynth.op.ensure_dir",
        description = "Ensure dodot shell target subdirectory exists: " .. profile_subdir_path,
        args = { path = profile_subdir_path, mode = "0755" }
      }, ops[2])

      -- Op 3: Symlink script
      local expected_symlink_name = "30-my_script.sh"
      local expected_symlink_path = pl_path.join(profile_subdir_path, expected_symlink_name)
      local expected_abs_source_file = "/testhome/pack1/my_script.sh" -- Resolved from pack_path
      assert.same({
        type = "fsynth.op.symlink",
        description = "Symlink shell script " .. expected_abs_source_file .. " to " .. expected_symlink_path,
        args = { src = expected_abs_source_file, dest = expected_symlink_path, force = true }
      }, ops[3])

      -- Op 4: Create init.sh
      local xdg_config_home_var = "${XDG_CONFIG_HOME:-$HOME/.config}"
      local script_base_dir_in_shell = xdg_config_home_var .. "/" .. DODOT_SHELL_BASE_DIR_NAME
      local expected_init_content_parts = {
            "#!/bin/sh",
            "# Sources all scripts managed by dodot.",
            "# This script is auto-generated by dodot. Do not edit manually.",
            "",
            "__dodot_source_files_from_dir() {",
            "  local dir=\"$1\"",
            "  if [ -d \"$dir\" ]; then",
            "    for f in \"$dir\"/*; do",
            "      if [ -f \"$f\" ]; then",
            "        . \"$f\"",
            "      fi",
            "    done",
            "  fi",
            "}",
            "",
            "# Source aliases",
            "__dodot_source_files_from_dir \"" .. script_base_dir_in_shell .. "/" .. ALIASES_SUBDIR_NAME .. "\"",
            "",
            "# Source profile scripts",
            "__dodot_source_files_from_dir \"" .. script_base_dir_in_shell .. "/" .. PROFILE_SUBDIR_NAME .. "\"",
            "",
            "unset __dodot_source_files_from_dir"
      }
      local expected_init_content = table.concat(expected_init_content_parts, "\n") .. "\n"

      assert.same({
        type = "fsynth.op.create_file",
        description = "Create/Update dodot init script: " .. init_script_path,
        args = { path = init_script_path, content = expected_init_content, mode = "0755", overwrite = true }
      }, ops[4])
    end)

    it("should place alias scripts in aliases subdirectory and use default order 50", function()
      local xdg_config_dir = "/testhome/.testconfig"
      local dodot_base_shell_path = pl_path.join(xdg_config_dir, DODOT_SHELL_BASE_DIR_NAME)
      local aliases_subdir_path = pl_path.join(dodot_base_shell_path, ALIASES_SUBDIR_NAME)

      local actions = {
        {
          type = "shell_source",
          data = {
            source_file = "/an/absolute/path/to/my_aliases.sh", -- Absolute path
            -- No order, should default to 50
          }
        }
      }
      local ops, err = get_fs_ops.get_fs_ops(actions)
      assert.is_nil(err)
      assert.equals(4, #ops)

      -- Check only relevant parts for this test
      -- Op 2: Ensure aliases subdir
      assert.same({
        type = "fsynth.op.ensure_dir",
        description = "Ensure dodot shell target subdirectory exists: " .. aliases_subdir_path,
        args = { path = aliases_subdir_path, mode = "0755" }
      }, ops[2])

      -- Op 3: Symlink (check name and dest path)
      local expected_symlink_name = "50-my_aliases.sh" -- Default order 50
      local expected_symlink_path = pl_path.join(aliases_subdir_path, expected_symlink_name)
      assert.equals(expected_symlink_path, ops[3].args.dest)
      assert.equals("/an/absolute/path/to/my_aliases.sh", ops[3].args.src)
    end)

    it("should use $HOME/.config if XDG_CONFIG_HOME is not set", function()
        _G.os.getenv = function(var_name) -- Temporarily override mock for this test case
          if var_name == "HOME" then return "/testhome" end
          return nil -- Simulate XDG_CONFIG_HOME not set
        end

        local home_config_dir = "/testhome/.config" -- Expected base for config
        local dodot_base_shell_path = pl_path.join(home_config_dir, DODOT_SHELL_BASE_DIR_NAME)

        local actions = {{ type = "shell_source", data = { source_file = "a.sh" }}}
        local ops, _ = get_fs_ops.get_fs_ops(actions)
        assert.is_not_nil(ops, "Operations should not be nil")
        assert.is_true(#ops > 0, "Expected at least one operation")
        -- Check that the path for the first ensure_dir op (base shell dir) uses $HOME/.config
        assert.equals(dodot_base_shell_path, ops[1].args.path)
    end)

    it("should return no ops and print error if HOME directory is not found by builder", function()
        _G.os.getenv = function(_) return nil end -- Mock getenv to return nil for HOME
        local actions = {{ type = "shell_source", data = { source_file = "a.sh" }}}
        -- Note: get_fs_ops itself pcalls the builder. If builder returns (nil, err_obj),
        -- get_fs_ops prints the error and continues, returning an empty ops table for that action.
        local ops, err = get_fs_ops.get_fs_ops(actions)
        assert.is_nil(err) -- get_fs_ops itself doesn't propagate the error from pcall
        assert.equals(0, #ops) -- No ops should be generated if home_dir is not found by the builder.
    end)

    it("should handle missing source_file in action.data (builder returns error)", function()
        local actions = {{ type = "shell_source", data = { order = 10 }}}
        local ops, err = get_fs_ops.get_fs_ops(actions)
        assert.is_nil(err)
        assert.equals(0, #ops) -- Expect no ops, error printed by get_fs_ops from builder
    end)
  end)
end)
