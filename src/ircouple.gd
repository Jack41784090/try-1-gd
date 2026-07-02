class_name IRCouple
extends RefCounted

@export var resource: Resource
#@export var ref_counted: Object

func _init(_r:Resource,  _i:  RefCounted):
	if _i.has_method(&"irc_instantiate"):
		_i.irc_instantiate(_r)
	pass
