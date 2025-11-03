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


# ENTIRE positioning logic in one method
func choose_action() -> SquadBattleTypes.SquadEntityAction:
	return _evaluate_best_action()

func choose_reaction() -> SquadBattleTypes.SquadEntityAction:
	return _evaluate_best_action()

func _evaluate_best_action() -> SquadBattleTypes.SquadEntityAction:
	print("\n=== EVALUATING BEST ACTION ===")
	var best_action := SquadBattleTypes.SquadEntityAction.IDLE
	var best_score := -INF
	
	for csdr in config.action_considerations:
		assert(csdr is ActionConsideration, "Invalid consideration type in SimplifiedSquadLogic");
		var score = csdr.score(entity, situation, context)

		if score > 0.0 and score > best_score:
			best_score = score
			best_action = csdr.target_action
	
	print("\n[RESULT] Best Action: %s (score=%.2f)" % [
		SquadBattleUtils.get_action_string(best_action), best_score])
	print("==============================\n")
	
	return best_action

# Rest of the interface remains the same
func choose_weapon():
	return entity.weapon

func choose_clash_skill() -> Skill:
	var clash_skills = []
	clash_skills.append_array(entity.get_skills_for_purpose("clash"))
	clash_skills.append_array(logic_specific_skills)
	
	if clash_skills.size() == 0:
		return get_default_attack()
	
	return clash_skills[randi() % clash_skills.size()]

func get_default_attack() -> Skill:
	return Skill.new("Basic Attack", [])

func choose_clash():
	var unwrapped = situation.unwrap()
	var my_location = unwrapped["my_location"]
	var frontline_enemy = unwrapped.get("frontline_enemy")
	var midline_enemy = unwrapped.get("midline_enemy")
	var backline_enemy = unwrapped.get("backline_enemy")
	
	var weapon = choose_weapon()
	var available_locs = weapon.get_range_at_location(my_location)
	
	var targets: Array = []
	for loc in available_locs:
		match loc:
			SquadBattleTypes.SquadEntityInSquadLocation.Front:
				if frontline_enemy:
					for e in frontline_enemy:
						targets.append(e)
			SquadBattleTypes.SquadEntityInSquadLocation.Middle:
				if midline_enemy:
					for e in midline_enemy:
						targets.append(e)
			SquadBattleTypes.SquadEntityInSquadLocation.Back:
				if backline_enemy:
					for e in backline_enemy:
						targets.append(e)
	
	if targets.size() == 0:
		return null
	
	var target = targets[randi() % targets.size()]
	return OneClash.new(
		entity,
		target,
		choose_clash_skill()
	)

## REMOVED ENTIRELY:
# - positioning_policy
# - retreat_if_outnumbered()
# - readjust_weapon()
# - heal_others_if_around()
# - is_line_ahead_of_me()
# - get_same_line_allies()
# - All subclasses (FrontlineLogic, ArcherLogic, etc.)
