{
  runCommand,
  lua,
  ...
}: let
  pipe = builtins.foldl' (x: f: f x);
in lua.pkgs.luaLib.toLuaModule (runCommand "shelua" {
  src = ./lua/sh.lua;
  env_path = with builtins; pipe lua.LuaPathSearchPaths [ head (split "[\/][?]") head ];
} /*bash*/ ''
  mkdir -p "$out/$env_path"
  cp "$src" "$out/$env_path/sh.lua"
'')
