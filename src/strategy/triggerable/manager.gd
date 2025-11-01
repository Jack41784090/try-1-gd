extends RefCounted
class_name TriggerableManager

signal triggerable_fired(triggerable: Triggerable, result: Variant)

var registered_triggerables: Array[Triggerable] = []

func register(triggerable: Triggerable) -> void:
	if not triggerable in registered_triggerables:
		registered_triggerables.append(triggerable)
		_connect_signals(triggerable)

func check_triggers(context: Dictionary, filter: Callable = func(_t): return true) -> Array[Triggerable]:
	var triggered: Array[Triggerable] = []
	
	for triggerable in registered_triggerables:
		if not filter.call(triggerable):
			continue
		
		if triggerable.can_trigger(context) and triggerable.check_conditions(context):
			triggered.append(triggerable)
	
	return triggered

func get_by_id(trigger_id: String) -> Triggerable:
	for triggerable in registered_triggerables:
		if triggerable.trigger_id == trigger_id:
			return triggerable
	return null

func _connect_signals(triggerable: Triggerable) -> void:
	if not triggerable.triggered.is_connected(_on_triggerable_triggered):
		triggerable.triggered.connect(_on_triggerable_triggered.bind(triggerable))

func _disconnect_signals(triggerable: Triggerable) -> void:
	if triggerable.triggered.is_connected(_on_triggerable_triggered):
		triggerable.triggered.disconnect(_on_triggerable_triggered)

func _on_triggerable_triggered(result: Dictionary, triggerable: Triggerable) -> void:
	triggerable_fired.emit(triggerable, result as Variant)
