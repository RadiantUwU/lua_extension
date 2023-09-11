extends RefCounted
class_name LuaCryptoKey

var k: CryptoKey

func __index(k: String):
	return null

func _to_string():
	return "<LuaCryptoKey object>"
