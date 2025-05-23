---Will contain either `s`, a plain string,
---or `c`, an input command string
---@class Shelua.PipeInput
---string stdin to combine
---@field s? string|any
---if string input came from a command,
---`e` will contain a table of all other command result fields
---such as `__exitcode`
---@field e? table
---cmd to combine
---@field c? string|any
---optional 2nd return of concat_cmd
---@field m? any

---@class Shelua.Repr
---escapes a string for the shell
---@field escape fun(arg: any, opts: Shelua.Opts?): string
---turns table form args from table keys and values into flags
---if returning a list, items will be added to args list in order
---@field arg_tbl fun(opts: Shelua.Opts, k: string, a: any): string|string[]?
---adds args to the command
---@field add_args fun(opts: Shelua.Opts, cmd: string, args: string[]): string|any
---returns cmd and an optional item such as path to a tempfile to be passed to post_5_2_run or pre_5_2_run
---called when proper_pipes is false
---cmd is the result of add_args
---codes is the list of codes that correspond with each input such as `__exitcode`, empty if none
---@field single_stdin fun(opts: Shelua.Opts, cmd: string|any, inputs: string[]?, codes: table[]?): (string|any, any?)
---strategy to combine piped inputs, 0, 1, or many, return resolved command to run
---called when proper_pipes is true
---@field concat_cmd fun(opts: Shelua.Opts, cmd: string|any, input: Shelua.PipeInput[]): (string|any, any?)
---a list of functions to run in order on the command before running it.
---each one recieves the previous value and returns a new one.
---they are ran after concat_cmd or single_stdin and before the post_5_2_run and pre_5_2_run functions
---@field transforms? (fun(cmd: string|any): string|any)[]
---runs the command and returns the result and exit code and signal
---@field post_5_2_run fun(opts: Shelua.Opts, cmd: string|any, msg: any?): { __input: string, __exitcode: number, __signal: number }
---runs the command and returns the result and exit code and signal
---@field pre_5_2_run fun(opts: Shelua.Opts, cmd: string|any, msg: any?): { __input: string, __exitcode: number, __signal: number }
---if your pre_5_2_run or post_5_2_run returns a table with extra keys, e.g. `__stderr`
---proper_pipes will need to know that accessing them should be a trigger to resolve the pipe.
---each string in this table must begin with '__' or it will be ignored
---@field extra_cmd_results string[]|fun(opts: Shelua.Opts): string[]

---@class Shelua.OptsClass
---proper pipes at the cost of access to mid pipe values after further calls have been chained from it.
---@field proper_pipes? boolean
---Assert that exit code is 0 or throw and error
---@field assert_zero? boolean
-- also escape unnamed shell arguments
---@field escape_args? boolean
---name of the repr implementation to choose
---@field shell? string
---@field repr? table<string, Shelua.Repr>
---WARNING: DANGER YOU CAN BREAK A SHELUA INSTANCE THIS WAY
---contains the metatable of this shelua instance
---@field meta_main? metatable
---applied to each new command result's metatable
---@field meta? metatable

---@alias Shelua.Opts Shelua.OptsClass | table

---@class Shelua.BuiltinResults
---@field __input string|any
---@field __exitcode number
---@field __signal number

---@alias Shelua.IdxCmd fun(...: string|Shelua.BuiltinResults|table):Shelua.Result

---@alias Shelua.Result Shelua.BuiltinResults | table<string, Shelua.IdxCmd>

---@alias Shelua.Copier fun(opts: nil|Shelua.Opts|(fun(opts: Shelua.Opts):Shelua.Opts)):Shelua

---@alias Shelua.Shell table<string, Shelua.IdxCmd> | fun(cmd: string, ...: string|Shelua.BuiltinResults|table):Shelua.IdxCmd

---@alias Shelua Shelua.Shell | Shelua.Copier | Shelua.Opts

local is_5_2_plus = (function()
	local major, minor = _VERSION:match("Lua (%d+)%.(%d+)")
	major, minor = tonumber(major), tonumber(minor)
	return major > 5 or (major == 5 and minor >= 2)
end)()

---@param orig any
---@param seen? table
---@return any
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

local function recUpdate(t, ...)
	for _, src in ipairs({...}) do
		for k, v in pairs(src) do
			if type(v) == "table" and type(t[k]) == "table" then
				recUpdate(t[k], v)
			else
				t[k] = v
			end
		end
	end
	return t
end

---@param t table
---@param default any
---@vararg any
---@return any
local function tbl_get(t, default, ...)
	if #{ ... } == 0 then return default end
	for _, key in ipairs({ ... }) do
		if type(t) ~= "table" then return default end
		t = t[key]
	end
	return t or default
end

---@param opts Shelua.Opts
---@param attr string
---@return function
local get_repr_fn = function(opts, attr)
	return tbl_get(opts, tbl_get(opts, function()
		error("Shelua Repr Error: " ..
			tostring(attr) .. " function required for shell: " .. tostring(opts.shell or "posix"))
	end, "repr", "posix", attr), "repr", opts.shell or "posix", attr)
end

local function cmd_result_names(opts)
	local names = { "__input", "__exitcode", "__signal" }
	local xtra = tbl_get(opts, {}, "repr", opts.shell or "posix", "extra_cmd_results")
	for _, v in ipairs(type(xtra) == "function" and xtra(opts) or xtra) do
		if type(v) == "string" and v:sub(1, 2) == '__' then
			table.insert(names, v)
		end
	end
	return names
end

local function check_if_cmd_result(opts, k)
	for _, v in ipairs(cmd_result_names(opts)) do
		if k == v then return true end
	end
	return false
end

---@type Shelua.Repr
local posix = {
	-- nixpkgs.lib.escapeShellArg in lua
	escape = function(arg, opts)
		local str = tostring(arg)
		if str:match("^[%w,._+:@%%/-]+$") == nil then
			return string.format("'%s'", str:gsub("'", "'\\''"))
		else
			return str
		end
	end,
	add_args = function(opts, cmd, args)
		return cmd .. " " .. table.concat(args, " ")
	end,
	-- converts key and it's argument to "-k" or "-k=v" or just ""
	arg_tbl = function(opts, k, a)
		k = (#k > 1 and '--' or '-') .. k
		if type(a) == 'boolean' and a then return k end
		if type(a) == 'string' then
			return k .. "=" .. get_repr_fn(opts, "escape")(a, opts)
		end
		if type(a) == 'number' then return k .. '=' .. tostring(a) end
		return nil
	end,
	single_stdin = function(opts, cmd, inputs, codes)
		local tmp
		if inputs then
			tmp = os.tmpname()
			local f = io.open(tmp, 'w')
			if f then
				f:write(table.concat(inputs))
				f:close()
				cmd = cmd .. ' <' .. tmp
			end
		end
		return cmd, tmp
	end,
	concat_cmd = function(opts, cmd, input)
		if #input == 1 then
			local v = input[1]
			if v.s then
				return 'printf "%s" ' .. get_repr_fn(opts, "escape")(v.s, opts) .. " | " .. cmd
			else
				return v.c .. " | " .. cmd
			end
		elseif #input > 1 then
			for i = 1, #input do
				local v = input[i]
				if v.s then
					input[i] = 'printf "%s" ' .. get_repr_fn(opts, "escape")(v.s, opts)
				elseif v.c then
					---@diagnostic disable-next-line: assign-type-mismatch
					input[i] = v.c
				end
			end
			return "{ " .. table.concat(input, " ; ") .. " ; } | " .. cmd
		else
			return cmd
		end
	end,
	post_5_2_run = function(opts, cmd, tmp)
		local p = io.popen(cmd, 'r')
		local output, _, exit, status
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
	end,
	pre_5_2_run = function(opts, cmd, tmp)
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
	end,
	extra_cmd_results = {},
	transforms = {},
}

local unresolved = {} -- store unresolved results here, with unresolved result table as key

-- converts nested tables into a flat list of arguments and concatenated input
---@param input table
---@param opts Shelua.Opts
local function flatten(input, opts)
	local result = { args = {}, res = {}, unres = {}, codes = {} }

	local function f(t)
		local keys = {}
		for k = 1, #t do
			keys[k] = true
			local v = t[k]
			if type(v) == 'table' then
				if unresolved[v] and opts.proper_pipes then
					table.insert(result.unres, v)
					table.insert(result.codes, false)
					table.insert(result.res, false)
				else
					f(v)
				end
			else
				table.insert(result.args, opts.escape_args and get_repr_fn(opts, "escape")(v, opts) or v)
			end
		end
		local codes = {}
		local to_add = false
		local _ = t.__input
		for _, k in ipairs(cmd_result_names(opts)) do
			local v = rawget(t, k)
			keys[k] = true
			if v ~= nil then
				if k == '__input' then
					table.insert(result.res, v)
					if opts.proper_pipes then
						table.insert(result.unres, false)
					end
					to_add = true
				else
					codes[k] = v
				end
			end
		end
		if to_add then
			table.insert(result.codes, codes)
		end
		for k, v in pairs(t) do
			if not keys[k] and k:sub(1, 2) ~= '__' then
				local key = get_repr_fn(opts, "arg_tbl")(opts, k, v)
				if type(key) == "table" then
					for _, val in ipairs(key) do
						table.insert(result.args, val)
					end
				elseif key then
					table.insert(result.args, key)
				end
			end
		end
	end

	f(input)
	return result
end

-- get associated { cmd, inputs } from unresolved table.
-- recursively resolve inputs list, which can contain strings, or other tables to call resolve on
-- should return final command string
---@param tores table
---@param opts Shelua.Opts
local function resolve(tores, opts)
	local val = unresolved[tores]
	unresolved[tores] = nil
	if not val then
		error(
		"Shelua Pipe Resolution Error: Can't resolve result table, due to an input command being part of another already resolved pipe")
	end
	local input = {}
	for k, v in ipairs(val.input or {}) do
		if val.unres[k] then
			local ok, c, m = pcall(resolve, val.unres[k], opts)
			if not ok then
				error("Shelua Pipe Resolution Error: command " ..
					tostring(val.cmd) .. " failed with message:\n" .. tostring(c))
			end
			table.insert(input, { c = c, m = m })
		else
			table.insert(input, { s = v, e = val.codes[k] })
		end
	end
	return get_repr_fn(opts, "concat_cmd")(opts, val.cmd, input)
end

local command

local cmd_mt = {
	__index = function(self, c)
		local opts = getmetatable(self)
		if not opts.proper_pipes then
			return command(self, c)
		end
		if check_if_cmd_result(opts, c) then
			local apply = function(com)
				local transforms = opts.transforms
				if transforms then print("Shelua Deprecation: transforms option moved to be a repr-specific option") end
				transforms = tbl_get(opts, transforms or {}, "repr", opts.shell or "posix", "transforms")
				for _, f in ipairs(transforms) do
					com = f(com)
				end
				return com
			end
			local cmd, msg = resolve(self, opts)
			local res
			if is_5_2_plus then
				res = get_repr_fn(opts, "post_5_2_run")(opts, apply(cmd), msg)
			else
				res = get_repr_fn(opts, "pre_5_2_run")(opts, apply(cmd), msg)
			end
			for k, v in pairs(res or {}) do
				rawset(self, k, v)
			end
			if opts.assert_zero and rawget(self, "__exitcode") ~= 0 then
				error("Command " ..
					tostring(cmd) ..
					" exited with non-zero status: " .. tostring(rawget(self, "__exitcode")))
			end
			return rawget(self, c)
		else
			return command(self, c)
		end
	end,
	__tostring = function(self)
		-- return trimmed command output as a string
		return self.__input:match('^%s*(.-)%s*$')
	end,
	__concat = function(a, b)
		return tostring(a) .. tostring(b)
	end,
}

local MT = {
	---@type Shelua.Opts
	__metatable = {
		-- escape unnamed shell arguments
		-- NOTE: k = v table keys are still not escaped, k = v table values always are
		escape_args = false,
		-- Assert that exit code is 0 or throw an error
		assert_zero = false,
		-- proper pipes at the cost of access to mid pipe values after further calls have been chained from it.
		proper_pipes = false,
		shell = "posix",
		repr = { posix = posix },
		meta = {},
		meta_main = {}
	},
	-- set hook for index as shell command
	__index = function(self, cmd)
		return command(self, cmd)
	end,
	-- change settings by assigning them to table
	__newindex = function(self, key, value)
		if type(key) == "string" and key:sub(1, 3) == "_x_" then
			local fkey = key:sub(4)
			local opts = getmetatable(self)
			if type(rawget(opts, fkey)) ~= "table" then
				opts[fkey] = value
			else
				recUpdate(opts[fkey], value)
			end
		else
			getmetatable(self)[key] = value
		end
	end,
}

local function make_meta(opts, main)
	local meta = main and deepcopy(MT) or deepcopy(cmd_mt)
	if opts then
		meta.__metatable = opts
	end
	local new = main and ((meta.__metatable or {}).meta_main or {}) or ((meta.__metatable or {}).meta or {})
	for key, value in pairs(new) do
		if key ~= "__metatable" and not meta[key] then
			meta[key] = value
		end
	end
	if main then
		(meta.__metatable or {}).meta_main = meta
	end
	return meta
end

-- returns a function that executes the command with given args and returns its
-- output, exit status etc
---@param self any
---@param cmdstr any
---@vararg any
---@return function
command = function(self, cmdstr, ...)
	local preargs = flatten({ ... }, getmetatable(self))
	return function(...)
		local shmt = getmetatable(self)
		local args = flatten({ ... }, shmt)
		local cmd = type(cmdstr) == "string" and cmdstr or
			error("Shelua Syntax Error: Shell commands (first argument or table index) must be strings!")
		local fargs = {}
		for _, v in ipairs(preargs.args) do
			table.insert(fargs, v)
		end
		for _, v in ipairs(args.args) do
			table.insert(fargs, v)
		end
		cmd = get_repr_fn(shmt, "add_args")(shmt, cmd, fargs)
		local input = {}
		local unres = {}
		local codes = {}
		for k, v in ipairs(preargs.res) do
			table.insert(input, v)
			table.insert(codes, preargs.codes[k])
			if shmt.proper_pipes then
				table.insert(unres, preargs.unres[k])
			end
		end
		for k, v in ipairs(args.res) do
			table.insert(input, v)
			table.insert(codes, args.codes[k])
			if shmt.proper_pipes then
				table.insert(unres, args.unres[k])
			end
		end
		local t = {}
		if shmt.proper_pipes then
			unresolved[t] = { cmd = cmd, unres = unres, input = input, codes = codes }
		else
			local apply = function(com)
				local transforms = shmt.transforms
				if transforms then print("Shelua Deprecation: transforms option moved to be a repr-specific option") end
				transforms = tbl_get(shmt, transforms or {}, "repr", shmt.shell or "posix", "transforms")
				for _, f in ipairs(transforms) do
					com = f(com)
				end
				return com
			end
			if is_5_2_plus then
				local msg
				cmd, msg = get_repr_fn(shmt, "single_stdin")(shmt, cmd, #input > 0 and input or nil,
					#codes > 0 and codes or nil)
				t = get_repr_fn(shmt, "post_5_2_run")(shmt, apply(cmd), msg)
			else
				local msg
				cmd, msg = get_repr_fn(shmt, "single_stdin")(shmt, cmd, #input > 0 and input or nil,
					#codes > 0 and codes or nil)
				t = get_repr_fn(shmt, "pre_5_2_run")(shmt, apply(cmd), msg)
			end
			if shmt.assert_zero and t.__exitcode ~= 0 then
				error("Command " .. tostring(cmd) .. " exited with non-zero status: " .. tostring(t.__exitcode))
			end
		end
		return setmetatable(t, make_meta(shmt))
	end
end
-- allow to call sh with a string to run shell commands
-- or no arguments to return clone
-- or first arg as table to tbl_extend settings then clone
-- or first arg as function that recieves old settings to set new settings and clone
---@param self table
---@param cmd nil | table | string | fun(opts: Shelua.Opts): table
---@vararg any
---@return table | any
MT.__call = function(self, cmd, ...)
	if cmd == nil then
		return setmetatable({}, make_meta(deepcopy(getmetatable(self)), true))
	elseif type(cmd) == 'table' then
		return setmetatable({}, make_meta(recUpdate(deepcopy(getmetatable(self)), cmd), true))
	elseif type(cmd) == 'function' then
		return setmetatable({}, make_meta(cmd(deepcopy(getmetatable(self))), true))
	else
		return command(self, cmd, ...)
	end
end
---@type Shelua
return setmetatable({}, make_meta(false, true))
