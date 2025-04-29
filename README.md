# shelua

[![Lua][lua-shield]][lua-url]
[![LuaRocks][luarocks-shield]][luarocks-url]

Tiny library for shell scripting with Lua (inspired by zserge/luash).

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

Note that the commands are not running in parallel (because Lua can only handle
one I/O loop at a time). So the inner-most command is executed, its output is
read, the the outer command is execute with the output redirected etc.

``` lua
require('sh')

local words = 'foo\nbar\nfoo\nbaz\n'
local u = sh.uniq(sh.sort({__input = words})) -- like $(echo ... | sort | uniq)
print(u) -- prints "bar", "baz", "foo"
```

Pipelines can be also written as chained function calls. Lua allows to omit parens, so the syntax really resembles unix shell:

``` lua
-- $ ls /bin | grep $filter | wc -l

-- normal syntax
sh.wc(sh.grep(sh.ls('/bin'), filter), '-l')
-- chained syntax
sh.ls('/bin'):grep(filter):wc('-l')
-- chained syntax without parens
sh.ls '/bin' : grep filter : wc '-l'
```

## Partial commands and commands with tricky names or characters

You can use `sh` as a function to construct a command function, optionally
pre-setting the arguments:

``` lua
local sh = require('sh')

local truecmd = sh('true') -- because "true" is a Lua keyword
local chrome = sh('google-chrome') -- because '-' is an operator

local gittag = sh('git', 'tag') -- gittag(...) is same as git('tag', ...)

gittag('-l') -- list all git tags
```

`require`ing this library also will add the `string.escapeShellArg` function,
allowing you to use it on any string `("like so"):escapeShellArg()`.

`string.escapeShellArg` receives a string and returns a string escaped for use in shell commands.

## Exit status and signal values

Each command function returns a table with `__exitcode` and `__signal` fields.
Those hold the exit status and signal value as numbers. Zero exit status means
the command was executed successfully.

SInce `f:close()` returns exitcode and signal in Lua 5.2 or newer - this will
not work in Lua 5.1 and current LuaJIT.

## Command arguments as a table

Key-value arguments can be also specified as argument table pairs:

```lua
require('sh')

-- $ somecommand --format=long --interactive -u=0
somecommand({format="long", interactive=true, u=0})
```
It becomes handy if you need to toggle or modify certain command line
argumnents without manually changing the argumnts list.

## Settings

The sh variable has settings in its metatable that you may set to change its behavior.

```lua
local sh_settings = getmetatable(require('sh'))
-- default values
sh_settings.escape_args = false
sh_settings.assert_zero = false
sh_settings.tempfile_path = '/tmp/sheluainput'
```

You can make a local copy with different settings by using the unary minus operator.

```lua
local newsh = -require('sh')
getmetatable(newsh).assert_zero = true

-- unaffected, prints 1
print(require('sh')["false"]().__exitcode)
-- would throw an error due to assert_zero = true
newsh["false"]()
```

## For nix users

The library is exported by the flake as `pkgs.default`, `pkgs.shelua5_1`, `pkgs.shelua5_2`, `pkgs.shelua5_3`, `pkgs.shelua5_4`, `pkgs.sheluajit_2_1`.

It also exports a `legacyPackages.${system}.runLuaCommand` which is a lot like `pkgs.runCommand` except the command is in lua.

`runLuaCommand :: str -> str -> attrs or (n2l -> attrs) -> str or (n2l -> str)`

where `n2l` is [this nix to lua library](https://github.com/BirdeeHub/nixToLua)

and the rest representing:

`runLuaCommand :: name -> lua_interpreter_path -> drvArgs -> lua_command`

### in the lua command:

- A `sh` global will be added containing `require('sh')`

- That `require('sh')` will also add the `string.escapeShellArg` function.

- `drvArgs.passthru` will be written verbatim to the `drv` global variable in lua,
	minus any nix functions, achieved via the `n2l` library mentioned above

- `$out` in for the derivation will have an associated `out` global in lua

- A temporary directory will be created for use, with its path given by the `temp` global

- `os.read_file(filename) -> string` and `os.readable(filename) -> boolean` will be added

- `os.write_file(opts, filename, contents)` will be added where opts is `{ append = false, newline = true }` by default

## License

Code is distributed under the MIT license.

[lua-shield]: https://img.shields.io/badge/lua-%232C2D72.svg?style=for-the-badge&logo=lua&logoColor=white
[lua-url]: https://www.lua.org/
[luarocks-shield]:
https://img.shields.io/luarocks/v/BirdeeHub/lze?logo=lua&color=purple&style=for-the-badge
[luarocks-url]: https://luarocks.org/modules/BirdeeHub/shelua
