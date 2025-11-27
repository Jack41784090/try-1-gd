extends RefCounted
class_name VisualNovelController

## Controls Visual Novel state machine and dialogue progression
## Extracted from TrainingGUI for better separation of concerns

signal chain_completed()
signal dialogue_advanced(index: int, total: int)

var current_chain: EventChain
var current_index: int = 0
var character_ids_in_chain: Array[String] = []
var portrait_cache: Dictionary = {}

func load_chain(chain: EventChain) -> bool:
	if not chain:
		push_error("Cannot load null EventChain")
		return false
	
	if chain.get_dialogue_count() == 0:
		push_warning("EventChain '%s' has no dialogues, completing immediately" % chain.chain_id)
		current_chain = null
		chain_completed.emit()
		return false
	
	current_chain = chain
	current_index = 0
	character_ids_in_chain = chain.get_all_character_ids()
	print("VisualNovelController: Loaded chain '%s' with %d dialogues" % [chain.chain_id, chain.get_dialogue_count()])
	return true

func advance() -> void:
	if not current_chain:
		push_warning("No chain loaded, cannot advance")
		return

	current_index += 1
	if is_complete():
		print("EventChain '%s' completed (showed %d/%d dialogues)" % [current_chain.chain_id, current_index, current_chain.get_dialogue_count()])
		chain_completed.emit()
	else:
		print("Advanced to dialogue %d/%d" % [current_index + 1, current_chain.get_dialogue_count()])
		dialogue_advanced.emit(current_index, current_chain.get_dialogue_count())

func get_current_dialogue_data() -> Dictionary:
	if not current_chain or current_index >= current_chain.get_dialogue_count():
		return {}
	
	var dialogue: Dialogue = current_chain.dialogues[current_index]
	return {
		"speaker_name": dialogue.speaker_name,
		"line_spoken": dialogue.line_spoken,
		"on_screen_character_ids": dialogue.on_screen_character_ids,
		"background_id": dialogue.background_id,
		"triggers": dialogue.triggers,
		"index": current_index,
		"total": current_chain.get_dialogue_count()
	}

func is_complete() -> bool:
	if not current_chain:
		return true
	return current_index >= current_chain.get_dialogue_count()

func reset() -> void:
	current_chain = null
	current_index = 0
	character_ids_in_chain.clear()

func get_or_create_portrait(character_id: String) -> Control:
	if portrait_cache.has(character_id):
		return portrait_cache[character_id].duplicate()
	
	var portrait = ColorRect.new()
	portrait.custom_minimum_size = Vector2(150, 250)
	var hash_val = character_id.hash()
	portrait.color = Color(
		float(hash_val % 100) / 100.0,
		float(int(hash_val / 100.0) % 100) / 100.0,
		float(int(hash_val / 10000.0) % 100) / 100.0, 1.0)
	portrait_cache[character_id] = portrait
	return portrait.duplicate()

func clear_portrait_cache() -> void:
	portrait_cache.clear()

func has_chain() -> bool:
	return current_chain != null

func get_progress_text() -> String:
	if not current_chain:
		return ""
	return "(%d/%d)" % [current_index + 1, current_chain.get_dialogue_count()]
