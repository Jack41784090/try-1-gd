@tool
class_name InventoryFloatingPanel
extends PanelContainer

@export var bookmark_left_path: NodePath
@export var bookmark_right_path: NodePath

signal equip_weapon_requested(warrior: Character, weapon: WeaponResource)
signal equip_armor_requested(warrior: Character, armor: ArmorConfig)
signal unequip_weapon_requested(warrior: Character)
signal unequip_armor_requested(warrior: Character)

const GRID_ITEM_SCENE = preload("res://scenes/ui/manage_squad/inventory_item_grid.tscn")
const WEAPON_SLOT_SCENE = preload("res://src/squad_battle/items/weapon/ui.tscn")
const ARMOR_SLOT_SCENE = preload("res://src/squad_battle/items/armor/ui.tscn")

@export var preview_in_editor: bool = false:
	set(v):
		preview_in_editor = v
		if Engine.is_editor_hint() and is_node_ready():
			if preview_in_editor:
				_build_demo_squad()
				_rebuild_inv()
			else:
				for child in _inventory_container.get_children():
					child.queue_free()
		else:
			push_warning("preview_in_editor can only be set in the editor.")

@onready var _inventory_container: Control = %InventoryContainer
#@onready var _empty_label: Label = $MainHBox/InventoryPanel/VBox/EmptyLabel

var _item_windows: Array[Control] = []

var _squad: StrategySquad:
	set(_s):
		if _s:
			_squad = _s
			_rebuild_inv()


func _build_demo_squad() -> StrategySquad:
	_squad = StrategySquad.new()
	var w = load("res://resources/strategy/warrior-presets/_crossbowman.tres")
	for i in range(5):
		var nw = Character.new(StrategyEntity.new(w))
		_squad.add_warrior(nw)

	var mace = load("res://resources/combat/weapon/config/mace.tres")
	for i in range(15):
		_squad.inventory.add_weapon(mace)
	return _squad


func _ready() -> void:
	if Engine.is_editor_hint() and _squad == null:
		_build_demo_squad()
		_rebuild_inv()
	visibility_changed.connect(_on_visibility_changed)


func setup(squad: StrategySquad) -> void:
	_squad = squad


func _connect_signals() -> void:
	if not _squad.inventory.changed.is_connected(_rebuild_inv):
		_squad.inventory.changed.connect(_rebuild_inv)


func _disconnect_signals() -> void:
	if _squad and _squad.inventory.changed.is_connected(_rebuild_inv):
		_squad.inventory.changed.disconnect(_rebuild_inv)


func _on_visibility_changed() -> void:
	if _squad == null:
		return
	if visible:
		_connect_signals()
		_rebuild_inv()
	else:
		_disconnect_signals()


func _rebuild_inv() -> void:
	var dm := get_tree().get_first_node_in_group(&"desktop_manager")
	var items: Array = _squad.inventory.get_all_items()
	var needed: Dictionary = {}
	for i in items:
		needed[i] = int(needed.get(i, 0)) + 1
	_item_windows.clear()
	for c in _inventory_container.get_children():
		if not (c is WeaponControl or c is ArmorControl):
			continue
		var cfg := _window_config(c)
		if cfg != null and int(needed.get(cfg, 0)) > 0:
			needed[cfg] -= 1
			_item_windows.append(c)
		else:
			if dm != null:
				dm.unregister_window(c)
			c.queue_free()
	for cfg in needed:
		for n in range(int(needed[cfg])):
			var win := _spawn_item_window(cfg)
			if win != null:
				_inventory_container.add_child(win)
				_item_windows.append(win)

	#_empty_label.visible = _squad.inventory.is_empty()


func _window_config(w: Control) -> CombatEquipment:
	if w is WeaponControl:
		return w.weapon_config
	if w is ArmorControl:
		return w.armor_config
	return null


func _spawn_item_window(item: CombatEquipment) -> Control:
	if item is WeaponResource:
		var ws = WEAPON_SLOT_SCENE.instantiate()
		ws.name = "WS_%s" % item
		ws.weapon_config = item
		return ws
	if item is ArmorConfig:
		var ar = ARMOR_SLOT_SCENE.instantiate()
		ar.name = "AS_%s" % item
		ar.armor_config = item
		return ar
	return null
