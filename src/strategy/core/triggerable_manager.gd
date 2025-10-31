extends RefCounted
class_name TriggerableManager

signal triggerable_fired(triggerable: Triggerable, result: Variant)

var registered_triggerables: Array[Triggerable] = []

func register(triggerable: Triggerable) -> void:
	if not triggerable in registered_triggerables:
		registered_triggerables.append(triggerable)
		_connect_signals(triggerable)

func register_many(triggerables: Array[Triggerable]) -> void:
	for triggerable in triggerables:
		register(triggerable)

func unregister(triggerable: Triggerable) -> void:
	var index = registered_triggerables.find(triggerable)
	if index >= 0:
		_disconnect_signals(triggerable)
		registered_triggerables.remove_at(index)

func clear() -> void:
	for triggerable in registered_triggerables:
		_disconnect_signals(triggerable)
	registered_triggerables.clear()

func check_triggers(context: Dictionary, filter: Callable = func(_t): return true) -> Array[Triggerable]:
	var triggered: Array[Triggerable] = []
	
	for triggerable in registered_triggerables:
		if not filter.call(triggerable):
			continue
		
		if triggerable.can_trigger(context) and triggerable.check_conditions(context):
			triggered.append(triggerable)
	
	return triggered

func trigger_all_matching(squad: StrategicSquad, world: World, context: Dictionary, filter: Callable = func(_t): return true) -> Array:
	var triggered_results: Array = []
	var matching = check_triggers(context, filter)
	
	for triggerable in matching:
		var result = triggerable.trigger(squad, world)
		triggered_results.append(result)
		triggerable_fired.emit(triggerable, result)
	
	return triggered_results

func get_by_id(trigger_id: String) -> Triggerable:
	for triggerable in registered_triggerables:
		if triggerable.trigger_id == trigger_id:
			return triggerable
	return null

func get_events() -> Array[GameEvent]:
	var events: Array[GameEvent] = []
	for triggerable in registered_triggerables:
		if triggerable is GameEvent:
			events.append(triggerable as GameEvent)
	return events

func get_missions() -> Array[Mission]:
	var missions: Array[Mission] = []
	for triggerable in registered_triggerables:
		if triggerable is Mission:
			missions.append(triggerable as Mission)
	return missions

func get_endings() -> Array[Ending]:
	var endings: Array[Ending] = []
	for triggerable in registered_triggerables:
		if triggerable is Ending:
			endings.append(triggerable as Ending)
	return endings

func _connect_signals(triggerable: Triggerable) -> void:
	if not triggerable.triggered.is_connected(_on_triggerable_triggered):
		triggerable.triggered.connect(_on_triggerable_triggered.bind(triggerable))

func _disconnect_signals(triggerable: Triggerable) -> void:
	if triggerable.triggered.is_connected(_on_triggerable_triggered):
		triggerable.triggered.disconnect(_on_triggerable_triggered)

func _on_triggerable_triggered(result: Dictionary, triggerable: Triggerable) -> void:
	triggerable_fired.emit(triggerable, result as Variant)
