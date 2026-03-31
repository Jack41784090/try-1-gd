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

var _clue_items: Array[InvestigationClueItem]

signal investigation_closed()

func setup(_actor) -> void:
	assert(_actor is ActivityRunner)
	actor = _actor

func _ready() -> void:
	overlay_panel.visible = false
	confirm_button.pressed.connect(_on_confirm_pressed)
	no_clues_label.visible = false

	for child in clues_container.get_children():
		if child is InvestigationClueItem:
			_clue_items.append(child)

	for item in _clue_items:
		item.visible = false

func show_investigation_menu() -> void:
	self.visible = true
	overlay_panel.visible = true
	_update_clues_list()
	await UIAnimations.show_overlay(self, overlay_panel)

func hide_investigation_menu() -> void:
	await UIAnimations.hide_overlay(self, overlay_panel)
	overlay_panel.visible = false
	_hide_all_clue_items()

func _update_clues_list() -> void:
	_hide_all_clue_items()
	
	if not current_location:
		_show_no_clues_message("Location not found")
		return
	
	title_label.text = "Investigating: %s" % current_location.location_name
	
	var current_hour = actor.aem.world.current_hour
	var active_clues = current_location.get_active_clues(current_hour)
	
	if active_clues.is_empty():
		_show_no_clues_message("No clues found at this location")
		return
	
	no_clues_label.visible = false
	
	var perception_roll = _calculate_perception_roll()
	var detection_chance = _calculate_detection_chance()
	
	var slot_index := 0
	for clue in active_clues:
		if slot_index >= _clue_items.size():
			break
		if randf() <= detection_chance:
			var squad_name := _get_squad_name(clue.left_by_squad_id) if not clue.left_by_squad_id.is_empty() else ""
			_clue_items[slot_index].populate(clue, perception_roll, current_hour, squad_name)
			slot_index += 1

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

func _get_squad_name(squad_id: String) -> String:
	var world = actor.aem.world
	for squad in world.roaming_squads:
		if squad.squad_id == squad_id:
			return squad.squad_name
	return "Unknown CombatSquad"

func _show_no_clues_message(message: String) -> void:
	no_clues_label.text = message
	no_clues_label.visible = true

func _on_confirm_pressed() -> void:
	investigation_closed.emit()

func _hide_all_clue_items() -> void:
	for item in _clue_items:
		item.visible = false
