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
      runCommandLua =  prev.callPackage ./runCommandLua.nix {};
    };
    overlay1 = final: prev: {
      shelua = prev.callPackage ./. {
        lua_interpreter = prev.lua5_2;
      };
    };
    overlay2 = final: prev: {
      runCommandLua =  prev.callPackage ./runCommandLua.nix {};
    };
  in {
    overlays.default = overlay;
    overlays.shelua = overlay1;
    overlays.runCommandLua = overlay2;
    packages = forAllSys (system: let
      pkgs = import nixpkgs { inherit system; overlays = [ overlay ]; };
    in nixpkgs.lib.pipe (with pkgs; [ lua5_1 lua5_2 lua5_3 lua5_4 luajit ]) [
      (builtins.map (li: { name = "she" + li.luaAttr; value = pkgs.shelua.override { lua_interpreter = li; }; }))
      builtins.listToAttrs
    ] // {
      default = pkgs.shelua;
      inherit (pkgs) runCommandLua;
    });
    checks = forAllSys (system: let
      pkgs = import nixpkgs { inherit system; overlays = [ overlay ]; };
    in {
      default = pkgs.runCommandLua "testpkg" pkgs.lua5_2.interpreter {} /*lua*/''
        local outbin = out .. "/bin"
        local outfile = outbin .. "/testpkg"
        sh.mkdir("-p", outbin)
        os.write_file({ newline = true, }, outfile, [[#!${pkgs.bash}/bin/bash]])
        os.write_file({ append = true, }, outfile, [[echo "hello world!"]])
        sh.chmod("+x", outfile)
      '';
    });
  };
}
