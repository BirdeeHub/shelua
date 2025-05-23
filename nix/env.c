#include <stdlib.h>
#include <lua.h>
#include <lauxlib.h>
#ifdef _WIN32
#include <windows.h>
#endif

static int env__newindex(lua_State *L) {
    const char *key = luaL_checkstring(L, 2);
#ifdef _WIN32
    if (lua_isnil(L, 3)) {
        if (SetEnvironmentVariable(key, NULL) == 0) {
            return luaL_error(L, "failed to unset env var");
        }
    } else if (lua_type(L, 3) == LUA_TSTRING) {
        if (SetEnvironmentVariable(key, lua_tostring(L, 3)) == 0) {
            return luaL_error(L, "failed to set env var");
        }
#else
    if (lua_isnil(L, 3)) {
        if (unsetenv(key) != 0) {
            return luaL_error(L, "failed to unset env var");
        }
    } else if (lua_type(L, 3) == LUA_TSTRING) {
        if (setenv(key, lua_tostring(L, 3), 1) != 0) {
            return luaL_error(L, "failed to set env var");
        }
#endif
    } else {
        return luaL_error(L, "env values must be strings or nil");
    }
    return 0;
}

static int env__index(lua_State *L) {
    const char *key = luaL_checkstring(L, 2);
    const char *val = getenv(key);
    if (val)
        lua_pushstring(L, val);
    else
        lua_pushnil(L);
    return 1;
}

int luaopen_env(lua_State *L) {
    lua_newtable(L); // module table
    lua_newtable(L); // metatable
    lua_pushcfunction(L, env__index);
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, env__newindex);
    lua_setfield(L, -2, "__newindex");
    lua_setmetatable(L, -2); // setmetatable(t, mt)
    return 1; // return env table
}
