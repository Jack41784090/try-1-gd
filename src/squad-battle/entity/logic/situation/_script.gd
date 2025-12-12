class_name Situation

var context: Dictionary

func _init(ctx: Dictionary):
	context = ctx

func my_location() -> int:
	return context["entity"].get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) as int

func get_effective_lines(is_ally: bool) -> Array:
	var lines = [SquadBattleTypes.SquadEntityInSquadLocation.Front, 
				SquadBattleTypes.SquadEntityInSquadLocation.Middle, 
				SquadBattleTypes.SquadEntityInSquadLocation.Back]
	var result: Array = []
	
	for loc in lines:
		var squad_dict = context["our_squad"] if is_ally else context["enemy_squad"]
		if squad_dict.has(loc) and squad_dict[loc].size() > 0:
			result.append(squad_dict[loc])
	
	return result

func get_enemy_squad() -> Dictionary:
	return context["enemy_squad"]

func all_enemy_entities() -> Array:
	var entities: Array = []
	for entry in context["enemy_squad"].values():
		if entry is Array:
			entities.append_array(entry)
	return entities

func all_ally_entities() -> Array:
	var entities: Array = []
	for entry in context["our_squad"].values():
		if entry is Array:
			entities.append_array(entry)
	return entities

func get_our_squad() -> Dictionary:
	return context["our_squad"]

func get_effective_line(is_ally: bool, effective_index: int):
	var effective = get_effective_lines(is_ally)
	if effective_index < effective.size():
		return effective[effective_index]
	return null


func frontline_ally():
	var dynamic = get_effective_line(true, 0)
	var positional = context["our_squad"].get(SquadBattleTypes.SquadEntityInSquadLocation.Front)
	
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
	var positional = context["our_squad"].get(SquadBattleTypes.SquadEntityInSquadLocation.Middle)
	
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
	var positional = context["our_squad"].get(SquadBattleTypes.SquadEntityInSquadLocation.Back)
	
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
	var positional = context["enemy_squad"].get(SquadBattleTypes.SquadEntityInSquadLocation.Front)
	
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
	var positional = context["enemy_squad"].get(SquadBattleTypes.SquadEntityInSquadLocation.Middle)
	
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
	var positional = context["enemy_squad"].get(SquadBattleTypes.SquadEntityInSquadLocation.Back)
	
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
