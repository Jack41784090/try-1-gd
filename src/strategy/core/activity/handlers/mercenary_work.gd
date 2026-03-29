class_name MercenaryWorkHandler
extends ActivityHandler


func execute(context: Dictionary, result: ActivityResult) -> ActivityResult:
	var squad = context.get("squad") as SquadData

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

	Log.info("MercenaryWorkHandler", "MERCENARY_WORK: %d monsters — %d kills, %d injuries, earned %.0f gold" % [
		monster_count,
		kills,
		casualties,
		money_earned,
	])

	return result
