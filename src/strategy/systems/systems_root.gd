class_name SystemsRoot
extends Node

var clock_system: ClockSystem
var squad_being_system: SquadBeingSystem
var squad_ai_system: SquadAISystem
var travel_system: SquadTravelSystem
var battle_system: BattleResolutionSystem
var activity_run_system: ActivityRunSystem
var debug_command_system: DebugCommandSystem
var location_eco_system: LocationEconomySystem
var caravan_eco_system: CaravanEconomySystem


func setup() -> void:
	clock_system = _enter_system(ClockSystem) as ClockSystem
	squad_being_system = _enter_system(SquadBeingSystem) as SquadBeingSystem
	squad_ai_system = _enter_system(SquadAISystem) as SquadAISystem
	travel_system = _enter_system(SquadTravelSystem) as SquadTravelSystem
	battle_system = _enter_system(BattleResolutionSystem) as BattleResolutionSystem
	activity_run_system = _enter_system(ActivityRunSystem) as ActivityRunSystem
	debug_command_system = _enter_system(DebugCommandSystem) as DebugCommandSystem
	location_eco_system = _enter_system(LocationEconomySystem) as LocationEconomySystem
	caravan_eco_system = _enter_system(CaravanEconomySystem) as CaravanEconomySystem


func _enter_system(system_script: GDScript) -> Node:
	var system = system_script.new()
	assert(system is Node)
	system.name = system_script.get_global_name()
	add_child(system)
	return system
