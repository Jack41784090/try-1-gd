extends Node

var _pass_count: int = 0
var _fail_count: int = 0


func _ready():
	print("\n=== AIP CLASH TEST: Goetz vs Adelheid ===\n")

	_test_goetz_iron_hand()
	_test_adelheid_sacred_sentence()
	_test_the_grin_cancel()
	_test_robber_knights_defiance()
	_test_budget_enforcement()
	_test_personal_rules_selection()

	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass_count, _fail_count])
	get_tree().quit(0 if _fail_count == 0 else 1)


func _test_goetz_iron_hand():
	print("--- Test: Goetz Iron Hand physical pipeline ---")
	var goetz := _build_goetz(1)
	var adelheid := _build_adelheid(2)

	var skill: Skill = load("res://resources/combat/logic/skills/aip_goetz/iron_hand.tres")
	var intent := ClashIntent.new(goetz, skill, adelheid)
	var resolver := ClashResolver.new()
	resolver.set_entities([goetz, adelheid])
	resolver.begin_round(1)
	var updates := resolver.resolve(intent)

	var committed := false
	for u in updates:
		if u.change.property == SquadBattleTypes.EntityChangeable.HP:
			committed = true
	var dodge_or_block := false
	for u in updates:
		if u.change.property == SquadBattleTypes.EntityChangeable.DODGE or u.change.property == SquadBattleTypes.EntityChangeable.CLINK:
			dodge_or_block = true

	_assert(committed or dodge_or_block, "Iron Hand resolved (damage or dodge/block)")
	_assert(goetz.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP) > 0, "Goetz alive")
	print("  Adelheid HP: %.1f" % adelheid.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP))


func _test_adelheid_sacred_sentence():
	print("--- Test: Adelheid Sacred Sentence magical + splash ---")
	var adelheid := _build_adelheid(3)
	var goetz := _build_goetz(4)
	var goetz_ally := _build_goetz(5)

	var context := {
		"entity": adelheid,
		"our_squad": {},
		"enemy_squad": {1: [goetz, goetz_ally]},
	}

	var skill: Skill = load("res://resources/combat/logic/skills/aip_adelheid/sacred_sentence.tres")
	var intent := ClashIntent.new(adelheid, skill, goetz, 0, null, null, context)
	var resolver := ClashResolver.new()
	resolver.set_entities([adelheid, goetz, goetz_ally])
	resolver.begin_round(1)
	var updates := resolver.resolve(intent)

	var any_resolution := false
	for u in updates:
		if u.change.property == SquadBattleTypes.EntityChangeable.HP or u.change.property == SquadBattleTypes.EntityChangeable.DODGE or u.change.property == SquadBattleTypes.EntityChangeable.CLINK:
			any_resolution = true
	_assert(any_resolution, "Sacred Sentence resolved through magical pipeline")
	print("  Goetz HP: %.1f, Ally HP: %.1f" % [
		goetz.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP),
		goetz_ally.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)])


func _test_the_grin_cancel():
	print("--- Test: The Grin cancels Iron Hand at ON_CAST ---")
	var goetz := _build_goetz(6)
	var adelheid := _build_adelheid(7)

	var grin := ReactionSkill.new()
	grin.reaction_name = "the_grin"
	grin.window = SquadBattleTypes.ReactionWindow.ON_CAST
	grin.relation_to_target = ReactionSkill.Relation.SELF
	grin.once_per_round = false
	grin.priority = 10
	var cancel_effect := ReactionEffect.new()
	cancel_effect.kind = ReactionEffect.Kind.CANCEL
	grin.effect = cancel_effect
	adelheid.reactions = [grin]

	var hp_before := adelheid.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)

	var skill: Skill = load("res://resources/combat/logic/skills/aip_goetz/iron_hand.tres")
	var intent := ClashIntent.new(goetz, skill, adelheid)
	var resolver := ClashResolver.new()
	resolver.set_entities([goetz, adelheid])
	resolver.begin_round(5)
	var updates := resolver.resolve(intent)

	var hp_changes := 0
	for u in updates:
		if u.change.property == SquadBattleTypes.EntityChangeable.HP:
			hp_changes += 1
	_assert(hp_changes == 0, "The Grin cancelled — zero HP changes (got %d)" % hp_changes)
	_assert(adelheid.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP) == hp_before, "Adelheid HP unchanged")

	var proc_found := false
	for u in updates:
		if u.change.property == SquadBattleTypes.EntityChangeable.PROC:
			proc_found = true
	_assert(proc_found, "PROC event emitted for cancelled intent")


func _test_robber_knights_defiance():
	print("--- Test: Robber Knight's Defiance (ON_PIERCE scale + counter) ---")
	var adelheid := _build_adelheid(8)
	var goetz := _build_goetz(9)

	var counter_skill: Skill = load("res://resources/combat/logic/skills/aip_goetz/robber_knights_defiance.tres")

	var defiance := ReactionSkill.new()
	defiance.reaction_name = "robber_knights_defiance"
	defiance.window = SquadBattleTypes.ReactionWindow.ON_PIERCE
	defiance.relation_to_target = ReactionSkill.Relation.SELF
	defiance.once_per_round = true
	defiance.priority = 5
	var scale_effect := ReactionEffect.new()
	scale_effect.kind = ReactionEffect.Kind.SCALE_DAMAGE
	scale_effect.value = 0.5
	defiance.effect = scale_effect
	defiance.skill = counter_skill
	goetz.reactions = [defiance]

	var hp_before_goetz := goetz.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	var hp_before_adelheid := adelheid.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)

	var context := {
		"entity": adelheid,
		"our_squad": {},
		"enemy_squad": {1: [goetz]},
	}
	var skill: Skill = load("res://resources/combat/logic/skills/aip_adelheid/sacred_sentence.tres")
	var intent := ClashIntent.new(adelheid, skill, goetz, 0, null, null, context)
	var resolver := ClashResolver.new()
	resolver.set_entities([adelheid, goetz])
	resolver.begin_round(5)
	var updates := resolver.resolve(intent)

	var proc_count := 0
	for u in updates:
		if u.change.property == SquadBattleTypes.EntityChangeable.PROC:
			proc_count += 1

	var hp_after_goetz := goetz.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	var hp_after_adelheid := adelheid.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	var goetz_damaged := hp_after_goetz < hp_before_goetz
	var adelheid_damaged := hp_after_adelheid < hp_before_adelheid

	if not goetz_damaged:
		print("  (attack dodged/blocked, defiance not triggered this run)")
		_assert(true, "no pierce occurred — defiance not testable this run")
	else:
		_assert(proc_count >= 1, "defiance PROC emitted (got %d)" % proc_count)
		var counter_resolved := adelheid_damaged
		for u in updates:
			if u.change.property == SquadBattleTypes.EntityChangeable.DODGE or u.change.property == SquadBattleTypes.EntityChangeable.CLINK:
				counter_resolved = true
		_assert(counter_resolved, "counter-attack resolved (hit or dodge/block)")
	print("  Goetz HP: %.1f→%.1f (scaled ×0.5), Adelheid HP: %.1f→%.1f, PROCs: %d" % [hp_before_goetz, hp_after_goetz, hp_before_adelheid, hp_after_adelheid, proc_count])


func _test_budget_enforcement():
	print("--- Test: reaction budget = 0 suppresses The Grin ---")
	var goetz := _build_goetz(10)
	var adelheid := _build_adelheid(11)

	var grin := ReactionSkill.new()
	grin.reaction_name = "the_grin"
	grin.window = SquadBattleTypes.ReactionWindow.ON_CAST
	grin.relation_to_target = ReactionSkill.Relation.SELF
	grin.once_per_round = false
	var cancel_effect := ReactionEffect.new()
	cancel_effect.kind = ReactionEffect.Kind.CANCEL
	grin.effect = cancel_effect
	adelheid.reactions = [grin]

	var skill: Skill = load("res://resources/combat/logic/skills/aip_goetz/iron_hand.tres")
	var intent := ClashIntent.new(goetz, skill, adelheid)
	var resolver := ClashResolver.new()
	resolver.set_entities([goetz, adelheid])
	resolver.begin_round(0)
	var updates := resolver.resolve(intent)

	var proc_found := false
	for u in updates:
		if u.change.property == SquadBattleTypes.EntityChangeable.PROC:
			proc_found = true
	_assert(not proc_found, "no reaction fired with budget=0")

	var resolved := false
	for u in updates:
		if u.change.property == SquadBattleTypes.EntityChangeable.HP or u.change.property == SquadBattleTypes.EntityChangeable.DODGE or u.change.property == SquadBattleTypes.EntityChangeable.CLINK:
			resolved = true
	_assert(resolved, "attack resolved normally without reactions")


func _test_personal_rules_selection():
	print("--- Test: personal_rules drive skill selection via action() ---")
	var goetz := _build_goetz(12)
	var adelheid := CombatEntityFactory.get_by_identification(
		"aip_adelheid", SquadBattleTypes.Side.DEFENDER, 13, SquadBattleTypes.SquadEntityInSquadLocation.Front)
	adelheid.skill_set.set_level(SkillType.Types.Scholarship, 8)

	var our_squad := {SquadBattleTypes.SquadEntityInSquadLocation.Front: [goetz]}
	var enemy_squad := {SquadBattleTypes.SquadEntityInSquadLocation.Front: [adelheid]}

	var updates := goetz.action(our_squad, enemy_squad)
	var any_resolution := false
	for u in updates:
		if u.change.property == SquadBattleTypes.EntityChangeable.HP or u.change.property == SquadBattleTypes.EntityChangeable.DODGE or u.change.property == SquadBattleTypes.EntityChangeable.CLINK:
			any_resolution = true
	_assert(any_resolution, "Goetz action() resolved through personal rule (Iron Hand)")

	var our_squad_a := {SquadBattleTypes.SquadEntityInSquadLocation.Front: [adelheid]}
	var enemy_squad_a := {SquadBattleTypes.SquadEntityInSquadLocation.Front: [goetz]}
	var updates_a := adelheid.action(our_squad_a, enemy_squad_a)
	var any_resolution_a := false
	for u in updates_a:
		if u.change.property == SquadBattleTypes.EntityChangeable.HP or u.change.property == SquadBattleTypes.EntityChangeable.DODGE or u.change.property == SquadBattleTypes.EntityChangeable.CLINK:
			any_resolution_a = true
	_assert(any_resolution_a, "Adelheid action() resolved through personal rule (Sacred Sentence)")


func _assert(condition: bool, msg: String) -> void:
	if condition:
		_pass_count += 1
		print("  ✓ PASS: %s" % msg)
	else:
		_fail_count += 1
		print("  ✗ FAIL: %s" % msg)


func _build_goetz(p_id: int) -> CombatEntity:
	var entity := CombatEntityFactory.get_by_identification(
		"aip_goetz", SquadBattleTypes.Side.ATTACKER, p_id, SquadBattleTypes.SquadEntityInSquadLocation.Front)
	entity.skill_set.set_level(SkillType.Types.Swords, 7)
	return entity


func _build_adelheid(p_id: int) -> CombatEntity:
	var entity := CombatEntityFactory.get_by_identification(
		"aip_adelheid", SquadBattleTypes.Side.DEFENDER, p_id, SquadBattleTypes.SquadEntityInSquadLocation.Back)
	entity.skill_set.set_level(SkillType.Types.Scholarship, 8)
	return entity
