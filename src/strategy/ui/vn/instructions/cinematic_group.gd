class_name CinematicGroup extends Resource

## A group of cinematic instructions and/or child groups.
## Groups with duration > 0 run children in parallel (occupation-based timing).
## Groups with duration <= 0 run children sequentially (auto-calculated start times).

@export var id: String = ""

## If > 0: children run parallel, each child's runtime = occupation × duration.
## If <= 0: children run sequential, each child starts after the previous finishes.
@export var duration: float = 0.0

## Fraction of parent group's duration this child occupies (parallel mode).
## -1 = unset (uses own duration). -2 = FILL (takes remaining time).
@export var occupation: float = -1.0

## If true, group pauses after all children finish and waits for player input.
@export var auto_gate: bool = false

## Trigger dependency on another group/instruction ID.
@export var after_id: String = ""

## Delay in seconds after the referenced item finishes.
@export var after_offset: float = 0.0

## Mixed array of CinematicInstruction and CinematicGroup (both Resource).
## Exported so an authored group round-trips through ResourceSaver/load as a
## reusable .tres cutscene.
@export var children: Array[Resource] = []


const OCCUPATION_FILL: float = -2.0


func is_parallel() -> bool:
	return duration > 0.0


func has_after_dependency() -> bool:
	return not after_id.is_empty()


func get_computed_duration() -> float:
	if is_parallel():
		return duration
	var total: float = 0.0
	for child in children:
		total += _child_duration(child)
	return total


func _child_duration(child) -> float:
	if child is CinematicGroup:
		return child.get_computed_duration()
	elif child is CinematicInstruction:
		if child.duration > 0.0:
			return child.duration
		if child is DialogueInstruction:
			return _estimate_typewriter_duration(child.line_spoken)
		return 0.0
	return 0.0


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
	group.occupation = data.get("occupation", -1.0)
	group.auto_gate = data.get("auto_gate", false)
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
			push_error("Unknown instruction type: %s" % type_str)
			return null
