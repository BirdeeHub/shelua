# What is a representation of a shell backend in `shelua`?

A shell representation is a collection of functions used for defining the actual character sequences your commands translate into.

`shelua` takes care of resolving the pipes of functions,
and defining all the special properties of the library.

It also provides a built in representation for `posix` shells.

These representation functions define the actual connective characters that join things together, after shelua has taken care of the structuring for you.

To define and use a new representation, add the table to the `repr` table in the `Shelua.Opts` table.
Then set the `shell` setting to the name of its key in that table.

The first 3 functions to define if necessary are hopefully fairly self explanatory.

- `arg_tbl` is what translates key value pairs in arguments provided within lua tables, for example, this command:

```lua
local utils_json = tostring(sh.nixdoc {
	j = true,
	category = "utils",
	description = "nixCats.utils set documentation",
	prefix = "nixCats",
	file = "./utils/default.nix"
})
```

- `escape` makes sure each string it is given will escaped as a single argument when passed to the shell.

- `add_args` is what concatenates the args onto the command. By default it uses space as a separator, and you are unlikely to need to change it.
	- The list of arguments provided to `add_args` will already have table-form arguments translated by `arg_tbl`
	- When `escape_args` is true, any unnamed arguments in the list will also already be escaped by the `escape` function defined in the representation.
	- If you wish to make your `add_args` return something that is not a string, your other representation functions and any defined `transforms` must be able to handle that.
	- In addition, if you wish to make your `add_args` return something that is not a string, you should define `__tostring` in its metatable to preserve useful error messages.

Our first 3 `Shelua.Repr` methods for `posix`: `arg_tbl`, `escape`, and `add_args`

```lua
---@type Shelua.Repr
local posix = {
	-- converts key and it's argument to "-k" or "-k=v" or "--key=v" or nil to ignore
	-- turns table form args from table keys and values into flags
	-- if returning a list, items will be added to args list in order
	---@field arg_tbl fun(opts: Shelua.Opts, k: string, a: any): string|string[]?
	arg_tbl = function(opts, k, a)
		k = (#k > 1 and '--' or '-') .. k
		if type(a) == 'boolean' and a then return k end
		if type(a) == 'string' then
			return k .. "=" .. opts.repr[opts.shell or "posix"].escape(a)
		end
		if type(a) == 'number' then return k .. '=' .. tostring(a) end
		return nil
	end,
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
	---if you decide to represent your command (first return value) internally as something other than a string,
	-- you should define __tostring metamethod for it to preserve error messages
	---@field add_args fun(opts: Shelua.Opts, cmd: string, args: string[]): string|any
	add_args = function(opts, cmd, args)
		return cmd .. " " .. table.concat(args, " ")
	end,
```

`single_stdin` is the function that modifies cmd to add stdin input when `proper_pipes` == `false`

Its first return value will then be passed through any defined `transforms`.

the result, in addition to its optional second return value will then be passed to one of the 2 following run functions based on current lua version.

`post_5_2_run` and `pre_5_2_run` are what call the actual final shell command when needed.

Their job is to run the command and report the result, exit and signal codes.

Prior to 5.2 the io.popen command does not return exit code or signal. You can decide to support older than 5.2 or not.

```lua
	---returns cmd and an optional item such as path to a tempfile to be passed to post_5_2_run or pre_5_2_run
	---called only when proper_pipes is false
	---cmd is the result of add_args
	---codes is the list of codes that correspond with each input such as `__exitcode`, empty if none
	---@field single_stdin fun(opts: Shelua.Opts, cmd: string|any, inputs: string[]?, codes: table[]?): (string|any, any?)
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
	---runs the command and returns the result and exit code and signal
	-- cmd is the result of single_stdin or concat_cmd, after being passed through any defined transforms
	---@field post_5_2_run fun(opts: Shelua.Opts, cmd: string|any, msg: any?): { __input: string, __exitcode: number, __signal: number }
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
	-- cmd is the result of single_stdin or concat_cmd, after being passed through any defined transforms
	---@field pre_5_2_run fun(opts: Shelua.Opts, cmd: string|any, msg: any?): { __input: string, __exitcode: number, __signal: number }
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
	---if your pre_5_2_run or post_5_2_run returns a table with extra keys, e.g. `__stderr`
	---proper_pipes will need to know that accessing them should be a trigger to resolve the pipe.
	---each string in this table must begin with '__' or it will be ignored
	---@field extra_cmd_results string[]|fun(opts: Shelua.Opts): string[]
	extra_cmd_results = {},
	---a list of functions to run in order on the command before running it.
	---each one recieves the previous value and returns a new one.
	---they are ran after concat_cmd or single_stdin and before the post_5_2_run and pre_5_2_run functions
	---@field transforms? (fun(cmd: string|any): string|any)[]
	transforms = {},
```

And the final method, `concat_cmd`. This is the counterpart to `single_stdin`.

It is called only when `proper_pipes` == `true`.

Instead of taking an input string, it receives an input list, and will be called as part of the recursive resolution of pipes.

Each item in the input list is a `PipeInput` type table. A table containing EITHER a `c` (command) or `s` (string) key.

These represent either a the return previous iteration of `concat_cmd`, or a string provided via an `{ __input }` argument.

They may also contain an `m` (message) key if they contain a `c`,
which is the optional second return value of the call to `concat_cmd`

Your goal in this function is to construct a string from the prior inputs,
that pipes them into the command, and then return that string, if there are any prior inputs to pipe.

Its result will be provided to the same run function as `single_stdin` would have, either `pre_5_2_run` or `post_5_2_run`,
after adding the newly resolved values to the command result being resolved.

```lua
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

	---strategy to combine piped inputs, 0, 1, or many, return resolved command to run
	---called only when proper_pipes is true
	---may return an optional second value to be placed in another PipeInput, or returned to post_5_2_run or pre_5_2_run
	-- cmd is the same type as the result of add_args
	---@field concat_cmd fun(opts: Shelua.Opts, cmd: string|any, input: Shelua.PipeInput[]): (string|any, any?)
	concat_cmd = function(opts, cmd, input)
		if #input == 1 then
			local v = input[1]
			if v.s then
				local esc = opts.repr[opts.shell or "posix"].escape(v.s)
				return 'printf "%s" ' .. esc .. " | " .. cmd
			else
				return v.c .. " | " .. cmd
			end
		elseif #input > 1 then
			for i = 1, #input do
				local v = input[i]
				if v.s then
					input[i] = 'printf "%s" ' .. opts.repr[opts.shell or "posix"].escape(v.s)
				elseif v.c then
					input[i] = v.c
				end
			end
			return "{ " .. table.concat(input, " ; ") .. " ; } | " .. cmd
		else
			return cmd
		end
	end,
}
```

That's an entire shell backend!

As you can see, shelua provides the structures and commands you will need to resolve,
and the representation defines the actual characters used to combine them into the command.

In this way, shelua may be used with ANY shell, provided you are willing to provide new versions of the above functions that do not work for that shell.

For example, Fish will need to define a new `escape` and a new `concat_cmd` function.

When you don't provide a method for a representation, the current `posix` representation will be used by default.
