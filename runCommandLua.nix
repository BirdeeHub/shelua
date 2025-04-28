{ lib, runCommand, n2l, ... }: name: interpreter: env: text: let
  luaentrypoint = /*lua*/ ''
    _G.sh = require("sh")
    function os.write_file(opts, filename, content)
      local file = assert(io.open(filename, opts.append and "a" or "w"))
      file:write(content .. (opts.newline ~= false and "\n" or ""))
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
    local shell = os.getenv("SHELL")
    local oldpopen = io.popen
    local oldexec = os.execute
    io.popen = function(cmd, ...)
      local tempexec = temp .. "/popen-" .. math.random(0, 100)
      os.write_file({}, tempexec, "source " .. temp .. "/shell_hooks.sh\n" .. cmd)
      return oldpopen(shell .. " " .. tempexec, ...)
    end
    os.execute = function(cmd, ...)
      local tempexec = temp .. "/exec-" .. math.random(0, 100)
      os.write_file({}, tempexec, "source " .. temp .. "/shell_hooks.sh\n" .. cmd)
      return oldexec(shell .. " " .. tempexec, ...)
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
    sh.rm("-rf", temp)
  '';
  initlua = builtins.concatStringsSep ";" [
    ''_G.out = "${placeholder "out"}"''
    ''package.preload.sh = function() return dofile("${./sh.lua}") end''
    ''local ok, err = pcall(dofile, "${builtins.toFile "luastdenv" luaentrypoint}")''
    ''assert(ok, err)''
  ];
  fenv = (if lib.isFunction env then env n2l else env);
in runCommand name (fenv // {
  passAsFile = [ "luaBuilder" ] ++ fenv.passAsFile or [];
  luaBuilder = "package.preload.drv = function() return ${n2l.toLua fenv} end; _G.drv = require([[drv]]);" + (if lib.isFunction text then text n2l else text);
}) ''
  TEMPDIR=$(mktemp -d)
  mkdir -p "$TEMPDIR"
  declare -f > "$TEMPDIR/shell_hooks.sh"
  echo "_G.temp = '$TEMPDIR';" '${initlua}' | exec ${interpreter} -
''
