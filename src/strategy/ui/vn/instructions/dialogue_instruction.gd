extends CinematicInstruction

class_name DialogueInstruction

## Pure dialogue content — stage directions (walk, face, behavior) are separate CharacterInstruction entries.

## Empty or "narrator" routes to the narrator textbox.
@export var speaker_name: String = ""

@export var line_spoken: String = ""

## When true, previous speech bubbles stay on screen.
@export var keep_previous_bubbles: bool = false

@export var expression_override: String = ""


func _init(config: Dictionary = { }) -> void:
	super(config)
	if config.is_empty():
		return
	speaker_name = config.get("speaker_name", "")
	line_spoken = config.get("line_spoken", "")
	keep_previous_bubbles = config.get("keep_previous_bubbles", false)
	expression_override = config.get("expression_override", "")

	if config.has("speak"):
		var speak_data = config["speak"]
		if speak_data is Dictionary:
			for speaker in speak_data.keys():
				speaker_name = speaker
				var line_data = speak_data[speaker]
				if line_data is String:
					line_spoken = line_data
				break
