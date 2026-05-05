pkgs: let
  mkBuildTest = lua: let
    luapath = (lua.withPackages (ps: with ps; [ inspect shelua ])).interpreter;
  in pkgs.runCommand ("shelua_package_test-" + lua.luaAttr) {} ''
    echo 'package.path = package.path .. ";${./.}/?.lua"; require("test")' | ${luapath} - > "$out"
  '';
  mkCmdTest = lua:
    pkgs.runLuaCommand ("runLuaCommand_test-" + lua.luaAttr) (lua.withPackages (ps: with ps; [ inspect ])).interpreter {
      nativeBuildInputs = [ pkgs.makeWrapper ];
      passthru.info = {
        testdata = [ "some" "values" ];
        notincluded = system: builtins.trace system system;
      };
    } /*lua*/
    ''
      local inspect = require('inspect')
      local outbin = out .. "/bin"
      local outfile = outbin .. "/testpkg"
      local outdrv = outbin .. "/testdrv"
      local outcat = outbin .. "/newcat"
      local outecho = outbin .. "/newecho"
      sh.mkdir("-p", outbin)
      os.env.FRIEND = "everyone"
      assert(os.getenv("FRIEND") == os.env.FRIEND, "os.env failed")
      print(os.getenv("FRIEND"))
      os.write_file({}, outfile, [[#!${pkgs.bash}/bin/bash]])
      os.write_file({ append = true, }, outfile, [[echo "hello world!"]])
      os.write_file({ append = true, }, outfile, [[cat ]] .. outdrv)
      os.write_file({ append = true, }, outfile, outcat)
      os.write_file({}, outdrv, inspect(drv))
      sh.escape_args = true
      sh.makeWrapper([[${pkgs.writeShellScript "testscript" ''echo "$@"''}]], outecho, "--add-flags", "testingtesting '1 2' 3")
      sh.escape_args = false
      sh.makeWrapper([[${pkgs.coreutils}/bin/cat]], outcat, "--add-flags", outecho)
      sh.chmod("+x", outfile)
      package.path = package.path .. ";${./.}/?.lua"
      require("example")
      require("test")
    '';
  run_on = with pkgs; [ lua5_1 lua5_2 lua5_3 lua5_4 lua5_5 luajit ];
in pkgs.lib.pipe run_on [
  (map (li: { name = "runLuaCommand-" + li.luaAttr; value = mkCmdTest li; }))
  builtins.listToAttrs
] // (
  pkgs.lib.pipe run_on [
    (map (li: { name = "withPackages-" + li.luaAttr; value = mkBuildTest li; }))
    builtins.listToAttrs
  ]
)
