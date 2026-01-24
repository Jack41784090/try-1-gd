class_name VisualNovelController extends Control

## Controls Visual Novel state machine and dialogue progression
## Extracted from TrainingGUI for better separation of concerns

@onready var character_container: HBoxContainer = $CharacterContainer
# @onready var hint_icon: TextureRect = $PanelContainer/MainVBox/MainScreenArea/HintIcon
@onready var dialogue_box: PanelContainer = $DialogueBox
@onready var speaker_label: Label = $DialogueBox/MarginContainer/VBoxContainer/SpeakerLabel
@onready var dialogue_label: Label = $DialogueBox/MarginContainer/VBoxContainer/DialogueLabel
@onready var advance_prompt: Label = $DialogueBox/AdvancePrompt

signal chain_completed()
signal dialogue_advanced(index: int, total: int)

var event_chain_queue = []
var is_playing_chain = false
var current_chain: EventChain
var current_index: int = 0
var character_ids_in_chain: Array[String] = []
var portrait_cache: Dictionary = {}

func _ready() -> void:
	dialogue_box.gui_input.connect(_on_dialogue_box_clicked)

func exit() -> void:
	character_container.visible = false
	dialogue_box.visible = false
	speaker_label.visible = false
	dialogue_label.visible = false
	advance_prompt.visible = false
	
func enter() -> void:
	character_container.visible = true
	dialogue_box.visible = true
	speaker_label.visible = true
	dialogue_label.visible = true
	advance_prompt.visible = true

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
		reset()
	else:
		print("Advanced to dialogue %d/%d" % [current_index + 1, current_chain.get_dialogue_count()])
		_vn_display_current_dialogue()

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


#region Event Chain Management

func queue_event_chain(chain_path: String) -> void:
	event_chain_queue.append(chain_path)
	print("TrainingScreen: Queued event chain: %s (queue size: %d)" % [chain_path, event_chain_queue.size()])
	# Don't auto-play here - let the caller decide when to start playback

## Doesn't enable the visibility some neccessary UI's. That will require the main UI script to do.
func play_next_queued_chain() -> bool:
	var empty = event_chain_queue.is_empty()
	if not empty:
		is_playing_chain = true
		var chain = load(event_chain_queue.pop_front())
		print("TrainingScreen: Playing EventChain: %s (%d dialogues)" % [chain.chain_id, chain.get_dialogue_count()])
		load_chain(chain)
		_vn_display_current_dialogue()
	return empty


#endregion

#region Visual Novel Functions

func _on_dialogue_box_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			advance()

func _vn_display_current_dialogue() -> void:
	var dialogue_data = get_current_dialogue_data()
	if dialogue_data.is_empty():
		return
	
	speaker_label.text = dialogue_data.get("speaker_name", "")
	dialogue_label.text = dialogue_data.get("line_spoken", "")
	_update_vn_background(dialogue_data.get("background_id", ""))
	_update_vn_portraits(dialogue_data.get("on_screen_character_ids", []))
	advance_prompt.text = "Click to continue %s" % get_progress_text()
	
func _update_vn_background(_bg_id: String) -> void:
	pass

func _update_vn_portraits(character_ids: Array) -> void:
	for child in character_container.get_children():
		child.queue_free()
	for char_id in character_ids:
		if char_id is String:
			character_container.add_child(get_or_create_portrait(char_id))

# func _on_vn_chain_completed() -> void:
# 	vn_controller.reset()
# 	await _animate_stat_changes()
# 	_capture_stat_snapshot()
	
# 	if event_chain_queue.size() > 0:
# 		print("[StatAnimation] More chains in queue (%d), playing next..." % event_chain_queue.size())
# 		_play_next_queued_chain()
# 	else:
# 		print("[StatAnimation] All chains completed")
# 		vn_completed.emit()

# func _on_vn_dialogue_advanced(_index: int, _total: int) -> void:
# 	_vn_display_current_dialogue()

# func _on_vn_completed_signal() -> void:
# 	is_playing_chain = false
# 	_exit_from_vn_to_strategy()

#endregion
