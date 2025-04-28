return function(tempdir)
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
  function string.escapeShellArg(arg)
    local string = tostring(arg)
    if string:match("^[%w,._+:@%%/-]+$") == nil then
      return string.format("'%s'", string:gsub("'", "'\\''"))
    else
      return string
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
  local builder = os.getenv("luaBuilderPath")
  if os.readable(builder) then
    local ok, err = pcall(dofile, builder)
    sh.rm("-rf", temp)
    sh.rm("-rf", tempdir)
    assert(ok, err)
  else
    local ok, ret = pcall((loadstring or load), os.getenv("luaBuilder"))
    if ok and ret then
      ok, ret = pcall(ret)
      sh.rm("-rf", temp)
      sh.rm("-rf", tempdir)
      assert(ok, ret)
    end
  end
end
