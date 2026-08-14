class_name MercenaryWorkHandler
extends ActivityHandler


func execute(context: Dictionary, result: ActivityResult) -> ActivityResult:
	var squad = context.get("squad") as StrategySquad
	var world = context.get("world") as World

	if squad.get_living_warriors().is_empty():
		return result

	if world == null:
		return _execute_legacy(squad, result)

	var demand_calc := MercenaryDemandCalculator.new()
	var location := world.get_location_by_id(squad.current_location_id)
	if location == null:
		return _execute_legacy(squad, result)

	var bandit := demand_calc.find_nearest_bandit(location, world)
	if bandit == null:
		MyLog.info("MercenaryWorkHandler", "MERCENARY_WORK: no bandits found — uneventful patrol")
		return result

	result.requires_combat = true
	result.combat_target_squad_id = bandit.squad_id

	var bounty := demand_calc.get_bounty(bandit)
	squad.gain_money(bounty)

	MyLog.info("MercenaryWorkHandler", "MERCENARY_WORK: targeting bandit %s — bounty %.0f gold" % [
		bandit.squad_name, bounty])

	return result


func _execute_legacy(squad: StrategySquad, result: ActivityResult) -> ActivityResult:
	var monster_count = randi_range(2, 4)
	var base_pay_per_kill := 15.0
	var squad_warriors = squad.get_living_warriors()

	if squad_warriors.is_empty():
		return result

	var kills := 0
	var casualties := 0

	for i in range(monster_count):
		var roll = randf()
		var warrior_strength = squad_warriors.size() - casualties
		if warrior_strength <= 0:
			break
		var win_chance = clampf(float(warrior_strength) / float(monster_count + 1), 0.2, 0.9)
		if roll < win_chance:
			kills += 1
		else:
			casualties += 1

	if casualties > 0:
		var living = squad.get_living_warriors()
		for i in range(mini(casualties, living.size())):
			living[i].is_injured = true

	var money_earned = kills * base_pay_per_kill
	squad.gain_money(money_earned)

	if casualties > 0:
		result.modify_squad_stat(StrategyTypes.SquadProperty.MORALE, -5.0)

	MyLog.info("MercenaryWorkHandler", "MERCENARY_WORK: %d monsters — %d kills, %d injuries, earned %.0f gold" % [
		monster_count,
		kills,
		casualties,
		money_earned,
	])

	return result
