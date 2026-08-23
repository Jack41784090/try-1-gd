class_name SinInheringSystem
extends Node

## Deliberately obtuse spawn trigger (dice roll + random location) — proves the spawn_triggered pipeline end to end; real narrative/economic triggering is future work.

signal spawn_triggered(near_location_id: String)

@export var spawn_chance_per_hour: float = 0.15

var scenario: GameScenario


func setup(_scenario: GameScenario) -> void:
	assert(_scenario != null, "SinInheringSystem requires a GameScenario")
	scenario = _scenario


func on_hour_pass(hour: int) -> void:
	if scenario.world.locations.is_empty():
		return
	if randf() > spawn_chance_per_hour:
		return
	var loc: Location = scenario.world.locations[randi() % scenario.world.locations.size()]
	spawn_triggered.emit(loc.location_id)
