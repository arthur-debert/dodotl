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
	"lual >= 1.0.11",
	"string-format-all >= 0.2.0", -- Package name uses hyphens, but require() uses dots
	"lua-toml >= 2.0-1", -- The module name is 'toml' despite package name being 'lua-toml'
	"dkjson >= 2.5", -- For JSON file support
	"lyaml >= 6.2", -- For YAML file support
}
test_dependencies = {
	"busted >= 2.0.0",
	"luacov",
}
build = {
	type = "builtin",
	install = {
		lua = {
			["dodot"] = "lua/dodot",
		},
	},
}
test = {
	type = "busted",
	-- Additional test configuration can go here
}
