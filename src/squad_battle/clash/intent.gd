class_name ClashIntent
extends RefCounted

enum Phase { PROPOSED, GATHERED, COMMITTED, CANCELLED }

var caster: CombatEntity
var skill: Skill
var target: CombatEntity
var phase: Phase = Phase.PROPOSED
var depth: int = 0
var cause: ClashIntent = null
var damage_multiplier: float = 1.0
var bonus_damage: float = 0.0
var is_reaction: bool = false
var situation: Situation = null

var reaction_source_name: String = ""
var reaction_source_owner: int = -1

var _window: int = 0


func _init(p_caster: CombatEntity, p_skill: Skill, p_target: CombatEntity, p_depth: int = 0, p_cause: ClashIntent = null, p_situation: Situation = null) -> void:
	caster = p_caster
	skill = p_skill
	target = p_target
	depth = p_depth
	cause = p_cause
	is_reaction = p_cause != null
	situation = p_situation


func cancel() -> void:
	assert(phase != Phase.COMMITTED, "Cannot cancel a committed intent")
	phase = Phase.CANCELLED


func redirect(new_target: CombatEntity) -> void:
	assert(phase != Phase.COMMITTED, "Cannot redirect a committed intent")
	target = new_target


func replace_skill(new_skill: Skill) -> void:
	assert(phase != Phase.COMMITTED, "Cannot replace skill on a committed intent")
	skill = new_skill


func metadata() -> Dictionary:
	return {
		"depth": depth,
		"cause": cause.skill.name if cause else "",
		"window": _window,
		"reaction": is_reaction,
	}
