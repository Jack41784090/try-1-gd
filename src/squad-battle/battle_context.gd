class_name BattleContext extends RefCounted

var entity: CharacterCombatStats
var our_squad: Dictionary
var enemy_squad: Dictionary

static func from_dict(ctx: Dictionary) -> BattleContext:
	var bc = BattleContext.new()
	bc.entity = ctx.get("entity")
	bc.our_squad = ctx.get("our_squad", {})
	bc.enemy_squad = ctx.get("enemy_squad", {})
	return bc

func get_enemies_at(loc: int) -> Array:
	return enemy_squad.get(loc, [])

func get_allies_at(loc: int) -> Array:
	return our_squad.get(loc, [])

func to_dict() -> Dictionary:
	return {"entity": entity, "our_squad": our_squad, "enemy_squad": enemy_squad}
