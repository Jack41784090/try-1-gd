@tool
class_name ManageSquadPage
extends Control

signal closed
signal recruitment_completed(warrior: Character)

@onready var overlay_panel: PanelContainer = $OverlayPanel

@onready var tab_tactics: Button = $OverlayPanel/MainMargin/MainVBox/NavBar/TacticsBtn
@onready var tab_units: Button = $OverlayPanel/MainMargin/MainVBox/NavBar/UnitsBtn
@onready var tab_formation: Button = $OverlayPanel/MainMargin/MainVBox/NavBar/FormationBtn
@onready var tab_recruitment: Button = $OverlayPanel/MainMargin/MainVBox/NavBar/RecruitmentBtn
@onready var tab_inventory: Button = $OverlayPanel/MainMargin/MainVBox/NavBar/InventoryBtn
@onready var close_button: Button = $OverlayPanel/MainMargin/MainVBox/NavBar/CloseBtn

@onready var tab_container: Control = $OverlayPanel/MainMargin/MainVBox/TabContainer

@onready var tactics_tab: TacticsTab = $OverlayPanel/MainMargin/MainVBox/TabContainer/TacticsTab
@onready var units_tab: UnitsTab = $OverlayPanel/MainMargin/MainVBox/TabContainer/UnitsTab
@onready var formation_tab: FormationTab = $OverlayPanel/MainMargin/MainVBox/TabContainer/FormationTab
@onready var recruitment_tab: RecruitmentTab = $OverlayPanel/MainMargin/MainVBox/TabContainer/RecruitmentTab
@onready var inventory_tab: InventoryTab = $OverlayPanel/MainMargin/MainVBox/TabContainer/InventoryTab

var squad: StrategySquad
var actor: ActivityRunner

var _nav_buttons: Array[Button] = []
@export var _active_tab: int = 0:
	set(value):
		_active_tab = value
		_switch_tab(value)


func _build_demo_squad() -> StrategySquad:
	squad = StrategySquad.new()
	var w = load("res://resources/strategy/warrior-presets/crossbowman_demo_squad.tres")
	for i in range(5):
		var nw = Character.new(StrategyEntity.new(w))
		squad.add_warrior(nw)

	var mace = load("res://resources/combat/weapon/config/mace.tres")
	for i in range(15):
		squad.inventory.add_weapon(mace)
	return squad


func _ready() -> void:
	_nav_buttons = [tab_tactics, tab_units, tab_formation, tab_recruitment, tab_inventory]
	for btn in _nav_buttons:
		UIAnimations.register_button(btn)
	UIAnimations.register_button(close_button)

	tab_tactics.pressed.connect(func(): _active_tab = 0)
	tab_units.pressed.connect(func(): _active_tab = 1)
	tab_formation.pressed.connect(func(): _active_tab = 2)
	tab_recruitment.pressed.connect(func(): _active_tab = 3)
	tab_inventory.pressed.connect(func(): _active_tab = 4)
	close_button.pressed.connect(func(): close())

	tactics_tab.tactic_selected.connect(_on_tactic_selected)
	formation_tab.formation_changed.connect(_on_formation_changed)
	recruitment_tab.recruit_requested.connect(_on_recruit)
	inventory_tab.equip_weapon_requested.connect(_on_equip_weapon)
	inventory_tab.equip_armor_requested.connect(_on_equip_armor)
	inventory_tab.unequip_weapon_requested.connect(_on_unequip_weapon)
	inventory_tab.unequip_armor_requested.connect(_on_unequip_armor)

	if get_tree().current_scene == self and squad == null:
		_build_demo_squad()
		open(squad, null)


func open(p_squad: StrategySquad, p_actor: ActivityRunner) -> void:
	squad = p_squad
	actor = p_actor
	tactics_tab.setup(squad)
	units_tab.setup(squad)
	formation_tab.setup(squad)
	recruitment_tab.setup(squad, actor)
	inventory_tab.setup(squad)
	_active_tab = 0
	_switch_tab(_active_tab)  # force, in case _active_tab was already 0
	visible = true
	await UIAnimations.show_overlay(self)


func close() -> void:
	await UIAnimations.hide_overlay(self)
	visible = false
	squad = null
	actor = null
	closed.emit()


func _switch_tab(tab: int) -> void:
	var base := "OverlayPanel/MainMargin/MainVBox/TabContainer/"
	var tabs := ["TacticsTab", "UnitsTab", "FormationTab", "RecruitmentTab", "InventoryTab"]
	for i in tabs.size():
		var node := get_node_or_null(base + tabs[i]) as Control
		if node:
			node.visible = i == tab
	_update_nav_highlight(tab)


func _update_nav_highlight(tab: int) -> void:
	var nav := "OverlayPanel/MainMargin/MainVBox/NavBar/"
	var btns := ["TacticsBtn", "UnitsBtn", "FormationBtn", "RecruitmentBtn", "InventoryBtn"]
	for i in btns.size():
		var btn := get_node_or_null(nav + btns[i]) as Button
		if btn == null:
			continue
		if i == tab:
			btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6, 1.0))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.75, 1.0))
		else:
			btn.remove_theme_color_override("font_color")
			btn.remove_theme_color_override("font_hover_color")


func _on_tactic_selected(tactic: Tactic) -> void:
	squad.set_tactic(tactic)
	Log.info("ManageSquadPage", "Tactic set to %s" % tactic.tactic_id)


func _on_formation_changed(warrior: Character, new_pos: SquadBattleTypes.SquadEntityInSquadLocation) -> void:
	warrior.location_prebattle = new_pos


func _on_recruit(background: WarriorBackground) -> void:
	var cost: int = background.cost
	if not squad.spend_money(cost):
		return

	var new_warrior := Character.new(StrategyEntityFactory.Create(
		background,
		StrategyTypes.Religion.CATHOLIC,
	))
	squad.add_warrior(new_warrior)
	Log.info("ManageSquadPage", "Recruited %s for %d gold" % [new_warrior.display_name, cost])
	recruitment_completed.emit(new_warrior)


func _on_equip_weapon(warrior: Character, weapon: WeaponResource) -> void:
	squad.inventory.equip_weapon(warrior, weapon)
	Log.info("ManageSquadPage", "Equipped %s with %s" % [warrior.display_name, SquadBattleTypes.WeaponClasses.keys()[weapon.weapon_class]])


func _on_equip_armor(warrior: Character, armor: ArmorConfig) -> void:
	squad.inventory.equip_armor(warrior, armor)
	Log.info("ManageSquadPage", "Equipped %s with %s" % [warrior.display_name, SquadBattleTypes.ArmorClasses.keys()[armor.armor_class]])


func _on_unequip_weapon(warrior: Character) -> void:
	var weapon_name = SquadBattleTypes.WeaponClasses.keys()[warrior.get_equipped_weapon().weapon_class] if warrior.get_equipped_weapon() else "nothing"
	squad.inventory.unequip_weapon(warrior)
	Log.info("ManageSquadPage", "Unequipped %s from %s" % [weapon_name, warrior.display_name])


func _on_unequip_armor(warrior: Character) -> void:
	var armor_name = SquadBattleTypes.ArmorClasses.keys()[warrior.get_equipped_armor().armor_class] if warrior.get_equipped_armor() else "nothing"
	squad.inventory.unequip_armor(warrior)
	Log.info("ManageSquadPage", "Unequipped %s from %s" % [armor_name, warrior.display_name])
