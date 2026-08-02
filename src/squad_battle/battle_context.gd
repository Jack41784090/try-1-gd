class_name BattleContext extends RefCounted

var entity: CombatEntity
var our_squad: Dictionary
var enemy_squad: Dictionary

static func from_dict(ctx: Dictionary) -> BattleContext:
	var bc = BattleContext.new()
	bc.entity = ctx.get("entity")
	bc.our_squad = ctx.get("our_squad", {})
	bc.enemy_squad = ctx.get("enemy_squad", {})
	return bc

func get_enemies_at(loc: int) -> Array[CombatEntity]:
	return enemy_squad.get(loc, [])
