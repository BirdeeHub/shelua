{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    n2l.url = "github:BirdeeHub/nixToLua";
  };
  outputs = { nixpkgs, n2l, ... }: let
    forAllSys = nixpkgs.lib.genAttrs nixpkgs.lib.platforms.all;
    overlay = final: prev: {
      shelua = prev.callPackage ./. { lua_interpreter = prev.lua5_2; };
      runLuaCommand =  prev.callPackage ./runLuaCommand.nix { inherit n2l; };
    };
    overlay1 = final: prev: {
      shelua = prev.callPackage ./. { lua_interpreter = prev.lua5_2; };
    };
    overlay2 = final: prev: {
      runLuaCommand =  prev.callPackage ./runLuaCommand.nix { inherit n2l; };
    };
  in {
    overlays.default = overlay;
    overlays.shelua = overlay1;
    overlays.runLuaCommand = overlay2;
    packages = forAllSys (system: let
      pkgs = import nixpkgs { inherit system; overlays = [ overlay ]; };
    in nixpkgs.lib.pipe (with pkgs; [ lua5_1 lua5_2 lua5_3 lua5_4 luajit ]) [
      (builtins.map (li: { name = "she" + li.luaAttr; value = pkgs.shelua.override { lua_interpreter = li; }; }))
      builtins.listToAttrs
    ] // {
      default = pkgs.shelua;
      inherit (pkgs) runLuaCommand;
    });
    checks = forAllSys (system: let
      pkgs = import nixpkgs { inherit system; overlays = [ overlay ]; };
    in {
      default = pkgs.runLuaCommand "testpkg" (pkgs.lua5_2.withPackages (ps: with ps; [inspect])).interpreter {
        nativeBuildInputs = [ pkgs.makeWrapper ];
        passthru = {
          testdata = [ "some" "values" ];
          notincluded = system: builtins.trace system system;
        };
      } /*lua*/''
        local inspect = require('inspect')
        local outbin = out .. "/bin"
        local outfile = outbin .. "/testpkg"
        local outdrv = outbin .. "/testdrv"
        local outcat = outbin .. "/newcat"
        local outecho = outbin .. "/newecho"
        sh.mkdir("-p", outbin)
        os.write_file({}, outfile, [[#!${pkgs.bash}/bin/bash]])
        os.write_file({ append = true, }, outfile, [[echo "hello world!"]])
        os.write_file({ append = true, }, outfile, [[cat ]] .. outdrv)
        os.write_file({ append = true, }, outfile, outcat)
        os.write_file({}, outdrv, inspect(drv))
        getmetatable(sh).escape_args = true
        sh.makeWrapper([[${pkgs.writeShellScript "testscript" ''echo "$@"''}]], outecho, "--add-flags", "testingtesting '1 2' 3")
        getmetatable(sh).escape_args = false
        sh.makeWrapper([[${pkgs.coreutils}/bin/cat]], outcat, "--add-flags", outecho)
        sh.chmod("+x", outfile)
        dofile("${./example.lua}")
        package.path = package.path .. ";${./tests}/?.lua"
        require("test")
      '';
    });
  };
}
