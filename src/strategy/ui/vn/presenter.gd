class_name VnPresenter extends Node

var view: VnView

var event_chain_queue = []
var is_playing_chain = false
var current_chain: EventChain
var current_index: int = 0
var character_ids_in_chain: Array[String] = []

func bind_view(v: VnView) -> void:
	view = v

func queue_event_chain(chain_path: String) -> void:
	event_chain_queue.append(chain_path)
	print("[VnPresenter] Queued event chain: %s (queue size: %d)" % [chain_path, event_chain_queue.size()])

## Returns true if queue is empty (nothing to play), false if chain started playing
func play_next_queued_chain() -> bool:
	var empty = event_chain_queue.is_empty()
	if not empty:
		is_playing_chain = true
		var chain = load(event_chain_queue.pop_front())
		print("[VnPresenter] Playing EventChain: %s (%d dialogues)" % [chain.chain_id, chain.get_dialogue_count()])
		_load_chain(chain)
		_display_current_dialogue()
	return empty

func on_advance() -> void:
	if not current_chain:
		push_warning("No chain loaded, cannot advance")
		return
	current_index += 1
	if _is_complete():
		print("EventChain '%s' completed (showed %d/%d dialogues)" % [current_chain.chain_id, current_index, current_chain.get_dialogue_count()])
		view.chain_completed.emit()
		_reset()
	else:
		print("Advanced to dialogue %d/%d" % [current_index + 1, current_chain.get_dialogue_count()])
		_display_current_dialogue()

func has_chain() -> bool:
	return current_chain != null

func _load_chain(chain: EventChain) -> bool:
	if not chain:
		push_error("Cannot load null EventChain")
		return false
	if chain.get_dialogue_count() == 0:
		push_warning("EventChain '%s' has no dialogues, completing immediately" % chain.chain_id)
		current_chain = null
		view.chain_completed.emit()
		return false
	current_chain = chain
	current_index = 0
	character_ids_in_chain = chain.get_all_character_ids()
	print("[VnPresenter] Loaded chain '%s' with %d dialogues" % [chain.chain_id, chain.get_dialogue_count()])
	return true

func _display_current_dialogue() -> void:
	var data = _get_current_dialogue_data()
	if data.is_empty():
		return
	view.display_dialogue(data, _get_progress_text())

func _get_current_dialogue_data() -> Dictionary:
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

func _is_complete() -> bool:
	if not current_chain:
		return true
	return current_index >= current_chain.get_dialogue_count()

func _reset() -> void:
	current_chain = null
	current_index = 0
	character_ids_in_chain.clear()

func _get_progress_text() -> String:
	if not current_chain:
		return ""
	return "(%d/%d)" % [current_index + 1, current_chain.get_dialogue_count()]
