extends Node
class_name AIRunner

## AI squad controller that manages activity execution and decision-making
## Combines activity execution with game theory-based decision logic

# Activity execution engine
var executor: ActivityExecuteManager = ActivityExecuteManager.new(true)

# SquadCombatData assignment
var assigned_squad: Squad = null
var squad_id: String = ""

# Game theory metrics
var survival_urgency: float = 0.0 # 0.0 = comfortable, 1.0 = desperate

# Decision mode thresholds
const SURVIVAL_FOOD_THRESHOLD: int = 5
const SURVIVAL_MONEY_THRESHOLD: float = 20.0
const COMFORTABLE_FOOD_LEVEL: int = 15
const COMFORTABLE_MONEY_LEVEL: float = 60.0

# Activity preferences by mode
enum DecisionMode {
	SURVIVAL, # Running out of resources
	ACHIEVEMENT # Good on resources, pursuing objectives
}

func _ready():
	pass

func setup(scenario: GameScenario, squad: Squad) -> void:
	assert(scenario != null, "AIRunner requires a GameScenario")
	assert(squad != null, "AIRunner requires a Squad assignment")
	
	executor.setup(scenario, {"squad": squad})
	assigned_squad = squad
	#squad_id = squad.squad_id
	
	print("[AIRunner:%s] Setup complete" % squad_id)

## Calculate how urgent survival needs are (0.0 = comfortable, 1.0 = desperate)
func calculate_survival_urgency() -> float:
	if not assigned_squad:
		return 0.0
	
	# Food urgency: 0 at comfortable level, 1 at zero
	var food_urgency = 1.0 - clamp(
		float(assigned_squad.food) / COMFORTABLE_FOOD_LEVEL,
		0.0, 1.0
	)
	
	# Money urgency: 0 at comfortable level, 1 at zero
	var money_urgency = 1.0 - clamp(
		assigned_squad.money / COMFORTABLE_MONEY_LEVEL,
		0.0, 1.0
	)
	
	# Take the maximum urgency (most desperate need)
	var urgency = max(food_urgency, money_urgency)
	
	# If below critical thresholds, urgency increases but not overwhelmingly
	if assigned_squad.food < SURVIVAL_FOOD_THRESHOLD:
		urgency = max(urgency, 0.6)
	if assigned_squad.money < SURVIVAL_MONEY_THRESHOLD:
		urgency = max(urgency, 0.55)
	
	return clamp(urgency, 0.0, 1.0)

## Determine which decision mode the squad should operate in
func get_decision_mode() -> DecisionMode:
	survival_urgency = calculate_survival_urgency()
	
	if survival_urgency >= 0.5:
		return DecisionMode.SURVIVAL
	else:
		return DecisionMode.ACHIEVEMENT

## Main decision-making function - determines which activity to execute
## Returns ActivityType that should be executed this turn
func decide_activity(world: World, context: Dictionary) -> StrategyTypes.ActivityType:
	assert(assigned_squad != null, "SquadCombatData must be assigned before making decisions")
	
	var mode = get_decision_mode()
	var current_location = world.get_location_by_id(assigned_squad.current_location_id)
	
	print("[AIRunner:%s] Decision mode: %s (urgency=%.2f)" % [
		squad_id,
		DecisionMode.keys()[mode],
		survival_urgency
	])
	print("[AIRunner:%s] Resources: food=%d, money=%.1f" % [
		squad_id,
		assigned_squad.food,
		assigned_squad.money
	])
	
	match mode:
		DecisionMode.SURVIVAL:
			return _decide_survival_mode(world, current_location, context)
		DecisionMode.ACHIEVEMENT:
			return _decide_achievement_mode(world, current_location, context)
		_:
			return StrategyTypes.ActivityType.REST

## Survival mode: focus on acquiring resources
func _decide_survival_mode(world: World, current_location: Location, context: Dictionary) -> StrategyTypes.ActivityType:
	# Priority 1: If critically low on food, try to get some
	if assigned_squad.food < SURVIVAL_FOOD_THRESHOLD:
		# Check if we can forage here
		if current_location != null and current_location.has_activity_type(StrategyTypes.ActivityType.FORAGE):
			print("[AIRunner:%s] SURVIVAL: Foraging for food" % squad_id)
			return StrategyTypes.ActivityType.FORAGE
		
		# Travel to nearest town to buy supplies
		var nearest_town = _find_nearest_location_of_type(
			world,
			current_location,
			[StrategyTypes.LocationType.TOWN, StrategyTypes.LocationType.CITY]
		)
		if nearest_town and nearest_town.location_id != current_location.location_id:
			print("[AIRunner:%s] SURVIVAL: Traveling to %s to buy food" % [squad_id, nearest_town.location_name])
			context["travel_destination"] = nearest_town.location_id
			return StrategyTypes.ActivityType.TRAVEL
	
	# Priority 2: If low on money, raid/patrol for loot
	if assigned_squad.money < SURVIVAL_MONEY_THRESHOLD:
		# Check for enemy squads nearby to attack for loot
		var enemies = world.get_squads_at_location(current_location.location_id)
		if not enemies.is_empty():
			print("[AIRunner:%s] SURVIVAL: Attacking enemies at current location for loot" % squad_id)
			context["attack_target"] = enemies[0].squad_id
			return StrategyTypes.ActivityType.ATTACK
		
		# Patrol to find opportunities
		if current_location.has_activity_type(StrategyTypes.ActivityType.PATROL):
			print("[AIRunner:%s] SURVIVAL: Patrolling for opportunities" % squad_id)
			return StrategyTypes.ActivityType.PATROL
		
		# Try mercenary work if available
		if current_location.has_activity_type(StrategyTypes.ActivityType.MERCENARY_WORK):
			print("[AIRunner:%s] SURVIVAL: Taking mercenary work" % squad_id)
			return StrategyTypes.ActivityType.MERCENARY_WORK
	
	# Default: Rest to recover
	print("[AIRunner:%s] SURVIVAL: Resting to recover" % squad_id)
	return StrategyTypes.ActivityType.REST

## Achievement mode: pursue objectives and eliminate threats
func _decide_achievement_mode(world: World, current_location: Location, context: Dictionary) -> StrategyTypes.ActivityType:
	# Priority 1: Investigate for clues about enemy squads
	if current_location != null and current_location.has_activity_type(StrategyTypes.ActivityType.INVESTIGATE):
		var active_clues = current_location.get_active_clues(world.turn_count)
		if active_clues.size() > 0:
			print("[AIRunner:%s] ACHIEVEMENT: Investigating clues at current location" % squad_id)
			return StrategyTypes.ActivityType.INVESTIGATE
	
	# Priority 2: Attack enemies at current location
	var enemies = world.get_squads_at_location(assigned_squad.current_location_id)
	print("[AIRunner:%s] Checking for enemies at %s: found %d squads" % [
		squad_id,
		assigned_squad.current_location_id,
		enemies.size()
	])
	if not enemies.is_empty():
		var target = _choose_attack_target(enemies)
		if target:
			print("[AIRunner:%s] ACHIEVEMENT: Attacking enemy squad %s" % [squad_id, target.squad_id])
			context["attack_target"] = target.squad_id
			return StrategyTypes.ActivityType.ATTACK
		else:
			print("[AIRunner:%s] No valid targets after filtering" % squad_id)
	
	# Priority 3: Hunt for enemy squads at other locations
	var enemy_location = _find_nearest_enemy_location(world, current_location)
	if enemy_location and enemy_location.location_id != current_location.location_id:
		print("[AIRunner:%s] ACHIEVEMENT: Hunting enemies at %s" % [squad_id, enemy_location.location_name])
		context["travel_destination"] = enemy_location.location_id
		return StrategyTypes.ActivityType.FORCE_MARCH
	
	# Priority 4: Track down known enemy locations via clues
	var clue_destination = _find_clue_destination(current_location, world)
	if clue_destination:
		print("[AIRunner:%s] ACHIEVEMENT: Pursuing clue to %s" % [squad_id, clue_destination])
		context["travel_destination"] = clue_destination
		return StrategyTypes.ActivityType.FORCE_MARCH # Fast pursuit
	
	# Priority 5: Patrol to generate clues or find enemies
	if current_location != null and current_location.has_activity_type(StrategyTypes.ActivityType.PATROL):
		print("[AIRunner:%s] ACHIEVEMENT: Patrolling area" % squad_id)
		return StrategyTypes.ActivityType.PATROL
	
	# Priority 6: Move to high-value locations (cities, forts)
	var strategic_location = _find_nearest_location_of_type(
		world,
		current_location,
		[StrategyTypes.LocationType.CITY, StrategyTypes.LocationType.FORT]
	)
	if strategic_location and strategic_location.location_id != current_location.location_id:
		print("[AIRunner:%s] ACHIEVEMENT: Moving to strategic location %s" % [squad_id, strategic_location.location_name])
		context["travel_destination"] = strategic_location.location_id
		return StrategyTypes.ActivityType.TRAVEL
	
	# Default: Drill to improve combat effectiveness
	if current_location != null and current_location.has_activity_type(StrategyTypes.ActivityType.DRILL):
		print("[AIRunner:%s] ACHIEVEMENT: Drilling squad" % squad_id)
		return StrategyTypes.ActivityType.DRILL
	
	# Last resort: Rest
	print("[AIRunner:%s] ACHIEVEMENT: Resting" % squad_id)
	return StrategyTypes.ActivityType.REST

## Find nearest location of given types using BFS pathfinding
func _find_nearest_location_of_type(world: World, from_location: Location, types: Array) -> Location:
	if not world.travel_graph:
		return null
	
	var visited: Dictionary = {}
	var queue: Array = [from_location.location_id]
	visited[from_location.location_id] = true
	
	while queue.size() > 0:
		var current_id = queue.pop_front()
		var current_loc = world.get_location_by_id(current_id)
		
		if not current_loc:
			continue
		
		# Check if this location matches desired type
		if current_id != from_location.location_id and current_loc.type in types:
			return current_loc
		
		# Add neighbors to queue
		for neighbor_id in current_loc.connections:
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				queue.append(neighbor_id)
	
	return null

## Find nearest location with enemy squads
func _find_nearest_enemy_location(world: World, from_location: Location) -> Location:
	if not world.travel_graph:
		return null
	
	var visited: Dictionary = {}
	var queue: Array = [from_location.location_id]
	visited[from_location.location_id] = true
	
	while queue.size() > 0:
		var current_id = queue.pop_front()
		var current_loc = world.get_location_by_id(current_id)
		
		if not current_loc:
			continue
		
		# Check if this location has enemy squads (excluding self)
		if current_id != from_location.location_id:
			var squads = world.get_squads_at_location(current_id)
			for squad in squads:
				if squad.squad_id != squad_id: # Use squad_id not executor.squad.squad_id
					return current_loc
		
		# Add neighbors to queue
		for neighbor_id in current_loc.connections:
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				queue.append(neighbor_id)
	
	return null

## Choose which enemy squad to attack based on strategic considerations
func _choose_attack_target(enemies: Array) -> SquadStrategicData:
	if enemies.is_empty():
		return null
	
	# Filter out self (squad attacking itself)
	var valid_enemies: Array[SquadStrategicData] = []
	for enemy in enemies:
		if enemy.squad_id != squad_id: # Use squad_id not executor.squad.squad_id
			valid_enemies.append(enemy)
	
	print("[AIRunner:%s] Filtered %d enemies down to %d valid targets" % [
		squad_id,
		enemies.size(),
		valid_enemies.size()
	])
	
	if valid_enemies.is_empty():
		return null
	
	# Choose the weakest target (lowest morale)
	var weakest = valid_enemies[0]
	for enemy in valid_enemies:
		if enemy.get_morale() < weakest.get_morale():
			weakest = enemy
	
	return weakest

## Find destination from clues at current location
func _find_clue_destination(location: Location, world: World) -> String:
	var active_clues = location.get_active_clues(world.turn_count)
	
	if active_clues.is_empty():
		return ""
	
	# Return the destination of the freshest clue
	var freshest = active_clues[0]
	for clue in active_clues:
		if clue.created_turn > freshest.created_turn:
			freshest = clue
	
	return freshest.destination_id

## Execute the decided activity for this turn
## Returns ActivityResult
func execute_activity(activity_type: StrategyTypes.ActivityType, context: Dictionary) -> ActivityResult:
	# Get activity from scenario
	var activity = _get_activity_from_scenario(activity_type)
	if not activity:
		push_error("[AIRunner:%s] Could not find activity of type %s" % [
			squad_id,
			StrategyTypes.ActivityType.keys()[activity_type]
		])
		return null
	
	# Handle special activities that need extra setup
	match activity_type:
		StrategyTypes.ActivityType.TRAVEL, StrategyTypes.ActivityType.FORCE_MARCH:
			var destination = context.get("travel_destination", "")
			if destination.is_empty():
				push_error("[AIRunner:%s] TRAVEL activity requires destination in context" % squad_id)
				return null
			activity.destination_id = destination
		
		StrategyTypes.ActivityType.ATTACK:
			var target = context.get("attack_target", "")
			if target.is_empty():
				push_error("[AIRunner:%s] ATTACK activity requires target in context" % squad_id)
				return null
			# Target will be handled by activity execution
	
	# Build context for activity execution
	var exec_context = executor._build_context(activity)
	
	# Execute activity
	var results = activity.execute(exec_context)
	
	if results.is_empty():
		return null
	
	# Apply result to squad
	var result = results[0]
	executor._apply_result(result)
	
	return result

## Get activity from scenario's triggerable manager
func _get_activity_from_scenario(activity_type: StrategyTypes.ActivityType) -> Activity:
	for triggerable in executor.scenario.triggerable_manager.registered_triggerables:
		if triggerable is Activity and triggerable.activity_type == activity_type:
			return triggerable
	return null
