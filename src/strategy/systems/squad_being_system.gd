class_name SquadBeingSystem
extends Node

## Holds every Squad in the scenario — player and AI alike, no distinction.
## Doesn't run any game logic itself: on each hour_pass from the clock it
## just re-broadcasts squad_turn per squad. ActivityRunSystem (or anything
## else) listens for that and decides what to do — SquadBeingSystem doesn't
## know or care who's listening.

signal squad_turn(squad: StrategySquad)
signal squad_registered(squad: StrategySquad)
signal squad_unregistered(squad_id: String)

var squads: Dictionary = {} ## squad_id -> StrategySquad


func register_squad(squad: StrategySquad) -> void:
	squads[squad.squad_id] = squad
	squad_registered.emit(squad)
	LogGd.debug("[SquadBeingSystem] registered %s (%s)" % [squad.squad_name, squad.squad_id])


func unregister_squad(squad_id: String) -> void:
	if squads.erase(squad_id):
		squad_unregistered.emit(squad_id)
		LogGd.debug("[SquadBeingSystem] unregistered %s" % squad_id)


func get_squad(squad_id: String) -> StrategySquad:
	return squads.get(squad_id)


func get_all_squads() -> Array[StrategySquad]:
	var result: Array[StrategySquad] = []
	for squad in squads.values():
		result.append(squad)
	return result


## Connected to the clock's hour signal by main.gd — see load_scenario().
func on_hour_pass(hour: int) -> void:
	LogGd.debug("[SquadBeingSystem] hour_pass(%d) — %d squad(s)" % [hour, squads.size()])
	for squad: StrategySquad in squads.values():
		if squad.get_living_warriors().is_empty():
			continue
		squad_turn.emit(squad)
