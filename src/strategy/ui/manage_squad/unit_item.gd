@tool
class_name UnitItem
extends PanelContainer

@onready var icon_rect: TextureRect = $Rim/HBoxContainer/IconRect
@onready var name_label: Label = $Rim/HBoxContainer/InfoVBox/NameLabel
@onready var hp_bar = $Rim/HBoxContainer/InfoVBox/StatsHBox/HPBar
@onready var morale_bar = $Rim/HBoxContainer/InfoVBox/StatsHBox/MoraleBar
@onready var location_bar = $Rim/HBoxContainer/InfoVBox/StatsHBox/LocationBar
@onready var menu_bar: MenuBar = $Rim/HBoxContainer/MenuBar
@onready var popup_menu: PopupMenu = $"Rim/HBoxContainer/MenuBar/Actions ▼"

var warrior: StrategyEntity = null
var _pending_warrior_setup: StrategyEntity = null


func _ready() -> void:
	var move_submenu = popup_menu.get_node("PopupMenu_move")
	if move_submenu:
		popup_menu.set_item_submenu(4, "PopupMenu_move")
	if _pending_warrior_setup != null:
		_setup_warrior_internal(_pending_warrior_setup)
		_pending_warrior_setup = null


func setup(warrior_data: StrategyEntity) -> void:
	warrior = warrior_data
	if is_node_ready():
		_setup_warrior_internal(warrior_data)
	else:
		_pending_warrior_setup = warrior_data


func _setup_warrior_internal(warrior_data: StrategyEntity) -> void:
	icon_rect.modulate = Color(0.5, 0.5, 0.5, 0.5) if warrior_data.is_dead else Color(1, 1, 1, 1)

	name_label.text = warrior_data.display_name
	if warrior_data.is_dead:
		name_label.text += " [DEAD]"
		name_label.add_theme_color_override("font_color", Color(0.5, 0.3, 0.3, 1.0))
	elif warrior_data.is_injured:
		name_label.text += " [INJURED]"
		name_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3, 1.0))
	else:
		name_label.remove_theme_color_override("font_color")

	hp_bar.set_value(_get_warrior_hp_percent(warrior_data) * 100.0)

	morale_bar.set_value(warrior_data.morale * 100.0)
	if warrior_data.morale >= 0.75:
		morale_bar.set_value_color(Color(0.4, 0.9, 0.4, 1.0))
	elif warrior_data.morale >= 0.50:
		morale_bar.set_value_color(Color(0.9, 0.9, 0.4, 1.0))
	elif warrior_data.morale >= 0.25:
		morale_bar.set_value_color(Color(0.9, 0.6, 0.3, 1.0))
	else:
		morale_bar.set_value_color(Color(0.9, 0.3, 0.3, 1.0))

	location_bar.set_value_text("—")

	menu_bar.visible = not warrior_data.is_dead


func _on_action_selected(id: int) -> void:
	match id:
		0:
			print("Rest action selected for ", warrior.display_name)
		1:
			print("Train action selected for ", warrior.display_name)
		2:
			print("Heal action selected for ", warrior.display_name)
		3:
			print("Transfer action selected for ", warrior.display_name)
		5:
			print("Dismiss action selected for ", warrior.display_name)
		10:
			location_bar.set_value_text("Front")
		11:
			location_bar.set_value_text("Middle")
		12:
			location_bar.set_value_text("Back")


func _get_warrior_hp_percent(warrior_param: StrategyEntity) -> float:
	if warrior_param.is_dead:
		return 0.0
	if warrior_param.is_injured:
		return 0.5
	return 1.0
