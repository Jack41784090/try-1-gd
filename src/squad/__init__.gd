class_name Squad extends Resource

@export var base_data: SquadBaseData
@export var strategic_data: SquadStrategicData
@export var combat_data: SquadCombatData

## Internal method to duplicate the characters within base_data to prevent resource sharing
func _duplicate_characters_from_resource() -> void:
	var characters = base_data.characters;
	if characters.is_empty():
		print("  WARNING: No characters to duplicate!")
		return
		
	var duplicated_characters: Array[CharacterSocialStats] = []
	for i in range(characters.size()):
		var character = characters[i]
		if character != null:
			var dup = character.duplicate(true)
			dup.id = "%s_copy%d" % [character.id, i]
			duplicated_characters.append(dup)
			print("  Duplicated character: %s -> %s" % [character.id, dup.id])
	characters = duplicated_characters

func _init() -> void:
	assert(base_data != null, "Squad must have base_data")
	assert(strategic_data != null, "Squad must have strategic_data")
	_duplicate_characters_from_resource()
	strategic_data.warriors = base_data.characters.map(func(c): return c.social)
	combat_data.combat_characters = base_data.characters.map(func(c): return c.combat)
