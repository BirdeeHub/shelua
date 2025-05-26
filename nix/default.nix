{ lib
, stdenv
, n2l ? import (builtins.fetchGit (let
    lock = (builtins.fromJSON (builtins.readFile ../flake.lock)).nodes.n2l.locked;
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
    TEMPDIR=$(mktemp -d)
    mkdir -p "$TEMPDIR"
    STDENV_SHELL_HOOKS=$(mktemp)
    declare -f > "$STDENV_SHELL_HOOKS"
    envdir=$(mktemp -d)
    mkdir -p "$envdir"
    $CC -O2 -fPIC -shared -o "$envdir/env.so" '${./env.c}' -I"$(dirname $luaInterpreter)/../include"
    echo "package.cpath = '$envdir/?.so;' .. package.cpath
    package.path = '${../lua}/?.lua;' .. package.path
    local ok, val = pcall(dofile, '${./nix.lua}')
    assert(ok, val)
    ok, val = pcall(val, '$out', '$TEMPDIR', '$STDENV_SHELL_HOOKS')
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
