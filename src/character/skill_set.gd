class_name SkillSet
extends Resource

enum Types {
	Swords,
	Polearms,
	Crossbows,
	Firearms,
	Maces,
	Healing,
	Scholarship,
	Preaching,
}
var _levels: Dictionary = { }


func _init(defaults: Dictionary = { }) -> void:
	for skill_type in SkillType.Types.values():
		_levels[skill_type] = defaults.get(skill_type, 0)


func get_level(skill_type: SkillType.Types) -> int:
	return _levels.get(skill_type, 0)


func set_level(skill_type: SkillType.Types, level: int) -> void:
	_levels[skill_type] = clampi(level, 0, 10)
