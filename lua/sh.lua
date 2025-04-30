local is_5_2_plus = (function()
	local major, minor = _VERSION:match("Lua (%d+)%.(%d+)")
	major, minor = tonumber(major), tonumber(minor)
	return major > 5 or (major == 5 and minor >= 2)
end)()

local function deepcopy(orig, seen)
	seen = seen or {}
	-- memoize to prevent cycles
	if seen[orig] then
		return seen[orig]
	end
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		seen[orig] = copy
		for k, v in next, orig, nil do
			copy[deepcopy(k, seen)] = deepcopy(v, seen)
		end
	else
		copy = orig
	end
	-- Always try to copy metatable (if present)
	local mt = getmetatable(orig)
	if mt then
		pcall(setmetatable, copy, deepcopy(mt, seen))
	end
	return copy
end

local function simple_stdin(tmp, cmd, input)
	if input then
		local f = io.open(tmp, 'w')
		if f then
			f:write(input)
			f:close()
			cmd = cmd .. ' <' .. tmp
		end
	end
	return cmd
end

local function post_5_2_sh(cmd, tmp)
	local p = io.popen(cmd, 'r')
	local output, exit, status
	if p then
		output = p:read('*a')
		_, exit, status = p:close()
	end
	pcall(os.remove, tmp)

	return {
		__input = output,
		__exitcode = exit == 'exit' and status or 127,
		__signal = exit == 'signal' and status or 0,
	}
end

local function pre_5_2_sh(cmd, tmp)
	local p = io.popen(cmd .. "\necho __EXITCODE__$?", 'r')
	local output
	if p then
		output = p:read('*a')
		p:close()
	end
	pcall(os.remove, tmp)
	local exit
	output = (output or ""):gsub("__EXITCODE__(%d*)\r?\n?$", function(code)
		exit = tonumber(code)
		return ""
	end)
	return {
		__input = output,
		__exitcode = exit or 127,
		__signal = (exit and exit > 128) and (exit - 128) or 0
	}
end

-- nixpkgs.lib.escapeShellArg in lua
function string.escapeShellArg(arg)
	local str = tostring(arg)
	if str:match("^[%w,._+:@%%/-]+$") == nil then
		return string.format("'%s'", str:gsub("'", "'\\''"))
	else
		return str
	end
end

-- converts key and it's argument to "-k" or "-k=v" or just ""
local function arg(k, a)
	k = (#k > 1 and '--' or '-') .. k
	if type(a) == 'boolean' and a then return k end
	if type(a) == 'string' then return k .. "=" .. string.escapeShellArg(a) end
	if type(a) == 'number' then return k .. '=' .. tostring(a) end
	return nil
end

local unresolved = {} -- store unresolved results here, with unresolved result table as key

-- get associated { cmd, inputs } from unresolved table.
-- recursively resolve inputs list, which can contain strings, or other tables to call resolve on
-- should return final command string
local function resolve(tores, opts)
	local val = unresolved[tores]
	if not val then
		error("Can't resolve result table, due to an input command being part of another already resolved pipe")
	end
	unresolved[tores] = nil
	local input = {}
	for _, v in ipairs(val.input or {}) do
		if type(v) == "string" then
			table.insert(input, "echo " .. string.escapeShellArg(v))
		elseif type(v) == "table" then
			table.insert(input, resolve(v, opts))
		end
	end
	if #input == 0 then
		return val.cmd
	elseif #input == 1 then
		return input[1] .. " | " .. val.cmd
	elseif #input > 1 then
		return "{ " .. table.concat(input, " ; ") .. " ; } | " .. val.cmd
	end
end

-- converts nested tables into a flat list of arguments and concatenated input
local function flatten(input, opts)
	local result = { args = {}, input = {} }

	local function f(t)
		local keys = {}
		for k = 1, #t do
			keys[k] = true
			local v = t[k]
			if type(v) == 'table' then
				if unresolved[v] then
					if opts.proper_pipes then
						table.insert(result.input, v)
					else -- resolve it if not proper_pipes
						local _ = v.__input
						f(v)
					end
				else
					f(v)
				end
			else
				table.insert(result.args, opts.escape_args and string.escapeShellArg(v) or v)
			end
		end
		for k, v in pairs(t) do
			if k == '__input' then
				table.insert(result.input, v)
			elseif not keys[k] and k:sub(1, 2) ~= '__' then
				local key = arg(k, v)
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
		local cmd = type(cmdstr) == "string" and cmdstr or error("Shell commands must be strings!")
		for _, v in ipairs(preargs.args) do
			cmd = cmd .. ' ' .. v
		end
		for _, v in ipairs(args.args) do
			cmd = cmd .. ' ' .. v
		end
		local apply = function(c)
			local res = c
			for _, f in ipairs(shmt.transforms or {}) do
				res = f(res)
			end
			return res
		end
		local input
		if shmt.proper_pipes then
			input = {}
			for _, v in ipairs(preargs.input or {}) do
				table.insert(input, v)
			end
			for _, v in ipairs(args.input or {}) do
				table.insert(input, v)
			end
		else
			input = (preargs.input or args.input) and table.concat(preargs.input or {}) .. table.concat(args.input or {}) or nil
		end
		local t = {}
		if shmt.proper_pipes then
			unresolved[t] = { cmd = cmd, input = input }
		elseif is_5_2_plus then
			local tmp = os.tmpname()
			t = post_5_2_sh(apply(simple_stdin(tmp, cmd, input)), tmp)
		else
			local tmp = os.tmpname()
			t = pre_5_2_sh(apply(simple_stdin(tmp, cmd, input)), tmp)
		end
		if not shmt.proper_pipes and shmt.assert_zero and t.__exitcode ~= 0 then
			error("Command " .. tostring(cmd) .. " exited with non-zero status: " .. tostring(t.__exitcode))
		end
		local mt = {
			__metatable = shmt,
			__index = function(s, c)
				if not shmt.proper_pipes then
					return command(s, c)
				end
				if c == "__input" or c == "__exitcode" or c == "__signal" then
					cmd = resolve(t, shmt)
					local res
					if is_5_2_plus then
						res = post_5_2_sh(apply(cmd))
					else
						res = pre_5_2_sh(apply(cmd))
					end
					for k, v in pairs(res or {}) do
						rawset(t, k, v)
					end
					if shmt.assert_zero and rawget(t, "__exitcode") ~= 0 then
						error("Command " .. tostring(cmd) .. " exited with non-zero status: " .. rawget(t, "__exitcode"))
					end
					return rawget(t, c)
				else
					return command(s, c)
				end
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
	__metatable = {
		-- escape unnamed shell arguments
		-- NOTE: k = v table keys are still not escaped, k = v table values always are
		escape_args = false,
		-- Assert that exit code is 0 or throw and error
		assert_zero = false,
		-- proper pipes at the cost of access to mid pipe values after further calls have been chained from it.
		proper_pipes = false,
		-- a list of functions to run in order on the command before running it.
		-- each one recieves the final command and is to return a string representing the new one
		transforms = {},
	},
	-- set hook for index as shell command
	__index = function(self, cmd)
		return command(self, cmd)
	end,
	-- change settings by assigning them to table
	__newindex = function(self, k, v)
		getmetatable(self)[k] = v
	end,
}
-- allow to call sh with a string to run shell commands
-- or no arguments to return clone
-- or first arg as table to tbl_extend settings then clone
-- or first arg as function that recieves old settings to set new settings and clone
MT.__call = function(self, cmd, ...)
	if cmd == nil then
		local newMT = deepcopy(MT)
		newMT.__metatable = deepcopy(getmetatable(self))
		return setmetatable({}, newMT)
	elseif type(cmd) == 'table' then
		local newMT = deepcopy(MT)
		local config = deepcopy(getmetatable(self))
		for k, v in pairs(cmd) do
			config[k] = v
		end
		newMT.__metatable = config
		return setmetatable({}, newMT)
	elseif type(cmd) == 'function' then
		local newMT = deepcopy(MT)
		newMT.__metatable = cmd(deepcopy(getmetatable(self)))
		return setmetatable({}, newMT)
	else
		return command(self, cmd, ...)
	end
end
return setmetatable({}, MT)
