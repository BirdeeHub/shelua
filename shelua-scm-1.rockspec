local _MODREV, _SPECREV = 'scm', '-1'
rockspec_format = '3.0'
package = "shelua"
version = _MODREV .. _SPECREV

source = {
   url = "https://github.com/BirdeeHub/"..package,
}

description = {
   summary = "Tiny lua module to write shell scripts with lua (inspired by zserge/luash)",
   homepage = "https://github.com/BirdeeHub/"..package,
   license = "MIT"
}

dependencies = {
   "lua >= 5.1"
}

build = {
   type = "builtin",
   modules = { ["sh.env"] = "nix/env.c" }
}
