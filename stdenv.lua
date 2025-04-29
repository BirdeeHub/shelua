return function(tempdir)
  _G.sh = require("sh")
  local sh_settings = getmetatable(_G.sh)
  sh_settings.assert_zero = true
  sh_settings.tempfile_path = tempdir .. "/sheluainput"
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
  function string.escapeShellArg(arg)
    local str = tostring(arg)
    if str:match("^[%w,._+:@%%/-]+$") == nil then
      return str.format("'%s'", str:gsub("'", "'\\''"))
    else
      return str
    end
  end
  local shell = os.getenv("SHELL")
  local oldpopen = io.popen
  local oldexec = os.execute
  io.popen = function(cmd, ...)
    local tempexec = tempdir .. "/popen-" .. math.random(0, 100)
    os.write_file({}, tempexec, "source " .. tempdir .. "/shell_hooks.sh\n" .. cmd)
    return oldpopen(shell .. " " .. tempexec, ...)
  end
  os.execute = function(cmd, ...)
    local tempexec = tempdir .. "/exec-" .. math.random(0, 100)
    os.write_file({}, tempexec, "source " .. tempdir .. "/shell_hooks.sh\n" .. cmd)
    return oldexec(shell .. " " .. tempexec, ...)
  end
  local ok, err = pcall(dofile, os.getenv("luaBuilderDataPath"))
  if not ok then
    ok, err = pcall((loadstring or load), os.getenv("luaBuilderData"))
    if ok and err then
      ok, err = pcall(err)
    end
  end
  if ok then
    _G.drv = err
    package.preload.drv = function() return _G.drv end
    ok, err = pcall(dofile, os.getenv("luaBuilderPath"))
    if not ok then
      ok, err = pcall((loadstring or load), os.getenv("luaBuilder"))
      if ok and err then
        ok, err = pcall(err)
      end
    end
    io.popen = oldpopen
    os.execute = oldexec
    sh.rm("-rf", temp)
    sh.rm("-rf", tempdir)
    assert(ok, tostring(err))
  else
    io.popen = oldpopen
    os.execute = oldexec
    sh.rm("-rf", temp)
    sh.rm("-rf", tempdir)
    error(tostring(err))
  end
end
