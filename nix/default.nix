{ lib
, stdenv
, ...
}: name: interpreter: env: text:
stdenv.mkDerivation (finalAttrs: {
  inherit name;
  luaInterpreter = interpreter;
  luaBuilder = text;
  luaBuilderData = lib.pipe (finalAttrs.passthru.info or {}) [
    (lib.filterAttrsRecursive (n: v: ! lib.isFunction v))
    (v: "return ${lib.generators.toLua { } v}")
  ];
  passAsFile = [ "luaBuilder" "luaBuilderData" ] ++ (env.passAsFile or [ ]);
  buildCommand = /*bash*/ ''
    TEMPDIR=$(mktemp -d)
    mkdir -p "$TEMPDIR"
    STDENV_SHELL_HOOKS=$(mktemp)
    declare -f > "$STDENV_SHELL_HOOKS"
    envdir=$(mktemp -d)
    mkdir -p "$envdir"
    $CC -O2 -fPIC ${if stdenv.isDarwin then "-bundle -undefined dynamic_lookup" else "-shared"} -o "$envdir/sh.so" '${./env.c}' -I"$(dirname $luaInterpreter)/../include"
    echo "package.cpath = '$envdir/?.so;' .. package.cpath
    package.path = '${../lua}/?.lua;' .. package.path
    local ok, val = pcall(dofile, '${./nix.lua}')
    assert(ok, val)
    ok, val = pcall(val, '$out', '$TEMPDIR', '$STDENV_SHELL_HOOKS')
    assert(ok, val)
    " | "$luaInterpreter" -
  '';
} // lib.optionalAttrs (!env ? meta) {
  pos =
    let
      args = builtins.attrNames env;
    in
    if builtins.length args > 0 then
      builtins.unsafeGetAttrPos (builtins.head args) env
    else
      null;
} // (removeAttrs env [ "passAsFile" "buildCommand" ]))
