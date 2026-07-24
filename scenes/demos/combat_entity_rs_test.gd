extends Node

## Regression test for CombatEntity's ReactiveStat-backed stat system.
## Verifies template resolution, _REALITY_TABLE-driven ceiling calculation,
## floor/ceiling clamping, and per-instance duplication independence.
## Run headless: godot --headless --path . scenes/demos/combat_entity_rs_test.tscn

const IDENTIFICATION := "landsknecht"

# Hand-transcribed from resources/combat/classes/landsknecht.tres (BS_test-Landsnecht values).
const EXPECTED_STRENGTH := 1.25
const EXPECTED_ENDURANCE := 1.25
const EXPECTED_SIZ := 1.0
const EXPECTED_WIL := 1.5
const EXPECTED_FAI := 1.0

# _REALITY_TABLE[HP] = [3.0, MUL, [[ENDURANCE, 5.0], [SIZ, 2.0]]]
#   → 3.0 + (1.25 * 5.0) * (1.0 * 2.0) = 3.0 + 6.25 * 2.0 = 15.5
const EXPECTED_MAX_HP := 15.5
# _REALITY_TABLE[Guts] = [10.0, ADD, [[WIL, 8.0], [FAI, 5.0]]]
#   → 10.0 + (1.5 * 8.0) + (1.0 * 5.0) = 10.0 + 12.0 + 5.0 = 27.0
const EXPECTED_MAX_ORG := 27.0

var passed := 0
var failed := 0


func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("COMBAT ENTITY REACTIVESTAT TEST")
	print("=".repeat(70) + "\n")

	_test_base_attributes_match_template()
	_test_ceiling_matches_reality_table_formula()
	_test_hp_starts_at_ceiling()
	_test_hp_clamps_at_floor()
	_test_hp_clamps_at_ceiling()
	_test_instance_duplication_independence()
	_test_character_enter_battle_tier1_fallback()
	_test_character_no_strategy_resolves_from_template()

	print("\n" + "=".repeat(70))
	print("RESULTS: %d passed, %d failed" % [passed, failed])
	print("=".repeat(70))
	if failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func _assert(condition: bool, msg: String) -> void:
	if condition:
		print("  PASS: %s" % msg)
		passed += 1
	else:
		print("  FAIL: %s" % msg)
		failed += 1


func _build_entity(player_id: int) -> CombatEntity:
	return CombatEntityFactory.get_by_identification(
		IDENTIFICATION,
		SquadBattleTypes.Side.ATTACKER,
		player_id,
		SquadBattleTypes.SquadEntityInSquadLocation.Front,
	)


func _test_base_attributes_match_template() -> void:
	print("\n[1] Base attributes resolve from the class template")
	var entity := _build_entity(1)

	_assert(is_equal_approx(entity.get_stat_value(StatName.I.STRENGTH), EXPECTED_STRENGTH),
		"STRENGTH matches template (got %s)" % entity.get_stat_value(StatName.I.STRENGTH))
	_assert(is_equal_approx(entity.get_stat_value(StatName.I.ENDURANCE), EXPECTED_ENDURANCE),
		"ENDURANCE matches template (got %s)" % entity.get_stat_value(StatName.I.ENDURANCE))
	_assert(is_equal_approx(entity.get_stat_value(StatName.I.WIL), EXPECTED_WIL),
		"WIL matches template (got %s)" % entity.get_stat_value(StatName.I.WIL))


func _test_ceiling_matches_reality_table_formula() -> void:
	print("\n[2] get_ceiling_changeable_stat() matches hand-computed _REALITY_TABLE formula")
	var entity := _build_entity(2)

	var max_hp := entity.get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.HP)
	_assert(is_equal_approx(max_hp, EXPECTED_MAX_HP),
		"max HP = 3.0 + (ENDURANCE*5.0)*(SIZ*2.0) = %s (got %s)" % [EXPECTED_MAX_HP, max_hp])

	var max_org := entity.get_ceiling_changeable_stat(SquadBattleTypes.EntityChangeable.ORG)
	_assert(is_equal_approx(max_org, EXPECTED_MAX_ORG),
		"max ORG = 10.0 + WIL*8.0 + FAI*5.0 = %s (got %s)" % [EXPECTED_MAX_ORG, max_org])


func _test_hp_starts_at_ceiling() -> void:
	print("\n[3] HP is seeded at the ceiling on construction")
	var entity := _build_entity(3)
	var hp := entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	_assert(is_equal_approx(hp, EXPECTED_MAX_HP),
		"starting HP equals max HP (got %s, expected %s)" % [hp, EXPECTED_MAX_HP])


func _test_hp_clamps_at_floor() -> void:
	print("\n[4] HP writes clamp at the floor")
	var entity := _build_entity(4)
	entity.set_changeable_stat(SquadBattleTypes.EntityChangeable.HP, -100.0)
	var hp := entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	_assert(hp == 0.0, "HP clamped to floor 0.0 (got %s)" % hp)
	_assert(entity.is_dead(), "entity is_dead() true at 0 HP")


func _test_hp_clamps_at_ceiling() -> void:
	print("\n[5] HP writes clamp at the ceiling")
	var entity := _build_entity(5)
	entity.set_changeable_stat(SquadBattleTypes.EntityChangeable.HP, 9999.0)
	var hp := entity.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	_assert(is_equal_approx(hp, EXPECTED_MAX_HP), "HP clamped to ceiling %s (got %s)" % [EXPECTED_MAX_HP, hp])


func _test_instance_duplication_independence() -> void:
	print("\n[6] Two entities from the same template have independent ReactiveStats")
	var entity1 := _build_entity(6)
	var entity2 := _build_entity(7)

	var hp1_before := entity1.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	var hp2_before := entity2.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	_assert(is_equal_approx(hp1_before, hp2_before), "both start at the same max HP")

	entity1.mod_changeable_stat(SquadBattleTypes.EntityChangeable.HP, -5.0)
	var hp1_after := entity1.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)
	var hp2_after := entity2.get_changeable_stat_num(SquadBattleTypes.EntityChangeable.HP)

	_assert(not is_equal_approx(hp1_after, hp1_before), "entity1 HP actually changed")
	_assert(is_equal_approx(hp2_after, hp2_before), "entity2 HP untouched by entity1's mutation (got %s)" % hp2_after)


func _test_character_enter_battle_tier1_fallback() -> void:
	print("\n[7] Character.enter_battle(): tier-2-miss falls through to the tier-1 template")
	# StrategyEntityResource authors no BASE_ATTRIBUTE_STATS entries (per design — that's
	# the extension seam for a future training/growth system), so this persistent
	# character's STRENGTH lookup must fall all the way through to the class template.
	var res := StrategyEntityResource.new()
	res.name = "Tier2 Siegmund"
	res.identification = IDENTIFICATION
	var strategy_entity := StrategyEntity.new(res)
	var character := Character.new(strategy_entity)

	_assert(character.get_stat(StatName.I.STRENGTH) == null,
		"tier-2 StrategyEntity has no STRENGTH entry of its own (confirms this exercises the fallback)")

	var combat_entity := character.enter_battle(
		SquadBattleTypes.Side.ATTACKER, 8, SquadBattleTypes.SquadEntityInSquadLocation.Front)

	_assert(is_equal_approx(combat_entity.get_stat_value(StatName.I.STRENGTH), EXPECTED_STRENGTH),
		"resolved STRENGTH matches template via tier-1 fallback (got %s)" % combat_entity.get_stat_value(StatName.I.STRENGTH))
	_assert(character.combat == combat_entity, "Character.combat is set to the entered battle entity")

	character.exit_battle()
	_assert(character.combat == null, "Character.combat cleared after exit_battle()")


func _test_character_no_strategy_resolves_from_template() -> void:
	print("\n[8] Character with strategy=null resolves straight from the template (monster/demo path)")
	var character := Character.new(null, IDENTIFICATION)

	_assert(character.get_combat_identification() == IDENTIFICATION,
		"combat_identification override used with no strategy")

	var combat_entity := character.enter_battle(
		SquadBattleTypes.Side.DEFENDER, 9, SquadBattleTypes.SquadEntityInSquadLocation.Front)

	_assert(is_equal_approx(combat_entity.get_stat_value(StatName.I.STRENGTH), EXPECTED_STRENGTH),
		"resolved STRENGTH matches template with no StrategyEntity at all (got %s)" % combat_entity.get_stat_value(StatName.I.STRENGTH))
