{
  runCommand,
  lua,
  luapkgs ? lua.pkgs,
  ...
}: let
  pipe = builtins.foldl' (x: f: f x);
in luapkgs.luaLib.toLuaModule (runCommand "shelua" {
  src = ./lua/sh.lua;
  env_path = with builtins; pipe luapkgs.lua.LuaPathSearchPaths [ head (split "[\/][?]") head ];
} /*bash*/ ''
  mkdir -p "$out/$env_path"
  cp "$src" "$out/$env_path/sh.lua"
'')
