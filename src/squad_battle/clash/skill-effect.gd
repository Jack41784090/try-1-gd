## SkillEffects go along with Skill. Always commits the moment a Skill a committed. If commit fails, it wouldn't stay in the queue of statuses within the entity.
class_name SkillEffect extends Resource


@export var name: String
@export var source: SquadEntity
@export var affected: SquadEntity; @export var targeting = "target"  # "self" or "target"
@export var commitType: ClashCommonTypes.CommitType
@export var triggers: Array[StatusEffectEventBus.Signals]

# ApplyStatusEffect
@export var statusEffectToApply: StatusEffect = null

# Damage or Heal
@export var calculationType: ClashCommonTypes.CalculationType
@export var value: float

func _init(
	_name: String = '',
	_source: SquadEntity = null,
	_affected: SquadEntity = null,
	_commitType: ClashCommonTypes.CommitType = ClashCommonTypes.CommitType.ApplyStatusEffect,
	_triggers: Array[StatusEffectEventBus.Signals] = [],
	_additional_data: Dictionary = {}
) -> void:
	
	print("  [SkillEffect._init] Called with _name='%s'" % _name)
	print("    → @export name is currently: '%s'" % name)
	print("    → @export triggers array size: %d" % triggers.size())
	
	if _name == '':
		print("    ✗ Empty _name parameter - assuming resource loading")
		print("    → Will skip manual initialization, @export vars will be set by resource loader")
		# At this point, @export variables are NOT yet loaded from the .tres file
		# They will be set AFTER _init() completes
		return
	else:
		print("    ✓ Non-empty _name - manual initialization")
		name = _name;
		source = _source;
		affected = _affected if _affected != null else (source if targeting == "self" else null);
		commitType = _commitType;
		triggers = _triggers;
		match commitType:
			ClashCommonTypes.CommitType.ApplyStatusEffect:
				statusEffectToApply = _additional_data.get('statusEffectToApply', null)
				assert(statusEffectToApply != null, "ApplyStatusEffect has no status effect set")
			ClashCommonTypes.CommitType.Damage, ClashCommonTypes.CommitType.Heal:
				calculationType = _additional_data.get('calculationType', ClashCommonTypes.CalculationType.Flat)
				value = _additional_data.get('value', 0.0)
			_:
				pass
	
	# match commitType:
	# 	ClashCommonTypes.CommitType.ApplyStatusEffect:
	# 		assert(statusEffectToApply != null, "ApplyStatusEffect has no status effect set")
	# 	_:
	# 		pass
	
	# # This loop will only run if programmatically created, not when loaded from resource
	# print("    → Attempting to subscribe %d triggers..." % triggers.size())
	# for t in triggers:
	# 	print("      → Subscribing to trigger: %s" % StatusEffectEventBus._signals.get(t))
	# 	StatusEffectEventBus.Connect(t, commit)
	pass

func setup_connections() -> void:
	"""Call this after the resource is loaded to connect triggers to the event bus."""
	print("  [SkillEffect] Setting up connections for '%s'" % name)
	print("    → Effect type: %s" % _get_commit_type_name(commitType))
	print("    → Triggers to connect: %d" % triggers.size())
	
	for t in triggers:
		var signal_name = _format_trigger_name(t)
		print("      → Connecting to signal: %s" % signal_name)
		var _result = StatusEffectEventBus.Connect(t, commit)
		print("      → Connection result: %s" % _result)

func _format_trigger_name(trigger) -> String:
	match trigger:
		StatusEffectEventBus.Signals.HelloWorld: return "HelloWorld"
		StatusEffectEventBus.Signals.TargetTookDamage: return "TargetTookDamage"
		_: return "Signal_%d" % trigger

func _get_commit_type_name(type: ClashCommonTypes.CommitType) -> String:
	match type:
		ClashCommonTypes.CommitType.ApplyStatusEffect: return "ApplyStatusEffect"
		ClashCommonTypes.CommitType.Damage: return "Damage"
		ClashCommonTypes.CommitType.Heal: return "Heal"
		_: return "Unknown"

func _format_triggers(trigger_array: Array) -> String:
	if trigger_array.is_empty():
		return "None"
	var names = []
	for t in trigger_array:
		match t:
			StatusEffectEventBus.Signals.HelloWorld: names.append("HelloWorld")
			StatusEffectEventBus.Signals.TargetTookDamage: names.append("TargetTookDamage")
			_: names.append("Signal_%d" % t)
	return ", ".join(names)

func commit() -> Array[SquadBattleTypes.EntityUpdate]:
	print("    [SkillEffect] Committing '%s'" % name)
	
	var updates: Array[SquadBattleTypes.EntityUpdate] = []
	
	match commitType:
		ClashCommonTypes.CommitType.ApplyStatusEffect:
			if statusEffectToApply and affected:
				print("      → Applying status '%s' to %s" % [statusEffectToApply.name, affected.entity_name])
				affected.status_effects.append(statusEffectToApply)
				print("      → %s now has %d status effects" % [affected.entity_name, affected.status_effects.size()])
			else:
				print("      ✗ Cannot apply status: missing effect or target")
		
		ClashCommonTypes.CommitType.Damage:
			if affected and source:
				print("      → Dealing %.2f damage to %s" % [value, affected.entity_name])
				var damage_updates = affected.damage(value, source.player_id)
				for u in damage_updates:
					updates.append(u)
					print("      → Update: %s" % u)
			else:
				print("      ✗ Cannot deal damage: missing source or target")
		
		ClashCommonTypes.CommitType.Heal:
			if affected and source:
				print("      → Healing %.2f to %s" % [value, affected.entity_name])
				var heal_change = affected.heal(value)
				if heal_change:
					var update = SquadBattleTypes.EntityUpdate.new(source.player_id, affected.player_id, heal_change)
					updates.append(update)
					print("      → Update: %s" % update)
			else:
				print("      ✗ Cannot heal: missing source or target")
		
		_:
			print("      ✗ Unknown commit type: %d" % commitType)
	
	# Disconnect triggers after commit
	for t in triggers:
		StatusEffectEventBus.Disconnect(t, commit)
	
	print("    [SkillEffect] Commit complete - %d updates generated" % updates.size())
	return updates
