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
@export var timeline: Array[CinematicInstruction] = []:
	set(value):
		timeline = value
		resolve_after_ids()

enum TransitionType { NONE, FADE_FROM_BLACK, QUICK, CUT_TO_BLACK, CROSSFADE }
var transition_type: TransitionType = TransitionType.QUICK

## Root group for group-based playback. Null when using legacy flat timeline.
var root_group: CinematicGroup = null


func _init(config: Dictionary = { }) -> void:
	# Constructs an EventChain from a config dict (from .tres @export or JSON parse)
	# Steps:
	#   1. Extract chain_id and chain_name from config (supports both "chain_id" and "id" keys)
	#   2. Build character_ids typed array from raw list (iterative append for type safety)
	#   3. Build setting array: accepts StagePosition resources or raw dicts → StagePosition.new()
	#   4. Build timeline array: accepts CinematicInstruction resources or raw dicts → _parse_instruction()
	#   5. If no character_ids provided, auto-extract from setting + timeline instructions
	# e.g., config={chain_id:"camp", setting:[{character_id:"Hans", x:100, y:50, face_direction:1}],
	#                timeline:[{type:"dialogue", speaker_name:"Hans", line:"Hi", time:0}]}
	#   → EventChain(chain_id="camp", character_ids=["Hans"], setting=[StagePos], timeline=[DialogueInst])
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
				setting.append(StagePosition.from_dict(entry))

	var raw_timeline = config.get("timeline", null)
	if raw_timeline is Dictionary and raw_timeline.get("type", "") == "group":
		root_group = CinematicGroup.from_dict(raw_timeline)
	elif raw_timeline is Array:
		for entry in raw_timeline:
			if entry is CinematicInstruction:
				timeline.append(entry)
			elif entry is Dictionary:
				var inst = CinematicGroup.parse_instruction(entry)
				if inst:
					timeline.append(inst)

	var trans_str: String = config.get("transition_type", "")
	if not trans_str.is_empty():
		transition_type = _parse_transition_type(trans_str)

	if character_ids.is_empty():
		_extract_character_ids()

	if root_group:
		_extract_character_ids_from_group(root_group)

	resolve_after_ids()


func resolve_after_ids() -> void:
	if timeline.is_empty():
		return

	var id_map: Dictionary = {}
	for inst in timeline:
		if inst is CinematicInstruction and not inst.id.is_empty():
			assert(not id_map.has(inst.id), "Duplicate instruction id: %s" % inst.id)
			id_map[inst.id] = inst

	if id_map.is_empty():
		return

	var max_passes = timeline.size()
	for pass_num in max_passes:
		var changed = false
		for inst in timeline:
			if inst is CinematicInstruction and inst.has_after_dependency():
				assert(id_map.has(inst.after_id), "after_id '%s' not found in timeline" % inst.after_id)
				var ref = id_map[inst.after_id]
				var resolved_time = ref.time + ref.duration + inst.after_offset
				if absf(inst.time - resolved_time) > 0.001:
					inst.time = resolved_time
					changed = true
		if not changed:
			break


func _extract_character_ids() -> void:
	# Auto-discovers all character IDs referenced anywhere in the chain (setting + timeline)
	# Uses a Dictionary as a set for deduplication, then appends unique IDs to character_ids
	# Scans: setting positions, DialogueInstruction speakers, CharacterInstruction targets,
	#        CameraInstruction targets and include lists
	# e.g., setting=[Hans], timeline=[Dialogue(Fritz), Camera(include=[Hans,Fritz])]
	#   → char_set={Hans:true, Fritz:true} → character_ids=["Hans", "Fritz"]
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


func _extract_character_ids_from_group(group: CinematicGroup) -> void:
	var char_set: Dictionary = {}
	for cid in character_ids:
		char_set[cid] = true
	_collect_group_characters(group, char_set)
	character_ids.clear()
	for key in char_set.keys():
		if key is String:
			character_ids.append(key)


func _collect_group_characters(group: CinematicGroup, char_set: Dictionary) -> void:
	for child in group.children:
		if child is CinematicGroup:
			_collect_group_characters(child, char_set)
		elif child is DialogueInstruction:
			if not child.speaker_name.is_empty() and child.speaker_name != "narrator":
				char_set[child.speaker_name] = true
		elif child is CharacterInstruction:
			if not child.character_id.is_empty():
				char_set[child.character_id] = true
		elif child is CameraInstruction:
			if not child.target_character_id.is_empty():
				char_set[child.target_character_id] = true
			for cid in child.include_character_ids:
				if not cid.is_empty():
					char_set[cid] = true


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
	return CinematicGroup.parse_instruction(data)


static func load_from_json_file(file_path: String) -> EventChain:
	# Loads an EventChain from a JSON file: open → parse JSON → construct EventChain from dict
	# e.g., load_from_json_file("res://resources/jsons/camp_fire.json") → EventChain with timeline of instructions
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


func has_root_group() -> bool:
	return root_group != null


static func _parse_transition_type(s: String) -> TransitionType:
	match s.to_upper():
		"NONE":
			return TransitionType.NONE
		"FADE_FROM_BLACK":
			return TransitionType.FADE_FROM_BLACK
		"CUT_TO_BLACK":
			return TransitionType.CUT_TO_BLACK
		"CROSSFADE":
			return TransitionType.CROSSFADE
		_:
			return TransitionType.QUICK


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
