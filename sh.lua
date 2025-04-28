local M = {}

local is_pre_5_2 = (function()
	local majorversion, minorversion = _VERSION:match("Lua (%d+).(%d+)")
	majorversion = tonumber(majorversion)
	if majorversion < 6 then
		if majorversion == 5 and tonumber(minorversion) < 2 then
			return true
		end
	end
	return false
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

local function escapeShellArg(arg)
  local string = tostring(arg)
  -- Match against the regular expression for valid shell arguments
  if string:match("^[%w,._+:@%%/-]+$") == nil then
    -- Escape single quotes by replacing with '\\''
    return string.format("'%s'", string:gsub("'", "'\\''"))
  else
    return string
  end
end

-- converts key and it's argument to "-k" or "-k=v" or just ""
local function arg(k, a)
	if type(a) == 'boolean' or not k then return k end
	if type(a) == 'string' and #a > 0 then return k .. "=" .. escapeShellArg(a) end
	if type(a) == 'number' then return k .. '=' .. tostring(a) end
	error("invalid argument type: '" .. type(a) .. "' of value: '" .. a .. "'")
end

-- converts nested tables into a flat list of arguments and concatenated input
local function flatten(input)
	local result = { args = {} }

	local function f(t)
		local keys = {}
		for k = 1, #t do
			keys[k] = true
			local v = t[k]
			if type(v) == 'table' then
				f(v)
			else
				table.insert(result.args, v)
			end
		end
		for k, v in pairs(t) do
			if k == '__input' then
				result.input = (result.input and result.input or "") .. v
			elseif not keys[k] and k:sub(1, 1) ~= '_' then
				local key = '-' .. k
				if #k > 1 then key = '-' .. key end
				table.insert(result.args, arg(key, v))
			end
		end
	end

	f(input)
	return result
end

-- returns a function that executes the command with given args and returns its
-- output, exit status etc
local function command(cmd, ...)
	local prearg = { ... }
	return function(...)
		local args = flatten({ ... })
		local s = cmd
		for _, v in ipairs(prearg) do
			s = s .. ' ' .. v
		end
		for _, v in pairs(args.args) do
			s = s .. ' ' .. v
		end
		local t
		if is_pre_5_2 then
			t = pre_5_2_sh(M.shelua_tmpfile, s, args.input)
		else
			t = post_5_2_sh(M.shelua_tmpfile, s, args.input)
		end
		local mt = {
			__index = function(self, k, ...)
				return M[k] --, ...
			end,
			__tostring = function(self)
				-- return trimmed command output as a string
				return self.__input:match('^%s*(.-)%s*$')
			end
		}
		return setmetatable(t, mt)
	end
end

-- export command() function and configurable temporary "input" file
M.shelua_tmpfile = '/tmp/sheluainput'

return setmetatable(M, {
	-- set hook for undefined variables
	__index = function(_, cmd)
		return command(cmd)
	end,
	-- allow to call sh to run shell commands
	__call = function(_, cmd, ...)
		return command(cmd, ...)
	end,
})
