class_name Situation

var context: Dictionary

func _init(ctx: Dictionary):
	context = ctx

func my_location() -> int:
	return context["entity"].get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC) as int

func get_enemy_squad() -> Dictionary:
	return context["enemy_squad"]

func all_enemy_entities() -> Array[CombatEntity]:
	var entities: Array[CombatEntity] = []
	for entry in context["enemy_squad"].values():
		if entry is Array:
			entities.append_array(entry)
	return entities

func all_ally_entities() -> Array[CombatEntity]:
	var entities: Array[CombatEntity] = []
	for entry in context["our_squad"].values():
		if entry is Array:
			entities.append_array(entry)
	return entities

func get_our_squad() -> Dictionary:
	return context["our_squad"]

func get_effective_line(is_ally: bool, effective_index: int):
	var lines = [SquadBattleTypes.SquadEntityInSquadLocation.Front, 
				SquadBattleTypes.SquadEntityInSquadLocation.Middle, 
				SquadBattleTypes.SquadEntityInSquadLocation.Back]
	var effective: Array[Array] = []
	for loc in lines:
		var squad_dict = context["our_squad"] if is_ally else context["enemy_squad"]
		if squad_dict.has(loc) and squad_dict[loc].size() > 0:
			effective.append(squad_dict[loc])
	if effective_index < effective.size():
		return effective[effective_index]
	return null


func unwrap() -> Dictionary:
	var frontline_a = null
	var fa_dyn = get_effective_line(true, 0)
	var fa_pos = context["our_squad"].get(SquadBattleTypes.SquadEntityInSquadLocation.Front)
	if fa_dyn or fa_pos:
		if fa_dyn == fa_pos:
			frontline_a = fa_dyn
		else:
			frontline_a = []
			if fa_dyn:
				frontline_a.append_array(fa_dyn)
			if fa_pos:
				frontline_a.append_array(fa_pos)

	var midline_a = null
	var ma_dyn = get_effective_line(true, 1)
	var ma_pos = context["our_squad"].get(SquadBattleTypes.SquadEntityInSquadLocation.Middle)
	if ma_dyn or ma_pos:
		if ma_dyn == ma_pos:
			midline_a = ma_dyn
		else:
			midline_a = []
			if ma_dyn:
				midline_a.append_array(ma_dyn)
			if ma_pos:
				midline_a.append_array(ma_pos)

	var backline_a = null
	var ba_dyn = get_effective_line(true, 2)
	var ba_pos = context["our_squad"].get(SquadBattleTypes.SquadEntityInSquadLocation.Back)
	if ba_dyn or ba_pos:
		if ba_dyn == ba_pos:
			backline_a = ba_dyn
		else:
			backline_a = []
			if ba_dyn:
				backline_a.append_array(ba_dyn)
			if ba_pos:
				backline_a.append_array(ba_pos)

	var frontline_e = null
	var fe_dyn = get_effective_line(false, 0)
	var fe_pos = context["enemy_squad"].get(SquadBattleTypes.SquadEntityInSquadLocation.Front)
	if fe_dyn or fe_pos:
		if fe_dyn == fe_pos:
			frontline_e = fe_dyn
		else:
			frontline_e = []
			if fe_dyn:
				frontline_e.append_array(fe_dyn)
			if fe_pos:
				frontline_e.append_array(fe_pos)

	var midline_e = null
	var me_dyn = get_effective_line(false, 1)
	var me_pos = context["enemy_squad"].get(SquadBattleTypes.SquadEntityInSquadLocation.Middle)
	if me_dyn or me_pos:
		if me_dyn == me_pos:
			midline_e = me_dyn
		else:
			midline_e = []
			if me_dyn:
				midline_e.append_array(me_dyn)
			if me_pos:
				midline_e.append_array(me_pos)

	var backline_e = null
	var be_dyn = get_effective_line(false, 2)
	var be_pos = context["enemy_squad"].get(SquadBattleTypes.SquadEntityInSquadLocation.Back)
	if be_dyn or be_pos:
		if be_dyn == be_pos:
			backline_e = be_dyn
		else:
			backline_e = []
			if be_dyn:
				backline_e.append_array(be_dyn)
			if be_pos:
				backline_e.append_array(be_pos)

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
