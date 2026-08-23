class_name AIAct
extends Resource
## A scripted player action for headless testing; an Array[AIAct] drives one deterministic turn sequence.

@export var activity_type: StrategyTypes.ActivityType = StrategyTypes.ActivityType.REST
@export var destination_id: String = ""
@export var target_squad_id: String = ""
@export var description: String = ""

@export_group("Assertions")
@export var expect_location: String = ""
@export var expect_min_food: int = -1
@export var expect_max_food: int = -1
@export var expect_min_morale: int = -9999
@export var expect_event_fired: String = ""
@export var expect_events_fired: Array[String] = []
@export var expect_min_warriors: int = -1


static func create(
	type: StrategyTypes.ActivityType,
	desc: String = "",
	dest: String = "",
	target: String = "",
) -> AIAct:
	var act := AIAct.new()
	act.activity_type = type
	act.description = desc
	act.destination_id = dest
	act.target_squad_id = target
	return act


func get_display_name() -> String:
	var display: String = StrategyTypes.ActivityType.keys()[activity_type]
	if not destination_id.is_empty():
		display += " → %s" % destination_id
	if not target_squad_id.is_empty():
		display += " vs %s" % target_squad_id
	return display


func has_assertions() -> bool:
	return (
		not expect_location.is_empty()
		or expect_min_food >= 0
		or expect_max_food >= 0
		or expect_min_morale > -9999
		or not expect_event_fired.is_empty()
		or not expect_events_fired.is_empty()
		or expect_min_warriors >= 0
	)
