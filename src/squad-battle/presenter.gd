class_name SquadBattlePresenter extends Node

signal battle_completed(outcome: SquadBattleTypes.BattleOutcome)

var view: SquadBattleView
var battle: SquadBattle
var is_running: bool = false
var delay_between_rounds: float = 2.0
var last_round_capitulated: Array = []
var all_updates: Array[EntityUpdate] = []

func bind_view(v: SquadBattleView) -> void:
	view = v

func start(p_battle: SquadBattle, config: Dictionary) -> void:
	if p_battle == null:
		if config == null or config.is_empty():
			p_battle = _create_mock_battle()
		else:
			p_battle = SquadBattle.new(config)
	battle = p_battle
	view.spawn_all_entities(battle)
	is_running = true

	SBLog.section("SquadCombatData Battle Started!", 0, 2, 1)
	await view.get_tree().create_timer(1.0).timeout
	_process_round()

func _process_round() -> void:
	var outcome = battle.get_battle_outcome()
	if outcome != SquadBattleTypes.BattleOutcome.ONGOING:
		view.show_outcome(outcome, battle)
		is_running = false
		battle_completed.emit(outcome)
		return

	SBLog.section("Round %d / %d" % [battle.round_count + 1, battle.max_rounds], 1, 1, 1)
	battle.round_count += 1

	battle.remove_dead_entities()
	battle.remove_capitulated_entities(last_round_capitulated)
	last_round_capitulated.clear()

	var updates = battle.squad_actions()
	for update in updates:
		all_updates.append(update)
		if update.change.property == SquadBattleTypes.EntityChangeable.CAPITULATE:
			var entity = battle.get_entity_by_id(update.affected)
			if entity:
				last_round_capitulated.append(entity)

	battle.squad_recoveries()
	await view.process_updates(updates, battle)
	await view.animate_return_all()
	await view.wait_delay(delay_between_rounds)
	_process_round()

func _create_mock_battle() -> SquadBattle:
	var battle_config = {
		"teams": {
			SquadBattleTypes.Side.ATTACKER: [ {
				"side": SquadBattleTypes.Side.ATTACKER,
				"name": "Heroes",
				"team": "heroes",
				"entities": [
					EntityClasses.Types.Landsknecht,
					EntityClasses.Types.Landsknecht,
					EntityClasses.Types.Landsknecht,
					EntityClasses.Types.Healer
				]
			}],
			SquadBattleTypes.Side.DEFENDER: [ {
				"side": SquadBattleTypes.Side.DEFENDER,
				"name": "Monsters",
				"team": "monsters",
				"entities": [
					EntityClasses.Types.Landsknecht,
					EntityClasses.Types.Landsknecht,
					EntityClasses.Types.Landsknecht,
					EntityClasses.Types.Healer
				]
			}]
		},
		"attacker_tactic": Tactic.create_balanced(),
		"defender_tactic": Tactic.create_balanced()
	}

	return SquadBattle.new(battle_config)
