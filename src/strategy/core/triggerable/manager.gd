extends RefCounted

class_name TriggerableManager


var registered_triggerables: Array[Triggerable] = []

func register(triggerable: Triggerable) -> void:
	if not triggerable in registered_triggerables:
		registered_triggerables.append(triggerable)


func get_triggerables_triggered(context: Dictionary, filter: Callable = func(_t): return true) -> Array[Triggerable]:
	# Checks all registered triggerables against the context and returns those whose conditions pass
	# Also processes trigger_chains: if a triggerable fires, its chained triggers may also fire (with chance rolls)
	# e.g., context={location: "salzburg", activity: FORAGE, turn: 5}
	#   → checks 10 registered triggerables → 2 pass conditions → 1 has a chain trigger (50% chance, passes)
	#   → returns [event_A, event_B, chain_event_C]
	var triggered: Array[Triggerable] = []

	for triggerable in registered_triggerables:
		# 1. Filter out triggerables that don't match the timing or other broad criteria (e.g., only check GameEvents, skip Missions)
		if not filter.call(triggerable):
			continue

		# 2. Check conditions + repeat/chance gates via can_trigger (location, squad status, world state, etc.)
		if triggerable.can_trigger(context):
			# 2.1 If conditions pass, add to triggered list
			triggered.append(triggerable)

			# 2.2 Sometimes triggerables have chain triggers, add them to the list if chained_trigger can also be triggered (with chance rolls)
			for chain in triggerable.trigger_chains:
				Log.debug("TriggerableManager", "Processing chain for trigger: %s" % triggerable.trigger_name)
				var chained_trigger = chain.another_trigger
				var chance = chain.chance
				if chained_trigger.can_trigger(context) and (chance == 1.0 or (chance < 1.0 and RandomNumberGenerator.new().randf() <= chance)):
					Log.debug("TriggerableManager", "  Added chained trigger: %s" % chained_trigger.trigger_name)
					triggered.append(chained_trigger)
				else:
					Log.debug("TriggerableManager", "  Skipped chained trigger (chance failed): %s" % chained_trigger.trigger_name)

	return triggered