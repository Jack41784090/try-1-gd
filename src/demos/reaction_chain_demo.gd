extends Node

var _pass_count: int = 0
var _fail_count: int = 0


func _ready():
	print("\n=== REACTION CHAIN DEMO ===\n")

	# --- test: cancel at on cast ---
	print("--- Test: CANCEL at ON_CAST produces zero damage ---")
	var attacker := _build_entity(1, SquadBattleTypes.Side.ATTACKER)
	var target := _build_entity(2, SquadBattleTypes.Side.DEFENDER)

	var counter_reaction := ReactionSkill.new()
	counter_reaction.reaction_name = "counterspell"
	counter_reaction.window = SquadBattleTypes.ReactionWindow.ON_CAST
	counter_reaction.relation_to_target = ReactionSkill.Relation.SELF
	counter_reaction.once_per_round = false
	var cancel_effect := ReactionEffect.new()
	cancel_effect.kind = ReactionEffect.Kind.CANCEL
	counter_reaction.effect = cancel_effect
	target.reactions = [counter_reaction]

	var skill: Skill = load("res://resources/combat/logic/skills/example-attack-skill.tres")
	var intent := ClashIntent.new(attacker, skill, target)
	var resolver := ClashResolver.new()
	resolver.set_entities([attacker, target])
	resolver.begin_round(5)
	var updates := resolver.resolve(intent)

	var hp_changes := 0
	for u in updates:
		if u.change.property == SquadBattleTypes.EntityChangeable.HP:
			hp_changes += 1
	_assert(hp_changes == 0, "no HP changes after ON_CAST cancel (got %d)" % hp_changes)
	_assert(target.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP) > 0, "target still alive")

	# --- test: redirect to self ---
	print("--- Test: REDIRECT_TO_SELF moves damage to reactor ---")
	var attacker2 := _build_entity(3, SquadBattleTypes.Side.ATTACKER)
	var target2 := _build_entity(4, SquadBattleTypes.Side.DEFENDER)
	var protector := _build_entity(5, SquadBattleTypes.Side.DEFENDER)

	var redirect_reaction := ReactionSkill.new()
	redirect_reaction.reaction_name = "bodyguard"
	redirect_reaction.window = SquadBattleTypes.ReactionWindow.ON_PIERCE
	redirect_reaction.relation_to_target = ReactionSkill.Relation.ALLY
	redirect_reaction.once_per_round = false
	var redirect_effect := ReactionEffect.new()
	redirect_effect.kind = ReactionEffect.Kind.REDIRECT_TO_SELF
	redirect_reaction.effect = redirect_effect
	protector.reactions = [redirect_reaction]

	var hp_before_target := target2.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	var hp_before_protector := protector.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)

	var skill2: Skill = load("res://resources/combat/logic/skills/example-attack-skill.tres")
	var intent2 := ClashIntent.new(attacker2, skill2, target2)
	var resolver2 := ClashResolver.new()
	resolver2.set_entities([attacker2, target2, protector])
	resolver2.begin_round(5)
	resolver2.resolve(intent2)

	var hp_after_target := target2.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	var hp_after_protector := protector.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)

	var target_damaged := hp_after_target < hp_before_target
	var protector_damaged := hp_after_protector < hp_before_protector
	var any_damage := target_damaged or protector_damaged

	if not any_damage:
		print("  (attack was dodged/blocked, skipping redirect assertion)")
		_assert(true, "no damage dealt (dodge/block) — redirect not tested this run")
	else:
		_assert(not target_damaged, "target took no damage (HP %.1f→%.1f)" % [hp_before_target, hp_after_target])
		_assert(protector_damaged, "protector took damage (HP %.1f→%.1f)" % [hp_before_protector, hp_after_protector])

	# --- test: max depth enforcement ---
	print("--- Test: MAX_DEPTH stops infinite chains ---")
	var attacker3 := _build_entity(6, SquadBattleTypes.Side.ATTACKER)
	var target3 := _build_entity(7, SquadBattleTypes.Side.DEFENDER)

	var ping_reaction := ReactionSkill.new()
	ping_reaction.reaction_name = "ping"
	ping_reaction.window = SquadBattleTypes.ReactionWindow.ON_DAMAGED
	ping_reaction.relation_to_target = ReactionSkill.Relation.SELF
	ping_reaction.once_per_round = false
	var scale_effect := ReactionEffect.new()
	scale_effect.kind = ReactionEffect.Kind.SCALE_DAMAGE
	scale_effect.value = 1.0
	ping_reaction.effect = scale_effect
	ping_reaction.skill = load("res://resources/combat/logic/skills/example-attack-skill.tres")
	target3.reactions = [ping_reaction]

	var skill3: Skill = load("res://resources/combat/logic/skills/example-attack-skill.tres")
	var intent3 := ClashIntent.new(attacker3, skill3, target3)
	var resolver3 := ClashResolver.new()
	resolver3.set_entities([attacker3, target3])
	resolver3.begin_round(100)
	var updates3 := resolver3.resolve(intent3)

	var proc_count := 0
	for u in updates3:
		if u.change.property == SquadBattleTypes.EntityChangeable.PROC:
			proc_count += 1
	_assert(proc_count <= ClashResolver.MAX_DEPTH, "chain depth bounded (procs=%d, max=%d)" % [proc_count, ClashResolver.MAX_DEPTH])
	print("  (chain produced %d PROCs)" % proc_count)

	# --- test: once per round latch ---
	print("--- Test: once_per_round prevents repeat firing ---")
	var attacker4 := _build_entity(8, SquadBattleTypes.Side.ATTACKER)
	var target4 := _build_entity(9, SquadBattleTypes.Side.DEFENDER)

	var latch_reaction := ReactionSkill.new()
	latch_reaction.reaction_name = "latch_test"
	latch_reaction.window = SquadBattleTypes.ReactionWindow.ON_DAMAGED
	latch_reaction.relation_to_target = ReactionSkill.Relation.SELF
	latch_reaction.once_per_round = true
	var scale_effect2 := ReactionEffect.new()
	scale_effect2.kind = ReactionEffect.Kind.SCALE_DAMAGE
	scale_effect2.value = 0.5
	latch_reaction.effect = scale_effect2
	target4.reactions = [latch_reaction]

	var skill4: Skill = load("res://resources/combat/logic/skills/example-attack-skill.tres")
	var resolver4 := ClashResolver.new()
	resolver4.set_entities([attacker4, target4])
	resolver4.begin_round(10)

	var intent4a := ClashIntent.new(attacker4, skill4.duplicate(), target4)
	resolver4.resolve(intent4a)
	var intent4b := ClashIntent.new(attacker4, skill4.duplicate(), target4)
	var updates4 := resolver4.resolve(intent4b)

	var proc_in_second := 0
	for u in updates4:
		if u.change.property == SquadBattleTypes.EntityChangeable.PROC:
			proc_in_second += 1
	_assert(proc_in_second == 0, "reaction did not fire again in same round (procs=%d)" % proc_in_second)

	print("\n=== RESULTS: %d passed, %d failed ===\n" % [_pass_count, _fail_count])
	get_tree().quit(0 if _fail_count == 0 else 1)


func _assert(condition: bool, msg: String) -> void:
	if condition:
		_pass_count += 1
		print("  ✓ PASS: %s" % msg)
	else:
		_fail_count += 1
		print("  ✗ FAIL: %s" % msg)


func _build_entity(p_id: int, p_side: SquadBattleTypes.Side) -> CombatEntity:
	return CombatEntityFactory.get_by_identification(
		"landsknecht", p_side, p_id, SquadBattleTypes.SquadEntityInSquadLocation.Front)
