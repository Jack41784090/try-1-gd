class_name VnPresenter extends Node

const BEHAVIOR_MAP: Dictionary = {
	"idle": AnimTypes.Behavior.IDLE,
	"walking": AnimTypes.Behavior.WALKING,
	"attacking": AnimTypes.Behavior.ATTACKING,
	"defending": AnimTypes.Behavior.DEFENDING,
	"hurt": AnimTypes.Behavior.HURT,
	"dying": AnimTypes.Behavior.DYING,
	"talking": AnimTypes.Behavior.TALKING,
	"gesturing": AnimTypes.Behavior.GESTURING,
}

var view: VnView
var stage_presenter: StagePresenter

var event_chain_queue = []
var is_playing_chain = false
var current_chain: EventChain
var current_index: int = 0
var character_ids_in_chain: Array[String] = []
var _displayed_ids: Array[String] = []

func bind_view(v: VnView) -> void:
	view = v

func set_stage_presenter(sp: StagePresenter) -> void:
	stage_presenter = sp

func queue_event_chain(chain_path: String) -> void:
	event_chain_queue.append(chain_path)
	print("[VnPresenter] Queued event chain: %s (queue size: %d)" % [chain_path, event_chain_queue.size()])

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
		_on_chain_complete()
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
	_displayed_ids.clear()
	print("[VnPresenter] Loaded chain '%s' with %d dialogues" % [chain.chain_id, chain.get_dialogue_count()])

	if stage_presenter:
		_ensure_npc_rigs()
		stage_presenter.prepare_for_dialogue(character_ids_in_chain)
	return true

func _display_current_dialogue() -> void:
	var data = _get_current_dialogue_data()
	if data.is_empty():
		return

	var dialogue: Dialogue = current_chain.dialogues[current_index]

	if not dialogue.id.is_empty():
		_displayed_ids.append(dialogue.id)

	if stage_presenter:
		_display_via_stage(dialogue)
	else:
		view.display_dialogue(data, _get_progress_text())

func _display_via_stage(dialogue: Dialogue) -> void:
	if not dialogue.keep_previous_bubbles:
		stage_presenter.dismiss_all_speech()

	var speaker_id = _resolve_speaker_id(dialogue.speaker_name)
	var is_narrator = speaker_id.is_empty() or dialogue.speaker_name.is_empty() or dialogue.speaker_name == "narrator"
	var has_stage_rig = not is_narrator and stage_presenter.view.get_rig(speaker_id) != null

	if dialogue.face_direction != 0 and has_stage_rig:
		stage_presenter.set_character_facing(speaker_id, dialogue.face_direction)

	if dialogue.has_walk_to() and has_stage_rig:
		stage_presenter.walk_character(speaker_id, dialogue.walk_to)

	if has_stage_rig:
		if not dialogue.behavior.is_empty():
			var anim = BEHAVIOR_MAP.get(dialogue.behavior.to_lower())
			if anim != null:
				stage_presenter.set_character_behavior(speaker_id, anim)

		stage_presenter.show_speech(speaker_id, dialogue.speaker_name, dialogue.line_spoken)
		var focus_target = dialogue.camera_target if not dialogue.camera_target.is_empty() else speaker_id
		stage_presenter.focus_speaker(focus_target)
	else:
		view.show_narrator_line(dialogue.speaker_name, dialogue.line_spoken, _get_progress_text())

func _on_chain_complete() -> void:
	if stage_presenter:
		stage_presenter.dismiss_all_speech()
		stage_presenter.return_to_wide()
	view.chain_completed.emit()
	_reset()

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
	_displayed_ids.clear()

func _get_progress_text() -> String:
	if not current_chain:
		return ""
	return "(%d/%d)" % [current_index + 1, current_chain.get_dialogue_count()]

func _resolve_speaker_id(speaker_name: String) -> String:
	if speaker_name.is_empty() or speaker_name == "narrator":
		return ""
	for char_id in character_ids_in_chain:
		if char_id == speaker_name or char_id.to_lower() == speaker_name.to_lower():
			return char_id
	return speaker_name

func _ensure_npc_rigs() -> void:
	if not stage_presenter:
		return
	for char_id in character_ids_in_chain:
		if char_id.is_empty() or char_id == "narrator":
			continue
		if not stage_presenter.view.rigs.has(char_id):
			stage_presenter.spawn_npc_rig(char_id)
