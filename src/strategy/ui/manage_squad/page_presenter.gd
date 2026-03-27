class_name ManageSquadPagePresenter
extends Node

signal closed
signal recruitment_completed(warrior: CharacterSocialStats)

enum Tab { TACTICS, UNITS, FORMATION, RECRUITMENT, INVENTORY }

var view
var squad: SquadStrategicData
var actor: ActivityRunner
var active_tab: Tab = Tab.UNITS


func bind_view(v) -> void:
	view = v


func open(p_squad: SquadStrategicData, p_actor: ActivityRunner) -> void:
	squad = p_squad
	actor = p_actor
	active_tab = Tab.UNITS
	view.visible = true
	_refresh_tab()
	await UIAnimations.show_overlay(view)


func close() -> void:
	await UIAnimations.hide_overlay(view)
	view.visible = false
	squad = null
	closed.emit()


func switch_tab(tab: Tab) -> void:
	if active_tab == tab:
		return
	active_tab = tab
	_refresh_tab()


func _refresh_tab() -> void:
	view.show_tab(active_tab)
	match active_tab:
		Tab.TACTICS:
			view.tactics_tab.refresh(squad)
		Tab.UNITS:
			view.units_tab.refresh(squad)
		Tab.FORMATION:
			view.formation_tab.refresh(squad)
		Tab.RECRUITMENT:
			view.recruitment_tab.refresh(squad, actor)
		Tab.INVENTORY:
			view.inventory_tab.refresh(squad)


func on_tactic_selected(tactic: Tactic) -> void:
	squad.current_tactic = tactic
	view.tactics_tab.refresh(squad)


func on_formation_changed(warrior: CharacterSocialStats, new_pos: SquadBattleTypes.SquadEntityInSquadLocation) -> void:
	warrior.location_prebattle = new_pos


func on_recruit(class_enum: EntityClasses.Types, cost: float) -> void:
	if squad.money < cost:
		return

	var entity_template = EntityFactory.get_entity(class_enum)
	var class_logic_map: Dictionary = {
		EntityClasses.Types.Landsknecht: LogicFactory.LogicAvailable.Frontline,
		EntityClasses.Types.Healer: LogicFactory.LogicAvailable.BacklineHeal,
		EntityClasses.Types.Crossbowman: LogicFactory.LogicAvailable.BacklineShooter,
		EntityClasses.Types.Arquebusier: LogicFactory.LogicAvailable.BacklineGunner,
		EntityClasses.Types.Pikeman: LogicFactory.LogicAvailable.DefensiveFrontline,
		EntityClasses.Types.Feldprediger: LogicFactory.LogicAvailable.BacklineSupport,
		EntityClasses.Types.Gelehrter: LogicFactory.LogicAvailable.BacklineCaster,
	}
	var class_location_map: Dictionary = {
		EntityClasses.Types.Landsknecht: SquadBattleTypes.SquadEntityInSquadLocation.Front,
		EntityClasses.Types.Healer: SquadBattleTypes.SquadEntityInSquadLocation.Back,
		EntityClasses.Types.Crossbowman: SquadBattleTypes.SquadEntityInSquadLocation.Back,
		EntityClasses.Types.Arquebusier: SquadBattleTypes.SquadEntityInSquadLocation.Back,
		EntityClasses.Types.Pikeman: SquadBattleTypes.SquadEntityInSquadLocation.Front,
		EntityClasses.Types.Feldprediger: SquadBattleTypes.SquadEntityInSquadLocation.Back,
		EntityClasses.Types.Gelehrter: SquadBattleTypes.SquadEntityInSquadLocation.Back,
	}

	var new_warrior = WarriorFactory.create_warrior(
		class_enum,
		"warrior_%d_%d" % [actor.aem.world.turn_count, randi()],
		"%s Recruit" % entity_template.entity_name,
		StrategyTypes.Religion.CATHOLIC,
		entity_template.stats.duplicate(true) if entity_template.stats else EntityBaseStats.new()
	)
	new_warrior.logic_type = class_logic_map.get(class_enum, LogicFactory.LogicAvailable.Frontline)
	new_warrior.location_prebattle = class_location_map.get(class_enum, SquadBattleTypes.SquadEntityInSquadLocation.Front)

	squad.add_warrior(new_warrior)
	squad.money -= cost

	Log.info("ManageSquadPage", "Recruited %s for %.0f gold" % [new_warrior.name, cost])
	recruitment_completed.emit(new_warrior)
	view.recruitment_tab.refresh(squad, actor)


func on_equip_weapon(warrior: CharacterSocialStats, weapon: WeaponConfig) -> void:
	squad.inventory.equip_weapon(warrior, weapon)
	Log.info("ManageSquadPage", "Equipped %s with %s" % [warrior.name, weapon.weapon_name])
	_refresh_tab()


func on_equip_armor(warrior: CharacterSocialStats, armor: ArmorConfig) -> void:
	squad.inventory.equip_armor(warrior, armor)
	Log.info("ManageSquadPage", "Equipped %s with %s" % [warrior.name, armor.armor_name])
	_refresh_tab()


func on_unequip_weapon(warrior: CharacterSocialStats) -> void:
	var weapon_name := warrior.equipment_weapon.weapon_name if warrior.equipment_weapon else "nothing"
	squad.inventory.unequip_weapon(warrior)
	Log.info("ManageSquadPage", "Unequipped %s from %s" % [weapon_name, warrior.name])
	_refresh_tab()


func on_unequip_armor(warrior: CharacterSocialStats) -> void:
	var armor_name := warrior.equipment_armor.armor_name if warrior.equipment_armor else "nothing"
	squad.inventory.unequip_armor(warrior)
	Log.info("ManageSquadPage", "Unequipped %s from %s" % [armor_name, warrior.name])
	_refresh_tab()
