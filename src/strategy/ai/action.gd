class_name StrategicAction extends Resource

@export var action_name: String = ""
@export var activity_type: StrategyTypes.ActivityType = StrategyTypes.ActivityType.REST
@export var requires_destination: bool = false
@export var destination_strategy: StrategicAITypes.DestinationStrategy = StrategicAITypes.DestinationStrategy.NEAREST_TOWN
@export var requires_target: bool = false
@export var target_strategy: StrategicAITypes.TargetStrategy = StrategicAITypes.TargetStrategy.WEAKEST

func resolve_context(situation: StrategicSituation) -> Dictionary:
	var context: Dictionary = {}

	if requires_destination:
		var ultimate_dest = _resolve_destination(situation)
		if ultimate_dest.is_empty():
			return {}
		var next_hop = _get_next_hop(situation, ultimate_dest)
		if next_hop.is_empty():
			return {}
		context["travel_destination"] = next_hop
		if activity_type == StrategyTypes.ActivityType.FORCE_MARCH and ultimate_dest != next_hop:
			context["ultimate_destination"] = ultimate_dest

	if requires_target:
		var target = _resolve_target(situation)
		if target == null:
			return {}
		context["attack_target"] = target.squad_id

	return context

func _get_next_hop(situation: StrategicSituation, ultimate_dest: String) -> String:
	if situation.location.is_connected_to(ultimate_dest):
		return ultimate_dest
	if not situation.world.travel_graph:
		return ""
	var path = situation.world.travel_graph.find_path(situation.location.location_id, ultimate_dest)
	if path.size() > 1:
		return path[1]
	return ""

func can_resolve(situation: StrategicSituation) -> bool:
	if requires_destination:
		var dest_id = _resolve_destination(situation)
		if dest_id.is_empty():
			return false
	if requires_target:
		var target = _resolve_target(situation)
		if target == null:
			return false
	return true

func _resolve_destination(situation: StrategicSituation) -> String:
	match destination_strategy:
		StrategicAITypes.DestinationStrategy.NEAREST_TOWN:
			if situation.nearest_town != null:
				return situation.nearest_town.location_id
		StrategicAITypes.DestinationStrategy.NEAREST_ENEMY:
			if situation.nearest_enemy_location != null:
				return situation.nearest_enemy_location.location_id
		StrategicAITypes.DestinationStrategy.CLUE_DESTINATION:
			if not situation.clue_destination_id.is_empty():
				return situation.clue_destination_id
		StrategicAITypes.DestinationStrategy.DIRECTIVE_LOCATION:
			if situation.directive != null and not situation.directive.target_location_id.is_empty():
				return situation.directive.target_location_id
		StrategicAITypes.DestinationStrategy.AWAY_FROM_ENEMY:
			return _resolve_away_from_enemy(situation)
	return ""

func _resolve_away_from_enemy(situation: StrategicSituation) -> String:
	var best_id := ""
	var best_distance := -1

	for connection in situation.location.connections.tt:
		var neighbor_id = connection.to_location_id
		var neighbor_loc = situation.world.get_location_by_id(neighbor_id)
		if not neighbor_loc:
			continue

		var enemy_dist := 0
		if situation.nearest_enemy_location:
			enemy_dist = situation.world.travel_graph.get_distance(neighbor_id, situation.nearest_enemy_location.location_id)
		else:
			enemy_dist = 999

		if enemy_dist > best_distance:
			best_distance = enemy_dist
			best_id = neighbor_id

	return best_id

func _resolve_target(situation: StrategicSituation) -> SquadStrategicData:
	var enemies = situation.enemies_here
	if enemies.is_empty():
		return null

	if activity_type == StrategyTypes.ActivityType.ATTACK:
		var tracker = situation.world.contact_tracker
		var tracked: Array[SquadStrategicData] = []
		for enemy in enemies:
			var contact = tracker.get_contact(situation.squad.squad_id, enemy.squad_id)
			if contact and contact.get_state() >= StrategyTypes.ContactState.TRACKED:
				tracked.append(enemy)
		if tracked.is_empty():
			return null
		enemies = tracked

	match target_strategy:
		StrategicAITypes.TargetStrategy.WEAKEST:
			var weakest = enemies[0]
			for enemy in enemies:
				if enemy.get_morale() < weakest.get_morale():
					weakest = enemy
			return weakest
		StrategicAITypes.TargetStrategy.STRONGEST:
			var strongest = enemies[0]
			for enemy in enemies:
				if enemy.get_morale() > strongest.get_morale():
					strongest = enemy
			return strongest
		StrategicAITypes.TargetStrategy.RANDOM:
			return enemies[randi() % enemies.size()]

	return null
