class_name ManageSquadPagePresenter
extends Node

signal closed
signal recruitment_completed(warrior: Warrior)

enum Tab { TACTICS, UNITS, FORMATION, RECRUITMENT, INVENTORY }

var view
var squad: SquadData
var actor: ActivityRunner
var active_tab: Tab = Tab.UNITS


func bind_view(v) -> void:
	view = v


func open(p_squad: SquadData, p_actor: ActivityRunner) -> void:
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


func on_formation_changed(warrior: Warrior, new_pos: SquadBattleTypes.SquadEntityInSquadLocation) -> void:
	warrior.location_prebattle = new_pos


func on_recruit(background: WarriorBackground) -> void:
	var cost: int = background.cost
	if squad.money < cost:
		return

	var new_warrior = WarriorFactory.create_warrior(
		background.background_id,
		"warrior_%d_%d" % [actor.aem.world.current_hour, randi()],
		"%s Recruit" % background.display_name,
		StrategyTypes.Religion.CATHOLIC
	)

	squad.add_warrior(new_warrior)
	squad.money -= cost

	Log.info("ManageSquadPage", "Recruited %s for %d gold" % [new_warrior.name, cost])
	recruitment_completed.emit(new_warrior)
	view.recruitment_tab.refresh(squad, actor)


func on_equip_weapon(warrior: Warrior, weapon: WeaponConfig) -> void:
	squad.inventory.equip_weapon(warrior, weapon)
	Log.info("ManageSquadPage", "Equipped %s with %s" % [warrior.name, SquadBattleTypes.WeaponClasses.keys()[weapon.weapon_class]])
	_refresh_tab()


func on_equip_armor(warrior: Warrior, armor: ArmorConfig) -> void:
	squad.inventory.equip_armor(warrior, armor)
	Log.info("ManageSquadPage", "Equipped %s with %s" % [warrior.name, SquadBattleTypes.ArmorClasses.keys()[armor.armor_class]])
	_refresh_tab()


func on_unequip_weapon(warrior: Warrior) -> void:
	var weapon_name := SquadBattleTypes.WeaponClasses.keys()[warrior.equipment_weapon.weapon_class] if warrior.equipment_weapon else "nothing"
	squad.inventory.unequip_weapon(warrior)
	Log.info("ManageSquadPage", "Unequipped %s from %s" % [weapon_name, warrior.name])
	_refresh_tab()


func on_unequip_armor(warrior: Warrior) -> void:
	var armor_name := SquadBattleTypes.ArmorClasses.keys()[warrior.equipment_armor.armor_class] if warrior.equipment_armor else "nothing"
	squad.inventory.unequip_armor(warrior)
	Log.info("ManageSquadPage", "Unequipped %s from %s" % [armor_name, warrior.name])
	_refresh_tab()
