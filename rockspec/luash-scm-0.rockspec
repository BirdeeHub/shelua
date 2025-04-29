package = "shelua"
version = "scm-0"

source = {
	url = "git://github.com/BirdeeHub/" .. package .. ".git",
}

description = {
	summary = "Tiny library for shell scripting with Lua",
	detailed = [[
		Tiny library with syntax sugar for (unix) shell scripting in Lua (inspired by
		zserge/luash but with features localized to sh variable)
	]],
	homepage = "http://github.com/BirdeeHub/" .. package,
	license = "MIT/X11",
}

dependencies = {
	"lua >= 5.1"
}

build = {
	type = "none",
	install = {
		lua = {
			sh = "sh.lua",
		},
	},
	copy_directories = {},
}
