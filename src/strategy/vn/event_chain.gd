extends Resource
class_name EventChain

## EventChain fires when an Event is triggered, displaying a series of dialogues
## and sometimes offering choices to the player to render different EventEffects


@export var chain_id: String = ""
@export var chain_name: String = ""
@export var character_ids: Array[String] = []
@export var dialogues: Array = []

func _init(config: Dictionary = {}) -> void:
	if config.is_empty():
		return
	
	chain_id = config.get("chain_id", config.get("id", ""))
	chain_name = config.get("chain_name", config.get("name", ""))
	
	var raw_char_ids = config.get("character_ids", [])
	if raw_char_ids is Array:
		for char_id in raw_char_ids:
			if char_id is String:
				character_ids.append(char_id)
	
	var dialogue_configs: Array = config.get("dialogues", [])
	for dialogue_config in dialogue_configs:
		if dialogue_config is Dialogue:
			dialogues.append(dialogue_config)
		elif dialogue_config is Dictionary:
			dialogues.append(Dialogue.new(dialogue_config))
	
	# Auto-populate character_ids from dialogues if not provided
	if character_ids.is_empty():
		_extract_character_ids()

func _extract_character_ids() -> void:
	var char_set: Dictionary = {}
	for dialogue in dialogues:
		if dialogue is Dialogue:
			for char_id in dialogue.on_screen_character_ids:
				char_set[char_id] = true
	# character_ids = char_set.keys() as Array[String]
	var keys = char_set.keys()
	if keys is Array[String]:
		character_ids = keys

func set_character_ids(ids: Array[String]) -> void:
	character_ids.clear()
	character_ids.append_array(ids)

func set_dialogues(dialogue_list: Array) -> void:
	dialogues.clear()
	dialogues.append_array(dialogue_list)

func get_dialogue_count() -> int:
	return dialogues.size()

func get_all_character_ids() -> Array[String]:
	return character_ids.duplicate()

static func load_from_json_file(file_path: String) -> EventChain:
	if not FileAccess.file_exists(file_path):
		push_error("EventChain JSON file not found: " + file_path)
		return null
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open EventChain JSON file: " + file_path)
		return null
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse EventChain JSON: " + json.get_error_message())
		return null
	
	var data = json.get_data()
	if not data is Dictionary:
		push_error("EventChain JSON root must be a Dictionary")
		return null
	
	return EventChain.new(data)

static func load_from_json_string(json_string: String) -> EventChain:
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse EventChain JSON: " + json.get_error_message())
		return null
	
	var data = json.get_data()
	if not data is Dictionary:
		push_error("EventChain JSON root must be a Dictionary")
		return null
	
	return EventChain.new(data)
