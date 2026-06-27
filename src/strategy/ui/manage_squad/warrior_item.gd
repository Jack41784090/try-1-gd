extends PanelContainer

class_name WarriorItem

@onready var icon_rect: TextureRect = $MarginContainer/HBoxContainer/IconRect
@onready var name_label: Label = $MarginContainer/HBoxContainer/InfoVBox/NameLabel
@onready var hp_bar: ProgressBar = $MarginContainer/HBoxContainer/InfoVBox/StatsHBox/HPContainer/HPBar
@onready var morale_value_label: Label = $MarginContainer/HBoxContainer/InfoVBox/StatsHBox/MoraleContainer/MoraleValueLabel
@onready var loca_value_label: Label = $MarginContainer/HBoxContainer/InfoVBox/StatsHBox/LocationContainer/Label

@onready var menu_bar: MenuBar = $MarginContainer/HBoxContainer/MenuBar
@onready var popup_menu: PopupMenu = $"MarginContainer/HBoxContainer/MenuBar/Actions ▼"

var warrior: StrategyEntity = null
var _pending_warrior_setup: StrategyEntity = null


func _ready() -> void:
	# Connect submenu to Move item
	var move_submenu = popup_menu.get_node("PopupMenu_move")
	if move_submenu:
		popup_menu.set_item_submenu(4, "PopupMenu_move")

	if _pending_warrior_setup != null:
		_setup_warrior_internal(_pending_warrior_setup)
		_pending_warrior_setup = null


func setup_warrior(warrior_data: StrategyEntity) -> void:
	warrior = warrior_data

	if is_node_ready():
		_setup_warrior_internal(warrior_data)
	else:
		_pending_warrior_setup = warrior_data


func _setup_warrior_internal(warrior_data: StrategyEntity) -> void:
	# Set up icon (placeholder for now)
	if warrior_data.is_dead:
		icon_rect.modulate = Color(0.5, 0.5, 0.5, 0.5)
	else:
		icon_rect.modulate = Color(1, 1, 1, 1)

	# Update name with status
	name_label.text = warrior_data.name

	if warrior_data.is_dead:
		name_label.text += " [DEAD]"
		name_label.add_theme_color_override("font_color", Color(0.5, 0.3, 0.3, 1.0))
	elif warrior_data.is_injured:
		name_label.text += " [INJURED]"
		name_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3, 1.0))
	else:
		name_label.remove_theme_color_override("font_color")

	# Update HP bar value
	var hp_percent = _get_warrior_hp_percent(warrior_data)
	hp_bar.value = hp_percent * 100.0

	# Update morale display with color
	morale_value_label.text = "%.0f" % warrior_data.morale

	if warrior_data.morale >= 75:
		morale_value_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4, 1.0))
	elif warrior_data.morale >= 50:
		morale_value_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.4, 1.0))
	elif warrior_data.morale >= 25:
		morale_value_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3, 1.0))
	else:
		morale_value_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1.0))

	# Update location label
	match warrior_data.location_prebattle:
		SquadBattleTypes.SquadEntityInSquadLocation.Front:
			loca_value_label.text = "Front"
		SquadBattleTypes.SquadEntityInSquadLocation.Middle:
			loca_value_label.text = "Middle"
		SquadBattleTypes.SquadEntityInSquadLocation.Back:
			loca_value_label.text = "Back"

	# Disable menu for dead warriors
	if warrior_data.is_dead:
		menu_bar.visible = false
	else:
		menu_bar.visible = true


func _on_action_selected(id: int) -> void:
	match id:
		0: # Rest
			print("Rest action selected for ", warrior.name)
		1: # Train
			print("Train action selected for ", warrior.name)
		2: # Heal
			print("Heal action selected for ", warrior.name)
		3: # Transfer
			print("Transfer action selected for ", warrior.name)
		5: # Dismiss
			print("Dismiss action selected for ", warrior.name)
		10: # Move Front
			print("Move to Front selected for ", warrior.name)
			warrior.location_prebattle = SquadBattleTypes.SquadEntityInSquadLocation.Front
			loca_value_label.text = "Front"
		11: # Move Mid
			print("Move to Mid selected for ", warrior.name)
			warrior.location_prebattle = SquadBattleTypes.SquadEntityInSquadLocation.Middle
			loca_value_label.text = "Middle"
		12: # Move Back
			print("Move to Back selected for ", warrior.name)
			warrior.location_prebattle = SquadBattleTypes.SquadEntityInSquadLocation.Back
			loca_value_label.text = "Back"


func _get_warrior_hp_percent(warrior_param: StrategyEntity) -> float:
	if warrior_param.is_dead:
		return 0.0
	if warrior_param.is_injured:
		return 0.5
	return 1.0
