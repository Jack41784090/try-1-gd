# EXAMPLE: Simplified SquadLogic using only considerations
# This shows the target architecture after full migration

# Resource: Serializable configuration

# Runtime: Executes logic using the configuration
class_name SimplifiedSquadLogic
extends RefCounted

var entity: CombatEntity
var situation: Situation
var context: Dictionary
var logic_specific_skills: Array[Skill] = []
var config: SimplifiedLogicConfig


func _init(initial_context: Dictionary, logic_config: SimplifiedLogicConfig = null):
	context = initial_context
	entity = context["entity"]
	situation = Situation.new(context)
	config = logic_config if logic_config else SimplifiedLogicConfig.new()


func update_situation(new_context: Dictionary):
	context = new_context
	situation = Situation.new(context)
	return self


func choose_skill() -> Skill:
	# Evaluates all considerations in the entity's logic config to pick the best skill
	# Each consideration scores the situation using Glances and returns a Skill if score > 0
	# e.g., config.considerations: ["low_hp_heal"(score=0.8, returns=HealSkill), "attack"(score=0.5, returns=SlashSkill)]
	#   → best = "low_hp_heal" (0.8) → returns HealSkill
	# e.g., no considerations score > 0 → returns default attack skill
	if config.considerations.size() == 0:
		return get_default_attack()


	var best_skill: Skill = null
	var best_score := -INF

	for csdr in config.considerations:
		if csdr.should_return == Consideration.SkillOrTarget.Target:
			push_warning("[%s] returns a target, but it should return a skill" % csdr.name)
			continue

		var score = csdr.score(entity, situation, context)

		if score > 0.0 and score > best_score and csdr.returning != null:
			best_score = score
			best_skill = csdr.returning

	if best_skill:
		best_skill = best_skill.duplicate()
		print("  [%d] %s → '%s' (score %.2f)" % [entity.player_id, entity.display_name, best_skill.name, best_score])
	else:
		print("  [%d] %s → default attack (no considerations scored)" % [entity.player_id, entity.display_name])
		best_skill = get_default_attack()

	return best_skill


# Rest of the interface remains the same
func choose_weapon():
	return entity.weapon


func get_default_attack() -> Skill:
	return load('res://resources/combat/logic/skills/example-attack-skill.tres')


func choose_clash() -> OneClash:
	return choose_clash_with_skill(choose_skill())


func choose_clash_with_skill(selected_skill: Skill) -> OneClash:
	# Creates a OneClash from a chosen skill by finding the best target via the skill's targeting consideration
	# The targeting_consideration scores all valid targets and returns the highest-scoring one
	# e.g., SlashSkill with targeting(entity_limiter="enemies", glances=[HP(inverse)]) → targets weakest enemy
	#   → OneClash(attacker=Hans, target=Fritz, skill=Slash)
	var target = selected_skill.targeting_consideration.score_then_return(entity, situation, context)
	assert(target is CombatEntity or target == null)
	if target == null:
		print("No target found for skill %s" % selected_skill.name)
		return null
	return OneClash.new(
		entity,
		target,
		selected_skill,
		situation,
		context,
	)

## REMOVED ENTIRELY:
# - positioning_policy
# - retreat_if_outnumbered()
# - readjust_weapon()
# - heal_others_if_around()
# - is_line_ahead_of_me()
# - get_same_line_allies()
# - All subclasses (FrontlineLogic, ArcherLogic, etc.)
