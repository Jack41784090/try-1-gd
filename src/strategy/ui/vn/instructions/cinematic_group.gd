class_name CinematicGroup extends CinematicInstruction

## duration > 0 runs children in parallel with occupation-based timing; duration <= 0 runs them sequentially with auto-calculated start times.

## If true, group pauses after all children finish and waits for player input.
@export var gated_group: bool = false

## Holds both CinematicInstruction and CinematicGroup so an authored group round-trips through ResourceSaver/load as a reusable .tres.
@export var children: Array[CinematicInstruction] = []


func is_parallel() -> bool:
	return duration > 0.0


static func _estimate_typewriter_duration(text: String) -> float:
	if text.is_empty():
		return 0.0
	var total: float = 0.0
	for i in text.length():
		var ch = text[i]
		match ch:
			".", "!", "?":
				total += 0.22
			",", ";", ":":
				total += 0.12
			_:
				total += 0.04
	return total


static func from_dict(data: Dictionary) -> CinematicGroup:
	var group = CinematicGroup.new()
	group.id = data.get("id", "")
	group.duration = data.get("duration", 0.0)
	group.occupation = data.get("occupation", OCCUPATION_UNSET)
	group.gated_group = data.get("gated_group", data.get("auto_gate", false))
	group.after_id = data.get("after_id", "")
	group.after_offset = data.get("after_offset", 0.0)

	var raw_children = data.get("children", [])
	if raw_children is Array:
		for entry in raw_children:
			if entry is Dictionary:
				var type_str: String = entry.get("type", "")
				if type_str == "group":
					group.children.append(CinematicGroup.from_dict(entry))
				else:
					var inst = parse_instruction(entry)
					if inst:
						group.children.append(inst)
	return group


static func parse_instruction(data: Dictionary) -> CinematicInstruction:
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
			assert(false, "Unknown instruction type: %s" % type_str)
			return null
