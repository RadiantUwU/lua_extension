extends RefCounted
class_name LuaCrypto

var c:=Crypto.new()

func constant_time_compare(s1:String,s2:String)->bool:
	return c.constant_time_compare(s1.to_ascii_buffer(),s2.to_ascii_buffer())

func generate_random_bytes(length:int)->String:
	return c.generate_random_bytes(length).get_string_from_ascii()

func encrypt(key: LuaCryptoKey,text:String)->String:
	return c.encrypt(key.k,text.to_ascii_buffer()).get_string_from_ascii()

func decrypt(key: LuaCryptoKey,encrypted:String)->String:
	return c.decrypt(key.k,encrypted.to_ascii_buffer()).get_string_from_ascii()

func generate_rsa_key(bits: int)->LuaCryptoKey:
	var k := LuaCryptoKey.new()
	k.k = c.generate_rsa(bits)
	return k

func lua_fields():
	return ["constant_time_compare","generate_random_bytes","encrypt","decrypt","generate_rsa_key"]

var lua_metatable := LuaDefaultObjectMetatable.new()

func _init():
	lua_metatable.permissive = false
