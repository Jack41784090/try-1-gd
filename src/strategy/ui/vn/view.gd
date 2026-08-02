class_name VnView extends Control

@onready var character_container: HBoxContainer = $CharacterContainer
@onready var dialogue_box: PanelContainer = $DialogueBox
@onready var speaker_label: Label = $DialogueBox/MarginContainer/VBoxContainer/SpeakerLabel
@onready var dialogue_label: Label = $DialogueBox/MarginContainer/VBoxContainer/DialogueLabel
@onready var advance_prompt: Label = $DialogueBox/AdvancePrompt
@onready var presenter: VnPresenter = $VnPresenter

signal chain_completed()

var portrait_cache: Dictionary = {}

func _ready() -> void:
	dialogue_box.gui_input.connect(_on_dialogue_box_clicked)
	presenter.bind_view(self )

func exit() -> void:
	character_container.visible = false
	dialogue_box.visible = false
	speaker_label.visible = false
	dialogue_label.visible = false
	advance_prompt.visible = false

func enter() -> void:
	pass

func queue_event_chain(chain_path: String) -> void:
	presenter.queue_event_chain(chain_path)

func play_next_queued_chain() -> bool:
	return presenter.play_next_queued_chain()

func peek_next_transition_type() -> EventChain.TransitionType:
	return presenter.peek_next_transition_type()

#region Display Methods

func display_dialogue(data: Dictionary, progress_text: String) -> void:
	speaker_label.text = data.get("speaker_name", "")
	dialogue_label.text = data.get("line_spoken", "")
	var _portrait_ids = data.get("on_screen_character_ids", [])
	for child in character_container.get_children():
		child.queue_free()
	for char_id in _portrait_ids:
		if char_id is String:
			var _portrait_result: Control
			if portrait_cache.has(char_id):
				_portrait_result = portrait_cache[char_id].duplicate()
			else:
				var portrait = ColorRect.new()
				portrait.custom_minimum_size = Vector2(150, 250)
				var hash_val = char_id.hash()
				portrait.color = Color(
					float(hash_val % 100) / 100.0,
					float(int(hash_val / 100.0) % 100) / 100.0,
					float(int(hash_val / 10000.0) % 100) / 100.0, 1.0)
				portrait_cache[char_id] = portrait
				_portrait_result = portrait.duplicate()
			character_container.add_child(_portrait_result)
	advance_prompt.text = "Click to continue %s" % progress_text
	dialogue_box.visible = true
	speaker_label.visible = true
	dialogue_label.visible = true
	advance_prompt.visible = true

func show_narrator_line(speaker_name: String, text: String, progress_text: String) -> void:
	speaker_label.text = speaker_name if not speaker_name.is_empty() else "Narrator"
	dialogue_label.text = text
	advance_prompt.text = "Click to continue %s" % progress_text
	dialogue_box.visible = true
	speaker_label.visible = true
	dialogue_label.visible = true
	advance_prompt.visible = true

func setup_narrator_typewriter(speaker: String, text: String) -> void:
	speaker_label.text = speaker if not speaker.is_empty() else "Narrator"
	dialogue_label.text = text
	dialogue_label.visible_characters = 0
	advance_prompt.text = ""
	dialogue_box.visible = true
	speaker_label.visible = true
	dialogue_label.visible = true
	advance_prompt.visible = false

func set_narrator_visible_characters(count: int) -> void:
	dialogue_label.visible_characters = count

func hide_narrator_box() -> void:
	dialogue_box.visible = false
	advance_prompt.visible = false

#endregion

#region Display Helpers

func _on_dialogue_box_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if presenter:
				presenter.on_advance()

func _unhandled_input(event: InputEvent) -> void:
	if not presenter or not presenter.has_chain():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			presenter.on_advance()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			presenter.on_advance()
			get_viewport().set_input_as_handled()

func clear_portrait_cache() -> void:
	portrait_cache.clear()

#endregion
