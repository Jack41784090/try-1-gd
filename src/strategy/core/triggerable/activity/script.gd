# activity.gd
class_name Activity
extends Triggerable

@export var result: ActivityResult
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
		super(),
	]


func can_execute(squad: SquadStrategicData, location: Location) -> bool:
	# Checks if this activity can be performed given the squad's state and current location
	# e.g., ATTACK at Location(stability=90) with min_stability_to_block_attack=80 → blocked (90 > 80)
	# e.g., FORCE_MARCH to "vienna" with squad.food=3, demand=4 → false (not enough food)
	match activity_type:
		StrategyTypes.ActivityType.ATTACK:
			# 1. ATTACK only allowed in unstable locations (below threshold)
			return location.stability < min_stability_to_block_attack
		StrategyTypes.ActivityType.FORCE_MARCH:
			# 2. FORCE_MARCH needs a destination, adjacency, and enough food (2x normal demand)
			if destination_id.is_empty():
				return false
			if not location.is_connected_to(destination_id):
				return false
			var total_demand := 0.0
			for w in squad.get_living_warriors():
				var demand = w.get_demand()
				total_demand += demand.get(StrategyTypes.SquadProperty.FOOD_SUPPLIES, 0.0)
			var food_cost = int(ceil(total_demand * force_march_supply_multiplier))
			return squad.food >= food_cost
		_:
			# 3. All other activities (REST, DRILL, PATROL, etc.) are always executable
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
	# Central dispatch for all activity types. Duplicates the template result,
	# routes to the type-specific handler, then runs any chained triggers.
	# e.g., Activity(TRAVEL, destination="vienna") → _execute_travel(context) → ActivityResult(location_changed="vienna")
	assert(result)

	# 1. Save original result template and create a fresh duplicate for this execution
	# This prevents mutations from persisting across multiple executions of the same activity
	var saved_result := result
	result = saved_result.duplicate(true)
	var activity_result: ActivityResult = result

	# 2. Route to the appropriate handler based on activity_type
	# e.g., ActivityType.ATTACK → _execute_attack(context) which may set requires_combat=true
	# e.g., ActivityType.TRAVEL → _execute_travel(context) which consumes food and moves squad
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
		StrategyTypes.ActivityType.PATROL:
			activity_result = _execute_patrol(context)
		_:
			# Generic activities (REST, DRILL, PATROL, etc.) just return the template result as-is
			pass

	# 3. Restore the original result template so this Activity resource can be reused
	result = saved_result

	# 4. Process trigger_chains — chained activities that fire after this one
	# e.g., REST might chain to a "Random Encounter" event with 30% chance
	var all_triggered_results: Array[ActivityResult] = [activity_result]
	for chain in trigger_chains:
		var chained_trigger = chain.another_trigger
		var c_chance = chain.chance
		# 4.1 Check if chained trigger's conditions pass the current context
		if chained_trigger.can_trigger(context):
			# 4.2 Roll for chance (or auto-pass if chance == 1.0)
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

	# 5. Return array of all results — primary + any chained
	return all_triggered_results


func _execute_attack(context: Dictionary) -> ActivityResult:
	# ATTACK: Attempts to initiate combat with an enemy squad at the current location
	# Requires contact tracker to have at least SUSPECTED contact on the target
	# e.g., squad="Wolves" at "salzburg", enemies=[SquadStrategicData("Bandits")] → requires_combat=true
	var world = context.get("world") as World
	var squad = context.get("squad") as SquadStrategicData
	var tracker = world.contact_tracker

	# 1. Find enemy squads at the same location
	var enemies_here = world.get_squads_at_location(squad.current_location_id)

	# 2. If no enemies, attack fails with morale penalty
	if enemies_here.is_empty():
		result.modify_squad_stat(StrategyTypes.SquadProperty.MORALE, -5.0)
		return result

	# 3. Pick target — prefer brain's chosen target, then best-contacted enemy
	var target_enemy: SquadStrategicData = null
	var chosen_id = context.get("attack_target", "")
	if not chosen_id.is_empty():
		for e in enemies_here:
			if e.squad_id == chosen_id:
				target_enemy = e
				break

	if target_enemy == null:
		var best_progress: float = -1.0
		for e in enemies_here:
			var c = tracker.get_contact(squad.squad_id, e.squad_id)
			if c and c.progress > best_progress:
				best_progress = c.progress
				target_enemy = e
		if target_enemy == null:
			target_enemy = enemies_here[0]

	# 4. Check contact state — need LOCKED to attack
	var contact = tracker.get_contact(squad.squad_id, target_enemy.squad_id)
	if not contact or contact.get_state() < StrategyTypes.ContactState.LOCKED:
		var state_name = StrategyTypes.ContactState.keys()[contact.get_state()] if contact else "NONE"
		Log.info("Activity", "ATTACK blocked — contact on %s is only %s (need LOCKED)" % [
			target_enemy.squad_name, state_name])
		result.modify_squad_stat(StrategyTypes.SquadProperty.MORALE, -3.0)
		return result

	# 5. Contact is sufficient — flag this result as requiring async combat resolution
	# The UI layer will pick this up and switch to COMBAT_INTERMISSION mode
	result.requires_combat = true
	result.combat_target_squad_id = target_enemy.squad_id
	result.requires_async = true
	# 6. Classify engagement type (AMBUSH if we have LOCKED contact but they don't know us, else SET_PIECE/MEETING)
	result.engagement_type = tracker.classify_engagement(squad.squad_id, target_enemy.squad_id)

	Log.info("Activity", "ATTACK engagement: %s vs %s [%s]" % [
		squad.squad_name, target_enemy.squad_name,
		StrategyTypes.EngagementType.keys()[result.engagement_type]])
	return result


func _execute_travel(context: Dictionary) -> ActivityResult:
	# TRAVEL: Move squad one hop to the destination, consuming food and applying morale penalty
	# e.g., squad at "salzburg" with destination="vienna", food=5, 3 warriors
	#   → consume 3 food (1 per warrior), apply -2 morale penalty, set location to "vienna"
	var squad = context.get("squad") as SquadStrategicData

	# 1. Consume food based on each warrior's demand (social class affects demand)
	# e.g., 3 SOLDIER warriors × 1.0 demand = 3 food consumed
	var consumed = squad.consume_supplies_by_demand()
	if not consumed:
		# 1.1 Not enough food → extra morale penalty
		result.modify_squad_stat(StrategyTypes.SquadProperty.MORALE, -5.0)
	# 2. Apply travel morale penalty per warrior (mitigated by SURVIVAL attribute)
	# e.g., warrior with survival=80 gets -2 × (1 - 80/200) = -1.2 morale
	squad.apply_travel_morale_penalty(-2.0)
	# 3. Move squad to destination if one is set in result
	if not result.location_changed.is_empty():
		squad.set_location(result.location_changed)

	return result


func _execute_force_march(context: Dictionary) -> ActivityResult:
	# FORCE_MARCH: Fast travel covering up to 2 hops in one turn at high supply/morale cost
	# e.g., from "salzburg" → "linz" → "vienna" in one turn, consuming 2x food per hop
	var world = context.get("world") as World
	var squad = context.get("squad") as SquadStrategicData

	# 1. Consume supplies at 2x rate and apply heavy morale penalty
	squad.consume_supplies_by_demand(force_march_supply_multiplier)
	squad.apply_travel_morale_penalty(-4.0)

	# 2. Move to the first hop (destination_id)
	# e.g., destination_id = "linz"
	squad.set_location(destination_id)
	var final_location = destination_id

	# 3. Attempt second hop if there's an ultimate destination beyond the first hop
	# e.g., ultimate_destination_id = "vienna", and squad still has food
	if not ultimate_destination_id.is_empty() and ultimate_destination_id != destination_id:
		var current_loc = world.get_location_by_id(destination_id)
		if current_loc and squad.food > 0:
			# 3.1 Find path from first hop to ultimate destination
			var path = world.travel_graph.find_path(destination_id, ultimate_destination_id)
			if path.size() > 1:
				# 3.2 Move to the second hop, consuming supplies again
				var second_hop = path[1]
				squad.consume_supplies_by_demand(force_march_supply_multiplier)
				squad.set_location(second_hop)
				final_location = second_hop
				print(
					"[Activity] FORCE_MARCH double-hop: %s → %s → %s" % [
						context.get("squad").squad_name if context.has("squad") else "?",
						destination_id,
						second_hop,
					],
				)

	# 4. Record final location and apply heavy morale penalty (-10)
	result.location_changed = final_location
	result.modify_squad_stat(StrategyTypes.SquadProperty.MORALE, -10.0)

	# 5. Check if enemies are at the destination — triggers forced combat
	# e.g., enemies_at_destination = [SquadStrategicData("Bandits")] → requires_combat=true
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
	# FORAGE: Gather food from the current location. Yield depends on location type.
	# e.g., VILLAGE → 2-4 food, ROAD → 1-2 food, CITY → 0 food (no wilderness)
	var squad = context.get("squad") as SquadStrategicData
	var world = context.get("world") as World
	var location = world.get_location_by_id(squad.current_location_id)

	if not location:
		return result

	# 1. Roll for food based on location type
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

	# 2. Add gained food directly to squad inventory
	squad.food += food_gained
	print(
		"[Activity] FORAGE at %s (%s): gained %d food (now %d)" % [
			location.location_name,
			StrategyTypes.LocationType.keys()[location.type],
			food_gained,
			squad.food,
		],
	)

	return result


func _execute_heal(context: Dictionary) -> ActivityResult:
	# HEAL: Spend money to heal injured warriors. Costs 10 gold per warrior.
	# e.g., squad has 2 injured warriors, 25 gold → heals 2 warriors for 20 gold, +10 morale
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
		print(
			"[Activity] HEAL at %s: healed %d warriors for %.0f gold (morale +10)" % [
				location.location_name,
				healed_count,
				healed_count * cost_per_warrior,
			],
		)
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
	var supply_thing: Thing = shop.get_thing_by_type(EconomyTypes.ThingType.FOOD)
	if not supply_thing:
		return result

	var price: float = supply_thing.base_price
	var desired_amount := 5
	var affordable = int(squad.money / price)
	var buy_amount = mini(desired_amount, affordable)

	if buy_amount > 0:
		squad.spend_money(buy_amount * price)
		squad.food += buy_amount
		print(
			"[Activity] BUY_SUPPLIES at %s: bought %d supplies for %.0f gold (food now %d)" % [
				location.location_name,
				buy_amount,
				buy_amount * price,
				squad.food,
			],
		)

	return result


func _execute_patrol(context: Dictionary) -> ActivityResult:
	var squad = context.get("squad") as SquadStrategicData
	var world = context.get("world") as World
	var tracker = world.contact_tracker

	var contacts_for = tracker.get_contacts_for(squad.squad_id)
	var detected_count := 0
	for c in contacts_for:
		if c.get_state() >= StrategyTypes.ContactState.SUSPECTED:
			detected_count += 1

	result.modify_squad_stat(StrategyTypes.SquadProperty.MORALE, 2.0)

	Log.info("Activity", "PATROL: detected %d contacts, morale +2" % detected_count)

	return result


func _execute_mercenary_work(context: Dictionary) -> ActivityResult:
	# MERCENARY_WORK: Fight monsters for money. Risk/reward — kills earn gold, but warriors can be injured.
	# e.g., 3 monsters spawned, squad of 4 warriors → rolls per monster, chance of kill or casualty
	#   → 2 kills × 15g = 30 gold earned, 1 warrior injured, morale -5
	var squad = context.get("squad") as SquadStrategicData
	var world = context.get("world") as World

	# 1. Determine how many monsters to fight (2-4)
	var monster_count = randi_range(2, 4)
	var base_pay_per_kill := 15.0
	var squad_warriors = squad.get_living_warriors()

	if squad_warriors.is_empty():
		return result

	# 2. Roll for each monster — win_chance scales with warrior count vs monster count
	# e.g., 4 warriors vs 3 monsters → win_chance = 4/(3+1) = 1.0 (clamped to 0.9)
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

	print(
		"[Activity] MERCENARY_WORK: fought %d monsters — %d kills, %d injuries, earned %.0f gold" % [
			monster_count,
			kills,
			casualties,
			money_earned,
		],
	)

	return result
