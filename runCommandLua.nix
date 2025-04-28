{ runCommand, ... }: name: interpreter: env: text: let
  luaentrypoint = /*lua*/ ''
    _G.sh = require("sh")
    function os.write_file(opts, filename, content)
      local file = assert(io.open(filename, opts.append and "a" or "w"))
      file:write(content .. (opts.newline and "\n" or ""))
      file:close()
    end
    function os.read_file(filename)
      local file = assert(io.open(filename, "r"))
      local content = file:read("*a")
      file:close()
      return content
    end
    function os.readable(filename)
      if filename then
        local file = io.open(filename, "r")  -- Try to open the file in read mode
        if file then
          file:close()  -- Close the file if it exists
          return true
        end
      end
      return false
    end
    local builder = os.getenv("luaBuilderPath")
    if os.readable(builder) then
      local ok, err = pcall(dofile, builder)
      assert(ok, err)
    else
      local ok, ret = pcall((loadstring or load), os.getenv("luaBuilder"))
      if ok and ret then
        ok, ret = pcall(ret)
        assert(ok, ret)
      end
    end
  '';
  initlua = builtins.concatStringsSep ";" [
    ''package.preload.sh = function() return dofile("${./sh.lua}") end''
    ''local ok, err = pcall(dofile, "${builtins.toFile "luastdenv" luaentrypoint}")''
    ''assert(ok, err)''
  ];
in runCommand name (env // {
  passAsFile = [ "luaBuilder" ] ++ env.passAsFile or [];
  luaBuilder = text;
}) ''echo "_G.out = [[$out]];" '${initlua}' | exec ${interpreter} -''
