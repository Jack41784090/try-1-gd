extends Control
class_name VisualNovelScreen

## Visual Novel style screen for displaying EventChain dialogues

const EventChainClass = preload("res://src/strategy/events/event_chain.gd")
const DialogueClass = preload("res://src/strategy/events/dialogue.gd")

signal dialogue_advanced
signal chain_completed

@onready var background_rect: ColorRect = $Background
@onready var character_container: HBoxContainer = $CharacterContainer
@onready var dialogue_box: Panel = $DialogueBox
@onready var speaker_label: Label = $DialogueBox/MarginContainer/VBoxContainer/SpeakerLabel
@onready var text_label: RichTextLabel = $DialogueBox/MarginContainer/VBoxContainer/TextLabel
@onready var continue_button: Button = $DialogueBox/ContinueButton

var event_chain: EventChainClass
var current_dialogue_index: int = 0
var character_portraits: Dictionary = {}
var background_textures: Dictionary = {}

func _ready() -> void:
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	
	# Hide initially
	visible = false

func load_event_chain(chain: EventChainClass) -> void:
	event_chain = chain
	current_dialogue_index = 0
	
	# Preload character portraits
	_preload_character_portraits()
	
	# Show the screen
	visible = true
	
	# Display first dialogue
	if event_chain and event_chain.get_dialogue_count() > 0:
		_display_dialogue(0)

func _preload_character_portraits() -> void:
	character_portraits.clear()
	
	if not event_chain:
		return
	
	# Stub: In a real implementation, load portrait textures from assets
	for character_id in event_chain.get_all_character_ids():
		# For now, create placeholder colored rectangles
		character_portraits[character_id] = _create_placeholder_portrait(character_id)

func _create_placeholder_portrait(character_id: String) -> ColorRect:
	var portrait = ColorRect.new()
	portrait.custom_minimum_size = Vector2(150, 200)
	
	# Different colors for different characters
	var hash_val = character_id.hash()
	var color = Color(
		float(hash_val % 100) / 100.0,
		float(int(hash_val / 100.0) % 100) / 100.0,
		float(int(hash_val / 10000.0) % 100) / 100.0
	)
	portrait.color = color
	
	return portrait

func _display_dialogue(index: int) -> void:
	if not event_chain or index >= event_chain.get_dialogue_count():
		_complete_chain()
		return
	
	var dialogue: DialogueClass = event_chain.dialogues[index]
	
	# Update background
	_set_background(dialogue.background_id)
	
	# Update characters on screen
	_update_character_display(dialogue.on_screen_character_ids)
	
	# Update dialogue text
	if speaker_label:
		speaker_label.text = dialogue.speaker_name
	
	if text_label:
		text_label.text = dialogue.line_spoken
	
	# Process triggers if present
	if dialogue.has_triggers():
		_process_dialogue_triggers(dialogue)
	
	# Enable continue button
	if continue_button:
		continue_button.disabled = false

func _process_dialogue_triggers(dialogue: DialogueClass) -> void:
	# Stub: Process triggers for expression changes and other effects
	# In a real implementation, this would scan the dialogue text and apply
	# expression changes at specific text positions
	for trigger in dialogue.triggers:
		if trigger is Dictionary:
			for text_pos in trigger.keys():
				var effect = trigger[text_pos]
				if effect is Dictionary and effect.has("expression-change"):
					var expression = effect["expression-change"]
					print("Trigger: Change expression to '", expression, "' at text: '", text_pos, "'")
					# TODO: Implement actual expression change on character portraits

func _set_background(background_id: String) -> void:
	if not background_rect:
		return
	
	# Stub: In real implementation, load background texture from assets
	# For now, just change color based on background_id
	if background_id.is_empty():
		background_rect.color = Color(0.2, 0.2, 0.2)
	else:
		var hash_val = background_id.hash()
		background_rect.color = Color(
			0.1 + float(hash_val % 50) / 200.0,
			0.1 + float(int(hash_val / 50.0) % 50) / 200.0,
			0.1 + float(int(hash_val / 2500.0) % 50) / 200.0
		)

func _update_character_display(character_ids: Array[String]) -> void:
	if not character_container:
		return
	
	# Clear existing portraits
	for child in character_container.get_children():
		child.queue_free()
	
	# Add portraits for on-screen characters
	for character_id in character_ids:
		if character_portraits.has(character_id):
			var portrait = character_portraits[character_id].duplicate()
			character_container.add_child(portrait)
		else:
			# Create placeholder if character not preloaded
			var portrait = _create_placeholder_portrait(character_id)
			character_container.add_child(portrait)

func _on_continue_pressed() -> void:
	if continue_button:
		continue_button.disabled = true
	
	current_dialogue_index += 1
	dialogue_advanced.emit()
	
	# Small delay before showing next dialogue
	await get_tree().create_timer(0.1).timeout
	_display_dialogue(current_dialogue_index)

func _complete_chain() -> void:
	print("EventChain completed: ", event_chain.chain_id if event_chain else "none")
	chain_completed.emit()
	visible = false

func skip_to_end() -> void:
	_complete_chain()
