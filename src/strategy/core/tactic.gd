class_name Tactic
extends Resource

enum TacticType {
	BALANCED,
	AGGRESSIVE_CHARGE,
	GUERILLA_DEFENCE,
	FULL_ASSAULT,
	DEFENSIVE_FORMATION
}

@export var tactic_id: String = ""
@export var tactic_name: String = ""
@export var action_count: int = 1
@export var reaction_count: int = 1
@export var attack_modifier: float = 1.0
@export var defense_modifier: float = 1.0


static func create_balanced() -> Tactic:
	var tactic := Tactic.new()
	tactic.tactic_id = "balanced"
	tactic.tactic_name = "Balanced"
	tactic.action_count = 10
	tactic.reaction_count = 8
	tactic.attack_modifier = 1.0
	tactic.defense_modifier = 1.0
	return tactic


static func create_aggressive_charge() -> Tactic:
	var tactic := Tactic.new()
	tactic.tactic_id = "aggressive_charge"
	tactic.tactic_name = "Aggressive Charge"
	tactic.action_count = 6
	tactic.reaction_count = 2
	tactic.attack_modifier = 1.0
	tactic.defense_modifier = 0.8
	return tactic


static func create_guerilla_defence() -> Tactic:
	var tactic := Tactic.new()
	tactic.tactic_id = "guerilla_defence"
	tactic.tactic_name = "Guerilla Defence"
	tactic.action_count = 3
	tactic.reaction_count = 6
	tactic.attack_modifier = 0.8
	tactic.defense_modifier = 1.0
	return tactic


static func create_full_assault() -> Tactic:
	var tactic := Tactic.new()
	tactic.tactic_id = "full_assault"
	tactic.tactic_name = "Full Assault"
	tactic.action_count = 8
	tactic.reaction_count = 0
	tactic.attack_modifier = 1.2
	tactic.defense_modifier = 0.6
	return tactic


static func create_defensive_formation() -> Tactic:
	var tactic := Tactic.new()
	tactic.tactic_id = "defensive_formation"
	tactic.tactic_name = "Defensive Formation"
	tactic.action_count = 1
	tactic.reaction_count = 8
	tactic.attack_modifier = 0.6
	tactic.defense_modifier = 1.2
	return tactic


static func create_from_type(type: TacticType) -> Tactic:
	match type:
		TacticType.BALANCED:
			return create_balanced()
		TacticType.AGGRESSIVE_CHARGE:
			return create_aggressive_charge()
		TacticType.GUERILLA_DEFENCE:
			return create_guerilla_defence()
		TacticType.FULL_ASSAULT:
			return create_full_assault()
		TacticType.DEFENSIVE_FORMATION:
			return create_defensive_formation()
		_:
			return create_balanced()
