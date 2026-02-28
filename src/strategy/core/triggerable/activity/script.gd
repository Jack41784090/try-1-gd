# activity.gd
class_name Activity extends Triggerable

@export var result: ActivityResult;
@export var activity_type: StrategyTypes.ActivityType = StrategyTypes.ActivityType.CUSTOM
@export var time_cost: int = 1
@export var destination_id: String = ""
@export var min_stability_to_block_attack: float = 80.0
@export var force_march_supply_multiplier: float = 2.0
@export var force_march_clue_multiplier: int = 2

# Optional custom logic override
@export var custom_script: Script = null
var ultimate_destination_id: String = ""

func _to_string() -> String:
	return "Activity(Name: %s, Type: %s, Time Cost: %d, Destination: %s, Min Stability to Block Attack: %.1f, Force March Supply Multiplier: %.1f, Force March Clue Multiplier: %d, Custom Script: %s, Result: %s, %s)" % [
		trigger_name,
		StrategyTypes.ActivityType.keys()[activity_type],
		time_cost,
		destination_id,
		min_stability_to_block_attack,
		force_march_supply_multiplier,
		force_march_clue_multiplier,
		"custom_script" if custom_script else "None",
		result,
		super ()
	]

func can_execute(squad: SquadStrategicData, location: Location) -> bool:
	match activity_type:
		StrategyTypes.ActivityType.ATTACK:
			return location.stability < min_stability_to_block_attack
		StrategyTypes.ActivityType.FORCE_MARCH:
			if destination_id.is_empty():
				return false
			if not location.is_connected_to(destination_id):
				return false
			var food_cost = int(1 * force_march_supply_multiplier)
			return squad.food >= food_cost
		_:
			return true

func trigger(context: Dictionary) -> Array[ActivityResult]:
	# execution_started.emit()
	# triggered.emit(result)
	# if not result.requires_async:
	# 	execution_completed.emit(result)
	return execute(context)

func execute(context: Dictionary) -> Array[ActivityResult]:
	# if custom_script:
	# 	# Call custom script if provided
	# 	if custom_script.has_method("execute_custom"):
	# 		return custom_script.execute_custom(squad, world, result)
	return _execute_generic(context)

func _execute_generic(context: Dictionary) -> Array[ActivityResult]:
	assert(result)

	var saved_result := result
	result = saved_result.duplicate(true)
	var activity_result: ActivityResult = result

	match activity_type:
		StrategyTypes.ActivityType.ATTACK:
			activity_result = _execute_attack(context)
		StrategyTypes.ActivityType.FORCE_MARCH:
			activity_result = _execute_force_march(context)
		StrategyTypes.ActivityType.RECRUIT:
			activity_result = _execute_recruit(context)
		StrategyTypes.ActivityType.TRAVEL:
			activity_result = _execute_travel(context)
		StrategyTypes.ActivityType.INVESTIGATE:
			activity_result = _execute_investigate(context)
		StrategyTypes.ActivityType.FORAGE:
			activity_result = _execute_forage(context)
		StrategyTypes.ActivityType.HEAL:
			activity_result = _execute_heal(context)
		StrategyTypes.ActivityType.BUY_SUPPLIES:
			activity_result = _execute_buy_supplies(context)
		StrategyTypes.ActivityType.MERCENARY_WORK:
			activity_result = _execute_mercenary_work(context)
		_:
			pass

	result = saved_result

	var all_triggered_results: Array[ActivityResult] = [activity_result]
	for chain in trigger_chains:
		var chained_trigger = chain.another_trigger
		var c_chance = chain.chance
		if chained_trigger.can_trigger(context):
			if c_chance == 1.0 or (c_chance < 1.0 and RandomNumberGenerator.new().randf() <= c_chance):
				print("[Activity] Executing chained activity: ", chained_trigger.trigger_name)
				var chained_results = chained_trigger.execute(context)
				if chained_results is Array:
					for cr in chained_results:
						if cr is ActivityResult:
							all_triggered_results.append(cr)
				elif chained_results is ActivityResult:
					all_triggered_results.append(chained_results)
			else:
				print("[Activity] Skipped chained activity (c_chance failed): ", chained_trigger.trigger_name)

	return all_triggered_results


func _execute_attack(context: Dictionary) -> ActivityResult:
	var world = context.get("world") as World
	var squad = context.get("squad") as SquadStrategicData
	var tracker = world.contact_tracker

	var enemies_here = world.get_squads_at_location(squad.current_location_id)

	if enemies_here.is_empty():
		result.modify_squad_stat(StrategyTypes.SquadProperty.MORALE, -5.0)
		return result

	var target_enemy = enemies_here[0]

	var contact = tracker.get_contact(squad.squad_id, target_enemy.squad_id)
	if not contact or contact.get_state() < StrategyTypes.ContactState.TRACKED:
		var state_name = StrategyTypes.ContactState.keys()[contact.get_state()] if contact else "NONE"
		print("[Activity] ATTACK blocked — contact on %s is only %s (need TRACKED+)" % [
			target_enemy.squad_name,
			state_name
		])
		result.modify_squad_stat(StrategyTypes.SquadProperty.MORALE, -3.0)
		return result

	result.requires_combat = true
	result.combat_target_squad_id = target_enemy.squad_id
	result.requires_async = true
	result.engagement_type = tracker.classify_engagement(squad.squad_id, target_enemy.squad_id)

	print("[Activity] ATTACK engagement classified as %s" % StrategyTypes.EngagementType.keys()[result.engagement_type])
	return result

func _execute_travel(context: Dictionary) -> ActivityResult:
	var squad = context.get("squad") as SquadStrategicData

	# Simple travel logic: move the squad to a new location
	var consumed = squad.consume_food(1)
	if not consumed:
		result.modify_squad_stat(StrategyTypes.SquadProperty.MORALE, -5.0)
	squad.set_location(destination_id)
	result.location_changed = destination_id
	
	return result

func _execute_force_march(context: Dictionary) -> ActivityResult:
	var world = context.get("world") as World
	var squad = context.get("squad") as SquadStrategicData

	var food_cost = int(1 * force_march_supply_multiplier)
	squad.consume_food(food_cost)

	squad.set_location(destination_id)
	var final_location = destination_id

	if not ultimate_destination_id.is_empty() and ultimate_destination_id != destination_id:
		var current_loc = world.get_location_by_id(destination_id)
		if current_loc and squad.food >= food_cost:
			var path = world.travel_graph.find_path(destination_id, ultimate_destination_id)
			if path.size() > 1:
				var second_hop = path[1]
				squad.consume_food(food_cost)
				squad.set_location(second_hop)
				final_location = second_hop
				print("[Activity] FORCE_MARCH double-hop: %s → %s → %s" % [
					context.get("squad").squad_name if context.has("squad") else "?",
					destination_id, second_hop
				])

	result.location_changed = final_location
	result.modify_squad_stat(StrategyTypes.SquadProperty.MORALE, -10.0)

	var enemies_at_destination = world.get_squads_at_location(final_location)
	if not enemies_at_destination.is_empty():
		var target_enemy = enemies_at_destination[0]
		result.requires_combat = true
		result.combat_target_squad_id = target_enemy.squad_id
		result.requires_async = true

	return result

func _execute_recruit(context: Dictionary) -> ActivityResult:
	var world = context.get("world") as World

	# Simple recruit logic: add a new warrior to the squad
	var recruited_entity = EntityFactory.get_entity(EntityClasses.Types.Landsknecht)
	var class_id = recruited_entity.class_id

	var new_warrior = WarriorFactory.create_warrior(class_id, EntityClasses.Types.keys()[class_id], recruited_entity.entity_name, StrategyTypes.Religion.CATHOLIC, EntityBaseStats.new())
	new_warrior.name = "Recruit_%d" % world.turn_count
	
	print("[RecruitActivity] Recruited new warrior: %s" % new_warrior.name)
	
	# Append the new recruit to the result
	result.append_new_recruits([new_warrior])
	
	return result

func _execute_investigate(context: Dictionary) -> ActivityResult:
	var squad = context.get("squad") as SquadStrategicData
	var world = context.get("world") as World
	var location = world.get_location_by_id(squad.current_location_id)

	if not location:
		return result

	var clues_found = randf() * 5
	result.clues_left += clues_found

	return result

func _execute_forage(context: Dictionary) -> ActivityResult:
	var squad = context.get("squad") as SquadStrategicData
	var world = context.get("world") as World
	var location = world.get_location_by_id(squad.current_location_id)

	if not location:
		return result

	var food_gained: int = 0
	match location.type:
		StrategyTypes.LocationType.ROAD:
			food_gained = randi_range(1, 2)
		StrategyTypes.LocationType.VILLAGE:
			food_gained = randi_range(2, 4)
		StrategyTypes.LocationType.FORT:
			food_gained = randi_range(1, 2)
		StrategyTypes.LocationType.TOWN:
			food_gained = randi_range(0, 1)
		StrategyTypes.LocationType.CITY:
			food_gained = 0

	squad.food += food_gained
	print("[Activity] FORAGE at %s (%s): gained %d food (now %d)" % [
		location.location_name,
		StrategyTypes.LocationType.keys()[location.type],
		food_gained,
		squad.food
	])

	return result

func _execute_heal(context: Dictionary) -> ActivityResult:
	var squad = context.get("squad") as SquadStrategicData
	var world = context.get("world") as World
	var location = world.get_location_by_id(squad.current_location_id)

	if not location:
		return result

	var cost_per_warrior := 10.0
	var healed_count := 0

	for warrior in squad.warriors:
		if warrior.is_injured and not warrior.is_dead:
			if squad.money >= cost_per_warrior:
				squad.spend_money(cost_per_warrior)
				warrior.is_injured = false
				healed_count += 1

	if healed_count > 0:
		result.modify_squad_stat(StrategyTypes.SquadProperty.MORALE, 10.0)
		print("[Activity] HEAL at %s: healed %d warriors for %.0f gold (morale +10)" % [
			location.location_name, healed_count, healed_count * cost_per_warrior
		])
	else:
		print("[Activity] HEAL at %s: no warriors to heal or not enough money" % location.location_name)

	return result

func _execute_buy_supplies(context: Dictionary) -> ActivityResult:
	var squad = context.get("squad") as SquadStrategicData
	var world = context.get("world") as World
	var location = world.get_location_by_id(squad.current_location_id)

	if not location or not location.has_shop():
		return result

	var shop = location.shop
	var supply_item = shop.get_item_by_type(StrategyTypes.ItemType.SUPPLY)
	if not supply_item:
		return result

	var desired_amount := 5
	var affordable = int(squad.money / supply_item.price)
	var buy_amount = mini(desired_amount, affordable)

	if buy_amount > 0:
		squad.spend_money(buy_amount * supply_item.price)
		squad.food += buy_amount
		print("[Activity] BUY_SUPPLIES at %s: bought %d supplies for %.0f gold (food now %d)" % [
			location.location_name, buy_amount, buy_amount * supply_item.price, squad.food
		])

	return result

func _execute_mercenary_work(context: Dictionary) -> ActivityResult:
	var squad = context.get("squad") as SquadStrategicData
	var world = context.get("world") as World

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

	var casualty_warriors: Array[CharacterSocialStats] = []
	if casualties > 0:
		var living = squad.get_living_warriors()
		for i in range(mini(casualties, living.size())):
			living[i].is_injured = true
			casualty_warriors.append(living[i])

	var money_earned = kills * base_pay_per_kill
	squad.gain_money(money_earned)

	if casualties > 0:
		result.modify_squad_stat(StrategyTypes.SquadProperty.MORALE, -5.0)

	print("[Activity] MERCENARY_WORK: fought %d monsters — %d kills, %d injuries, earned %.0f gold" % [
		monster_count, kills, casualties, money_earned
	])

	return result
