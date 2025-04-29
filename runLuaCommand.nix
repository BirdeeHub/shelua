{ lib, stdenv, n2l, ... }: name: interpreter: env: text:
stdenv.mkDerivation (let
  derivationArgs = if lib.isFunction env then env n2l else env;
in {
  enableParallelBuilding = true;
  inherit name;
  luaBuilder = if lib.isFunction text then text n2l else text;
  luaBuilderData = "return ${n2l.toLua derivationArgs}";
  passAsFile = [ "luaBuilder" "luaBuilderData" ] ++ (derivationArgs.passAsFile or [ ]);
  buildCommand = /*bash*/ ''
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
  '';
} // lib.optionalAttrs (!derivationArgs ? meta) {
  pos =
    let
      args = builtins.attrNames derivationArgs;
    in
    if builtins.length args > 0 then
      builtins.unsafeGetAttrPos (builtins.head args) derivationArgs
    else
      null;
} // (builtins.removeAttrs derivationArgs [ "passAsFile" ]))
