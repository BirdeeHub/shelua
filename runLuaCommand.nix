{ lib, runCommand, n2l, ... }: name: interpreter: env: text: let
  fenv = (if lib.isFunction env then env n2l else env);
in runCommand name (fenv // {
  passAsFile = [ "luaBuilder" ] ++ fenv.passAsFile or [];
  luaBuilder = "package.preload.drv = function() return ${n2l.toLua fenv} end; _G.drv = require([[drv]]);" + (if lib.isFunction text then text n2l else text);
}) ''
  TEMPDIR=$(mktemp -d)
  mkdir -p "$TEMPDIR"
  TEMPDIR2=$(mktemp -d)
  mkdir -p "$TEMPDIR2"
  declare -f > "$TEMPDIR2/shell_hooks.sh"
  echo "_G.temp = '$TEMPDIR'
  _G.out = '${placeholder "out"}'
  package.preload.sh = function() return dofile('${./sh.lua}') end
  local ok, val = pcall(dofile, '${./stdenv.lua}')
  assert(ok, val)
  ok, val = pcall(val, '$TEMPDIR2')
  assert(ok, val)
  " | exec ${interpreter} -
''
