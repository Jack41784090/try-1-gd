@tool
class_name InventoryTab
extends Control

signal equip_weapon_requested(warrior: Character, weapon: WeaponResource)
signal equip_armor_requested(warrior: Character, armor: ArmorConfig)
signal unequip_weapon_requested(warrior: Character)
signal unequip_armor_requested(warrior: Character)

const WARRIOR_CARD_SCENE = preload("res://scenes/ui/manage_squad/warrior_equipment_card.tscn")
const GRID_ITEM_SCENE = preload("res://scenes/ui/manage_squad/inventory_item_grid.tscn")
const weapon_slot = preload("res://src/squad_battle/items/weapon/ui.tscn")

@export var preview_in_editor: bool = false:
	set(v):
		preview_in_editor = v
		if Engine.is_editor_hint() and is_node_ready():
			if preview_in_editor:
				_build_demo_squad()
				_rebuild_slots()
			else:
				_clear_all_slots()
		else:
			push_warning("preview_in_editor can only be set in the editor.")

@onready var _title_label: Label = $MainHBox/UnitsPanel/VBox/TitleLabel
@onready var _inventory_container: GridContainer = $MainHBox/InventoryPanel/VBox/InventoryScroll/InventoryContainer
@onready var _units_container: VBoxContainer = $MainHBox/UnitsPanel/VBox/UnitsScroll/UnitsContainer
@onready var _empty_label: Label = $MainHBox/InventoryPanel/VBox/EmptyLabel

var _squad: StrategySquad:
	set(_s):
		if _s:
			_squad = _s
			_rebuild_slots()


func _build_demo_squad() -> StrategySquad:
	_squad = StrategySquad.new()
	var w = load("res://resources/strategy/warrior-presets/crossbowman_demo_squad.tres")
	for i in range(5):
		var nw = Character.new(StrategyEntity.new(w))
		_squad.add_warrior(nw)

	var mace = load("res://resources/combat/weapon/config/mace.tres")
	for i in range(15):
		_squad.inventory.add_weapon(mace)
	return _squad


func _clear_all_slots() -> void:
	for c in _inventory_container.get_children():
		c.queue_free()
	for c in _units_container.get_children():
		c.queue_free()


func _rebuild_slots() -> void:
	_clear_all_slots()
	_pull()


func _ready() -> void:
	#if Engine.is_editor_hint() and _squad == null:
		#_squad = _build_demo_squad()
		#_rebuild_slots()
	visibility_changed.connect(_on_visibility_changed)


func setup(squad: StrategySquad) -> void:
	_squad = squad


func _pull() -> void:
	_refresh_inventory()
	_refresh_units()


func _connect_signals() -> void:
	if not _squad.inventory.changed.is_connected(_pull):
		_squad.inventory.changed.connect(_pull)


func _disconnect_signals() -> void:
	if _squad and _squad.inventory.changed.is_connected(_pull):
		_squad.inventory.changed.disconnect(_pull)


func _on_visibility_changed() -> void:
	if _squad == null:
		return
	if visible:
		_connect_signals()
		_rebuild_slots()
	else:
		_disconnect_signals()


func _refresh_inventory() -> void:
	for child in _inventory_container.get_children():
		child.queue_free()

	if _squad == null:
		return
	var items: Array = _squad.inventory.get_all_items()
	for i in items:
		if i is WeaponResource:
			var ws = weapon_slot.instantiate()
			ws.weapon_config = i
			_inventory_container.add_child(ws)
		elif i is ArmorConfig:
			pass

	_empty_label.visible = _squad.inventory.is_empty()


func _refresh_units() -> void:
	for child in _units_container.get_children():
		child.queue_free()

	#_title_label.text = "WARRIORS — %d" % _squad.get_living_warriors().size()

	for warrior in _squad.get_living_warriors():
		var card = WARRIOR_CARD_SCENE.instantiate()
		_units_container.add_child(card)
		card.setup(warrior)
		card.equip_weapon_requested.connect(func(w, wep): equip_weapon_requested.emit(w, wep))
		card.equip_armor_requested.connect(func(w, arm): equip_armor_requested.emit(w, arm))
		card.unequip_weapon_requested.connect(func(w): unequip_weapon_requested.emit(w))
		card.unequip_armor_requested.connect(func(w): unequip_armor_requested.emit(w))
