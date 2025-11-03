# EXAMPLE: Simplified SquadLogic using only considerations
# This shows the target architecture after full migration

# Resource: Serializable configuration
class_name SimplifiedLogicConfig extends Resource

@export var action_considerations: Array[Consideration] = []

# Runtime: Executes logic using the configuration
class SimplifiedSquadLogic extends RefCounted:
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
			SquadBattleTypes.SquadEntityAction.keys()[best_action], best_score])
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
		# Clash targeting can also use considerations if needed
		return null

## REMOVED ENTIRELY:
# - positioning_policy
# - retreat_if_outnumbered()
# - readjust_weapon()
# - heal_others_if_around()
# - is_line_ahead_of_me()
# - get_same_line_allies()
# - All subclasses (FrontlineLogic, ArcherLogic, etc.)
