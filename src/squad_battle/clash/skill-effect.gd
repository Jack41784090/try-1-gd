## SkillEffects go along with Skill. Always commits the moment a Skill a committed. If commit fails, it wouldn't stay in the queue of statuses within the entity.
class_name SkillEffect extends Resource

@export var source: SquadEntity
@export var affected: SquadEntity
@export var name: String
@export var commitType: ClashCommonTypes.CommitType
@export var triggers: Array[StatusEffectEventBus.Signals]

# ApplyStatusEffect
@export var statusEffectToAddID: StatusEffect = null

# Damage or Heal
@export var calculationType: ClashCommonTypes.CalculationType
@export var value: float

func _init(
	_name: String = '',
	_source: SquadEntity = null,
	_affected: SquadEntity = null,
	_commitType: ClashCommonTypes.CommitType = ClashCommonTypes.CommitType.ApplyStatusEffect):
	if _name == '':
		return;

	name = _name;
	source = _source;
	affected = _affected;
	commitType = _commitType;
	match commitType:
		ClashCommonTypes.CommitType.ApplyStatusEffect:
			assert(statusEffectToAddID != null, "ApplyStatusEffect has no status effect set")
		_:
			pass
	
	for t in triggers:
		StatusEffectEventBus.Connect(t, commit)
	pass

func commit() -> Array[SquadBattleTypes.EntityUpdate]:
	print("[SkE] " % resource_name)
	match commitType:
		ClashCommonTypes.CommitType.ApplyStatusEffect:
			print("Applying SE: " % statusEffectToAddID.name % " for " % affected.entity_name)
		ClashCommonTypes.CommitType.Damage:
			print("Damaging: " % value % " for " % affected.entity_name)
		ClashCommonTypes.CommitType.Heal:
			print("Healing: " % value % " for " % affected.entity_name)
		_:
			assert(false, "Unknown commit type: " % commitType);
	
	for t in triggers:
		StatusEffectEventBus.Disconnect(t, commit)
	return [];
