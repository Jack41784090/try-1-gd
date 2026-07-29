@tool
class_name UnitItem
extends PanelContainer

signal weapon_window_received(warrior: Character, window: Control)
signal armor_window_received(warrior: Character, window: Control)
signal weapon_display_removed(warrior: Character, window: Control)
signal armor_display_removed(warrior: Character, window: Control)

const WEAPON_SLOT_SCENE = preload("res://src/squad_battle/items/weapon/ui.tscn")
const ARMOR_SLOT_SCENE = preload("res://src/squad_battle/items/armor/ui.tscn")

@onready var icon_rect: TextureRect = $Rim/HBoxContainer/IconRect
@onready var name_label: Label = %NameLabel
@onready var status_label: Label = %StatusLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var hp_bar = $Rim/HBoxContainer/InfoVBox/StatsHBox/HPBar
@onready var morale_bar = $Rim/HBoxContainer/InfoVBox/StatsHBox/MoraleBar
@onready var speed_label: Label = %SpeedLabel
@onready var atk_label: Label = %AtkLabel
@onready var def_label: Label = %DefLabel
@onready var pen_label: Label = %PenLabel
@onready var mag_label: Label = %MagLabel
@onready var pos_label: Label = %PosLabel
@onready var menu_bar: MenuBar = $Rim/HBoxContainer/MenuBar
@onready var popup_menu: PopupMenu = $"Rim/HBoxContainer/MenuBar/Actions ▼"
@onready var float_control: FloatingControl = %FloatControl
@onready var weapon_dock: DockControl = %WeaponDock
@onready var armor_dock: DockControl = %ArmorDock

var warrior: Character = null
var _weapon_display: WeaponControl = null
var _armor_display: ArmorControl = null
var _pending_warrior_setup: Character = null:
	set(_pws):
		_pending_warrior_setup = _pws
var _connected_warrior: Character = null


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


func setup(warrior_data: Character) -> void:
	warrior = warrior_data
	if is_node_ready():
		_setup_warrior_internal(warrior_data)
	else:
		_pending_warrior_setup = warrior_data


func _setup_warrior_internal(warrior_data: Character) -> void:
	icon_rect.modulate = Color(0.5, 0.5, 0.5, 0.5) if warrior_data.is_dead else Color(1, 1, 1, 1)

	name_label.text = warrior_data.display_name
	if warrior_data.is_dead:
		status_label.text = "[DEAD]"
		status_label.add_theme_color_override("font_color", Color(0.5, 0.3, 0.3, 1.0))
	elif warrior_data.is_injured:
		status_label.text = "[INJURED]"
		status_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3, 1.0))
	else:
		status_label.text = ""

	var subtitle_parts: Array[String] = []
	if warrior_data.resource != null:
		if warrior_data.resource.name != "":
			subtitle_parts.append(warrior_data.resource.name)
		var social_key := StrategyTypes.SocialClass.keys()
		if warrior_data.resource.social_class >= 0 and warrior_data.resource.social_class < social_key.size():
			subtitle_parts.append(social_key[warrior_data.resource.social_class].capitalize())
		var religion_key := StrategyTypes.Religion.keys()
		if warrior_data.resource.religion >= 0 and warrior_data.resource.religion < religion_key.size():
			subtitle_parts.append(religion_key[warrior_data.resource.religion].capitalize())
	subtitle_label.text = " • ".join(subtitle_parts) if subtitle_parts.size() > 0 else "—"

	hp_bar.set_value(_get_warrior_hp_percent(warrior_data) * 100.0)

	_refresh_morale_speed(warrior_data)

	menu_bar.visible = not warrior_data.is_dead

	_refresh_weapon_display()
	_refresh_armor_display()
	_update_equipment_stats()

	if _connected_warrior != null and _connected_warrior.changed.is_connected(_on_warrior_changed):
		_connected_warrior.changed.disconnect(_on_warrior_changed)
	warrior_data.changed.connect(_on_warrior_changed)
	_connected_warrior = warrior_data


func _on_warrior_changed() -> void:
	_refresh_morale_speed(warrior)


func _refresh_morale_speed(warrior_data: Character) -> void:
	var morale := float(warrior_data.get_stat_value(StatName.I.MORALE))
	morale_bar.set_value(morale * 100.0)
	if morale >= 0.75:
		morale_bar.set_value_color(Color(0.4, 0.9, 0.4, 1.0))
	elif morale >= 0.50:
		morale_bar.set_value_color(Color(0.9, 0.9, 0.4, 1.0))
	elif morale >= 0.25:
		morale_bar.set_value_color(Color(0.9, 0.6, 0.3, 1.0))
	else:
		morale_bar.set_value_color(Color(0.9, 0.3, 0.3, 1.0))

	speed_label.text = "Spd: %.1f" % float(warrior_data.get_stat_value(StatName.I.MV_SPD))


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
	var cfg: WeaponResource = warrior.get_equipped_weapon() if warrior != null else null
	if cfg == null:
		if _weapon_display != null:
			_weapon_display.queue_free()
			_weapon_display = null
		_update_equipment_stats()
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
	_update_equipment_stats()


func _refresh_armor_display() -> void:
	if Engine.is_editor_hint():
		return
	if _armor_display != null and (not is_instance_valid(_armor_display) or _armor_display.get_parent() != armor_dock):
		_armor_display = null
	var cfg: ArmorConfig = warrior.get_equipped_armor() if warrior != null else null
	if cfg == null:
		if _armor_display != null:
			_armor_display.queue_free()
			_armor_display = null
		_update_equipment_stats()
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
	_update_equipment_stats()


func _update_equipment_stats() -> void:
	if warrior == null:
		atk_label.text = "Atk: —"
		def_label.text = "Def: —"
		pen_label.text = "Pen: —"
		mag_label.text = "Mag: —"
		return
	var w := warrior.get_equipped_weapon()
	if w != null:
		atk_label.text = "Atk: +%d" % int(w.hit_bonus)
		pen_label.text = "Pen: +%d" % int(w.penetration_bonus)
		mag_label.text = "Mag: ✦" if w.is_magical else "Mag: —"
	else:
		atk_label.text = "Atk: —"
		pen_label.text = "Pen: —"
		mag_label.text = "Mag: —"
	var a := warrior.get_equipped_armor()
	if a != null:
		def_label.text = "Def: +%d" % int(a.defense_bonus + a.armor_bonus + a.magical_armor_bonus)
	else:
		def_label.text = "Def: —"


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
			pos_label.text = "Pos: Front"
		11:
			pos_label.text = "Pos: Mid"
		12:
			pos_label.text = "Pos: Back"


func _get_warrior_hp_percent(warrior_param: Character) -> float:
	if warrior_param.is_dead:
		return 0.0
	if warrior_param.is_injured:
		return 0.5
	return 1.0
