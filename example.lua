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

