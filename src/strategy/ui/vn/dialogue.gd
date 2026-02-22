extends Resource
class_name Dialogue

## A single dialogue entry in an EventChain.
## Stage-aware: when the speaker has a rig on the warrior stage, displays as a
## speech bubble above the character. Falls back to a narrator textbox otherwise.

## Unique identifier within the chain. Required for after_id, interrupt references.
@export var id: String = ""

## Speaker identification
@export var speaker_name: String = ""
@export var line_spoken: String = ""

## Characters present during this dialogue (used for stage spawning/tracking)
@export var on_screen_character_ids: Array[String] = []

## Background reference (for future background rendering)
@export var background_id: String = ""

## Bubble behavior — when true, overlays new bubble without dismissing previous ones
@export var keep_previous_bubbles: bool = false

## Camera target override — focus on this character ID instead of the speaker
@export var camera_target: String = ""

## Expression override — play this expression on the speaker's rig
@export var expression_override: String = ""

## Sequencing — delay in milliseconds before this dialogue appears
@export var delay_ms: int = 0

## Sequencing — only show after the dialogue with this id has been displayed
@export var after_id: String = ""

## Sequencing — auto-advance after this many ms (0 = manual advance only)
@export var duration_ms: int = 0

## Interruption — this dialogue gets cut short when the dialogue with interrupt_by_id
## reaches the keyword interrupt_on_word. Both fields must be set.
@export var interrupt_by_id: String = ""
@export var interrupt_on_word: String = ""

## Stage movement — walk the speaker to these stage coordinates.
## Vector2.ZERO means no movement.
@export var walk_to: Vector2 = Vector2.ZERO

## Animation behavior override for the speaker (empty = default TALKING for speakers).
## Valid values: idle, walking, attacking, defending, hurt, dying, talking, gesturing
@export var behavior: String = ""

## Face direction override: 0 = no change, -1 = face left, 1 = face right
@export_range(-1, 1) var face_direction: int = 0

## Interactive triggers at text positions
@export var triggers: Array = []

func _init(config: Dictionary = {}) -> void:
	if config.is_empty():
		return

	id = config.get("id", "")

	var char_ids = config.get("on_screen_character_ids", [])
	if char_ids is Array:
		for char_id in char_ids:
			if char_id is String:
				on_screen_character_ids.append(char_id)

	background_id = config.get("background", config.get("background_id", ""))
	keep_previous_bubbles = config.get("keep_previous_bubbles", false)
	camera_target = config.get("camera_target", "")
	expression_override = config.get("expression_override", "")

	delay_ms = config.get("delay_ms", 0)
	after_id = config.get("after_id", "")
	duration_ms = config.get("duration_ms", 0)
	interrupt_by_id = config.get("interrupt_by_id", "")
	interrupt_on_word = config.get("interrupt_on_word", "")

	var wt = config.get("walk_to", null)
	if wt is Vector2:
		walk_to = wt
	elif wt is Dictionary:
		walk_to = Vector2(wt.get("x", 0.0), wt.get("y", 0.0))

	behavior = config.get("behavior", "")
	face_direction = config.get("face_direction", 0)

	triggers = config.get("triggers", [])

	if config.has("speak"):
		var speak_data = config["speak"]
		if speak_data is Dictionary:
			for speaker in speak_data.keys():
				if speaker == "triggers":
					continue
				speaker_name = speaker
				var line_data = speak_data[speaker]
				if line_data is String:
					line_spoken = line_data
				break

			if speak_data.has("triggers"):
				triggers = speak_data["triggers"]
	else:
		speaker_name = config.get("speaker_name", "")
		line_spoken = config.get("line_spoken", "")

func set_on_screen_character_ids(ids: Array[String]) -> void:
	on_screen_character_ids.clear()
	on_screen_character_ids.append_array(ids)

func has_triggers() -> bool:
	return triggers.size() > 0

func get_trigger_at_position(text_position: String) -> Dictionary:
	for trigger in triggers:
		if trigger is Dictionary:
			if trigger.has(text_position):
				return trigger[text_position]
	return {}

func has_interrupt() -> bool:
	return not interrupt_by_id.is_empty() and not interrupt_on_word.is_empty()

func has_walk_to() -> bool:
	return walk_to != Vector2.ZERO

func has_after_dependency() -> bool:
	return not after_id.is_empty()

func is_auto_advance() -> bool:
	return duration_ms > 0
