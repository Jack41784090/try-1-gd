extends Control
## Headless mock of StrategyView for AIAct testing.
## Provides no-op UI methods while wiring real game logic components
## (ActivityRunner, AIFleetManager) so StrategyPresenter can run the
## full production turn pipeline without any rendering.

var actor: ActivityRunner
var ai_fleet: AIFleetManager
var vn_view

var action_buttons: Control

var battle_viewport: SubViewport
var combat_overlay: CanvasLayer
var stat_animator


class _MockVnPresenter extends Node:
	var stage_presenter
	func set_stage_presenter(sp): stage_presenter = sp
	func queue_event_chain(_path: String): pass
	func play_next_queued_chain() -> bool: return true
	func bind_view(_v): pass


class _MockVnView extends Control:
	# signal chain_completed
	var presenter

	func _ready():
		presenter = _MockVnPresenter.new()
		add_child(presenter)

	func queue_event_chain(path: String):
		presenter.queue_event_chain(path)

	func play_next_queued_chain() -> bool:
		return true

	func exit(): pass
	func enter(): pass


class _MockStagePresenter extends Node:
	var current_mode: int = 2  # HIDDEN
	func set_mode(_mode): current_mode = _mode
	func start_march(_squad): pass
	func stop_march(): pass
	func refresh_warriors(_squad): pass
	func prepare_for_dialogue(_ids): pass
	func apply_setting(_setting): pass


class _MockStatAnimator:
	var stability_label := _FakeLabel.new()
	var development_label := _FakeLabel.new()
	var money_label := _FakeLabel.new()
	var food_label := _FakeLabel.new()
	var karma_label := _FakeLabel.new()


class _FakeLabel:
	var text: String = ""


var _stage_mock: _MockStagePresenter


func setup_headless():
	actor = ActivityRunner.new()
	actor.name = "ActivityExecuteManager"
	add_child(actor)

	ai_fleet = AIFleetManager.new()
	ai_fleet.name = "AIFleetManager"
	add_child(ai_fleet)

	vn_view = _MockVnView.new()
	vn_view.name = "MockVnView"
	add_child(vn_view)

	_stage_mock = _MockStagePresenter.new()
	_stage_mock.name = "MockStagePresenter"
	add_child(_stage_mock)

	action_buttons = Control.new()

	battle_viewport = SubViewport.new()
	battle_viewport.name = "BattleViewport"
	add_child(battle_viewport)

	combat_overlay = CanvasLayer.new()
	combat_overlay.name = "CombatOverlay"
	add_child(combat_overlay)

	stat_animator = _MockStatAnimator.new()


func get_stage_presenter():
	return _stage_mock


#region Display Updates (no-ops)

func update_clock(_hour: int): pass
func update_pause_state(_is_paused: bool): pass
func update_resting_banner(_is_resting: bool): pass
func update_speed_display(_speed: float): pass
func update_location(_text: String): pass
func update_morale_bar(_value: float): pass
func update_condition(_text: String): pass
func update_contact_bars(_contacts_data): pass

func update_stats(_money, _food, _karma, _stability, _development): pass

func update_activity_button(_key, _text, _disabled, _tooltip, _is_active = false):
	pass

func disable_all_activity_buttons(): pass

#endregion

#region Mode Transitions (no-ops)

func transition_to_strategy(): pass
func transition_to_vn(): pass
func hide_combat_panel(): pass
func show_combat_ui(): pass
func show_strategy_ui(): pass

#endregion

#region VN Delegation

func queue_vn_chain(path: String):
	vn_view.queue_event_chain(path)

func has_queued_vn_chains() -> bool:
	return false

func play_next_queued_chain() -> bool:
	return true

func get_chain_completed_signal() -> Signal:
	return vn_view.chain_completed

#endregion

#region Animation (no-op)

func animate_stat_changes(_deltas: Dictionary): pass
func show_result_summary(_stat_changes, _recruits): pass
func log_squad_event(_text: String, _color = null): pass
func log_squad_separator(): pass

#endregion

var game_over: bool = false

#region Game Over

func show_game_over(_title: String, _description: String):
	game_over = true
	Log.info("HeadlessView", "GAME OVER: %s — %s" % [_title, _description])

#endregion

#region Combat UI (no-ops)

func update_combat_intermission(_a, _b, _c, _d, _e): pass
func update_combat_timer(_value, _max_val): pass
func disable_combat_buttons(): pass
func set_combat_info_text(_text: String): pass
func show_combat_result_overlay(_result, _morale_before, _morale_after): pass
func cleanup_battle_scene(): pass

#endregion

#region Child GUI Delegation (no-ops)

func setup_child_guis(_a): pass
func show_travel_menu(_scenario, _locations): pass
func hide_travel_menu(): pass
func set_travel_mode_autopilot(): pass
func show_continue_travel_button(_dest_name: String): pass
func hide_continue_travel_button(): pass

func show_investigation_menu(): pass
func hide_investigation_menu(): pass
func show_recruitment_menu(): pass
func hide_recruitment_menu(): pass
func show_manage_squad(_squad, _actor = null): pass
func show_shop(_shop, _squad, _location = null): pass
func show_scouting(_world, _squad, _ai_decisions = {}): pass
func bind_scouting(_world, _squad, _ai_decisions = {}): pass
func show_missions(_factions): pass
func show_market(_world, _location, _visited_ids): pass
func hide_market(): pass
var last_notifications: Array = []

func show_notifications(_notifications):
	last_notifications.clear()
	for n in _notifications:
		last_notifications.append(n)

func clear_notifications():
	last_notifications.clear()

#endregion
