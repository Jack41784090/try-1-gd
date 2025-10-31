extends RefCounted
class_name EventManager

var registered_events: Array[GameEvent] = []

func register_event(event: GameEvent) -> void:
	registered_events.append(event)

func register_events(events: Array[GameEvent]) -> void:
	for event in events:
		register_event(event)

func clear_events() -> void:
	registered_events.clear()

func check_triggers(_when: StrategyTypes.TriggerWhen, context: Dictionary) -> Array[GameEvent]:
	var triggered_events: Array[GameEvent] = []
	
	for event in registered_events:
		if event.when_to_trigger != _when:
			continue
		
		if not event.can_trigger(context):
			continue
		
		if event.check_conditions(context):
			triggered_events.append(event)
	
	triggered_events.sort_custom(_sort_by_priority)
	
	return triggered_events

func _sort_by_priority(a: GameEvent, b: GameEvent) -> bool:
	return a.emergency_priority < b.emergency_priority

func get_event_by_id(event_id: String) -> GameEvent:
	for event in registered_events:
		if event.event_id == event_id:
			return event
	return null

func trigger_event_by_id(event_id: String, squad: StrategicSquad, world: World) -> StrategyTypes.EventResult:
	var event = get_event_by_id(event_id)
	if event:
		return event.trigger(squad, world)
	
	push_warning("Event not found: %s" % event_id)
	var result = StrategyTypes.EventResult.new()
	result.narrative_text = "Event not found: %s" % event_id
	return result
