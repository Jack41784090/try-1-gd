class_name StrategyView
extends Control

#region UI Elements
@onready var turn_label: Label = $PanelContainer/MainVBox/StatusHeader/HeaderPanel/HeaderHBox/HeaderMargin/TurnAndLocation/TurnLabel
@onready var location_label: Label = $PanelContainer/MainVBox/StatusHeader/HeaderPanel/HeaderHBox/HeaderMargin/TurnAndLocation/LocationLabel
@onready var end_button: Button = $PanelContainer/MainVBox/StatusArea/EndButton
@onready var morale_label: ProgressBar = $PanelContainer/MainVBox/StatusArea/StatusPanel/StatusMargin/StatusContent/ProgressBar
@onready var morale_panel: PanelContainer = $PanelContainer/MainVBox/StatusArea/StatusPanel
@onready var condition_label: Label = $PanelContainer/MainVBox/StatusArea/StatusPanel/StatusMargin/StatusContent/ConditionStatus/ConditionMargin/ConditionLabel

@onready var main_background: TextureRect = $PanelContainer/MainBackground
@onready var foreground: TextureRect = $PanelContainer/Foreground

@onready var action_buttons: PanelContainer = $PanelContainer/MainVBox/ActionButtons
@onready var rest_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/TrainingButton
@onready var drill_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/RestButton
@onready var patrol_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/SkillButton
@onready var investigate_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/NurseButton
@onready var hold_mass_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/OutingButton
@onready var travel_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/RaceButton
@onready var attack_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/AttackButton
@onready var manage_squad_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/ManageSquadButton
@onready var recruit_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/RecruitButton
@onready var shop_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/ShopButton
@onready var travel_view: TravelView = $TravelView
@onready var investigation_view: InvestigationView = $InvestigationView
@onready var recruitment_view: RecruitmentView = $RecruitmentView
@onready var manage_squad_page = $ManageSquadPage
@onready var shop_view: ShopView = $ShopView
@onready var scouting_view: ScoutingView = $PanelContainer/MainVBox/MainScreenArea/ScoutingView
@onready var squad_log_view: SquadLogView = $PanelContainer/MainVBox/MainScreenArea/SquadLogView
@onready var missions_view: MissionsView = $MissionsView
@onready var market_view: MarketView = $MarketView
@onready var resting_banner: CenterContainer = $PanelContainer/MainVBox/MainScreenArea/RestingBanner

@onready var skip_button: Button = $PanelContainer/MainVBox/BottomNavBar/NavMargin/NavContent/SkipButton
@onready var short_button: Button = $PanelContainer/MainVBox/BottomNavBar/NavMargin/NavContent/ShortButton
@onready var missions_button: Button = $PanelContainer/MainVBox/BottomNavBar/NavMargin/NavContent/MissionsButton
@onready var market_button: Button = $PanelContainer/MainVBox/BottomNavBar/NavMargin/NavContent/MarketButton

@onready var combat_intermission_node: PanelContainer = $CombatIntermission
@onready var combat_overlay_node: CanvasLayer = $CombatOverlay
var combat_ui: CombatUI
var _contact_bars: Array[ContactMiniBar] = []
var _active_contacts: Dictionary = {}

var battle_viewport: SubViewport:
	get:
		return combat_ui.viewport if combat_ui else null
var combat_overlay: CanvasLayer:
	get:
		return combat_ui.overlay if combat_ui else null
#endregion

#region Components
@onready var presenter: StrategyPresenter = $StrategyPresenter
@onready var cutscene_player: CutscenePlayer = $PanelContainer/Foreground/CutscenePlayer
@onready var vn_view: VnView = cutscene_player.vn_view
@onready var stage_view: StageView = cutscene_player.stage_view
@onready var stat_animator: StatChangeAnimator = $PanelContainer
@onready var actor: ActivityRunner = $ActivityExecuteManager
@onready var ai_fleet: AISquadManager = $AISquadManager
@onready var notification_bar: NotificationBar = $PanelContainer/MainVBox/NotificationBar
@onready var _game_over_overlay: ColorRect = $GameOverOverlay
@onready var _game_over_title: Label = $GameOverOverlay/GameOverVBox/TitleLabel
@onready var _game_over_desc: Label = $GameOverOverlay/GameOverVBox/DescLabel
@onready var _game_over_restart_btn: Button = $GameOverOverlay/GameOverVBox/RestartButton
@onready var _clock_display: ClockDisplay = $PanelContainer/MainVBox/StatusHeader/HeaderPanel/HeaderHBox/HeaderMargin/TurnAndLocation/ClockDisplay
#endregion

#region Lifecycle

func _init() -> void:
	print(" --- main gui init --- ")


func _ready() -> void:
	print(" --- Main gui is ready --- ")
	combat_ui = CombatUI.create(self , combat_intermission_node, combat_overlay_node, morale_panel, morale_label)
	rest_button.visible = false
	_connect_signals()
	StrategyEventBus.strategy_hour_tick.connect(update_clock)
	StrategyEventBus.squad_morale_changed.connect(update_morale_bar)
	StrategyEventBus.hud_location_changed.connect(update_location)
	StrategyEventBus.hud_condition_changed.connect(update_condition)
	StrategyEventBus.hud_stats_changed.connect(update_stats)
	StrategyEventBus.hud_contact_bars_changed.connect(update_contact_bars)
	StrategyEventBus.pause_state_changed.connect(update_pause_state)
	StrategyEventBus.speed_changed.connect(update_speed_display)
	var action_btns: Array[Button] = [
		drill_button,
		patrol_button,
		investigate_button,
		hold_mass_button,
		travel_button,
		attack_button,
		manage_squad_button,
		recruit_button,
		shop_button,
	]
	for btn in action_btns:
		btn.focus_mode = Control.FOCUS_NONE
		UIAnimations.register_button(btn)
	var nav_btns: Array[Button] = [skip_button, short_button, missions_button, market_button]
	for btn in nav_btns:
		btn.focus_mode = Control.FOCUS_NONE
		UIAnimations.register_button(btn)
	combat_ui.register_button_animations()
	presenter.bind_view(self )


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			presenter.on_pause_toggle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_G:
			get_viewport().set_input_as_handled()

#endregion

#region Signal Wiring

func _connect_signals() -> void:
	drill_button.pressed.connect(func(): presenter.on_activity_requested(StrategyTypes.ActivityType.DRILL))
	patrol_button.pressed.connect(func(): presenter.on_activity_requested(StrategyTypes.ActivityType.PATROL))
	investigate_button.pressed.connect(func(): presenter.on_investigate_requested())
	hold_mass_button.pressed.connect(func(): presenter.on_activity_requested(StrategyTypes.ActivityType.HOLD_MASS))
	travel_button.pressed.connect(func(): presenter.on_travel_requested())
	attack_button.pressed.connect(func(): presenter.on_activity_requested(StrategyTypes.ActivityType.ATTACK))
	manage_squad_button.pressed.connect(func(): presenter.on_manage_squad_requested())
	recruit_button.pressed.connect(func(): presenter.on_recruit_requested())
	shop_button.pressed.connect(func(): presenter.on_shop_requested())

	skip_button.pressed.connect(func(): presenter.on_skip_pressed())
	short_button.pressed.connect(func(): presenter.on_summary_pressed())
	missions_button.pressed.connect(func(): presenter.on_missions_requested())
	market_button.pressed.connect(func(): presenter.on_market_requested())

	if scouting_view:
		scouting_view.closed.connect(func(): presenter.on_scouting_closed())

	combat_ui.connect_signals(presenter)

	if travel_view:
		travel_view.travel_confirmed.connect(
			func(id):
				_play_sfx("play_ui_confirm")
				presenter.on_travel_confirmed(id)
		)
		travel_view.travel_cancelled.connect(
			func():
				_play_sfx("play_ui_cancel")
				presenter.on_travel_cancelled()
		)

	if investigation_view:
		investigation_view.investigation_closed.connect(func(): presenter.on_investigation_closed())

	if recruitment_view:
		recruitment_view.recruitment_completed.connect(func(warrior): presenter.on_recruitment_completed(warrior))
		recruitment_view.closed.connect(func(): presenter.on_recruitment_closed())

	if manage_squad_page:
		manage_squad_page.closed.connect(func(): presenter.on_manage_squad_closed())
		manage_squad_page.recruitment_completed.connect(func(warrior): presenter.on_recruitment_completed(warrior))

	if missions_view:
		missions_view.presenter.missions_closed.connect(func(): presenter.on_missions_closed())

	if market_view:
		market_view.closed.connect(func(): presenter.on_market_closed())

	_game_over_restart_btn.pressed.connect(func(): get_tree().reload_current_scene())

	if shop_view:
		shop_view.presenter.purchase_completed.connect(func(purchases): presenter.on_purchase_completed(purchases))
		shop_view.presenter.shop_closed.connect(func(): presenter.on_shop_closed())


#endregion

#region Display Updates

var _clock_base_text: String = ""


func update_clock(hour: int) -> void:
	var day := hour / 24 + 1
	var hour_of_day := hour % 24
	_clock_base_text = "Day %d — %02d:00" % [day, hour_of_day]
	turn_label.text = _clock_base_text
	_clock_display.set_hour(hour_of_day)


func update_pause_state(is_paused: bool) -> void:
	if is_paused:
		turn_label.text = _clock_base_text + " [PAUSED]"
	else:
		turn_label.text = _clock_base_text


func update_resting_banner(is_resting: bool) -> void:
	resting_banner.visible = is_resting and not presenter.game_scenario.world.is_paused


func update_speed_display(speed: float) -> void:
	pass


func update_location(text: String) -> void:
	location_label.text = text


func update_morale_bar(value: float) -> void:
	morale_label.value = value


func update_condition(text: String) -> void:
	condition_label.text = text


func update_contact_bars(contacts_data: Array[Dictionary]) -> void:
	var new_ids: Dictionary = {}
	for data in contacts_data:
		new_ids[data["target_id"]] = data

	var removed: Array[String] = []
	for tid in _active_contacts:
		if not new_ids.has(tid):
			removed.append(tid)
	for tid in removed:
		var bar: ContactMiniBar = _active_contacts.get(tid)
		if not bar:
			_active_contacts.erase(tid)
			continue
		_active_contacts.erase(tid)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(bar, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(bar, "position:y", 40.0, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		tween.chain().tween_callback(bar.reset_bar)

	for data in contacts_data:
		var tid: String = data["target_id"]
		if _active_contacts.has(tid):
			var bar: ContactMiniBar = _active_contacts[tid]
			bar.update_existing(data)
		else:
			var bar: ContactMiniBar = null
			for b in _contact_bars:
				if not b.visible:
					bar = b
					break
			if bar:
				bar.populate(data)
				_active_contacts[tid] = bar
				bar.modulate.a = 0.0
				bar.position.y = 30.0
				var tween := create_tween().set_parallel(true)
				tween.tween_property(bar, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
				tween.tween_property(bar, "position:y", 0.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func update_stats(money: float, food: int, karma: float, stability: float, development: int) -> void:
	stat_animator.stability_label.text = "%.0f" % stability
	stat_animator.development_label.text = "%d" % development
	stat_animator.money_label.text = "%.0f" % money
	stat_animator.food_label.text = "%d" % food
	stat_animator.karma_label.text = "%.0f" % karma


func update_activity_button(key: String, text: String, disabled: bool, tooltip: String, is_active: bool = false) -> void:
	var button: Button
	match key:
		"rest":
			button = rest_button
		"drill":
			button = drill_button
		"patrol":
			button = patrol_button
		"investigate":
			button = investigate_button
		"hold_mass":
			button = hold_mass_button
		"travel":
			button = travel_button
		"attack":
			button = attack_button
		"manage_squad":
			button = manage_squad_button
		"shop":
			button = shop_button
		"market":
			button = market_button
		_:
			button = null
	if button:
		button.text = text
		button.disabled = disabled
		button.tooltip_text = tooltip
		if is_active:
			button.modulate = Color(0.4, 1.0, 0.5, 1.0)
		else:
			button.modulate = Color(1, 1, 1, 1)


func disable_all_activity_buttons() -> void:
	drill_button.disabled = true
	patrol_button.disabled = true
	investigate_button.disabled = true
	hold_mass_button.disabled = true
	travel_button.disabled = true
	attack_button.disabled = true
	manage_squad_button.disabled = true
	shop_button.disabled = true


#endregion

#region UI Mode Transitions

func show_strategy_ui() -> void:
	action_buttons.visible = true
	var btns: Array[Button] = [
		drill_button,
		patrol_button,
		investigate_button,
		hold_mass_button,
		travel_button,
		attack_button,
		manage_squad_button,
		recruit_button,
		shop_button,
	]
	UIAnimations.stagger_buttons(btns)


func show_combat_ui() -> void:
	await combat_ui.show_ui()


func hide_combat_panel() -> void:
	await combat_ui.hide_panel()


func transition_to_strategy() -> void:
	await SceneManager.transition_quick(
		func():
			vn_view.exit()
			show_strategy_ui()
	)


func transition_to_vn(trans_type: EventChain.TransitionType = EventChain.TransitionType.QUICK) -> void:
	match trans_type:
		EventChain.TransitionType.NONE:
			vn_view.enter()
		_:
			await SceneManager.transition_quick(
				func():
					vn_view.enter()
			)

#endregion

#region Combat UI

func update_combat_intermission(enemy_name: String, enemy_count: int, flee_chance: float, negotiate_chance: float, options: Dictionary) -> void:
	combat_ui.update_intermission(enemy_name, enemy_count, flee_chance, negotiate_chance, options)


func update_combat_timer(value: float, max_value: float) -> void:
	combat_ui.update_timer(value, max_value)


func disable_combat_buttons() -> void:
	combat_ui.disable_buttons()


func set_combat_info_text(text: String) -> void:
	combat_ui.set_info_text(text)


func show_combat_result_overlay(result: CombatController.CombatResult, morale_before: float, morale_after: float) -> void:
	await combat_ui.show_result_overlay(result, morale_before, morale_after)


func cleanup_battle_scene() -> void:
	combat_ui.cleanup_battle_scene()

#endregion

#region VN Delegation

func queue_vn_chain(path: String) -> void:
	vn_view.queue_event_chain(path)


func has_queued_vn_chains() -> bool:
	return not vn_view.presenter.event_chain_queue.is_empty()


func play_next_queued_chain() -> bool:
	return vn_view.play_next_queued_chain()


func get_chain_completed_signal() -> Signal:
	return vn_view.chain_completed


func peek_next_vn_transition_type() -> EventChain.TransitionType:
	return vn_view.peek_next_transition_type()

#endregion

#region Child GUI Delegation

func setup_child_guis(a: ActivityRunner) -> void:
	## Passes the ActivityRunner reference to child menu views that need game state access
	## Called once during _setup_components by the presenter
	## e.g., travel_view needs actor to get reachable locations, investigation_view needs clues, etc.
	travel_view.setup(a)
	investigation_view.setup(a)
	recruitment_view.setup(a)


func show_travel_menu(scenario: GameScenario, locations) -> void:
	travel_view.show_travel_menu(scenario, locations)


func hide_travel_menu() -> void:
	travel_view.hide_travel_menu()


func set_travel_mode_autopilot() -> void:
	travel_view.set_mode_autopilot()


func show_investigation_menu() -> void:
	investigation_view.show_investigation_menu()


func hide_investigation_menu() -> void:
	investigation_view.hide_investigation_menu()


func show_recruitment_menu() -> void:
	recruitment_view.show_recruitment_menu()


func hide_recruitment_menu() -> void:
	recruitment_view.hide_recruitment_menu()


func show_manage_squad(squad: StrategySquad, p_actor: ActivityRunner) -> void:
	manage_squad_page.open(squad, p_actor)


func show_shop(shop: Shop, squad: StrategySquad, location: Location = null) -> void:
	shop_view.presenter.open(shop, squad, location)


func hide_shop() -> void:
	shop_view.presenter._on_closed()


func show_scouting(world: World, player_squad: StrategySquad, ai_decisions: Dictionary = {}) -> void:
	scouting_view.show_scouting(world, player_squad, ai_decisions)


func hide_scouting() -> void:
	scouting_view.hide_scouting()


func bind_scouting(world: World, player_squad: StrategySquad, ai_decisions: Dictionary = {}) -> void:
	scouting_view.bind(world, player_squad, ai_decisions)


func show_missions(factions: Array[Faction]) -> void:
	var all_missions: Array[Mission] = []
	for faction in factions:
		for mission in faction.missions:
			all_missions.append(mission)
	missions_view.presenter.open(all_missions)


func hide_missions() -> void:
	missions_view.hide_missions()


func show_market(world: World, location: Location, visited_ids: Array[String]) -> void:
	market_view.show_market(world, location, visited_ids)


func hide_market() -> void:
	market_view.hide_market()

#endregion

#region Animation

func animate_stat_changes(deltas: Dictionary) -> void:
	await stat_animator.animate_changes(deltas)

#endregion

#region Squad Log

func log_squad_event(text: String, color: Color = Color(0.78, 0.75, 0.68)) -> void:
	if squad_log_view:
		squad_log_view.add_entry(text, color)


func log_squad_separator() -> void:
	if squad_log_view:
		squad_log_view.add_separator()

#endregion

#region Stage Delegation

func get_stage_presenter() -> StagePresenter:
	return stage_view.presenter


func show_stage() -> void:
	stage_view.visible = true


func hide_stage() -> void:
	stage_view.visible = false

#endregion

#region Notification Bar

func show_notifications(notifications: Array[NotificationData]) -> void:
	notification_bar.show_notifications(notifications)


func clear_notifications() -> void:
	notification_bar.clear()

#endregion

#region Game Over

func show_game_over(title_text: String, description: String) -> void:
	disable_all_activity_buttons()
	action_buttons.visible = false

	_game_over_title.text = title_text
	_game_over_desc.text = description
	_game_over_overlay.visible = true
	_game_over_overlay.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(_game_over_overlay, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)

#endregion

#region Display Helpers

func _play_sfx(method_name: String) -> void:
	var sfx = get_tree().root.get_node_or_null("SFX")
	if sfx and sfx.has_method(method_name):
		sfx.call(method_name)

#endregion
