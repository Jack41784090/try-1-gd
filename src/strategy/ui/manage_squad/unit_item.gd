@tool
class_name UnitItem
extends PanelContainer

signal weapon_window_received(warrior: StrategyEntity, window: Control)
signal armor_window_received(warrior: StrategyEntity, window: Control)
signal weapon_display_removed(warrior: StrategyEntity, window: Control)
signal armor_display_removed(warrior: StrategyEntity, window: Control)

const WEAPON_SLOT_SCENE = preload("res://src/squad-battle/items/weapon/ui.tscn")
const ARMOR_SLOT_SCENE = preload("res://src/squad-battle/items/armor/ui.tscn")

@onready var icon_rect: TextureRect = $Rim/HBoxContainer/IconRect
@onready var name_label: Label = %NameLabel
@onready var hp_bar = $Rim/HBoxContainer/InfoVBox/StatsHBox/HPBar
@onready var morale_bar = $Rim/HBoxContainer/InfoVBox/StatsHBox/MoraleBar
@onready var location_bar = $Rim/HBoxContainer/InfoVBox/StatsHBox/LocationBar
@onready var menu_bar: MenuBar = $Rim/HBoxContainer/MenuBar
@onready var popup_menu: PopupMenu = $"Rim/HBoxContainer/MenuBar/Actions ▼"
@onready var float_control: FloatingControl = %FloatControl
@onready var weapon_dock: DockControl = %WeaponDock
@onready var armor_dock: DockControl = %ArmorDock

var warrior: StrategyEntity = null
var _weapon_display: WeaponControl = null
var _armor_display: ArmorControl = null
var _pending_warrior_setup: StrategyEntity = null:
	set(_pws):
		_pending_warrior_setup = _pws


func _ready() -> void:
	var move_submenu = popup_menu.get_node("PopupMenu_move")
	if move_submenu:
		popup_menu.set_item_submenu(4, "PopupMenu_move")
	if not Engine.is_editor_hint():
		weapon_dock.child_entered_tree.connect(_on_weapon_dock_child_entered)
		armor_dock.child_entered_tree.connect(_on_armor_dock_child_entered)
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

	_refresh_weapon_display()
	_refresh_armor_display()


func _on_weapon_dock_child_entered(node: Node) -> void:
	if node is WeaponControl and node != _weapon_display:
		weapon_window_received.emit(warrior, node)
		node.queue_free()
		_refresh_weapon_display()


func _on_armor_dock_child_entered(node: Node) -> void:
	if node is ArmorControl and node != _armor_display:
		armor_window_received.emit(warrior, node)
		node.queue_free()
		_refresh_armor_display()


func _on_weapon_display_drag_ended(window: Control, _pos: Vector2) -> void:
	if not is_instance_valid(window) or window.get_parent() == weapon_dock:
		return
	weapon_display_removed.emit(warrior, window)
	if window.get_parent() == null or _dock_of(window.get_parent()) == null:
		window.queue_free()
	_refresh_weapon_display()


func _on_armor_display_drag_ended(window: Control, _pos: Vector2) -> void:
	if not is_instance_valid(window) or window.get_parent() == armor_dock:
		return
	armor_display_removed.emit(warrior, window)
	if window.get_parent() == null or _dock_of(window.get_parent()) == null:
		window.queue_free()
	_refresh_armor_display()


func _refresh_weapon_display() -> void:
	if Engine.is_editor_hint():
		return
	if _weapon_display != null and (not is_instance_valid(_weapon_display) or _weapon_display.get_parent() != weapon_dock):
		_weapon_display = null
	var cfg: WeaponResource = warrior.equipment_weapon if warrior != null else null
	if cfg == null:
		if _weapon_display != null:
			_weapon_display.queue_free()
			_weapon_display = null
		return
	if _weapon_display != null:
		if _weapon_display.weapon_config == cfg:
			return
		_weapon_display.queue_free()
		_weapon_display = null
	_weapon_display = WEAPON_SLOT_SCENE.instantiate()
	_weapon_display.weapon_config = cfg
	weapon_dock.add_child(_weapon_display)
	var fc: FloatingControl = _weapon_display.get_node("FloatControl")
	fc.drag_ended.connect(_on_weapon_display_drag_ended)


func _refresh_armor_display() -> void:
	if Engine.is_editor_hint():
		return
	if _armor_display != null and (not is_instance_valid(_armor_display) or _armor_display.get_parent() != armor_dock):
		_armor_display = null
	var cfg: ArmorConfig = warrior.equipment_armor if warrior != null else null
	if cfg == null:
		if _armor_display != null:
			_armor_display.queue_free()
			_armor_display = null
		return
	if _armor_display != null:
		if _armor_display.armor_config == cfg:
			return
		_armor_display.queue_free()
		_armor_display = null
	_armor_display = ARMOR_SLOT_SCENE.instantiate()
	_armor_display.armor_config = cfg
	armor_dock.add_child(_armor_display)
	var fc: FloatingControl = _armor_display.get_node("FloatControl")
	fc.drag_ended.connect(_on_armor_display_drag_ended)


func _dock_of(node: Node) -> DockControl:
	if node == null:
		return null
	for c in node.get_children():
		if c is DockControl:
			return c
	return null


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
