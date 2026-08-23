class_name SimplifiedSquadLogic
extends RefCounted

var entity: CombatEntity
var situation: Situation
var context: Dictionary
var config: SimplifiedLogicConfig
var personal_rules: Array[Consideration] = []


func _init(initial_context: Dictionary, logic_config: SimplifiedLogicConfig = null, p_personal_rules: Array[Consideration] = []):
	context = initial_context
	entity = context["entity"]
	situation = Situation.new(context)
	config = logic_config if logic_config else SimplifiedLogicConfig.new()
	personal_rules = p_personal_rules


func update_situation(new_context: Dictionary):
	context = new_context
	situation = Situation.new(context)
	return self


## Highest-scoring consideration wins; falls back to default attack if none score > 0.
func choose_skill() -> Skill:
	var all_rules: Array[Consideration] = []
	all_rules.append_array(config.considerations)
	all_rules.append_array(personal_rules)

	if all_rules.is_empty():
		return get_default_attack()

	var best_skill: Skill = null
	var best_score := -INF

	for csdr in all_rules:
		if csdr.skill == null:
			continue

		var score = csdr.score(entity, situation, context)

		if score > 0.0 and score > best_score:
			best_score = score
			best_skill = csdr.skill

	if best_skill:
		best_skill = best_skill.instantiate()
		print("  [%d] %s → '%s' (score %.2f)" % [entity.player_id, entity.display_name, best_skill.name, best_score])
	else:
		print("  [%d] %s → default attack (no considerations scored)" % [entity.player_id, entity.display_name])
		best_skill = get_default_attack()

	return best_skill


func get_default_attack() -> Skill:
	return load('res://resources/combat/logic/skills/example-attack-skill.tres')


