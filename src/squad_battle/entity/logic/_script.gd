# EXAMPLE: Simplified SquadLogic using only considerations
# This shows the target architecture after full migration

# Resource: Serializable configuration

# Runtime: Executes logic using the configuration
class_name SimplifiedSquadLogic extends RefCounted

var entity: SquadEntity
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
	if config.considerations.size() == 0:
		return get_default_attack()
	
	print("\n=== EVALUATING BEST SKILL ===")
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
		print("\n[RESULT] Best Skill: %s (score=%.2f)" % [best_skill.name, best_score])
	else:
		print("\n[RESULT] No valid skill found, using default")
		best_skill = get_default_attack()
	print("==============================\n")
	
	return best_skill

# Rest of the interface remains the same
func choose_weapon():
	return entity.weapon

func get_default_attack() -> Skill:
	return Skill.new("Basic Attack", [])

func choose_clash() -> OneClash:
	return choose_clash_with_skill(choose_skill())

func choose_clash_with_skill(selected_skill: Skill) -> OneClash:	
	var target = selected_skill.targeting_consideration.score_then_return(entity, situation, context)
	assert(target is SquadEntity);
	return OneClash.new(
		entity,
		target,
		selected_skill
	)

## REMOVED ENTIRELY:
# - positioning_policy
# - retreat_if_outnumbered()
# - readjust_weapon()
# - heal_others_if_around()
# - is_line_ahead_of_me()
# - get_same_line_allies()
# - All subclasses (FrontlineLogic, ArcherLogic, etc.)
