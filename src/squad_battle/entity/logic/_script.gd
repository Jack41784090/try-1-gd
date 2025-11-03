extends RefCounted
class_name SquadLogic

var entity: SquadEntity
var situation: Situation
var context: Dictionary
var logic_specific_skills: Array[Skill] = []
var positioning_policy: PositioningPolicy = null

func _init(initial_context: Dictionary):
	context = initial_context
	entity = context["entity"]
	situation = Situation.new(context)

func update_situation(new_context: Dictionary):
	context = new_context
	situation = Situation.new(context)
	return self

func get_same_line_allies() -> Array:
	var my_location = entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) as int
	if context["our_squad"].has(my_location):
		return context["our_squad"][my_location]
	return []

func is_line_ahead_of_me() -> bool:
	var frontline = situation.frontline_ally()
	if frontline == null:
		return false
	
	for ally in frontline:
		if ally.player_id == entity.player_id:
			return false
	return true

func heal_others_if_around():
	var my_location = situation.my_location()
	var allies = null
	
	if context["our_squad"].has(my_location):
		allies = context["our_squad"][my_location]
	
	if allies and allies.size() > 0:
		return SquadBattleTypes.SquadEntityAction.HEAL
	return null

func retreat_if_outnumbered():
	var unwrapped = situation.unwrap()
	var my_location = unwrapped["my_location"]
	var my_allies = (unwrapped.get("frontline_ally_count", 0) + 
					unwrapped.get("midline_ally_count", 0) + 
					unwrapped.get("backline_ally_count", 0))
	var my_enemies = (unwrapped.get("frontline_enemy_count", 0) + 
					 unwrapped.get("midline_enemy_count", 0) + 
					 unwrapped.get("backline_enemy_count", 0))
	
	if my_enemies > my_allies * 2:
		if my_location == SquadBattleTypes.SquadEntityInSquadLocation.Back:
			return SquadBattleTypes.SquadEntityAction.CAPITULATE
		return SquadBattleTypes.SquadEntityAction.RETREAT
	return null

func readjust_weapon():
	var unwrapped = situation.unwrap()
	var my_location = unwrapped["my_location"]
	var weapon = choose_weapon()
	
	var front_options = weapon.get_range_at_location(SquadBattleTypes.SquadEntityInSquadLocation.Front)
	var mid_options = weapon.get_range_at_location(SquadBattleTypes.SquadEntityInSquadLocation.Middle)
	var back_options = weapon.get_range_at_location(SquadBattleTypes.SquadEntityInSquadLocation.Back)
	
	var front_options_total_count = 0
	for opt in front_options:
		match opt:
			SquadBattleTypes.SquadEntityInSquadLocation.Front:
				front_options_total_count += unwrapped.get("frontline_enemy_count", 0)
			SquadBattleTypes.SquadEntityInSquadLocation.Middle:
				front_options_total_count += unwrapped.get("midline_enemy_count", 0)
			SquadBattleTypes.SquadEntityInSquadLocation.Back:
				front_options_total_count += unwrapped.get("backline_enemy_count", 0)
	
	var mid_options_total_count = 0
	for opt in mid_options:
		match opt:
			SquadBattleTypes.SquadEntityInSquadLocation.Front:
				mid_options_total_count += unwrapped.get("frontline_enemy_count", 0)
			SquadBattleTypes.SquadEntityInSquadLocation.Middle:
				mid_options_total_count += unwrapped.get("midline_enemy_count", 0)
			SquadBattleTypes.SquadEntityInSquadLocation.Back:
				mid_options_total_count += unwrapped.get("backline_enemy_count", 0)
	
	var back_options_total_count = 0
	for opt in back_options:
		match opt:
			SquadBattleTypes.SquadEntityInSquadLocation.Front:
				back_options_total_count += unwrapped.get("frontline_enemy_count", 0)
			SquadBattleTypes.SquadEntityInSquadLocation.Middle:
				back_options_total_count += unwrapped.get("midline_enemy_count", 0)
			SquadBattleTypes.SquadEntityInSquadLocation.Back:
				back_options_total_count += unwrapped.get("backline_enemy_count", 0)
	
	var max_count = max(front_options_total_count, mid_options_total_count, back_options_total_count)
	var current_range_size = weapon.get_range_at_location(my_location).size()
	
	if max_count == current_range_size:
		return null
	
	match my_location:
		SquadBattleTypes.SquadEntityInSquadLocation.Front:
			if mid_options_total_count > front_options_total_count:
				return SquadBattleTypes.SquadEntityAction.RETREAT
		
		SquadBattleTypes.SquadEntityInSquadLocation.Middle:
			var maximum = max(front_options_total_count, back_options_total_count)
			if maximum == front_options_total_count:
				return SquadBattleTypes.SquadEntityAction.FORWARD
			if maximum == back_options_total_count:
				return SquadBattleTypes.SquadEntityAction.RETREAT
		
		SquadBattleTypes.SquadEntityInSquadLocation.Back:
			if mid_options_total_count > back_options_total_count:
				return SquadBattleTypes.SquadEntityAction.FORWARD
	
	return null

func choose_clash_skill() -> Skill:
	var clash_skills = []
	clash_skills.append_array(entity.get_skills_for_purpose("clash"))
	clash_skills.append_array(logic_specific_skills)
	
	if clash_skills.size() == 0:
		return get_default_attack()
	
	var chosen: Skill = clash_skills[randi() % clash_skills.size()]
	print("Chosen clash skill: %s" % str(chosen))
	return chosen

func get_default_attack() -> Skill:
	return Skill.new("Basic Attack", [	])

func choose_weapon():
	return entity.weapon

func choose_reaction() -> int:
	var unwrapped = situation.unwrap()
	var my_location = unwrapped["my_location"]
	
	match my_location:
		SquadBattleTypes.SquadEntityInSquadLocation.Back:
			if entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.ORG) == 0:
				return SquadBattleTypes.SquadEntityAction.CAPITULATE

	# Delegate to positioning policy if available
	if positioning_policy != null:
		var policy_move = positioning_policy.suggest_move(entity, situation, context)
		if policy_move != null and policy_move != SquadBattleTypes.SquadEntityAction.IDLE:
			return policy_move
	
	var retreat_result = retreat_if_outnumbered()
	if retreat_result != null:
		return retreat_result
	
	var readjust_result = readjust_weapon()
	if readjust_result != null:
		return readjust_result
	
	var heal_result = heal_others_if_around()
	if heal_result != null:
		return heal_result
	
	return SquadBattleTypes.SquadEntityAction.IDLE

func choose_action() -> int:
	var unwrapped = situation.unwrap()
	var my_location = unwrapped["my_location"]
	
	match my_location:
		SquadBattleTypes.SquadEntityInSquadLocation.Back:
			if entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.ORG) == 0:
				return SquadBattleTypes.SquadEntityAction.CAPITULATE

	# Delegate to positioning policy if available
	if positioning_policy != null:
		var policy_move = positioning_policy.suggest_move(entity, situation, context)
		if policy_move != null and policy_move != SquadBattleTypes.SquadEntityAction.IDLE:
			return policy_move
	
	var heal_result = heal_others_if_around()
	if heal_result != null:
		return heal_result
	
	var readjust_result = readjust_weapon()
	if readjust_result != null:
		return readjust_result
	
	return SquadBattleTypes.SquadEntityAction.IDLE

func choose_clash():
	print("Default choose target called")
	return null

class AbsurdLogic extends SquadLogic:
	func _init(ctx: Dictionary):
		super._init(ctx)
	
	func choose_action() -> int:
		return SquadBattleTypes.SquadEntityAction.FORWARD
	
	func choose_reaction() -> int:
		return SquadBattleTypes.SquadEntityAction.RETREAT

class AdjustWeaponTestLogic extends SquadLogic:
	func _init(ctx: Dictionary):
		super._init(ctx)
	
	func choose_action() -> int:
		var result = readjust_weapon()
		if result != null:
			return result
		return SquadBattleTypes.SquadEntityAction.IDLE
	
	func choose_reaction() -> int:
		var result = readjust_weapon()
		if result != null:
			return result
		return SquadBattleTypes.SquadEntityAction.IDLE

class FrontlineLogic extends SquadLogic:
	func _init(ctx: Dictionary):
		super._init(ctx)
		
		logic_specific_skills = [
			Skill.new("Frontline Strike", [
				SkillEffect.new(
					"FrontlineStrikeEffect1",
					entity,
					null,
					ClashCommonTypes.CommitType.Damage,
					[StatusEffectEventBus.Signals.OnBasicAttackHit],
					{
						"calculationType": ClashCommonTypes.CalculationType.StatScaling,
						"value": 0.10,
						"damage_type": SquadBattleTypes.Reality.Force,
					}
				)
			])
		]
	
	func forward_if_brave():
		if entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) == SquadBattleTypes.SquadEntityInSquadLocation.Front:
			return null
		
		var current_org = entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.ORG)
		var max_org = entity.get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.ORG)
		
		if current_org / max_org > 0.5:
			return SquadBattleTypes.SquadEntityAction.FORWARD
		
		return null
	
	func choose_action() -> int:
		var my_location = situation.my_location()
		
		match my_location:
			SquadBattleTypes.SquadEntityInSquadLocation.Front:
				return SquadBattleTypes.SquadEntityAction.ATTACK
			_:
				var forward_result = forward_if_brave()
				if forward_result != null:
					return forward_result
				return super.choose_action()
	
	func choose_reaction() -> int:
		return choose_action()
	
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

class ArcherLogic extends SquadLogic:
	func _init(ctx: Dictionary):
		super._init(ctx)
		logic_specific_skills = []
	
	func retreat_if_frontline_holds():
		var line_ahead = is_line_ahead_of_me()
		
		if not line_ahead and situation.my_location() != SquadBattleTypes.SquadEntityInSquadLocation.Back:
			return SquadBattleTypes.SquadEntityAction.RETREAT
		
		return null
	
	func choose_action() -> int:
		var retreat_result = retreat_if_frontline_holds()
		if retreat_result != null:
			return retreat_result
		return super.choose_action()
	
	func choose_reaction() -> int:
		return choose_action()
	
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
