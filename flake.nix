{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  outputs = { self, ... }@inputs: let
    lib = inputs.pkgs.lib or inputs.nixpkgs.lib or (import "${inputs.nixpkgs or <nixpkgs>}/lib");
    forAllSys = lib.genAttrs lib.platforms.all;
    getPkgs = system: overlays: if inputs.pkgs.stdenv.hostPlatform.system or null == system then
      if builtins.isList overlays && overlays != [] then
        inputs.pkgs.appendOverlays overlays
      else
        inputs.pkgs
    else
      import (inputs.pkgs.path or inputs.nixpkgs or <nixpkgs>) {
        inherit system;
        overlays = (if builtins.isList overlays then overlays else []) ++ inputs.pkgs.overlays or [];
        config = inputs.pkgs.config or {};
      };
    APPNAME = "shelua";
    l_pkg_enum = [ "lua5_1" "lua5_2" "lua5_3" "lua5_4" "lua5_5" "luajit" "lua" ];
    mkLuaOverlay = { packageOverrides, vimPlugins ? null, versions ? [], controlType ? "exclude", ... }:
      assert builtins.isList versions || throw "lua versions must be a list of strings containing `lua.luaAttr` names corresponding to `pkgs.luaInterpreters`!";
      assert controlType == "build" || controlType == "exclude" || throw ''controlType must be "build" or "exclude"'';
    final: prev: {
      luaInterpreters = prev.luaInterpreters // prev.lib.pipe (
        if controlType == "build" then
          prev.lib.intersectLists versions (builtins.attrNames prev.luaInterpreters)
        else
          builtins.filter (x: !builtins.elem x versions) (builtins.attrNames prev.luaInterpreters)
      ) [
        (map (v: prev.lib.nameValuePair v packageOverrides))
        builtins.listToAttrs
        (builtins.mapAttrs (
          n: new: prev.luaInterpreters.${n}.override (old: {
            packageOverrides = prev.lib.composeExtensions (old.packageOverrides or (_: _: {})) new;
          })
        ))
      ];
      ${if prev.lib.isFunction vimPlugins then "vimPlugins" else null} = prev.vimPlugins // vimPlugins final prev;
    };
    overlay = mkLuaOverlay {
      packageOverrides = luaself: luaprev: {
        ${APPNAME} = luaself.callPackage (
          { buildLuarocksPackage, }: buildLuarocksPackage {
            pname = APPNAME;
            version = "scm-1";
            src = self;
          }
        ) {};
      };
      vimPlugins = final: prev: {
        ${APPNAME} = final.neovimUtils.buildNeovimPlugin { pname = APPNAME; };
      };
    };
    packages = forAllSys (system: let
      pkgs = getPkgs system [ overlay ];
    in (
      builtins.listToAttrs (
        map (n: {
          name = "she${n}";
          value = pkgs.lib.attrByPath [ n "pkgs" APPNAME ] null pkgs;
        }) l_pkg_enum
      )
    ) // {
      default = pkgs.vimPlugins.${APPNAME};
      "vimPlugins-${APPNAME}" = pkgs.vimPlugins.${APPNAME};
    });
    runLuaCommandOverlay = final: prev: { runLuaCommand = final.callPackage ./nix {}; };
  in {
    overlays.default = overlay;
    overlays.runLuaCommand = runLuaCommandOverlay;
    legacyPackages = forAllSys (system: { inherit (getPkgs system [ runLuaCommandOverlay ]) runLuaCommand; });
    inherit packages;
    checks = forAllSys (system: import ./tests/tests.nix (getPkgs system [ overlay runLuaCommandOverlay ]) l_pkg_enum);
    devShells = forAllSys (system: let
      pkgs = getPkgs system [];
      lua = pkgs.luajit.withPackages (lp: [ lp.inspect lp.luarocks ]);
    in {
      default = pkgs.mkShell {
        name = "${APPNAME}-dev";
        packages = [ lua ];
        LUA_INCDIR = "${lua}/include";
        LUA = lua.interpreter;
        BEAR = "${pkgs.bear}/bin/bear";
      };
    });
  };
}
