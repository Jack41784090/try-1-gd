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

#region Display Methods

func display_dialogue(data: Dictionary, progress_text: String) -> void:
	speaker_label.text = data.get("speaker_name", "")
	dialogue_label.text = data.get("line_spoken", "")
	_update_background(data.get("background_id", ""))
	_update_portraits(data.get("on_screen_character_ids", []))
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
			presenter.on_advance()

func _unhandled_input(event: InputEvent) -> void:
	if not presenter.has_chain():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			presenter.on_advance()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			presenter.on_advance()
			get_viewport().set_input_as_handled()

func _update_background(_bg_id: String) -> void:
	pass

func _update_portraits(character_ids: Array) -> void:
	for child in character_container.get_children():
		child.queue_free()
	for char_id in character_ids:
		if char_id is String:
			character_container.add_child(_get_or_create_portrait(char_id))

func _get_or_create_portrait(character_id: String) -> Control:
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

#endregion
