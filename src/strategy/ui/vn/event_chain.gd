extends Resource

class_name EventChain

## EventChain: a cinematic timeline of instructions (dialogue, camera, character
## movement, control gates) fired at absolute timestamps.
##
## The "setting" defines initial character positions before the timeline starts.
## The "timeline" is a flat, time-sorted array of CinematicInstruction subclasses.

@export var chain_id: String = ""
@export var chain_name: String = ""
@export var character_ids: Array[String] = []
@export var setting: Array[StagePosition] = []
@export var timeline: Array[CinematicInstruction] = []


func _init(config: Dictionary = { }) -> void:
	if config.is_empty():
		return

	chain_id = config.get("chain_id", config.get("id", ""))
	chain_name = config.get("chain_name", config.get("name", ""))

	var raw_ids = config.get("character_ids", [])
	if raw_ids is Array:
		for id in raw_ids:
			if id is String:
				character_ids.append(id)

	var raw_setting = config.get("setting", [])
	if raw_setting is Array:
		for entry in raw_setting:
			if entry is StagePosition:
				setting.append(entry)
			elif entry is Dictionary:
				setting.append(
					StagePosition.new(
						entry.get("character_id", ""),
						Vector2(entry.get("x", 0.0), entry.get("y", 0.0)),
						entry.get("face_direction", 1),
					),
				)

	var raw_timeline = config.get("timeline", [])
	if raw_timeline is Array:
		for entry in raw_timeline:
			if entry is CinematicInstruction:
				timeline.append(entry)
			elif entry is Dictionary:
				var inst = _parse_instruction(entry)
				if inst:
					timeline.append(inst)

	if character_ids.is_empty():
		_extract_character_ids()


func _extract_character_ids() -> void:
	var char_set: Dictionary = { }
	for pos in setting:
		if not pos.character_id.is_empty():
			char_set[pos.character_id] = true
	for inst in timeline:
		if inst is DialogueInstruction:
			if not inst.speaker_name.is_empty() and inst.speaker_name != "narrator":
				char_set[inst.speaker_name] = true
		elif inst is CharacterInstruction:
			if not inst.character_id.is_empty():
				char_set[inst.character_id] = true
		elif inst is CameraInstruction:
			if not inst.target_character_id.is_empty():
				char_set[inst.target_character_id] = true
			for cid in inst.include_character_ids:
				if not cid.is_empty():
					char_set[cid] = true
	for key in char_set.keys():
		if key is String:
			character_ids.append(key)


func set_character_ids(ids: Array[String]) -> void:
	character_ids.clear()
	character_ids.append_array(ids)


func get_all_character_ids() -> Array[String]:
	return character_ids.duplicate()


func get_timeline_duration() -> float:
	if timeline.is_empty():
		return 0.0
	var max_time: float = 0.0
	for inst in timeline:
		var end = inst.time + inst.duration
		if end > max_time:
			max_time = end
	return max_time


func get_instruction_count() -> int:
	return timeline.size()


func get_dialogue_count() -> int:
	var count: int = 0
	for inst in timeline:
		if inst is DialogueInstruction:
			count += 1
	return count


static func _parse_instruction(data: Dictionary) -> CinematicInstruction:
	var type_str: String = data.get("type", "dialogue")
	match type_str:
		"dialogue":
			return DialogueInstruction.new(data)
		"camera":
			return CameraInstruction.new(data)
		"character":
			return CharacterInstruction.new(data)
		"gate":
			return GateInstruction.new(data)
		_:
			push_error("Unknown instruction type: %s" % type_str)
			return null


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
