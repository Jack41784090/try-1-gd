@tool
class_name TestUnitItem
extends PanelContainer

@onready var icon_rect: TextureRect = $Rim/HBoxContainer/IconRect
@onready var name_label: Label = %NameLabel
@onready var hp_bar = $Rim/HBoxContainer/InfoVBox/StatsHBox/HPBar
@onready var morale_bar = $Rim/HBoxContainer/InfoVBox/StatsHBox/MoraleBar
@onready var location_bar = $Rim/HBoxContainer/InfoVBox/StatsHBox/LocationBar
@onready var menu_bar: MenuBar = $Rim/HBoxContainer/MenuBar
@onready var popup_menu: PopupMenu = $"Rim/HBoxContainer/MenuBar/Actions ▼"
@onready var float_control: FloatingControl = %FloatControl

var warrior: TestStrategyEntity = null
var _pending_warrior_setup: TestStrategyEntity = null:
	set(_pws):
		_pending_warrior_setup = _pws

func _on_floatcontrol_docked(dock: DockControl) -> void:
	var parent = dock.get_parent()
	if parent is InventoryItemContainer:
		print("OK!")
		pass

func _connect_float_control_docked() -> void:
	float_control.docked.connect(_on_floatcontrol_docked)

func _ready() -> void:
	var move_submenu = popup_menu.get_node("PopupMenu_move")
	if move_submenu:
		popup_menu.set_item_submenu(4, "PopupMenu_move")
	if _pending_warrior_setup != null:
		_setup_warrior_internal(_pending_warrior_setup)
		_pending_warrior_setup = null


func setup(warrior_data: TestStrategyEntity) -> void:
	warrior = warrior_data
	if is_node_ready():
		_setup_warrior_internal(warrior_data)
	else:
		_pending_warrior_setup = warrior_data

func _build_subitems(unit: TestStrategyEntity) -> void:
	
	#icon_rect.modulate = Color(0.5, 0.5, 0.5, 0.5) if warrior_data.is_dead else Color(1, 1, 1, 1)
#
	var display_name = unit.display_name
	name_label.text = display_name

	#var hp := unit.get_stat_value(StatName.I.HP) as float
	hp_bar.set_value(1.0)

	var morale := unit.get_stat_value(StatName.I.MORALE) as float
	morale_bar.set_value(morale)
	#if warrior_data.morale >= 0.75:
		#morale_bar.set_value_color(Color(0.4, 0.9, 0.4, 1.0))
	#elif warrior_data.morale >= 0.50:
		#morale_bar.set_value_color(Color(0.9, 0.9, 0.4, 1.0))
	#elif warrior_data.morale >= 0.25:
		#morale_bar.set_value_color(Color(0.9, 0.6, 0.3, 1.0))
	#else:
		#morale_bar.set_value_color(Color(0.9, 0.3, 0.3, 1.0))

	location_bar.set_value_text("—")

	menu_bar.visible = true

func _setup_warrior_internal(unit: TestStrategyEntity) -> void:
	unit.changed.connect(func(): _build_subitems(unit))
	_build_subitems(unit)


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


#func _get_warrior_hp_percent(warrior_param: TestStrategyEntity) -> float:
	#if warrior_param.is_dead:
		#return 0.0
	#if warrior_param.is_injured:
		#return 0.5
	#return 1.0
