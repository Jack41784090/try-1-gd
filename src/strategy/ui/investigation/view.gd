class_name InvestigationView extends Control

@onready var overlay_panel: PanelContainer = $OverlayPanel
@onready var clues_container: VBoxContainer = $OverlayPanel/MarginContainer/VBoxContainer/CluesScroll/CluesContainer
@onready var confirm_button: Button = $OverlayPanel/MarginContainer/VBoxContainer/ConfirmButton
@onready var title_label: Label = $OverlayPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var no_clues_label: Label = $OverlayPanel/MarginContainer/VBoxContainer/NoCluesLabel

var actor: ActivityRunner
var current_location: Location:
	get:
		return actor.current_location

signal investigation_closed()

func setup(_actor) -> void:
	assert(_actor is ActivityRunner)
	actor = _actor

func _ready() -> void:
	overlay_panel.visible = false
	confirm_button.pressed.connect(_on_confirm_pressed)
	no_clues_label.visible = false

func show_investigation_menu() -> void:
	self.visible = true
	overlay_panel.visible = true
	_update_clues_list()

func hide_investigation_menu() -> void:
	overlay_panel.visible = false
	_clear_clue_items()

func _update_clues_list() -> void:
	_clear_clue_items()
	
	if not current_location:
		_show_no_clues_message("Location not found")
		return
	
	title_label.text = "Investigating: %s" % current_location.location_name
	
	var current_turn = actor.aem.world.turn_count
	var active_clues = current_location.get_active_clues(current_turn)
	
	if active_clues.is_empty():
		_show_no_clues_message("No clues found at this location")
		return
	
	no_clues_label.visible = false
	
	var perception_roll = _calculate_perception_roll()
	var detection_chance = _calculate_detection_chance()
	
	for clue in active_clues:
		if randf() <= detection_chance:
			_create_clue_item(clue, perception_roll, current_turn)

func _calculate_perception_roll() -> int:
	if not actor.player_squad or actor.player_squad.warriors.is_empty():
		return 50
	
	var total_perception = 0
	for warrior in actor.player_squad.warriors:
		total_perception += warrior.get_attribute(StrategyTypes.WarriorAttribute.SURVIVAL)
	
	var avg_perception = float(total_perception) / actor.player_squad.warriors.size()
	
	var roll = randi_range(-10, 10)
	return int(avg_perception + roll)

## Returns the base chance of detecting each clue (0.0 to 1.0)
## Currently returns a fixed value. Can be modified to incorporate squad stats, location stability, etc.
func _calculate_detection_chance() -> float:
	return 1 # TODO: Adjust this value based on game mechanics

func _create_clue_item(clue: Clue, perception_roll: int, current_turn: int) -> void:
	var item_panel = PanelContainer.new()
	item_panel.custom_minimum_size = Vector2(0, 80)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	item_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	var name_label = Label.new()
	name_label.text = "🔍 %s" % clue.clue_name
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)
	
	var age_label = Label.new()
	age_label.text = "Age: %s" % clue.get_age_description(current_turn)
	age_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(age_label)
	
	var destination_label = Label.new()
	var destination_hint = clue.get_destination_hint(perception_roll)
	destination_label.text = "Direction: %s" % destination_hint
	destination_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	vbox.add_child(destination_label)
	
	if not clue.left_by_squad_id.is_empty():
		var squad_label = Label.new()
		squad_label.text = "Left by: %s" % _get_squad_name(clue.left_by_squad_id)
		squad_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.6))
		vbox.add_child(squad_label)
	
	clues_container.add_child(item_panel)

func _get_squad_name(squad_id: String) -> String:
	var world = actor.aem.world
	for squad in world.roaming_squads:
		if squad.squad_id == squad_id:
			return squad.squad_name
	return "Unknown SquadCombatData"

func _show_no_clues_message(message: String) -> void:
	no_clues_label.text = message
	no_clues_label.visible = true

func _on_confirm_pressed() -> void:
	investigation_closed.emit()

func _clear_clue_items() -> void:
	for child in clues_container.get_children():
		child.queue_free()
