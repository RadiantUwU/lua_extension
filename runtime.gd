extends RefCounted
class_name LuaRuntimeController

var api :LuaAPI

var _k := ""
var _mutex:= Mutex.new()
var _immediate_change_hook:=Callable()
var _lua_hook:=Callable()
var _is_coref:=Callable()
var _hook_settings_flags:=0
var _hook_settings_count:=0

signal info_log(s: String)
signal warn_log(s: String)
signal err_log(s: String)

func _request_hook_change(hook: Callable,flags: int,count:=0)->void:
	_mutex.lock()
	_immediate_change_hook = hook
	_hook_settings_flags = flags
	_hook_settings_count = count
	_mutex.unlock()

func _hook_change_requested()->bool:
	_mutex.lock()
	var v := _immediate_change_hook.is_valid()
	_mutex.unlock()
	return v

func _get_hook_to_change()->Callable:
	_mutex.lock()
	var c := _immediate_change_hook
	_immediate_change_hook = Callable()
	_mutex.unlock()
	return c

func _get_hook_flags()->int:
	_mutex.lock()
	var f := _hook_settings_flags
	_mutex.unlock()
	return f

func _get_hook_count()->int:
	_mutex.lock()
	var c := _hook_settings_count
	_mutex.unlock()
	return c

var terminate_msg:="thread exhausted execution time"
var _term_attempts:=0

func _suspend_hook():
	if _hook_change_requested():
		api.set_hook(_get_hook_to_change(),_get_hook_flags(),_get_hook_count())
	else:
		if not _is_coref.call():
			api.get_running_coroutine().yield_state([])

func _terminate_hook():
	if _hook_change_requested():
		api.set_hook(_get_hook_to_change(),_get_hook_flags(),_get_hook_count())
	else:
		if not _is_coref.call():
			_term_attempts +=1
			if _term_attempts > 15:
				api.set_hook(_terminate_hook,LuaAPI.HOOK_MASK_COUNT,1)
				_term_attempts = -1000000
			return LuaError.new_error(terminate_msg,LuaError.ERR_RUNTIME)

func _typeof_str_lua(v: Variant)->String:
	match typeof(v):
		TYPE_AABB:
			return "AABB"
		TYPE_ARRAY:
			return "table"
		TYPE_BASIS:
			return "Basis"
		TYPE_BOOL:
			return "boolean"
		TYPE_CALLABLE:
			return "function"
		TYPE_COLOR:
			return "Color"
		TYPE_DICTIONARY:
			return "table"
		TYPE_FLOAT:
			return "number"
		TYPE_INT:
			return "number"
		TYPE_NIL:
			return "nil"
		TYPE_NODE_PATH:
			return "NodePath"
		TYPE_OBJECT:
			if v is LuaCoroutine:
				return "thread"
			return "Object"
		TYPE_PACKED_BYTE_ARRAY:
			return "PackedByteArray"
		TYPE_PACKED_COLOR_ARRAY:
			return "PackedColorArray"
		TYPE_PACKED_FLOAT32_ARRAY:
			return "PackedFloat32Array"
		TYPE_PACKED_FLOAT64_ARRAY:
			return "PackedFloat64Array"
		TYPE_PACKED_INT32_ARRAY:
			return "PackedFloatInt32Array"
		TYPE_PACKED_INT64_ARRAY:
			return "PackedFloatInt64Array"
		TYPE_PACKED_STRING_ARRAY:
			return "PackedStringArray"
		TYPE_PACKED_VECTOR2_ARRAY:
			return "PackedVector2Array"
		TYPE_PACKED_VECTOR3_ARRAY:
			return "PackedVector3Array"
		TYPE_PLANE:
			return "Plane"
		TYPE_PROJECTION:
			return "Projection"
		TYPE_QUATERNION:
			return "Quaternion"
		TYPE_RECT2:
			return "Rect2"
		TYPE_RECT2I:
			return "Rect2i"
		TYPE_RID:
			return "RID"
		TYPE_SIGNAL:
			return "Signal"
		TYPE_STRING:
			return "string"
		TYPE_STRING_NAME:
			return "StringName"
		TYPE_TRANSFORM2D:
			return "Transform2D"
		TYPE_TRANSFORM3D:
			return "Transform3D"
		TYPE_VECTOR2:
			return "Vector2"
		TYPE_VECTOR2I:
			return "Vector2i"
		TYPE_VECTOR3:
			return "Vector3"
		TYPE_VECTOR3I:
			return "Vector3i"
		TYPE_VECTOR4:
			return "Vector4"
		TYPE_VECTOR4I:
			return "Vector4i"
		_:
			return "<unknown>"

func set_lua_hook(h,flags: int=0,count: int=0)->LuaError:
	if typeof(h) == TYPE_NIL:
		h = Callable()
	elif typeof(h) != TYPE_CALLABLE:
		return LuaError.new_error("h expected function|nil, got "+_typeof_str_lua(h))
	_lua_hook = h
	api.set_hook(_normal_hook,flags,count)
	return null

func set_lua_is_core(h)->LuaError:
	if typeof(h) != TYPE_CALLABLE:
		return LuaError.new_error("h expected function, got "+_typeof_str_lua(h))
	_is_coref = h
	return null

func _normal_hook():
	if _hook_change_requested():
		api.set_hook(_get_hook_to_change(),_get_hook_flags(),_get_hook_count())
	elif _lua_hook.is_valid():
		_lua_hook.call()

func set_hook(hook: Callable, flags: int, count: int)->void:
	_mutex.lock()
	_request_hook_change(hook,flags,count)
	_mutex.unlock()

func _print_str(s: String)->void:
	print(s)
	info_log.emit(s)

func _print_warn(s: String)->void:
	push_warning(s)
	warn_log.emit(s)

func _print_error(s: String)->void:
	push_error(s)
	printerr(s)
	err_log.emit(s)

func _init()->void:
	var l = LuaAPI.new()
	_mutex.lock()
	l.set_hook(_normal_hook,LuaAPI.HOOK_MASK_COUNT,512)
	assert(not api,"LuaAPI already bound.")
	api = l
	l.bind_libraries(["basic","base","coroutine","debug","io","math","os","package","string","table","utf8"])
	l.push_variant("LuaCrypto",LuaCrypto.new)
	l.push_variant("core_set_hook",set_lua_hook)
	l.push_variant("core_set_is_core_f",set_lua_is_core)
	l.push_variant("core_suspend_all",_suspend_all)
	l.push_variant("core_terminate_all",_terminate_all)
	l.push_variant("core_restore",_restore)
	if _k == "":
		var c := Crypto.new()
		_k = c.generate_random_bytes(256).get_string_from_ascii()
	l.push_variant("core_key",_k)
	var e := l.do_file("res://addons/lua_extension/init.lua")
	if e:
		push_error(e.message)
	var _load_class
	_load_class = func(s: String):
		var enums:= ClassDB.class_get_enum_list(s)
		var int_consts:= ClassDB.class_get_integer_constant_list(s)
		var consts := {}
		for enum_ in enums:
			var enum_tbl:={}
			var i := 0
			for k in ClassDB.class_get_enum_constants(s,enum_):
				enum_tbl[k] = i
				i+=1
			consts[enum_] = enum_tbl
		for int_const in int_consts:
			consts[int_const] = ClassDB.class_get_integer_constant(s,int_const)
		l.call_function("load_class",[
			s,
			ClassDB.instantiate.bind(s),
			consts
		])
	for cls in ClassDB.get_class_list():
		_load_class.call(cls)
	for s in Engine.get_singleton_list():
		l.call_function("load_core_env",[s,Engine.get_singleton(s)])
	l.call_function("load_core_env",["scene_tree",Engine.get_main_loop()])
	l.call_function("load_core_env",["_print_str",_print_str])
	l.call_function("load_core_env",["_warn_str",_print_warn])
	l.call_function("load_core_env",["_err_str",_print_error])
	l.call_function("finish_post_lua",[])
	_mutex.unlock()

func suspend_all()->void:
	_mutex.lock()
	_request_hook_change(_suspend_hook,LuaAPI.HOOK_MASK_COUNT,1)
	_mutex.unlock()

func terminate_all()->void:
	_mutex.lock()
	_term_attempts = 0
	_request_hook_change(_terminate_hook,LuaAPI.HOOK_MASK_COUNT,512)
	_mutex.unlock()

func restore()->void:
	_mutex.lock()
	api.set_hook(_normal_hook,LuaAPI.HOOK_MASK_COUNT,512)
	_mutex.unlock()

func _suspend_all()->void:
	_mutex.lock()
	api.set_hook(_suspend_hook,LuaAPI.HOOK_MASK_COUNT,1)
	_mutex.unlock()

func _terminate_all()->void:
	_mutex.lock()
	_term_attempts = 0
	api.set_hook(_terminate_hook,LuaAPI.HOOK_MASK_COUNT,512)
	_mutex.unlock()

func _restore()->void:
	_mutex.lock()
	api.set_hook(_normal_hook,LuaAPI.HOOK_MASK_COUNT,512)
	_mutex.unlock()

func run_as_user_main_thread(code: String)->LuaError:
	return api.do_string(code)

func run_as_core_main_thread(code: String)->LuaError:
	return api.call_function("_run_core",[_k,code])

func run_as_user(code: String)->LuaCoroutine:
	var c:=api.new_coroutine()
	c.load_string(code)
	return c

func run_as_core(code: String)->LuaCoroutine:
	return api.call_function("_run_core_coro",[_k,code])

func run_as_user_main_thread_fn(fn: String,args:=[])->LuaError:
	args = args.duplicate()
	args.push_front(fn)
	return api.call_function("_run_user_fn",args)

func run_as_core_main_thread_fn(fn: String,args:=[])->LuaError:
	args = args.duplicate()
	args.push_front(fn)
	return api.call_function("_run_user_fn",args)

func run_as_user_fn(fn: Callable)->LuaCoroutine:
	return api.call_function("_run_user_coro_fn",[fn])

func run_as_core_fn(fn: Callable)->LuaCoroutine:
	return api.call_function("_run_core_coro_fn",[_k,fn])
