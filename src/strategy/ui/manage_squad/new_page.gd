@tool
class_name NewManageSquadPage
extends Control

signal closed
signal recruitment_completed(warrior: StrategyEntity)

#@onready var overlay_panel: PanelContainer = $OverlayPanel
@onready var desktop: DesktopManager = $Desktop
#@onready var tab_tactics: Button = $OverlayPanel/MainMargin/MainVBox/NavBar/TacticsBtn
#@onready var tab_units: Button = $OverlayPanel/MainMargin/MainVBox/NavBar/UnitsBtn
#@onready var tab_formation: Button = $OverlayPanel/MainMargin/MainVBox/NavBar/FormationBtn
#@onready var tab_recruitment: Button = $OverlayPanel/MainMargin/MainVBox/NavBar/RecruitmentBtn
#@onready var tab_inventory: Button = $OverlayPanel/MainMargin/MainVBox/NavBar/InventoryBtn
#@onready var close_button: Button = $OverlayPanel/MainMargin/MainVBox/NavBar/CloseBtn

#@onready var tab_container: Control = $OverlayPanel/MainMargin/MainVBox/TabContainer

#@onready var tactics_tab: TacticsTab = $OverlayPanel/MainMargin/MainVBox/TabContainer/TacticsTab
@onready var units_tab: UnitsFloatingPanel = %WarriorsPanel
#@onready var formation_tab: FormationTab = $OverlayPanel/MainMargin/MainVBox/TabContainer/FormationTab
#@onready var recruitment_tab: RecruitmentTab = $OverlayPanel/MainMargin/MainVBox/TabContainer/RecruitmentTab
@onready var inventory_tab: InventoryFloatingPanel = %InventoryPanel

var squad: StrategySquad
var actor: ActivityRunner


func _build_demo_squad() -> StrategySquad:
	squad = StrategySquad.new()
	var w = load("res://resources/strategy/warrior-presets/_crossbowman.tres")
	for i in range(5):
		var nw = StrategyEntity.new(w)
		squad.add_warrior(nw)

	var mace = load("res://resources/combat/weapon/config/mace.tres")
	for i in range(15):
		squad.inventory.add_weapon(mace)
	return squad


func _ready() -> void:
	#UIAnimations.register_button(close_button)

	#tab_tactics.pressed.connect(func(): _active_tab = 0)
	#tab_units.pressed.connect(func(): _active_tab = 1)
	#tab_formation.pressed.connect(func(): _active_tab = 2)
	#tab_recruitment.pressed.connect(func(): _active_tab = 3)
	#tab_inventory.pressed.connect(func(): _active_tab = 4)
	#close_button.pressed.connect(func(): close())

	#tactics_tab.tactic_selected.connect(_on_tactic_selected)
	#formation_tab.formation_changed.connect(_on_formation_changed)
	#recruitment_tab.recruit_requested.connect(_on_recruit)
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
	#tactics_tab.setup(squad)
	units_tab.setup(squad)
	#formation_tab.setup(squad)
	#recruitment_tab.setup(squad, actor)
	inventory_tab.setup(squad)
	visible = true
	#await UIAnimations.show_overlay(self)


func close() -> void:
	#await UIAnimations.hide_overlay(self)
	visible = false
	squad = null
	actor = null
	closed.emit()


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


func _on_formation_changed(warrior: StrategyEntity, new_pos: SquadBattleTypes.SquadEntityInSquadLocation) -> void:
	warrior.location_prebattle = new_pos


func _on_recruit(background: WarriorBackground) -> void:
	var cost: int = background.cost
	if not squad.spend_money(cost):
		return

	# DISABLED: recruitment needs the StrategyEntity runtime-build bridge
	# (StrategyEntityFactory) which does not exist during the StrategyEntity rewrite.
	# var new_warrior := StrategyEntityFactory.Create(
	# 	background.background_id,
	# 	"warrior_%d_%d" % [actor.aem.world.current_hour, randi()],
	# 	"%s Recruit" % background.display_name,
	# 	StrategyTypes.Religion.CATHOLIC,
	# )
	# squad.add_warrior(new_warrior)
	# Log.info("ManageSquadPage", "Recruited %s for %d gold" % [new_warrior.name, cost])
	# recruitment_completed.emit(new_warrior)


func _on_equip_weapon(warrior: StrategyEntity, weapon: WeaponResource) -> void:
	squad.inventory.equip_weapon(warrior, weapon)
	Log.info("ManageSquadPage", "Equipped %s with %s" % [warrior.name, SquadBattleTypes.WeaponClasses.keys()[weapon.weapon_class]])


func _on_equip_armor(warrior: StrategyEntity, armor: ArmorConfig) -> void:
	squad.inventory.equip_armor(warrior, armor)
	Log.info("ManageSquadPage", "Equipped %s with %s" % [warrior.name, SquadBattleTypes.ArmorClasses.keys()[armor.armor_class]])


func _on_unequip_weapon(warrior: StrategyEntity) -> void:
	var weapon_name = SquadBattleTypes.WeaponClasses.keys()[warrior.equipment_weapon.weapon_class] if warrior.equipment_weapon else "nothing"
	squad.inventory.unequip_weapon(warrior)
	Log.info("ManageSquadPage", "Unequipped %s from %s" % [weapon_name, warrior.name])


func _on_unequip_armor(warrior: StrategyEntity) -> void:
	var armor_name = SquadBattleTypes.ArmorClasses.keys()[warrior.equipment_armor.armor_class] if warrior.equipment_armor else "nothing"
	squad.inventory.unequip_armor(warrior)
	Log.info("ManageSquadPage", "Unequipped %s from %s" % [armor_name, warrior.name])
