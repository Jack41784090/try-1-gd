extends RefCounted
class_name SquadLogic

const Types = preload("res://squad_battle/types.gd")

var entity
var situation
var context: Dictionary
var logic_specific_skills: Array = []

func _init(initial_context: Dictionary):
	context = initial_context
	entity = context["entity"]
	situation = Situation.new(context)

func update_situation(new_context: Dictionary):
	context = new_context
	situation = Situation.new(context)
	return self

func get_same_line_allies() -> Array:
	var my_location = entity.get_changeable_stat_num("LOC") as int
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
		return Types.SquadEntityAction.HEAL
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
		if my_location == Types.SquadEntityInSquadLocation.Back:
			return Types.SquadEntityAction.CAPITULATE
		return Types.SquadEntityAction.RETREAT
	return null

func readjust_weapon():
	var unwrapped = situation.unwrap()
	var my_location = unwrapped["my_location"]
	var weapon = choose_weapon()
	
	var front_options = weapon.get_range_at_location(Types.SquadEntityInSquadLocation.Front)
	var mid_options = weapon.get_range_at_location(Types.SquadEntityInSquadLocation.Middle)
	var back_options = weapon.get_range_at_location(Types.SquadEntityInSquadLocation.Back)
	
	var front_options_total_count = 0
	for opt in front_options:
		match opt:
			Types.SquadEntityInSquadLocation.Front:
				front_options_total_count += unwrapped.get("frontline_enemy_count", 0)
			Types.SquadEntityInSquadLocation.Middle:
				front_options_total_count += unwrapped.get("midline_enemy_count", 0)
			Types.SquadEntityInSquadLocation.Back:
				front_options_total_count += unwrapped.get("backline_enemy_count", 0)
	
	var mid_options_total_count = 0
	for opt in mid_options:
		match opt:
			Types.SquadEntityInSquadLocation.Front:
				mid_options_total_count += unwrapped.get("frontline_enemy_count", 0)
			Types.SquadEntityInSquadLocation.Middle:
				mid_options_total_count += unwrapped.get("midline_enemy_count", 0)
			Types.SquadEntityInSquadLocation.Back:
				mid_options_total_count += unwrapped.get("backline_enemy_count", 0)
	
	var back_options_total_count = 0
	for opt in back_options:
		match opt:
			Types.SquadEntityInSquadLocation.Front:
				back_options_total_count += unwrapped.get("frontline_enemy_count", 0)
			Types.SquadEntityInSquadLocation.Middle:
				back_options_total_count += unwrapped.get("midline_enemy_count", 0)
			Types.SquadEntityInSquadLocation.Back:
				back_options_total_count += unwrapped.get("backline_enemy_count", 0)
	
	var max_count = max(front_options_total_count, mid_options_total_count, back_options_total_count)
	var current_range_size = weapon.get_range_at_location(my_location).size()
	
	if max_count == current_range_size:
		return null
	
	match my_location:
		Types.SquadEntityInSquadLocation.Front:
			if mid_options_total_count > front_options_total_count:
				return Types.SquadEntityAction.RETREAT
		
		Types.SquadEntityInSquadLocation.Middle:
			var maximum = max(front_options_total_count, back_options_total_count)
			if maximum == front_options_total_count:
				return Types.SquadEntityAction.FORWARD
			if maximum == back_options_total_count:
				return Types.SquadEntityAction.RETREAT
		
		Types.SquadEntityInSquadLocation.Back:
			if mid_options_total_count > back_options_total_count:
				return Types.SquadEntityAction.FORWARD
	
	return null

func choose_clash_skill() -> Dictionary:
	var clash_skills = []
	clash_skills.append_array(entity.get_skills_for_purpose("clash"))
	clash_skills.append_array(logic_specific_skills)
	
	if clash_skills.size() == 0:
		return get_default_attack()
	
	var chosen = clash_skills[randi() % clash_skills.size()]
	print("Chosen clash skill: ", chosen["name"], " (", chosen["id"], ")")
	return chosen

func get_default_attack() -> Dictionary:
	return {
		"id": "basic-attack",
		"name": "Basic Attack",
		"effects": [{
			"name": "basic-attack",
			"affected": "target",
			"trigger": "OnBasicAttackHit",
			"original_source": entity.player_id,
			"affected_id": -1,
			"duration": 0,
			"effect": {
				"type": "Damage",
				"damage_type": "Physical",
				"amount": 1
			}
		}]
	}

func choose_weapon():
	return entity.weapon

func choose_reaction() -> int:
	var unwrapped = situation.unwrap()
	var my_location = unwrapped["my_location"]
	
	match my_location:
		Types.SquadEntityInSquadLocation.Back:
			if entity.get_changeable_stat_num("ORG") == 0:
				return Types.SquadEntityAction.CAPITULATE
	
	var retreat_result = retreat_if_outnumbered()
	if retreat_result != null:
		return retreat_result
	
	var readjust_result = readjust_weapon()
	if readjust_result != null:
		return readjust_result
	
	var heal_result = heal_others_if_around()
	if heal_result != null:
		return heal_result
	
	return Types.SquadEntityAction.IDLE

func choose_action() -> int:
	var unwrapped = situation.unwrap()
	var my_location = unwrapped["my_location"]
	
	match my_location:
		Types.SquadEntityInSquadLocation.Back:
			if entity.get_changeable_stat_num("ORG") == 0:
				return Types.SquadEntityAction.CAPITULATE
	
	var heal_result = heal_others_if_around()
	if heal_result != null:
		return heal_result
	
	var readjust_result = readjust_weapon()
	if readjust_result != null:
		return readjust_result
	
	return Types.SquadEntityAction.IDLE

func choose_clash():
	print("Default choose target called")
	return null

class Situation:
	var context: Dictionary
	
	func _init(ctx: Dictionary):
		context = ctx
	
	func my_location() -> int:
		return context["entity"].get_changeable_stat_num("LOC") as int
	
	func get_effective_lines(is_ally: bool) -> Array:
		var lines = [Types.SquadEntityInSquadLocation.Front, 
					Types.SquadEntityInSquadLocation.Middle, 
					Types.SquadEntityInSquadLocation.Back]
		var result: Array = []
		
		for loc in lines:
			var squad_dict = context["our_squad"] if is_ally else context["enemy_squad"]
			if squad_dict.has(loc) and squad_dict[loc].size() > 0:
				result.append(squad_dict[loc])
		
		return result
	
	func get_effective_line(is_ally: bool, effective_index: int):
		var effective = get_effective_lines(is_ally)
		if effective_index < effective.size():
			return effective[effective_index]
		return null
	
	func frontline_ally():
		var dynamic = get_effective_line(true, 0)
		var positional = context["our_squad"].get(Types.SquadEntityInSquadLocation.Front)
		
		if not dynamic and not positional:
			return null
		if dynamic == positional:
			return dynamic
		
		var combined = []
		if dynamic:
			combined.append_array(dynamic)
		if positional:
			combined.append_array(positional)
		return combined
	
	func midline_ally():
		var dynamic = get_effective_line(true, 1)
		var positional = context["our_squad"].get(Types.SquadEntityInSquadLocation.Middle)
		
		if not dynamic and not positional:
			return null
		if dynamic == positional:
			return dynamic
		
		var combined = []
		if dynamic:
			combined.append_array(dynamic)
		if positional:
			combined.append_array(positional)
		return combined
	
	func backline_ally():
		var dynamic = get_effective_line(true, 2)
		var positional = context["our_squad"].get(Types.SquadEntityInSquadLocation.Back)
		
		if not dynamic and not positional:
			return null
		if dynamic == positional:
			return dynamic
		
		var combined = []
		if dynamic:
			combined.append_array(dynamic)
		if positional:
			combined.append_array(positional)
		return combined
	
	func frontline_enemy():
		var dynamic = get_effective_line(false, 0)
		var positional = context["enemy_squad"].get(Types.SquadEntityInSquadLocation.Front)
		
		if not dynamic and not positional:
			return null
		if dynamic == positional:
			return dynamic
		
		var combined = []
		if dynamic:
			combined.append_array(dynamic)
		if positional:
			combined.append_array(positional)
		return combined
	
	func midline_enemy():
		var dynamic = get_effective_line(false, 1)
		var positional = context["enemy_squad"].get(Types.SquadEntityInSquadLocation.Middle)
		
		if not dynamic and not positional:
			return null
		if dynamic == positional:
			return dynamic
		
		var combined = []
		if dynamic:
			combined.append_array(dynamic)
		if positional:
			combined.append_array(positional)
		return combined
	
	func backline_enemy():
		var dynamic = get_effective_line(false, 2)
		var positional = context["enemy_squad"].get(Types.SquadEntityInSquadLocation.Back)
		
		if not dynamic and not positional:
			return null
		if dynamic == positional:
			return dynamic
		
		var combined = []
		if dynamic:
			combined.append_array(dynamic)
		if positional:
			combined.append_array(positional)
		return combined
	
	func unwrap() -> Dictionary:
		var frontline_a = frontline_ally()
		var midline_a = midline_ally()
		var backline_a = backline_ally()
		var frontline_e = frontline_enemy()
		var midline_e = midline_enemy()
		var backline_e = backline_enemy()
		
		return {
			"my_location": my_location(),
			"frontline_ally_count": frontline_a.size() if frontline_a else 0,
			"frontline_enemy_count": frontline_e.size() if frontline_e else 0,
			"midline_ally_count": midline_a.size() if midline_a else 0,
			"midline_enemy_count": midline_e.size() if midline_e else 0,
			"backline_ally_count": backline_a.size() if backline_a else 0,
			"backline_enemy_count": backline_e.size() if backline_e else 0,
			"frontline_ally": frontline_a,
			"midline_ally": midline_a,
			"backline_ally": backline_a,
			"frontline_enemy": frontline_e,
			"midline_enemy": midline_e,
			"backline_enemy": backline_e
		}

class AbsurdLogic extends SquadLogic:
	func _init(ctx: Dictionary):
		super._init(ctx)
	
	func choose_action() -> int:
		return Types.SquadEntityAction.FORWARD
	
	func choose_reaction() -> int:
		return Types.SquadEntityAction.RETREAT

class AdjustWeaponTestLogic extends SquadLogic:
	func _init(ctx: Dictionary):
		super._init(ctx)
	
	func choose_action() -> int:
		var result = readjust_weapon()
		if result != null:
			return result
		return Types.SquadEntityAction.IDLE
	
	func choose_reaction() -> int:
		var result = readjust_weapon()
		if result != null:
			return result
		return Types.SquadEntityAction.IDLE

class FrontlineLogic extends SquadLogic:
	func _init(ctx: Dictionary):
		super._init(ctx)
		
		logic_specific_skills = [
			{
				"id": "frontline-default",
				"name": "Frontline Strike",
				"effects": [
					{
						"name": "FrontlineStrikeEffect1",
						"affected": "target",
						"original_source": entity.player_id,
						"affected_id": -1,
						"trigger": "OnBasicAttackHit",
						"effect": {
							"type": "Damage",
							"damage_type": "Physical",
							"calculation": {
								"type": "StatScaling",
								"stat": Types.Reality.Force,
								"percent": 0.10
							}
						},
						"duration": 0
					}
				]
			}
		]
	
	func forward_if_brave():
		if entity.get_changeable_stat_num("LOC") == Types.SquadEntityInSquadLocation.Front:
			return null
		
		var current_org = entity.get_changeable_stat_num("ORG")
		var max_org = entity.get_ceiling_changeable_stat("ORG")
		
		if current_org / max_org > 0.5:
			return Types.SquadEntityAction.FORWARD
		
		return null
	
	func choose_action() -> int:
		var my_location = situation.my_location()
		
		match my_location:
			Types.SquadEntityInSquadLocation.Front:
				return Types.SquadEntityAction.ATTACK
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
				Types.SquadEntityInSquadLocation.Front:
					if frontline_enemy:
						for e in frontline_enemy:
							targets.append(e)
				Types.SquadEntityInSquadLocation.Middle:
					if midline_enemy:
						for e in midline_enemy:
							targets.append(e)
				Types.SquadEntityInSquadLocation.Back:
					if backline_enemy:
						for e in backline_enemy:
							targets.append(e)
		
		if targets.size() == 0:
			return null
		
		var target = targets[randi() % targets.size()]
		return OneClash.new({
			"attacker": entity,
			"defender": target,
			"skill": choose_clash_skill()
		})

class ArcherLogic extends SquadLogic:
	func _init(ctx: Dictionary):
		super._init(ctx)
		logic_specific_skills = []
	
	func retreat_if_frontline_holds():
		var line_ahead = is_line_ahead_of_me()
		
		if not line_ahead and situation.my_location() != Types.SquadEntityInSquadLocation.Back:
			return Types.SquadEntityAction.RETREAT
		
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
				Types.SquadEntityInSquadLocation.Front:
					if frontline_enemy:
						for e in frontline_enemy:
							targets.append(e)
				Types.SquadEntityInSquadLocation.Middle:
					if midline_enemy:
						for e in midline_enemy:
							targets.append(e)
				Types.SquadEntityInSquadLocation.Back:
					if backline_enemy:
						for e in backline_enemy:
							targets.append(e)
		
		if targets.size() == 0:
			return null
		
		var target = targets[randi() % targets.size()]
		return OneClash.new({
			"attacker": entity,
			"defender": target,
			"skill": choose_clash_skill()
		})

