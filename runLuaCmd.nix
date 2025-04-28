{ runCommandNoCC, ... }: name: lua: env: text: let
  luaentrypoint = builtins.toFile "luastdenv" /*lua*/ ''
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
        local file = io.open(filename, "r")  -- Try to open the file in read mode
        if file then
            file:close()  -- Close the file if it exists
            return true
        else
            return false
        end
    end
    local builder = os.getenv("luaBuilderPath")
    if os.readable(builder) then
      ok, err = pcall(dofile, builder)
      assert(ok, err)
    else
      ok, err = pcall(loadstring, os.getenv("luaBuilder"))
      assert(ok, err)
    end
  '';
  initlua = builtins.concatStringsSep ";" [
    ''package.preload.sh = function() return dofile("${./sh.lua}") end''
    ''local ok, err = pcall(dofile, "${luaentrypoint}")''
    ''assert(ok, err)''
  ];
in (runCommandNoCC name env ''echo "_G.out = [[$out]];" '${initlua}' | exec ${lua.interpreter} -'').overrideAttrs {
  passAsFile = [ "luaBuilder" ];
  luaBuilder = text;
}
