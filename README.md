# shelua

[![Lua][lua-shield]][lua-url]
[![LuaRocks][luarocks-shield]][luarocks-url]

Tiny library for shell scripting with Lua (inspired by zserge/luash).

`luash` is interesting, but it modifies `_G` in an extreme way.

This makes it very difficult to use as part of anything else.

I localized `luash` to the variable itself, improved escaping,
and added some settings that proved useful to me.

Due to the settings being localized to the variable as well, you can have multiple of them, with different [settings](#settings).

It also contains a workaround to make the error codes still work prior to `lua 5.2`.

It works with any "posix-enough" shell by default such as `bash`, `zsh`, and `dash`/`sh`.

But it will not work by default with `fish`, `nushell`, `cmd` or `powershell` unless you define a representation for that shell.

It also exports a [small nix helper](#in-addition-to-the-library) that allows you
to use `shelua` to write `nix` derivations in `lua` instead of `bash`.

It is `pkgs.runCommand` except it is `pkgs.runLuaCommand` because the command is in `lua`.

It is useful when you have a short build or wrapper script that needs to deal with a lot of structured data.

Especially when you have a lot of `json` and would rather use `cjson` and deal with tables than use `jq` and bash arrays

## Install

via luarocks: `luarocks install shelua`

[via nix](#for-nix-users)

Or just clone this repo and copy `lua/sh.lua` into your project.

## Simple usage

Every command that can be called via os.execute can be called via the sh table.
All the arguments passed into the function become command arguments.

``` lua
local sh = require('sh')

local wd = tostring(sh.pwd()) -- calls `pwd` and returns its output as a string

local files = tostring(sh.ls('/tmp')) -- calls `ls /tmp`
for f in string.gmatch(files, "[^\n]+") do
	print(f)
end
```

## Command input and pipelines

If command argument is a table which has a `__input` field - it will be used as
a command input (stdin). Multiple arguments with input are allowed, they will
be concatenated.

The each command function returns a structure that contains the `__input`
field, so nested functions can be used to make a pipeline.

``` lua
local sh = require('sh')

local words = 'foo\nbar\nfoo\nbaz\n'
local u = sh.uniq(sh.sort({__input = words})) -- like $(echo ... | sort | uniq)
print(u) -- prints "bar", "baz", "foo"
```

Pipelines can be also written as chained function calls. Lua allows you to omit parens, so the syntax really resembles unix shell:

``` lua
-- $ ls /bin | grep $filter | wc -l

-- normal syntax
sh.wc(sh.grep(sh.ls('/bin'), "$filter"), '-l')
-- chained syntax
sh.ls('/bin'):grep("$filter"):wc('-l')
-- chained syntax without parens
sh.ls '/bin' : grep "$filter" : wc '-l'
```

Note that the commands are not running in parallel (because Lua can only handle
one I/O loop at a time). So the inner-most command is executed, its output is
read, the the outer command is execute with the output redirected etc.

However, `shelua` also offers a `proper_pipes` [setting](#settings).

It will cause the chains you make to be piped directly in bash!
Accessing a returned values `__exitcode`, `__signal` and `__input` fields,
or calling `tostring()` or `print()` will cause your value to be "resolved".

This means the chain up to that point will be translated to a bash pipeline and ran at that point.

It also means that after a chain has been resolved,
you no longer can get the values of intermediate values in the chain,
so this is not the default behavior.

## Command arguments as a table

Key-value arguments can be also specified as argument table pairs:

```lua
local sh = require('sh')

-- $ somecommand --format=long --interactive -u=0
sh.somecommand({format="long", interactive=true, u=0})
```

It becomes handy if you need to toggle or modify certain command line
arguments without manually changing the arguments list.

## Partial commands and commands with tricky names or characters

You can call `sh` with a string as the first argument to construct a command function, optionally
pre-setting the arguments:

``` lua
local sh = require('sh')

local truecmd = sh('true') -- because "true" is a Lua keyword
local chrome = sh('google-chrome') -- because '-' is an operator
local chromeagain = sh['google-chrome'] -- same as above

local gittag = sh('git', 'tag') -- gittag(...) is same as sh.git('tag', ...)

gittag('-l') -- list all git tags
```

## Exit status and signal values

Each command function returns a table with `__exitcode` and `__signal` fields.
Those hold the exit status and signal value as numbers. Zero exit status means
the command was executed successfully.

Since `f:close()` only returns exitcode and signal in Lua 5.2 or newer, this works differently in Lua 5.1 and current LuaJIT.

It will detect the version and in versions older than 5.2 it will add `\necho __EXITCODE__$?`, and remove and parse the value for the code instead.

## Settings

The sh variable has settings in its metatable that you may set to change its behavior.

If you assign a value to the sh table, it will set the value in the metatable.

```lua
local sh = require('sh')

-- default values
-- escape unnamed shell arguments
-- NOTE: k = v table keys are still not escaped, k = v table values always are
sh.escape_args = false
-- Assert that exit code is 0 or throw and error
sh.assert_zero = false
-- proper pipes at the cost of access to mid pipe values after further calls have been chained from it.
sh.proper_pipes = false
-- a list of functions to run in order on the command before running it.
-- each one recieves the final command and is to return a string representing the new one
sh.transforms = {}
---Allows the definition of new shell backends.
---@type table<string, Shelua.Repr>
sh.repr = { posix = { --[[...]] } }
sh.shell = "posix"
```

For info on `sh.repr`, see [Shell Representation docs](./REPR.md)

You can make a local copy with different settings by calling the sh table as a function with no arguments.

Or you can call it with a table to modify the existing settings and return a new sh table.

Or you can call it with a function that receives the old settings table and returns a new one.

```lua
-- these 4 forms are equivalent
local nsh = require('sh')()
nsh.assert_zero = true
-- or
local newsh = require('sh')()
getmetatable(newsh).assert_zero = true
-- or
local newersh = require('sh')({assert_zero = true})
-- or
local evennewersh = require('sh')(function(s) s.assert_zero = true return s end)

-- unaffected, prints 1
print(require('sh')["false"]().__exitcode)
-- would throw an error due to assert_zero = true
print(nsh["false"]().__exitcode)
```

## For nix users

```nix
inputs.shelua = {
	url = "github:BirdeeHub/shelua";
	inputs.nixpkgs.follows = "nixpkgs";
};
```

The library is exported by the flake under `inputs.shelua.packages.${system}` as `default`, `shelua5_1`, `shelua5_2`, `shelua5_3`, `shelua5_4`, and `sheluajit_2_1`.

You may import any of them for any nixpkgs lua interpreter like this if you don't want to match them up.

```nix
luaEnv = pkgs.lua5_2.withPackages (ps: [(inputs.shelua.packages.${system}.default.override { luapkgs = ps; })]);
```

It also exports overlays. See the [flake](./flake.nix) for more details.

### In addition to the library:

It exports a `inputs.shelua.legacyPackages.${system}.runLuaCommand` which is a lot like `pkgs.runCommand` except the command is in lua.

`runLuaCommand :: str -> str -> attrs or (n2l -> attrs) -> str or (n2l -> str) -> drv`

where `n2l` is [this nix to lua library](https://github.com/BirdeeHub/nixToLua)

and the rest representing:

`runLuaCommand :: name -> lua_interpreter_path -> drvArgs -> lua_command -> drv`

You should provide the interpreter path via something like this to get the most of this function.

`(pkgs.lua5_2.withPackages (ps: with ps; [inspect])).interpreter`

### in the lua command:

- An `sh` global will be added containing `require('sh')`

- `drvArgs.passthru` will be written verbatim to the `drv` global variable in lua,
	minus any nix functions, achieved via the `n2l` library mentioned above.
	This will apply even if you add them later via `overrideAttrs`

- `$out` for the derivation will have an associated `out` global in lua

- A temporary directory will be created for use, with its path given by the `temp` global

- `string.escapeShellArg` function will be added,
	allowing you to use it on any string `("like so"):escapeShellArg()`.
	`string.escapeShellArg` is `pkgs.lib.escapeShellArg` in lua.

- `os.read_file(filename) -> string` and `os.readable(filename) -> boolean` will be added

- `os.write_file(opts, filename, contents)` will be added where opts is `{ append = false, newline = true }` by default

## License

Code is distributed under the MIT license.

[lua-shield]: https://img.shields.io/badge/lua-%232C2D72.svg?style=for-the-badge&logo=lua&logoColor=white
[lua-url]: https://www.lua.org/
[luarocks-shield]:
https://img.shields.io/luarocks/v/BirdeeHub/lze?logo=lua&color=purple&style=for-the-badge
[luarocks-url]: https://luarocks.org/modules/BirdeeHub/shelua
