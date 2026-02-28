extends Node

## Sanity tests for SquadStrategicData integrity after setup.
## Verifies that warriors survive duplicate(true), morale is non-zero,
## and manage-squad data is correct.
## Run headless: godot --headless --path . -s scenes/demos/squad_data_sanity_test.gd

const FULL_SQUAD_PATH = "res://resources/strategy-squads/test-player-squad-full.tres"

var passed := 0
var failed := 0

func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("SQUAD DATA SANITY TEST")
	print("=".repeat(70) + "\n")

	_test_squad_strategic_data_warriors_survive_duplicate()
	_test_squad_morale_is_nonzero_after_duplicate()
	_test_ensure_initialized_populates_warriors()
	_test_demo_scenario_player_squad_warriors()
	_test_demo_scenario_player_squad_morale()
	_test_warrior_item_hp_percent_logic()
	_test_warrior_location_label_data()

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

#region Tests

func _test_squad_strategic_data_warriors_survive_duplicate() -> void:
	print("\n[1] Warriors survive duplicate(true)")
	var squad := SquadStrategicData.new()
	for i in range(3):
		var w := CharacterSocialStats.new()
		w.name = "Warrior %d" % i
		w.morale = 80.0
		squad.add_warrior(w)

	var duped: SquadStrategicData = squad.duplicate(true)
	_assert(duped.warriors.size() == 3,
		"duplicate(true) preserves warrior count (expected 3, got %d)" % duped.warriors.size())
	if duped.warriors.size() > 0:
		_assert(duped.warriors[0].name == "Warrior 0",
			"first warrior name preserved after duplicate")

func _test_squad_morale_is_nonzero_after_duplicate() -> void:
	print("\n[2] Morale is non-zero after duplicate(true)")
	var squad := SquadStrategicData.new()
	for i in range(3):
		var w := CharacterSocialStats.new()
		w.morale = 80.0
		squad.add_warrior(w)

	var duped: SquadStrategicData = squad.duplicate(true)
	var morale := duped.get_morale()
	_assert(morale > 0.0,
		"get_morale() > 0 after duplicate (got %.1f)" % morale)
	_assert(abs(morale - 80.0) < 1.0,
		"get_morale() approx 80.0 (got %.1f)" % morale)

func _test_ensure_initialized_populates_warriors() -> void:
	print("\n[3] Squad.ensure_initialized() populates warriors from base_data")
	if not ResourceLoader.exists(FULL_SQUAD_PATH):
		print("  SKIP: %s not found" % FULL_SQUAD_PATH)
		return

	var full_squad: Squad = ResourceLoader.load(FULL_SQUAD_PATH)
	_assert(full_squad != null, "Loaded full squad resource")
	if full_squad == null:
		return

	full_squad._initialized = false
	if full_squad.base_data != null and not full_squad.base_data.characters.is_empty():
		full_squad.strategic_data.warriors.clear()
		full_squad.ensure_initialized()
		_assert(full_squad.strategic_data.warriors.size() > 0,
			"ensure_initialized() populates warriors (got %d)" % full_squad.strategic_data.warriors.size())
	else:
		print("  INFO: base_data has no characters, testing strategic_data.warriors directly")
		_assert(full_squad.strategic_data.warriors.size() > 0,
			"strategic_data.warriors already populated from .tres (got %d)" % full_squad.strategic_data.warriors.size())

func _test_demo_scenario_player_squad_warriors() -> void:
	print("\n[4] DemoScenarioFactory: player_squad.warriors not empty")
	var scenario := DemoScenarioFactory.create_demo_scenario()
	var runner := ActivityExecuteManager.new()
	runner.setup(scenario)
	var squad := runner.player_squad

	_assert(squad != null, "player_squad is not null")
	if squad == null:
		return
	_assert(squad.warriors.size() > 0,
		"player_squad.warriors not empty (got %d)" % squad.warriors.size())

func _test_demo_scenario_player_squad_morale() -> void:
	print("\n[5] DemoScenarioFactory: player_squad morale > 0")
	var scenario := DemoScenarioFactory.create_demo_scenario()
	var runner := ActivityExecuteManager.new()
	runner.setup(scenario)
	var squad := runner.player_squad

	if squad == null:
		_assert(false, "Cannot test morale, squad is null")
		return

	var morale := squad.get_morale()
	_assert(morale > 0.0,
		"player_squad.get_morale() > 0 (got %.1f)" % morale)

func _test_warrior_item_hp_percent_logic() -> void:
	print("\n[6] Warrior HP percent: dead=0, injured=0.5, alive=1.0")
	var alive := CharacterSocialStats.new()
	alive.is_dead = false
	alive.is_injured = false

	var injured := CharacterSocialStats.new()
	injured.is_dead = false
	injured.is_injured = true

	var dead := CharacterSocialStats.new()
	dead.is_dead = true

	_assert(_get_warrior_hp_percent(alive) == 1.0,
		"alive warrior HP percent = 1.0 (got %.1f)" % _get_warrior_hp_percent(alive))
	_assert(_get_warrior_hp_percent(injured) == 0.5,
		"injured warrior HP percent = 0.5 (got %.1f)" % _get_warrior_hp_percent(injured))
	_assert(_get_warrior_hp_percent(dead) == 0.0,
		"dead warrior HP percent = 0.0 (got %.1f)" % _get_warrior_hp_percent(dead))

func _test_warrior_location_label_data() -> void:
	print("\n[7] Warrior location_prebattle maps to correct label text")
	var w := CharacterSocialStats.new()

	w.location_prebattle = SquadBattleTypes.SquadEntityInSquadLocation.Front
	_assert(_location_to_label(w) == "Front",
		"Front location label correct")

	w.location_prebattle = SquadBattleTypes.SquadEntityInSquadLocation.Middle
	_assert(_location_to_label(w) == "Middle",
		"Middle location label correct")

	w.location_prebattle = SquadBattleTypes.SquadEntityInSquadLocation.Back
	_assert(_location_to_label(w) == "Back",
		"Back location label correct")

#endregion

#region Helpers (mirror WarriorItem logic for headless testing)

func _get_warrior_hp_percent(warrior_param: CharacterSocialStats) -> float:
	if warrior_param.is_dead:
		return 0.0
	if warrior_param.is_injured:
		return 0.5
	return 1.0

func _location_to_label(warrior_param: CharacterSocialStats) -> String:
	match warrior_param.location_prebattle:
		SquadBattleTypes.SquadEntityInSquadLocation.Front:
			return "Front"
		SquadBattleTypes.SquadEntityInSquadLocation.Middle:
			return "Middle"
		SquadBattleTypes.SquadEntityInSquadLocation.Back:
			return "Back"
		_:
			return "Unknown"

#endregion
