class_name FactionBrain extends RefCounted

var config: FactionBrainConfig

func _init(p_config: FactionBrainConfig = null) -> void:
	if p_config != null:
		config = p_config
	else:
		config = FactionBrainConfig.new()

func produce_directives(_world: World) -> Array[FactionDirective]:
	var directives: Array[FactionDirective] = []
	directives.append(FactionDirective.create_none())
	return directives
