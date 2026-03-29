class_name ActivityHandler
extends RefCounted


func can_execute(_activity, _squad, _location) -> bool:
	return true


func execute(_context: Dictionary, result):
	return result
