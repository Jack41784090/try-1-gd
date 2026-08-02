class_name CombatSfxFeedback
extends FeedbackEffect


func wants(change: EntityChange, _role: int) -> bool:
	return change.property in [
		SquadBattleTypes.EntityChangeable.HP,
		SquadBattleTypes.EntityChangeable.CLINK,
		SquadBattleTypes.EntityChangeable.DIE,
	]


func play(update: EntityUpdate, role: int) -> void:
	var tree := _host.get_tree()
	var sfx: Node = tree.root.get_node_or_null("SFX") if tree else null
	if not sfx:
		return

	match update.change.property:
		SquadBattleTypes.EntityChangeable.HP:
			if role == Role.SOURCE and _host.squad_entity:
				sfx.play_attack_for_weapon(_host.squad_entity.weapon.resource.weapon_class)
		SquadBattleTypes.EntityChangeable.CLINK:
			if role == Role.TARGET:
				sfx.play_combat_clink()
		SquadBattleTypes.EntityChangeable.DIE:
			if role == Role.TARGET:
				sfx.play_death()

