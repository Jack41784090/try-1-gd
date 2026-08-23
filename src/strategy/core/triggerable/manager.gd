extends RefCounted

class_name TriggerableManager


var registered_triggerables: Array[Triggerable] = []

func register(triggerable: Triggerable) -> void:
	if not triggerable in registered_triggerables:
		registered_triggerables.append(triggerable)


func get_triggerables_triggered(context: Dictionary, filter: Callable = func(_t): return true) -> Array[Triggerable]:
	# a fired triggerable's trigger_chains may also fire their own chained trigger (subject to a chance roll)
	var triggered: Array[Triggerable] = []

	for triggerable in registered_triggerables:
		if not filter.call(triggerable):
			continue

		if triggerable.can_trigger(context):
			triggered.append(triggerable)

			for chain in triggerable.trigger_chains:
				MyLog.debug("TriggerableManager", "Processing chain for trigger: %s" % triggerable.trigger_name)
				var chained_trigger = chain.another_trigger
				var chance = chain.chance
				if chained_trigger.can_trigger(context) and (chance == 1.0 or (chance < 1.0 and RandomNumberGenerator.new().randf() <= chance)):
					MyLog.debug("TriggerableManager", "  Added chained trigger: %s" % chained_trigger.trigger_name)
					triggered.append(chained_trigger)
				else:
					MyLog.debug("TriggerableManager", "  Skipped chained trigger (chance failed): %s" % chained_trigger.trigger_name)

	return triggered