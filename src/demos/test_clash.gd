extends Node

var clash_resource = preload("res://resources/test-clash.tres")

func _ready() -> void:
	# The preloaded resource is already an instance of OneClash
	print("Type: ", clash_resource.get_class())
	print("Has commit: ", clash_resource.has_method("commit"))
	var results = clash_resource.commit()
	print("Clash results: ", results)
