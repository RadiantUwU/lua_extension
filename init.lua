do
    local core_env = {pairs=pairs}
    function table.clone(t)
        local tt = {}
        for k,v in core_env.pairs(t) do
            tt[k]=v
        end
        return tt
    end
    local user_env = table.clone(_G)
    core_env = table.clone(_G)
    core_env.crypto = core_env.LuaCrypto()
    core_env.core_env = core_env
    core_env.user_env = user_env
    _G.core_key = nil
    local protected_functions = setmetatable({},{__mode="k"})
    local core_functions = setmetatable({},{__mode="k"})
    core_env.protected_metatables = setmetatable({},{__mode="k"})
    core_env.killing_threads = setmetatable({},{__mode="k"})
    local function setfenv(fn, env)
        if protected_functions[fn] then
            core_env.error("function is protected.",2)
        end
        local i = 1
        while true do
            local name = core_env.debug.getupvalue(fn, i)
            if name == "_ENV" then
                core_env.debug.upvaluejoin(fn, i, (function()
                    return env
                end), 1)
                break
            elseif not name then
                break
            end
            i = i + 1
        end
        return fn
    end
    local function getfenv(fn)
        if protected_functions[fn] then
            error("function is protected.",2)
        end
        local i = 1
        while true do
            local name, val = core_env.debug.getupvalue(fn, i)
            if name == "_ENV" then
                return val
            elseif not name then
                break
            end
            i = i + 1
        end
    end
    local function _setfenv(fn, env)
        local i = 1
        while true do
            local name = core_env.debug.getupvalue(fn, i)
            if name == "_ENV" then
                core_env.debug.upvaluejoin(fn, i, (function()
                    return env
                end), 1)
                break
            elseif not name then
                break
            end
            i = i + 1
        end
        return fn
    end
    local function _getfenv(fn)
        local i = 1
        while true do
            local name, val = core_env.debug.getupvalue(fn, i)
            if name == "_ENV" then
                return val
            elseif not name then
                break
            end
            i = i + 1
        end
    end
    core_env._setfenv = _setfenv
    core_env._getfenv = _getfenv
    user_env.setfenv = setfenv
    core_env.setfenv = setfenv
    user_env.getfenv = getfenv
    core_env.getfenv = getfenv
    user_env.core_set_hook = nil
    user_env.core_set_is_core_f = nil
    user_env.core_suspend_all = nil
    user_env.core_terminate_all = nil
    user_env.core_restore = nil
    local function protect_fn(fn)
        protected_functions[fn] = true
        return fn
    end
    local function is_fn_protected(fn)
        return protected_functions[fn] or false
    end
    local function _unprotect_fn(fn)
        protected_functions[fn] = nil
    end
    core_env._unprotect_fn = _unprotect_fn
    local function _enter_core(key)
        if core_env.crypto.constant_time_compare(core_env.core_key,key) then
            protect_fn(debug.getinfo(2,"f").func)
            _setfenv(2,core_env)
        else
            log_error("Attempt to enter core layer with an invalid key.")
            coroutine.terminate()
        end
    end
    local function _run_user_fn(fn,...)
        return _G[fn](...)
    end
    local function _run_user_coro_fn(fn)
        return core_env.coroutine.create(fn)
    end
    local function _run_core(key,code)
        if core_env.crypto.constant_time_compare(core_env.core_key,key) then
            core_env.load(code,"(corespace)","t",core_env)()
        else
            log_error("Attempt to enter core layer with an invalid key.")
            coroutine.terminate()
        end
    end
    local function _run_core_fn(key,fn_name,...)
        if core_env.crypto.constant_time_compare(core_env.core_key,key) then
            local fn = core_env[fn_name]
            if not fn then
                core_env.error(fn_name.." not found.",2)
            end
            protect_fn(fn)
            _setfenv(fn,core_env)
            return fn(...)
        else
            log_error("Attempt to enter core layer with an invalid key.")
            coroutine.terminate()
        end
    end
    local function _run_core_coro(key,code)
        if core_env.crypto.constant_time_compare(core_env.core_key,key) then
            return core_env.coroutine.create(core_env.load(code,"(corespace)","t",core_env))
        else
            log_error("Attempt to enter core layer with an invalid key.")
            coroutine.terminate()
        end
    end
    local function _run_core_coro_fn(key,fn_name)
        if core_env.crypto.constant_time_compare(core_env.core_key,key) then
            local fn = core_env[fn_name]
            if not fn then
                core_env.error(fn_name.." not found.",2)
            end
            protect_fn(fn)
            _setfenv(fn,core_env)
            return core_env.coroutine.create(fn)
        else
            log_error("Attempt to enter core layer with an invalid key.")
            coroutine.terminate()
        end
    end
    core_env.protect_fn = protect_fn
    core_env.is_fn_protected = is_fn_protected
    user_env.protect_fn = protect_fn
    user_env.is_fn_protected = is_fn_protected
    function core_env.trust_core_function(fn)
        core_functions[fn] = true
        protect_fn(fn)
        _setfenv(fn,core_env)
        return fn
    end
    local immutable_user_env = {
        _enter_core=_enter_core,
        _run_user_fn=_run_user_fn,
        _run_user_coro_fn=_run_core_coro_fn,
        _run_core=_run_core,
        _run_core_fn=_run_core_fn,
        _run_core_coro=_run_core_coro,
        _run_core_coro_fn=_run_core_coro_fn,
        protect_fn=protect_fn,
        is_fn_protected=is_fn_protected,
        _G=_G
    }
    setmetatable(user_env,{
        __index=immutable_user_env,
        __newindex=protect_fn(function (t, k, v)
            if immutable_user_env[k] == nil then
                rawset(t,k,v)
            end
        end),
        __metatable=false,
        __isfrozen=true
    })
    function core_env.add_to_user_env(name,var,immutable)
        if immutable == nil then
            immutable = true
        end
        if immutable then
            immutable_user_env[name]=var
        else
            user_env[name]=var
        end
    end
    function core_env.erase_user_env(name)
        immutable_user_env[name]=nil
        user_env[name]=nil
    end
    function table.base(...)
        local t = {}
        for _,table in core_env.ipairs({...}) do
            if table then
                if core_env.type(table) == "table" then
                    for k,v in core_env.pairs(table) do
                        t[k] = v
                    end
                end
            end
        end
        return t
    end
    function table.baseinto(t,...)
        for _,table in core_env.ipairs({...}) do
            if table then
                if core_env.type(table) == "table" then
                    for k,v in core_env.pairs(table) do
                        t[k] = v
                    end
                end
            end
        end
        return t
    end
    function table.freeze(t)
        if core_env.type(t) ~= "table" then
            core_env.error("expected table, got "..type(t),2)
        end
        local tmt = core_env.debug.getmetatable(t)
        if tmt then
            if tmt.__isfrozen then
                return t -- already frozen., can also be used to protect against freezing.
            end
        end
        local mt = core_env.table.base(core_env.debug.getmetatable(t),{
            __metatable = core_env.debug.getmetatable(t) or false,
            __newindex = protect_fn(function (_,_,_)
                core_env.error("table is frozen.",2)
            end),
            __isfrozen = true
        })
        core_env.protected_metatables[mt]="lge" -- disallow rawset
        return core_env.debug.setmetatable(t,mt)
    end
    function table.isfrozen(t)
        if type(t) ~= "table" then
            core_env.error("expected table, got "..type(t),2)
        end
        local mt = core_env.debug.getmetatable(t)
        if mt then
        return mt.__isfrozen or false 
        end
    end
    function table.clear(t)
        for k,_ in core_env.pairs(t) do
            t[k]=nil
        end
        return t
    end
    function table.overwrite(t,nt)
        if core_env.type(t) ~= "table" then
            core_env.error("expected table, got "..type(t),2)
        end
        if core_env.type(nt) ~= "table" then
            core_env.error("expected table, got "..type(nt),2)
        end
        local mt = core_env.debug.getmetatable(t)
        if mt then
            if mt.__metatable ~= nil then
                core_env.error("table t is protected.",2)
            end
        end
        core_env.debug.setmetatable(t,nil)
        core_env.table.clear(t)
        for k,v in core_env.pairs(nt) do
            t[k]=v
        end
        return core_env.debug.setmetatable(t,core_env.debug.getmetatable(nt))
    end
    --make t1 a reference of t2
    function table.reference(t1,t2)
        if core_env.type(t1) ~= "table" then
            core_env.error("expected table, got "..core_env.type(t1),2)
        end
        if core_env.type(t2) ~= "table" then
            core_env.error("expected table, got "..core_env.type(t2),2)
        end
        local mt = core_env.debug.getmetatable(t1)
        if mt then
            if mt.__metatable ~= nil then
                core_env.error("table t1 is protected.",2)
            end
        end
        core_env.debug.setmetatable(t1,nil)
        core_env.table.clear(t1)
        core_env.debug.setmetatable(t1,core_env.debug.setmetatable({
            __index=t2,
            __newindex=protect_fn(function (t,k,v)
                t2[k]=v
            end),
        },{
            __index=protect_fn(function(t,k)
                if k == "__metatable" then
                    return core_env.getmetatable(t2)
                else
                    local mt = core_env.debug.getmetatable(t2)
                    if mt then
                        return mt[k]
                    end
                end
            end),
            __newindex=protect_fn(function(t,k,v)
                core_env.getmetatable(t2)[k]=v
            end),
            __metatable=false,
        }))
        core_env.protected_metatables[core_env.debug.getmetatable(t1)] = "le" -- length and equal are still allowed
        return t1
    end
    core_env._resume = coroutine.resume
    coroutine.resume = protect_fn(function (thread,...)
        local args_ret = {core_env._resume(thread,...)}
        if core_env.killing_threads[thread] then
            coroutine.close(thread)
        end
        return table.unpack(args_ret)
    end)
    coroutine.terminate = protect_fn(function ()
        assert(coroutine.isyieldable(),"unable to terminate -- cannot yield thread.")
        local coro = coroutine.running()
        core_env.killing_threads[coro] = true
        while true do
            coroutine.yield()
        end
    end)
    table.freeze(coroutine)
    table.freeze(debug)
    table.freeze(io)
    table.freeze(math)
    table.freeze(os)
    table.freeze(package)
    table.freeze(string)
    table.freeze(table)
    table.freeze(utf8)
    user_env.debug = table.freeze({
        getinfo=debug.getinfo,
        traceback=debug.traceback
    })
    user_env.io = nil
    user_env.os = table.freeze({
        clock = os.clock,
        date = os.date,
        difftime = os.difftime,
        time = os.time
    })
    user_env.package = nil
    function user_env.loadstring(text, env)
        env = env or user_env
        if core_env.type(text) ~= "string" then
            core_env.error("expected string, got "..core_env.type(text),2)
        end
        if core_env.type(env) ~= "table" then
            core_env.error("expected table, got "..core_env.type(env),2)
        end
        return core_env.load(text,"="..text,"t",env)
    end
    user_env.loadfile = nil
    user_env.load = nil
    function user_env.collectgarbage(opt, ...)
        if opt ~= "count" then
            core_env.error("unrecognized option",2)
        end
        return core_env.collectgarbage("count")
    end
    core_env.debug.getregistry().core_enviroment = core_env
    core_env.debug.getregistry().user_enviroment = user_env
    core_env.core_set_is_core_f(function(fn)
        return core_functions[fn]
    end)
    function core_env.create_new_user_env()
        return core_env.table.overwrite({},user_env) -- full shallow copy of table entries and reference the metatable.
    end
    function core_env.change_user_env(new_env)
        core_env.debug.setmetatable(_G,nil)
        table.reference(_G,new_env)
    end
    function core_env.rawpairs(t)
        assert(type(t) == "table","expected table, got "..type(t))
        return next,t,nil
    end
    function user_env.rawset(t,k,v)
        core_env.assert(core_env.type(t) == "table","expected table as first argument, got "..core_env.type(t))
        local flags = core_env.protected_metatables[core_env.debug.getmetatable(t)]
        if flags then
            if not core_env.string.find(flags,"s") then
                -- perform without raw
                t[k]=v
                return
            end
        end
        core_env.rawset(t,k,v)
    end
    function user_env.rawget(t,k)
        core_env.assert(core_env.type(t) == "table","expected table as first argument, got "..core_env.type(t))
        local flags = core_env.protected_metatables[core_env.debug.getmetatable(t)]
        if flags then
            if not core_env.string.find(flags,"g") then
                return t[k]
            end
        end
        return core_env.rawget(t,k)
    end
    function user_env.rawlen(t)
        core_env.assert(core_env.type(t) == "table","expected table as first argument, got "..core_env.type(t))
        local flags = core_env.protected_metatables[core_env.debug.getmetatable(t)]
        if flags then
            if not core_env.string.find(flags,"l") then
                return #t
            end
        end
        return core_env.rawlen(t)
    end
    function user_env.rawequal(t,o)
        core_env.assert(core_env.type(t) == "table","expected table as first argument, got "..core_env.type(t))
        local flags = core_env.protected_metatables[core_env.debug.getmetatable(t)]
        if flags then
            if not core_env.string.find(flags,"e") then
                return t==o
            end
        end
        return core_env.rawequal(t,o)
    end
    function user_env.next(t,k)
        core_env.assert(core_env.type(t) == "table","expected table as first argument, got "..core_env.type(t))
        local flags = core_env.protected_metatables[core_env.debug.getmetatable(t)]
        if flags then
            if not core_env.string.find(flags,"n") then
                local _n,_t,_ = core_env.pairs(t)
                return _n(_t,k)
            end
        end
        return core_env.pairs(t)
    end
    for k,v in pairs({
        [setfenv]=true,
        [getfenv]=true,
        [_setfenv]=true,
        [_getfenv]=true,
        [protect_fn]=true,
        [_unprotect_fn]=true,
        [is_fn_protected]=true,
        [_enter_core]=true,
        [_run_user_fn]=true,
        [_run_user_coro_fn]=true,
        [_run_core]=true,
        [_run_core_fn]=true,
        [_run_core_coro]=true,
        [_run_core_coro_fn]=true,
        [table.base]=true,
        [table.baseinto]=true,
        [table.freeze]=true,
        [table.isfrozen]=true,
        [table.clear]=true,
        [table.overwrite]=true,
        [table.reference]=true,
        [user_env.loadstring]=true,
        [user_env.collectgarbage]=true,
        [core_env.trust_core_function]=true,
        [core_env.add_to_user_env]=true,
        [core_env.erase_user_env]=true,
        [core_env.create_new_user_env]=true,
        [core_env.change_user_env]=true,
        [core_env.rawpairs]=true
    }) do
        protected_functions[k]=v
        core_functions[k]=v
    end
    for k,v in pairs({
        [user_env.rawset]=true,
        [user_env.rawget]=true,
        [user_env.rawlen]=true,
        [user_env.rawequal]=true,
        [user_env.next]=true,
    }) do
        protected_functions[k]=v
    end
    function _G.load_class(class_name,class_constructor,class_constants_and_funcs)
        core_env[class_name] = table.base(class_constants_and_funcs,{
            new=class_constructor
        })
    end
    function _G.load_core_env(name,object)
        core_env[name]=object
    end
    function _G.finish_post_lua()
        _G.load_class = nil
        _G.load_core_env = nil
        _G.finish_post_lua = nil
        local function print_serial(func_to_run)
            return protect_fn(function(...)
                local buf = ""
                for i,v in ipairs({...}) do
                    if i == 1 then
                        buf = buf..tostring(v)
                    else
                        buf = buf.."\t"..tostring(v)
                    end
                end
                func_to_run(...)
            end)
        end
        user_env.print = print_serial(core_env._print_str)
        core_env.print = user_env.print
        user_env.warn = print_serial(core_env._warn_str)
        core_env.warn = user_env.warn
        user_env.log_error = print_serial(core_env._err_str)
        core_env.log_error = user_env.logerror
        -- load user_env by default
        core_env.change_user_env(core_env.create_new_user_env())
    end
end