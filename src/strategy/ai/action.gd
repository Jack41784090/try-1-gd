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
		var dest_id = _resolve_destination(situation)
		if dest_id.is_empty():
			return {}
		context["travel_destination"] = dest_id

	if requires_target:
		var target = _resolve_target(situation)
		if target == null:
			return {}
		context["attack_target"] = target.squad_id

	return context

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
	return ""

func _resolve_target(situation: StrategicSituation) -> SquadStrategicData:
	var enemies = situation.enemies_here
	if enemies.is_empty():
		return null

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
