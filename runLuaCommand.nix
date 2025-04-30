{ lib
, stdenv
, n2l ? import (builtins.fetchGit (let
    lock = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.n2l.locked;
  in {
    url = "https://github.com/${lock.owner}/${lock.repo}.git";
    rev = lock.rev;
  }))
, ...
}: name: interpreter: env: text:
stdenv.mkDerivation (finalAttrs: let
  derivationArgs = if lib.isFunction env then env n2l else env;
in {
  enableParallelBuilding = true;
  inherit name;
  luaInterpreter = interpreter;
  luaBuilder = if lib.isFunction text then text n2l else text;
  luaBuilderData = lib.pipe (finalAttrs.passthru or {}) [
    (lib.filterAttrsRecursive (n: v: ! lib.isFunction v))
    (v: "return ${n2l.toLua v}")
  ];
  passAsFile = [ "luaBuilder" "luaBuilderData" ] ++ (derivationArgs.passAsFile or [ ]);
  buildCommand = /*bash*/ ''
    LUA_SHELL_HOOKS=$(mktemp)
    TEMPDIR=$(mktemp -d)
    mkdir -p "$TEMPDIR"
    declare -f > "$LUA_SHELL_HOOKS"
    echo "_G.temp = '$TEMPDIR'
    _G.out = '${placeholder "out"}'
    package.preload.sh = function() return dofile('${./lua/sh.lua}') end
    local ok, val = pcall(dofile, '${./nix.lua}')
    assert(ok, val)
    ok, val = pcall(val, '$LUA_SHELL_HOOKS')
    assert(ok, val)
    " | "$luaInterpreter" -
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
