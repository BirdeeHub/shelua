# What is a representation of a shell backend in `shelua`?

A shell representation is a collection of functions used for defining the actual character sequences your commands translate into.

`shelua` takes care of resolving the pipes of functions,
and defining all the special properties of the library,
and provides a built in representation for `posix` shells.

These functions define the actual connective characters that join things together, after shelua has taken care of the structuring for you.

To define and use a new representation, add the table to the `repr` table in the `SheluaOpts` table.
Then set the `shell` setting to the name of its key in that table.

The first 3 functions to define if necessary are hopefully fairly self explanatory.

`escape` makes sure each string it is given will escaped as a single argument when passed to the shell.

`add_args` is what concatenates the args onto the command. By default it uses space as a separator, and you are unlikely to need to change it.

`arg_tbl` is what translates key value pairs in arguments provided within lua tables, for example, this command:

```lua
local utils_json = tostring(sh.nixdoc {
	j = true,
	category = "utils",
	description = "nixCats.utils set documentation",
	prefix = "nixCats",
	file = "./utils/default.nix"
})
```

Our first 3 Repr methods for posix, `escape`, `add_args`, and `arg_tbl`

```lua
---@type Shelua.Repr
local posix = {
	---escapes a string for the shell
	---@field escape fun(arg: any): string
	escape = function(arg)
		local str = tostring(arg)
		-- nixpkgs.lib.escapeShellArg in lua
		if str:match("^[%w,._+:@%%/-]+$") == nil then
			return string.format("'%s'", str:gsub("'", "'\\''"))
		else
			return str
		end
	end,
	---adds args to the command
	---@field add_args fun(cmd: string, args: string[]): string
	add_args = function(cmd, args)
		return cmd .. " " .. table.concat(args, " ")
	end,
	-- converts key and it's argument to "-k" or "-k=v" or "--key=v" or nil to ignore
	---turns table form args from table keys and values into flags
	---@field arg_tbl fun(opts: SheluaOpts, k: string, a: any): string|nil
	arg_tbl = function(opts, k, a)
		k = (#k > 1 and '--' or '-') .. k
		if type(a) == 'boolean' and a then return k end
		if type(a) == 'string' then
			return k .. "=" .. opts.repr[opts.shell or "posix"].escape(a)
		end
		if type(a) == 'number' then return k .. '=' .. tostring(a) end
		return nil
	end,
```

`single_stdin` is the function that modifies cmd to add stdin input when `proper_pipes` == `false`

Its result(s) will then be passed to one of the 2 following run functions based on current lua version.

`post_5_2_run` and `pre_5_2_run` are what call the actual final shell command when needed.

Their job is to run the command and report the result, exit and signal codes.

Prior to 5.2 the io.popen command does not return exit code or signal. You can decide to support older than 5.2 or not.

```lua
	---returns cmd and an optional item such as path to a tempfile to be passed to post_5_2_run or pre_5_2_run
	---called only when proper_pipes is false
	---@field single_stdin fun(opts: SheluaOpts, cmd: string, input: string?): (string, any?)
	single_stdin = function(opts, cmd, input)
		local tmp
		if input then
			tmp = os.tmpname()
			local f = io.open(tmp, 'w')
			if f then
				f:write(input)
				f:close()
				cmd = cmd .. ' <' .. tmp
			end
		end
		return cmd, tmp
	end,
	---runs the command and returns the result and exit code and signal
	---@field post_5_2_run fun(opts: SheluaOpts, cmd: string, tmp: any?): { __input: string, __exitcode: number, __signal: number }
	post_5_2_run = function(opts, cmd, tmp)
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
	end,
	---runs the command and returns the result and exit code and signal
	---Should return the flags using the same format as io.popen does in 5.2+
	---@field pre_5_2_run fun(opts: SheluaOpts, cmd: string, tmp: any?): { __input: string, __exitcode: number, __signal: number }
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
```

And the final method, `concat_cmd`. This is the counterpart to `single_stdin`.

It is called only when `proper_pipes` == `true`.

Instead of taking an input string, it receives an input list, and will be called as part of the recursive resolution of pipes.

Each item in the input list is a `PipeInput` type table. A table containing EITHER a `c` (command) or `s` (string) key.

These represent either a the return previous iteration of `concat_cmd`, or a string provided via an `{ __input }` argument.

Your goal in this function is to construct a string from the prior inputs,
that pipes them into the command, and then return that string, if there are any prior inputs to pipe.

Its result will be provided to the same run function as `single_stdin` would have, either `pre_5_2_run` or `post_5_2_run`,
after adding the newly resolved values to the command result being resolved.
However `concat_cmd` cannot return an optional second argument.

```lua
	---strategy to combine piped inputs, 0, 1, or many, return resolved command to run
	---called only when proper_pipes is true
	---@field concat_cmd fun(opts: SheluaOpts, cmd: string, input: Shelua.PipeInput[]): string
	concat_cmd = function(opts, cmd, input)
		if #input == 1 then
			local v = input[1]
			if v.s then
				local esc = tbl_get(opts, opts.repr[opts.shell or "posix"].escape(v.s)
				return "echo " .. esc .. " | " .. cmd
			else
				return v.c .. " | " .. cmd
			end
		elseif #input > 1 then
			for i = 1, #input do
				local v = input[i]
				if v.s then
					input[i] = "echo " .. opts.repr[opts.shell or "posix"].escape(v.s)
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
	---Will contain either s, a string,
	---or B, an input command string
	---@class Shelua.PipeInput
	---string stdin to combine
	---@field s? string
	---cmd to combine
	---@field c? string
}
```

Thats an entire shell backend!

As you can see, shelua provides the structures you will need to resolve,
and the representation defines the actual string of characters or actions to resolve to!

In this way, shelua may be used with ANY shell, provided you are willing to provide new versions of the above functions that do not work for that shell.

For example, Fish will need to define a new `escape` and a new `concat_cmd` function.

When you don't provide a method for a representation, the current `posix` representation will be used by default.
