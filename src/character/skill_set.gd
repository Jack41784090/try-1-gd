class_name SkillSet extends RefCounted

var _levels: Dictionary = {}

func _init(defaults: Dictionary = {}) -> void:
	for skill_type in SkillType.Types.values():
		_levels[skill_type] = defaults.get(skill_type, 0)

func get_level(skill_type: SkillType.Types) -> int:
	return _levels.get(skill_type, 0)

func set_level(skill_type: SkillType.Types, level: int) -> void:
	_levels[skill_type] = clampi(level, 0, 10)

func to_dict() -> Dictionary:
	var d := {}
	for skill_type in _levels:
		d[skill_type] = _levels[skill_type]
	return d

static func from_dict(d: Dictionary) -> SkillSet:
	var ss := SkillSet.new()
	for skill_type in d:
		ss.set_level(skill_type as SkillType.Types, d[skill_type])
	return ss
