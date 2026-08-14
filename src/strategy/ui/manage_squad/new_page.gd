@tool
class_name NewManageSquadPage
extends Control

signal closed

const PRESETS: Registry = preload("res://resources/registries/preset_registry.tres")
const WEAPONS: Registry = preload("res://resources/registries/weapon_registry.tres")

#@onready var overlay_panel: PanelContainer = $OverlayPanel
@onready var desktop: DesktopManager = $Desktop
#@onready var tab_tactics: Button = $OverlayPanel/MainMargin/MainVBox/NavBar/TacticsBtn
#@onready var tab_units: Button = $OverlayPanel/MainMargin/MainVBox/NavBar/UnitsBtn
#@onready var tab_formation: Button = $OverlayPanel/MainMargin/MainVBox/NavBar/FormationBtn
#@onready var tab_recruitment: Button = $OverlayPanel/MainMargin/MainVBox/NavBar/RecruitmentBtn
#@onready var tab_inventory: Button = $OverlayPanel/MainMargin/MainVBox/NavBar/InventoryBtn
@onready var close_button: Button = %CloseButton

#@onready var tactics_tab: TacticsTab = $OverlayPanel/MainMargin/MainVBox/TabContainer/TacticsTab
@onready var units_tab: UnitsFloatingPanel = %UnitsPanel
#@onready var formation_tab: FormationTab = $OverlayPanel/MainMargin/MainVBox/TabContainer/FormationTab
#@onready var recruitment_tab: RecruitmentTab = $OverlayPanel/MainMargin/MainVBox/TabContainer/RecruitmentTab
@onready var inventory_tab: InventoryFloatingPanel = %InventoryPanel

var squad: StrategySquad
var actor: ActivityRunner

func _process(_d) -> void:
	pass ;


func _build_demo_squad() -> StrategySquad:
	squad = StrategySquad.new()
	var w = PRESETS.load_entry("crossbowman_demo_squad")
	for i in range(5):
		var nw = Character.new(StrategyEntity.new(w))
		squad.add_warrior(nw)

	var mace = WEAPONS.load_entry("mace")
	for i in range(15):
		squad.inventory.add_weapon(mace)

	var leather = load("res://resources/combat/armor/leather-armor.tres")
	for i in range(3):
		squad.inventory.add_armor(leather)
	return squad


func _ready() -> void:
	#UIAnimations.register_button(close_button)
	#tab_tactics.pressed.connect(func(): _active_tab = 0)
	#tab_units.pressed.connect(func(): _active_tab = 1)
	#tab_formation.pressed.connect(func(): _active_tab = 2)
	#tab_recruitment.pressed.connect(func(): _active_tab = 3)
	#tab_inventory.pressed.connect(func(): _active_tab = 4)
	close_button.pressed.connect(func(): close())
	#tactics_tab.tactic_selected.connect(_on_tactic_selected)
	#formation_tab.formation_changed.connect(_on_formation_changed)
	#recruitment_tab.recruit_requested.connect(_on_recruit)
	inventory_tab.equip_weapon_requested.connect(_on_equip_weapon)
	inventory_tab.equip_armor_requested.connect(_on_equip_armor)
	inventory_tab.unequip_weapon_requested.connect(_on_unequip_weapon)
	inventory_tab.unequip_armor_requested.connect(_on_unequip_armor)
	units_tab.weapon_window_received.connect(_on_weapon_window_received)
	units_tab.armor_window_received.connect(_on_armor_window_received)
	units_tab.weapon_display_removed.connect(_on_weapon_display_removed)
	units_tab.armor_display_removed.connect(_on_armor_display_removed)

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
	#squad = null
	#actor = null
	var save_err = ResourceSaver.save(squad, "res://resources/saved_squads/squad.tres")
	if save_err != OK:
		MyLog.error("ManageSquadPage", "Failed to save squad")
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
	MyLog.info("ManageSquadPage", "Tactic set to %s" % tactic.tactic_id)


func _on_formation_changed(warrior: Character, new_pos: SquadBattleTypes.SquadEntityInSquadLocation) -> void:
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
	# MyLog.info("ManageSquadPage", "Recruited %s for %d gold" % [new_warrior.display_name, cost])
	# recruitment_completed.emit(new_warrior)


func _on_weapon_window_received(warrior: Character, window: Control) -> void:
	var cfg: WeaponResource = (window as WeaponControl).weapon_config
	if cfg == null or warrior == null:
		return
	var owner: Character = null
	for w in squad.warriors:
		if w.get_equipped_weapon() == cfg:
			owner = w
			break
	if owner != null:
		squad.inventory.unequip_weapon(owner)
	if squad.inventory.weapons.has(cfg):
		_on_equip_weapon(warrior, cfg)


func _on_armor_window_received(warrior: Character, window: Control) -> void:
	var cfg: ArmorConfig = (window as ArmorControl).armor_config
	if cfg == null or warrior == null:
		return
	var owner: Character = null
	for w in squad.warriors:
		if w.get_equipped_armor() == cfg:
			owner = w
			break
	if owner != null:
		squad.inventory.unequip_armor(owner)
	if squad.inventory.armors.has(cfg):
		_on_equip_armor(warrior, cfg)


func _on_weapon_display_removed(warrior: Character, _window: Control) -> void:
	_on_unequip_weapon(warrior)


func _on_armor_display_removed(warrior: Character, _window: Control) -> void:
	_on_unequip_armor(warrior)


func _on_equip_weapon(warrior: Character, weapon: WeaponResource) -> void:
	squad.inventory.equip_weapon(warrior, weapon)
	MyLog.info("ManageSquadPage", "Equipped %s with %s" % [warrior.display_name, SquadBattleTypes.WeaponClasses.keys()[weapon.weapon_class]])


func _on_equip_armor(warrior: Character, armor: ArmorConfig) -> void:
	squad.inventory.equip_armor(warrior, armor)
	MyLog.info("ManageSquadPage", "Equipped %s with %s" % [warrior.display_name, SquadBattleTypes.ArmorClasses.keys()[armor.armor_class]])


func _on_unequip_weapon(warrior: Character) -> void:
	var weapon_name = SquadBattleTypes.WeaponClasses.keys()[warrior.get_equipped_weapon().weapon_class] if warrior.get_equipped_weapon() else "nothing"
	squad.inventory.unequip_weapon(warrior)
	MyLog.info("ManageSquadPage", "Unequipped %s from %s" % [weapon_name, warrior.display_name])


func _on_unequip_armor(warrior: Character) -> void:
	var armor_name = SquadBattleTypes.ArmorClasses.keys()[warrior.get_equipped_armor().armor_class] if warrior.get_equipped_armor() else "nothing"
	squad.inventory.unequip_armor(warrior)
	MyLog.info("ManageSquadPage", "Unequipped %s from %s" % [armor_name, warrior.display_name])
