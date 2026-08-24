## Bundles everything main.gd needs to boot straight into a scenario when DEBUG is on: a
## GameScenario plus the live roaming StrategySquad instances its production load_scenario()
## expects. Swap this Resource for a different one in the Inspector to boot a different debug
## scenario. A few fields deliberately aren't @export'd elsewhere (not meant to round-trip to
## disk) and so reset on every ResourceLoader.load(): GameScenario.triggerable_manager,
## StrategySquad.current_location_id, and Population.people (rebuilt from population_config, same
## as GameScenario._setup_economy() does for a production scenario). prepare() rebuilds all three.
class_name DebugScenario
extends Resource

@export var scenario: GameScenario
@export var squads: Array[StrategySquad] = []
@export var activity_paths: Array[String] = [
	"res://resources/strategy/generic-activities/travelling/travel.tres",
	"res://resources/strategy/generic-activities/forage/forage.tres",
]
## squad_id -> location_id, applied after load. Covers squads whose starting_location_id
## points outside this scenario's own world (e.g. a squad preset authored against a different sandbox).
@export var location_overrides: Dictionary[String, String] = {}


func prepare() -> Array[StrategySquad]:
	if scenario.triggerable_manager == null:
		scenario.triggerable_manager = TriggerableManager.new()
		for path: String in activity_paths:
			scenario.triggerable_manager.register(load(path))
	for loc: Location in scenario.world.locations:
		if loc.population_config != null:
			loc.population = loc.population_config.build_population(loc.location_id)
	for squad in squads:
		if location_overrides.has(squad.squad_id):
			squad.current_location_id = location_overrides[squad.squad_id]
		elif squad.current_location_id.is_empty():
			squad.current_location_id = squad.starting_location_id
	return squads
