{
  runCommand,
  lua,
  luapkgs ? lua.pkgs,
  ...
}: luapkgs.luaLib.toLuaModule (runCommand "shelua" {
  src = ./lua/sh.lua;
  env_path = with builtins; (head (split "[\/][?]" (head luapkgs.lua.LuaPathSearchPaths)));
} /*bash*/ ''
  mkdir -p "$out/$env_path"
  cp "$src" "$out/$env_path/sh.lua"
'')
