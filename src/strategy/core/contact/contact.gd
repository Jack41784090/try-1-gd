class_name Contact extends RefCounted

var being_tracked: bool = false
var observer_id: String
var target_id: String
var progress: float = 0.0
var last_delta: float = 0.0
var last_updated_hour: int = 0

static func create(p_observer: String, p_target: String):
	var c = Contact.new()
	c.observer_id = p_observer
	c.target_id = p_target
	return c

func get_state() -> StrategyTypes.ContactState:
	if progress >= 100.0:
		return StrategyTypes.ContactState.LOCKED
	elif progress >= 30.0:
		return StrategyTypes.ContactState.TRACKED
	elif progress >= 1.0:
		return StrategyTypes.ContactState.SUSPECTED
	return StrategyTypes.ContactState.NONE

func apply_delta(delta: float, current_hour: int) -> void:
	if delta <= 0.0: being_tracked = false
	else: being_tracked = true

	last_delta = delta
	progress = clampf(progress + delta, 0.0, 100.0)
	last_updated_hour = current_hour
