local sh = require('sh')

-- any shell command can be called as a function
print('User:', sh.whoami())
print('Current directory:', sh.pwd())

-- commands can be grouped into the pipeline as nested functions
print('Files in /bin:', sh.wc(sh.ls('/bin'), '-l'))

-- commands can be chained as in unix shell pipeline
print(sh.echo('Hello World'):sed("s/Hello/Goodbye/g"))
-- Lua allows to omit parens
print(sh.echo 'Hello World' :sed "s/Hello/Goodbye/g")

-- intermediate output in the pipeline can be stored into variables
local sedecho = sh.sed(sh.echo('hello', 'world'), 's/world/Lua/g')
print('output:', sedecho)
print('exit code:', sedecho.__exitcode)
local res = sh.tr(sedecho, '[[:lower:]]', '[[:upper:]]')
print('output+tr:', res)

-- command functions can be created dynamically. Optionally, some arguments
-- can be prepended (like partially applied functions)
local e = sh('echo')
local greet = sh('echo', 'hello')
print(e('this', 'is', 'some', 'output'))
print(greet('world'))
print(greet('foo'))

-- sh module itself can be called as a function
-- it's an alias for sh.command()
print(sh('type')('ls'))
print(sh 'type' 'ls')

-- changing settings for sh variable

sh.escape_args = true
print(sh.echo 'Hello World' :sed "s/Hello World/Goodbye Universe/g")
sh.escape_args = false

-- cloning sh with new settings, and "proper_pipes" setting (and others)

local nsh = sh({
  proper_pipes = true,
  escape_args = true,
  assert_zero = true,
  transforms = {
    function(cmd)
      print(cmd)
      return cmd
    end
  }
})
print(nsh.echo 'Hello world' :sed "s/Hello/Goodbye/g")
print(nsh.sed(nsh.echo 'Hello world', nsh.echo 'Hello world', "s/Hello/Goodbye/g"))
print(nsh.echo 'Hello World' :sed(nsh.echo 'Hello World', nsh.echo 'Hello World' :sed(nsh.echo 'Hello World', "s/Hello/Goodbye/g"), "s/World/Universe/g"))
