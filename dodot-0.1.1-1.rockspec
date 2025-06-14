rockspec_format = "3.0"
package = "dodot"
version = "0.1.1-1"
source = {
  url = "git+https://github.com/arthur-debert/dodotl",
}
description = {
  summary = "A dotfile manager.",
  detailed = [[
		 Simple cmds for simple people
   ]],
  homepage = "https://github.com/arthur-debert/dodotl",
  license = "MIT",
}
dependencies = {
  "lua >= 5.1",
  "penlight >= 1.14.0",
  "lual >= 1.0.13",
  "string-format-all >= 0.2.0", -- Package name uses hyphens, but require() uses dots
  "lua-toml >= 2.0-1", -- The module name is 'toml' despite package name being 'lua-toml'
  "dkjson >= 2.5", -- For JSON file support
  "lyaml >= 6.2", -- For YAML file support
  "fsynth >= 0.1.3", -- File system operations and safety
  "melt >= 0.1.3", -- Configuration merging and hierarchy
  "luaposix >= 36.3",
}
test_dependencies = {
  "busted >= 2.0.0",
  "luacov",
}
build = {
  type = "builtin",
  -- Generated module mappings for rockspec
  modules = {
    ["dodot.actions"] = "lua/dodot/actions/init.lua",
    ["dodot.cli"] = "lua/dodot/cli.lua",
    ["dodot.commands.deploy"] = "lua/dodot/commands/deploy.lua",
    ["dodot.commands.list"] = "lua/dodot/commands/list.lua",
    ["dodot.core.get_actions"] = "lua/dodot/core/get_actions.lua",
    ["dodot.core.get_firing_triggers"] = "lua/dodot/core/get_firing_triggers.lua",
    ["dodot.core.get_fs_ops"] = "lua/dodot/core/get_fs_ops.lua",
    ["dodot.core.get_packs"] = "lua/dodot/core/get_packs.lua",
    ["dodot.core.list_packs"] = "lua/dodot/core/list_packs.lua",
    ["dodot.core.run_ops"] = "lua/dodot/core/run_ops.lua",
    ["dodot.errors.codes"] = "lua/dodot/errors/codes.lua",
    ["dodot.errors"] = "lua/dodot/errors/init.lua",
    ["dodot.libs"] = "lua/dodot/libs.lua",
    ["dodot.matchers"] = "lua/dodot/matchers/init.lua",
    ["dodot.powerups"] = "lua/dodot/powerups/init.lua",
    ["dodot.triggers"] = "lua/dodot/triggers/init.lua",
    ["dodot.types"] = "lua/dodot/types.lua",
    ["dodot.utils.registry"] = "lua/dodot/utils/registry.lua",
    ["dodot"] = "lua/dodot/init.lua",
  },
}

test = {
  type = "busted",
  -- Additional test configuration can go here
}
