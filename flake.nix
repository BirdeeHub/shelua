{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };
  outputs = { nixpkgs, ... }: let
    forAllSys = nixpkgs.lib.genAttrs nixpkgs.lib.platforms.all;
    overlay = final: prev: {
      shelua = prev.callPackage ./. {
        lua_interpreter = prev.lua5_2;
      };
      runLuaCmd =  prev.callPackage ./runLuaCmd.nix {};
    };
  in {
    overlays.default = overlay;
    packages = forAllSys (system: let
      pkgs = import nixpkgs { inherit system; overlays = [ overlay ]; };
    in nixpkgs.lib.pipe (with pkgs; [ lua5_1 lua5_2 lua5_3 lua5_4 luajit ]) [
      (builtins.map (li: { name = "she" + li.luaAttr; value = pkgs.shelua.override { lua_interpreter = li; }; }))
      builtins.listToAttrs
    ] // {
      default = pkgs.shelua;
      inherit (pkgs) runLuaCmd;
    });
  };
}
