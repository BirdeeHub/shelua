{
  runCommandNoCC,
  lua_interpreter,
  ...
}: let
  pipe = builtins.foldl' (x: f: f x);
in lua_interpreter.pkgs.luaLib.toLuaModule (runCommandNoCC "luash" {
  src = ./sh.lua;
  env_path = with builtins; pipe lua_interpreter.LuaPathSearchPaths [ head (split "[\/][?]") head ];
} /*bash*/ ''
  mkdir -p "$out/$env_path"
  cp "$src" "$out/$env_path/sh.lua"
'')
