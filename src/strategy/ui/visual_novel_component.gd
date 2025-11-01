extends RefCounted
class_name VisualNovelComponent

## Logic component for managing EventChain playback
## Does not own UI nodes - emits signals for UI updates

signal dialogue_advanced(index: int)
signal chain_completed
signal display_updated(dialogue_data: Dictionary)

var current_chain: EventChain
var current_index: int = 0
var character_ids_in_chain: Array[String] = []

func load_chain(chain: EventChain) -> void:
	if not chain:
		push_error("VisualNovelComponent: Cannot load null EventChain")
		return
	
	if chain.get_dialogue_count() == 0:
		push_warning("VisualNovelComponent: EventChain '%s' has no dialogues, completing immediately" % chain.chain_id)
		current_chain = null
		chain_completed.emit()
		return
	
	current_chain = chain
	current_index = 0
	character_ids_in_chain = chain.get_all_character_ids()
	
	print("VisualNovelComponent: Loading EventChain '%s' with %d dialogues" % [chain.chain_id, chain.get_dialogue_count()])
	
	if current_chain.get_dialogue_count() > 0:
		_emit_current_dialogue()

func advance() -> void:
	if not current_chain:
		push_warning("VisualNovelComponent: No chain loaded, cannot advance")
		return
	
	if is_complete():
		push_warning("VisualNovelComponent: Chain already complete")
		chain_completed.emit()
		return
	
	current_index += 1
	dialogue_advanced.emit(current_index)
	
	print("VisualNovelComponent: Advanced to dialogue %d/%d" % [current_index + 1, current_chain.get_dialogue_count()])
	
	if is_complete():
		print("VisualNovelComponent: EventChain '%s' completed" % current_chain.chain_id)
		chain_completed.emit()
	else:
		_emit_current_dialogue()

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

func get_all_character_ids() -> Array[String]:
	return character_ids_in_chain

func is_complete() -> bool:
	if not current_chain:
		return true
	return current_index >= current_chain.get_dialogue_count()

func reset() -> void:
	current_chain = null
	current_index = 0
	character_ids_in_chain.clear()

func _emit_current_dialogue() -> void:
	var data = get_current_dialogue_data()
	if not data.is_empty():
		display_updated.emit(data)
