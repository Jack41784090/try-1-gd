class_name RetreatTracker extends RefCounted

enum RetreatState { FIGHTING, RETREATING, LAST_STAND, CAPITULATED }

var state: RetreatState = RetreatState.FIGHTING

func new_round_reset() -> void:
	if state == RetreatState.FIGHTING or state == RetreatState.RETREATING:
		state = RetreatState.FIGHTING

func should_retreat(org: float) -> bool:
	return org <= 0 and state == RetreatState.FIGHTING

func advance(entity: CombatEntity) -> Array[EntityUpdate]:
	var eid = entity.player_id
	var current_loc = entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.LOC)
	var guts_restore = entity.calculate_reality_value(SquadBattleTypes.Reality.Guts) * 0.1
	var updates: Array[EntityUpdate] = []

	if current_loc < SquadBattleTypes.SquadEntityInSquadLocation.Back:
		state = RetreatState.RETREATING
		updates.append(EntityUpdate.new(eid, eid, entity.mod_changeable_stat(SquadBattleTypes.EntityChangeable.LOC, 1)))
		updates.append(EntityUpdate.new(eid, eid, entity.set_changeable_stat(SquadBattleTypes.EntityChangeable.ORG, guts_restore)))
	elif state != RetreatState.LAST_STAND:
		state = RetreatState.LAST_STAND
		updates.append(EntityUpdate.new(eid, eid, entity.set_changeable_stat(SquadBattleTypes.EntityChangeable.ORG, guts_restore)))
	else:
		state = RetreatState.CAPITULATED
		updates.append(EntityUpdate.new(eid, eid, EntityChange.new(SquadBattleTypes.EntityChangeable.CAPITULATE)))

	return updates
