extends Node

var clash_resource = preload("res://resources/test-clash.tres")

func _ready() -> void:
	# The preloaded resource is already an instance of OneClash
	print("Type: ", clash_resource.get_class())
	print("Has commit: ", clash_resource.has_method("commit"))
	var clash: OneClash = clash_resource
	clash.targeted.initialise_changeables()
	clash.attacker.initialise_changeables()
	var results = clash.commit()
	print("Clash results: ", results)
