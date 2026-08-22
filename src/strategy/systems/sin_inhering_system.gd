class_name SinInheringSystem
extends Node

## Owns "why" monster squads spawn — deliberately obtuse for this test: no
## narrative/economic grounding, just a per-hour dice roll and a uniformly
## random location. Real triggering (narrative beats, economic desperation
## mirroring BanditSpawner's pressure model, etc.) is future work by someone
## else; this system's only job is to prove the spawn_triggered -> "what to
## spawn" -> "how to spawn" pipeline end to end.

signal spawn_triggered(near_location_id: String)

@export var spawn_chance_per_hour: float = 0.15

var scenario: GameScenario


func setup(_scenario: GameScenario) -> void:
	assert(_scenario != null, "SinInheringSystem requires a GameScenario")
	scenario = _scenario


## Connected to ClockSystem.hour_changed by main.gd, same public-slot
## convention as SquadBeingSystem.on_hour_pass.
func on_hour_pass(hour: int) -> void:
	if scenario.world.locations.is_empty():
		return
	if randf() > spawn_chance_per_hour:
		return
	var loc: Location = scenario.world.locations[randi() % scenario.world.locations.size()]
	spawn_triggered.emit(loc.location_id)
