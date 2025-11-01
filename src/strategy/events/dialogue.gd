extends Resource
class_name Dialogue

## A single dialogue entry in an EventChain
## Contains speaker info, text, character display, and background

@export var on_screen_character_ids: Array[String] = []
@export var speaker_name: String = ""
@export var line_spoken: String = ""
@export var background_id: String = ""
@export var triggers: Array = []

func _init(config: Dictionary = {}) -> void:
	if config.is_empty():
		return
	
	var char_ids = config.get("on_screen_character_ids", [])
	if char_ids is Array:
		for char_id in char_ids:
			if char_id is String:
				on_screen_character_ids.append(char_id)
	
	background_id = config.get("background", 
		config.get("background_id", ""))
	
	triggers = config.get("triggers", [])
	
	# Parse the "speak" object to extract speaker and text
	if config.has("speak"):
		var speak_data = config["speak"]
		if speak_data is Dictionary:
			# Extract speaker name and line from the speak dictionary
			for speaker in speak_data.keys():
				if speaker == "triggers":
					continue  # Skip the triggers key
				speaker_name = speaker
				var line_data = speak_data[speaker]
				if line_data is String:
					line_spoken = line_data
				break
			
			# Extract triggers if present in speak object
			if speak_data.has("triggers"):
				triggers = speak_data["triggers"]
	else:
		# Fallback to old format
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
