-- lua `stdenv` for runLuaCommand
return function(outdir, tempdir, shell_hooks)
  _G.out = outdir
  _G.temp = tempdir
  os.env = require("env")
  _G.sh = require("sh")
  local sh_settings = getmetatable(sh)
  string.escapeShellArg = sh_settings.repr.posix.escape
  sh_settings.assert_zero = true
  sh_settings.stdenv_shell_hooks_path = shell_hooks
  local shell = os.env.SHELL
  local function with_shell_hooks(cmd)
    return string.format(
      "%s -c %s",
      string.escapeShellArg(shell),
      string.escapeShellArg(". " .. shell_hooks .. "\n" .. cmd)
    )
  end
  sh_settings.repr.posix.transforms = { with_shell_hooks }
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
    if type(filename) == "string" then
      local file = io.open(filename, "r")  -- Try to open the file in read mode
      if file then
        file:close()  -- Close the file if it exists
        return true
      end
    end
    return false
  end
  local ok, err = pcall(dofile, os.env.luaBuilderDataPath)
  if not ok then
    ok, err = pcall((loadstring or load), os.env.luaBuilderData)
    if ok and err then
      ok, err = pcall(err)
    end
  end
  if ok then
    _G.drv = err
    package.preload.drv = function() return _G.drv end
    local bp = os.env.luaBuilderPath
    if bp then
      ok, err = pcall(dofile, bp)
    else
      ok, err = pcall((loadstring or load), os.env.luaBuilder)
      if ok and err then
        ok, err = pcall(err)
      end
    end
    sh.rm("-rf", temp)
    sh_settings.repr.posix.transforms = {}
    os.remove(shell_hooks)
    assert(ok, tostring(err))
  else
    sh.rm("-rf", temp)
    sh_settings.repr.posix.transforms = {}
    os.remove(shell_hooks)
    error(tostring(err))
  end
end
