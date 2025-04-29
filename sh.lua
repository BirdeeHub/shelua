local is_5_2_plus = (function()
	local major, minor = _VERSION:match("Lua (%d+)%.(%d+)")
	major, minor = tonumber(major), tonumber(minor)
	return major > 5 or (major == 5 and minor >= 2)
end)()

local function pre_5_2_sh(tmp, cmd, input)
	if input then
		local f = io.open(tmp, 'w')
		if f then
			f:write(input)
			f:close()
			cmd = cmd .. ' <' .. tmp
		end
	end
	local p = io.popen(cmd .. "; echo __EXITCODE__$?;", 'r')
	local output
	if p then
		output = p:read('*a')
		p:close()
	end
	os.remove(tmp)
	local exit
	output = (output or ""):gsub("__EXITCODE__(%d*)\n?$", function(code)
		exit = tonumber(code)
		return ""
	end)
	return {
		__input = output,
		__exitcode = exit or 127,
		__signal = (exit and exit > 128) and (exit - 128) or 0
	}
end

local function post_5_2_sh(tmp, cmd, input)
	if input then
		local f = io.open(tmp, 'w')
		if f then
			f:write(input)
			f:close()
			cmd = cmd .. ' <' .. tmp
		end
	end
	local p = io.popen(cmd, 'r')
	local output, exit, status
	if p then
		output = p:read('*a')
		_, exit, status = p:close()
	end
	os.remove(tmp)

	return {
		__input = output,
		__exitcode = exit == 'exit' and status or 127,
		__signal = exit == 'signal' and status or 0,
	}
end

-- nixpkgs.lib.escapeShellArg in lua
local function escapeShellArg(arg)
	local str = tostring(arg)
	if str:match("^[%w,._+:@%%/-]+$") == nil then
		return str.format("'%s'", str:gsub("'", "'\\''"))
	else
		return str
	end
end

-- converts key and it's argument to "-k" or "-k=v" or just ""
local function arg(k, a)
	if type(a) == 'boolean' and a then return k end
	if type(a) == 'string' and #a >= 0 then return k .. "=" .. escapeShellArg(a) end
	if type(a) == 'number' then return k .. '=' .. tostring(a) end
	return nil
end

-- converts nested tables into a flat list of arguments and concatenated input
local function flatten(input, opts)
	local result = { args = {} }
	local esc = opts.escape_args

	local function f(t)
		local keys = {}
		for k = 1, #t do
			keys[k] = true
			local v = t[k]
			if type(v) == 'table' then
				f(v)
			else
				table.insert(result.args, esc and escapeShellArg(v) or v)
			end
		end
		for k, v in pairs(t) do
			if k == '__input' then
				result.input = (result.input or "") .. v
			elseif not keys[k] and k:sub(1, 2) ~= '__' then
				local key = '-' .. k
				if #k > 1 then key = '-' .. key end
				key = arg(key, v)
				if key then
					table.insert(result.args, key)
				end
			end
		end
	end

	f(input)
	return result
end

-- returns a function that executes the command with given args and returns its
-- output, exit status etc
local function command(self, cmdstr, ...)
	local preargs = flatten({ ... }, getmetatable(self))
	return function(...)
		local shmt = getmetatable(self)
		local args = flatten({ ... }, shmt)
		local cmd = cmdstr
		for _, v in ipairs(preargs.args) do
			cmd = cmd .. ' ' .. v
		end
		for _, v in ipairs(args.args) do
			cmd = cmd .. ' ' .. v
		end
		local t
		local input = (preargs.input or args.input) and (preargs.input or '') .. (args.input or '') or nil
		if is_5_2_plus then
			t = post_5_2_sh(shmt.tempfile_path, cmd, input)
		else
			t = pre_5_2_sh(shmt.tempfile_path, cmd, input)
		end
		if shmt.assert_zero and t.__exitcode ~= 0 then
			error("Command " .. tostring(cmd) .. " exited with non-zero status: " .. tostring(t.__exitcode))
		end
		local mt = {
			tempfile_path = shmt.tempfile_path,
			escape_args = shmt.escape_args,
			assert_zero = shmt.assert_zero,
			__index = function(s, c)
				return command(s, c)
			end,
			__tostring = function(s)
				-- return trimmed command output as a string
				return s.__input:match('^%s*(.-)%s*$')
			end
		}
		return setmetatable(t, mt)
	end
end

local MT = {
	-- temporary "input" file
	tempfile_path = '/tmp/sheluainput',
	-- escape unnamed shell arguments
	-- NOTE: k = v table keys are still not escaped, k = v table values always are
	escape_args = false,
	-- Assert that exit code is 0 or throw and error
	assert_zero = false,
	-- set hook for undefined variables
	__index = function(self, cmd)
		return command(self, cmd)
	end,
	-- allow to call sh to run shell commands
	__call = function(self, cmd, ...)
		return command(self, cmd, ...)
	end,
}
local function deepcopy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for k, v in next, orig, nil do
      copy[deepcopy(k)] = deepcopy(v)
    end
    setmetatable(copy, deepcopy(getmetatable(orig)))
  else
    copy = orig
  end
  return copy
end
MT.__unm = function(self)
	return setmetatable({}, deepcopy(getmetatable(self)))
end
return setmetatable({}, MT)
