class_name SystemsRoot
extends Node

var clock_system: ClockSystem
var squad_acting_system: SquadActingSystem
var travel_system: SquadTravelSystem
var battle_system: BattleResolutionSystem
var activity_run_system: ActivityRunSystem
var debug_command_system: DebugCommandSystem
var location_eco_system: LocationEconomySystem
var population_system: PopulationSystem
var caravan_eco_system: CaravanEconomySystem
var trade_system: TradeSystem
var monster_spawn_system: MonsterSpawnSystem
var sin_inhering_system: SinInheringSystem


func setup() -> void:
	clock_system = _enter_system(ClockSystem) as ClockSystem
	squad_acting_system = _enter_system(SquadActingSystem) as SquadActingSystem
	travel_system = _enter_system(SquadTravelSystem) as SquadTravelSystem
	battle_system = _enter_system(BattleResolutionSystem) as BattleResolutionSystem
	activity_run_system = _enter_system(ActivityRunSystem) as ActivityRunSystem
	debug_command_system = _enter_system(DebugCommandSystem) as DebugCommandSystem
	location_eco_system = _enter_system(LocationEconomySystem) as LocationEconomySystem
	population_system = _enter_system(PopulationSystem) as PopulationSystem
	caravan_eco_system = _enter_system(CaravanEconomySystem) as CaravanEconomySystem
	trade_system = _enter_system(TradeSystem) as TradeSystem
	monster_spawn_system = _enter_system(MonsterSpawnSystem) as MonsterSpawnSystem
	sin_inhering_system = _enter_system(SinInheringSystem) as SinInheringSystem


func _enter_system(system_script: GDScript) -> Node:
	var system = system_script.new()
	assert(system is Node)
	system.name = system_script.get_global_name()
	add_child(system)
	return system
