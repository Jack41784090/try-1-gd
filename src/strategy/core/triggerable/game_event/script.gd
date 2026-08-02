class_name GameEvent
extends Triggerable

@export var result: GenericResult
@export var when_to_trigger: StrategyTypes.TriggerWhen = StrategyTypes.TriggerWhen.AFTER_ACTIVITY

var times_triggered: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	super._init()


func can_trigger(context: Dictionary = {}) -> bool:
	if repeats >= 0 and times_triggered >= repeats:
		return false

	## Check chance roll (only roll if chance < 1.0 to avoid unnecessary RNG calls)
	if chance < 1.0 and _rng.randf() > chance:
		return false

	return super.can_trigger(context)


func trigger(context: Dictionary) -> Array[GenericResult]:
	times_triggered += 1
	var _result = execute(context)

	return [_result]


func execute(context: Dictionary) -> GenericResult:
	return result


func increment_trigger_count() -> void:
	times_triggered += 1


func reset_trigger_count() -> void:
	times_triggered = 0
