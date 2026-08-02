class_name SimplifiedSquadLogic
extends RefCounted

var entity: CombatEntity
var situation: Situation
var context: Dictionary
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


## Evaluates all considerations in the entity's logic config to pick the best
## skill. Each consideration scores the situation using Glances and returns a
## Skill if score > 0; highest score wins. Falls back to default attack.
func choose_skill() -> Skill:
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
		best_skill = best_skill.instantiate()
		print("  [%d] %s → '%s' (score %.2f)" % [entity.player_id, entity.display_name, best_skill.name, best_score])
	else:
		print("  [%d] %s → default attack (no considerations scored)" % [entity.player_id, entity.display_name])
		best_skill = get_default_attack()

	return best_skill


func get_default_attack() -> Skill:
	return load('res://resources/combat/logic/skills/example-attack-skill.tres')


