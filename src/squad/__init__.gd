class_name Squad extends Resource

@export var base_data: SquadBaseData
@export var strategic_data: SquadStrategicData
@export var combat_data: SquadCombatData

var _initialized: bool = false

func _duplicate_characters_from_resource() -> void:
	if base_data == null or base_data.characters.is_empty():
		return

	var duplicated_characters: Array[Character] = []
	for i in range(base_data.characters.size()):
		var character = base_data.characters[i]
		if character != null:
			var dup = character.duplicate(true)
			duplicated_characters.append(dup)
			print("  Duplicated character index %d" % i)
	base_data.characters = duplicated_characters

func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	assert(strategic_data != null, "Squad must have strategic_data")
	if base_data != null and not base_data.characters.is_empty():
		_duplicate_characters_from_resource()
		strategic_data.warriors.clear()
		for character in base_data.characters:
			if character != null and character.social != null:
				strategic_data.warriors.append(character.social)
