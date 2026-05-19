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

	# Check chance roll (only roll if chance < 1.0 to avoid unnecessary RNG calls)
	if chance < 1.0 and _rng.randf() > chance:
		return false

	return super.can_trigger(context)


func trigger(context: Dictionary) -> Array[GenericResult]:
	times_triggered += 1
	var _result = execute(context)


	#if _result.auto_resolved and _result.event_chain_path.is_empty():
	#execution_completed.emit(_result)

	return [_result]


func execute(context: Dictionary) -> GenericResult:
	# Override this in subclasses to implement event logic
	# var result = EventResult.new({
	# 	"event_chain_path": event_chain_path,
	# 	"auto_resolved": event_chain_path.is_empty(),
	# 	"requires_async": not event_chain_path.is_empty()
	# })
	return result


func increment_trigger_count() -> void:
	times_triggered += 1


func reset_trigger_count() -> void:
	times_triggered = 0
