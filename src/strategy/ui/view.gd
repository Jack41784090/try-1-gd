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
@onready var continue_travel_button: Button = $PanelContainer/MainVBox/ActionButtons/ActionMargin/ActionGrid/ContinueTravelButton
@onready var travel_view: TravelView = $TravelView
@onready var investigation_view: InvestigationView = $InvestigationView
@onready var recruitment_view: RecruitmentView = $RecruitmentView
@onready var manage_squad_page = $ManageSquadPage
@onready var shop_view: ShopView = $ShopView
@onready var scouting_view: ScoutingView = $ScoutingView
@onready var missions_view: MissionsView = $MissionsView
@onready var market_view: MarketView = $MarketView

@onready var skip_button: Button = $PanelContainer/MainVBox/BottomNavBar/NavMargin/NavContent/SkipButton
@onready var short_button: Button = $PanelContainer/MainVBox/BottomNavBar/NavMargin/NavContent/ShortButton
@onready var scout_button: Button = $PanelContainer/MainVBox/BottomNavBar/NavMargin/NavContent/ScoutButton
@onready var missions_button: Button = $PanelContainer/MainVBox/BottomNavBar/NavMargin/NavContent/MissionsButton
@onready var market_button: Button = $PanelContainer/MainVBox/BottomNavBar/NavMargin/NavContent/MarketButton

@onready var combat_panel: PanelContainer = $CombatIntermission
@onready var combat_enemy_label: Label = $CombatIntermission/MarginContainer/VBoxContainer/EnemyInfoLabel
@onready var encounter_flee_button: Button = $CombatIntermission/MarginContainer/VBoxContainer/ButtonContainer/FleeButton
@onready var encounter_negotiate_button: Button = $CombatIntermission/MarginContainer/VBoxContainer/ButtonContainer/NegotiateButton
@onready var encounter_fight_button: Button = $CombatIntermission/MarginContainer/VBoxContainer/ButtonContainer/FightButton
@onready var combat_timer_bar: ProgressBar = $CombatIntermission/MarginContainer/VBoxContainer/TimerBar
@onready var combat_info_label: Label = $CombatIntermission/MarginContainer/VBoxContainer/InfoLabel

@onready var combat_overlay: CanvasLayer = $CombatOverlay
@onready var battle_viewport: SubViewport = $CombatOverlay/BattleViewportContainer/BattleViewport
@onready var battle_close_button: Button = $CombatOverlay/CloseButton
#endregion

#region Components
@onready var presenter: StrategyPresenter = $StrategyPresenter
@onready var vn_view: VnView = $PanelContainer/MainVBox/MainScreenArea/VnView
@onready var stage_view: StageView = $PanelContainer/Foreground/StageView
@onready var stat_animator: StatChangeAnimator = $PanelContainer
@onready var actor: ActivityRunner = $ActivityExecuteManager
@onready var ai_fleet: AIFleetManager = $AIFleetManager
var notification_bar: NotificationBar
#endregion

#region Lifecycle

func _init() -> void:
	print(" --- main gui init --- ")


func _ready() -> void:
	print(" --- Main gui is ready --- ")
	_setup_notification_bar()
	_connect_signals()
	_register_button_animations()
	presenter.bind_view(self)

#endregion

#region Button Animations

func _register_button_animations() -> void:
	var action_btns: Array[Button] = [
		rest_button, drill_button, patrol_button, investigate_button,
		hold_mass_button, travel_button, attack_button, manage_squad_button,
		recruit_button, shop_button
	]
	for btn in action_btns:
		UIAnimations.register_button(btn)
	if continue_travel_button:
		UIAnimations.register_button(continue_travel_button)

	var nav_btns: Array[Button] = [skip_button, short_button, scout_button, missions_button, market_button]
	for btn in nav_btns:
		UIAnimations.register_button(btn)

	if encounter_flee_button:
		UIAnimations.register_button(encounter_flee_button)
	if encounter_negotiate_button:
		UIAnimations.register_button(encounter_negotiate_button)
	if encounter_fight_button:
		UIAnimations.register_button(encounter_fight_button)

#endregion

#region Signal Wiring

func _connect_signals() -> void:
	rest_button.pressed.connect(func(): presenter.on_activity_requested(StrategyTypes.ActivityType.REST))
	drill_button.pressed.connect(func(): presenter.on_activity_requested(StrategyTypes.ActivityType.DRILL))
	patrol_button.pressed.connect(func(): presenter.on_activity_requested(StrategyTypes.ActivityType.PATROL))
	investigate_button.pressed.connect(func(): presenter.on_investigate_requested())
	hold_mass_button.pressed.connect(func(): presenter.on_activity_requested(StrategyTypes.ActivityType.HOLD_MASS))
	travel_button.pressed.connect(func(): presenter.on_travel_requested())
	attack_button.pressed.connect(func(): presenter.on_activity_requested(StrategyTypes.ActivityType.ATTACK))
	manage_squad_button.pressed.connect(func(): presenter.on_manage_squad_requested())
	recruit_button.pressed.connect(func(): presenter.on_recruit_requested())
	shop_button.pressed.connect(func(): presenter.on_shop_requested())

	if continue_travel_button:
		continue_travel_button.pressed.connect(func():
			_play_sfx("play_ui_confirm")
			presenter.on_continue_travel()
		)
		continue_travel_button.visible = false

	skip_button.pressed.connect(func(): presenter.on_skip_pressed())
	short_button.pressed.connect(func(): presenter.on_summary_pressed())
	scout_button.pressed.connect(func(): presenter.on_scouting_requested())
	missions_button.pressed.connect(func(): presenter.on_missions_requested())
	market_button.pressed.connect(func(): presenter.on_market_requested())

	if scouting_view:
		scouting_view.closed.connect(func(): presenter.on_scouting_closed())

	if encounter_flee_button:
		encounter_flee_button.pressed.connect(func():
			_play_sfx("play_ui_cancel")
			presenter.on_combat_choice(CombatController.IntermissionChoice.FLEE)
		)
	if encounter_negotiate_button:
		encounter_negotiate_button.pressed.connect(func():
			_play_sfx("play_ui_confirm")
			presenter.on_combat_choice(CombatController.IntermissionChoice.NEGOTIATE)
		)
	if encounter_fight_button:
		encounter_fight_button.pressed.connect(func():
			_play_sfx("play_ui_confirm")
			presenter.on_combat_choice(CombatController.IntermissionChoice.FIGHT)
		)

	if travel_view:
		travel_view.travel_confirmed.connect(func(id):
			_play_sfx("play_ui_confirm")
			presenter.on_travel_confirmed(id)
		)
		travel_view.travel_cancelled.connect(func():
			_play_sfx("play_ui_cancel")
			presenter.on_travel_cancelled()
		)

	if investigation_view:
		investigation_view.investigation_closed.connect(func(): presenter.on_investigation_closed())

	if recruitment_view:
		recruitment_view.recruitment_completed.connect(func(warrior): presenter.on_recruitment_completed(warrior))
		recruitment_view.closed.connect(func(): presenter.on_recruitment_closed())

	if manage_squad_page:
		manage_squad_page.presenter.closed.connect(func(): presenter.on_manage_squad_closed())
		manage_squad_page.presenter.recruitment_completed.connect(func(warrior): presenter.on_recruitment_completed(warrior))

	if missions_view:
		missions_view.presenter.missions_closed.connect(func(): presenter.on_missions_closed())

	if market_view:
		market_view.closed.connect(func(): presenter.on_market_closed())

	if shop_view:
		shop_view.presenter.purchase_completed.connect(func(purchases): presenter.on_purchase_completed(purchases))
		shop_view.presenter.shop_closed.connect(func(): presenter.on_shop_closed())

	if battle_close_button:
		battle_close_button.pressed.connect(func():
			_play_sfx("play_ui_cancel")
			presenter.on_retreat_requested()
		)

#endregion

#region Display Updates

func update_turn(turn: int) -> void:
	turn_label.text = "Turn %d" % turn


func update_location(text: String) -> void:
	location_label.text = text


func update_morale_bar(value: float) -> void:
	morale_label.value = value


func update_condition(text: String) -> void:
	condition_label.text = text


func update_stats(money: float, food: int, karma: float, stability: float, development: int) -> void:
	stat_animator.stability_label.text = "%.0f" % stability
	stat_animator.development_label.text = "%d" % development
	stat_animator.money_label.text = "%.0f" % money
	stat_animator.food_label.text = "%d" % food
	stat_animator.karma_label.text = "%.0f" % karma


func update_activity_button(button: Button, text: String, disabled: bool, tooltip: String) -> void:
	# button.text = text
	button.disabled = disabled
	button.tooltip_text = tooltip


func disable_all_activity_buttons() -> void:
	rest_button.disabled = true
	drill_button.disabled = true
	patrol_button.disabled = true
	investigate_button.disabled = true
	hold_mass_button.disabled = true
	travel_button.disabled = true
	attack_button.disabled = true
	manage_squad_button.disabled = true
	shop_button.disabled = true
	if continue_travel_button:
		continue_travel_button.visible = false

#endregion

#region UI Mode Transitions

func show_strategy_ui() -> void:
	action_buttons.visible = true
	var btns: Array[Button] = [
		rest_button, drill_button, patrol_button, investigate_button,
		hold_mass_button, travel_button, attack_button, manage_squad_button,
		recruit_button, shop_button
	]
	UIAnimations.stagger_buttons(btns)


func show_combat_ui() -> void:
	action_buttons.visible = false
	await UIAnimations.slide_in_panel(combat_panel)


func hide_combat_panel() -> void:
	if combat_panel.visible:
		await UIAnimations.slide_out_panel(combat_panel)
	else:
		combat_panel.visible = false


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
	combat_enemy_label.text = "Encountered: %s (%d warriors)" % [enemy_name, enemy_count]

	encounter_flee_button.text = "Flee (%.0f%% chance)" % flee_chance
	encounter_flee_button.disabled = not options.get("can_flee", true)
	encounter_flee_button.tooltip_text = "Attempt to escape. Uses SURVIVAL stat.\nSuccess: Escape with morale penalty\nFailure: Forced into combat"

	encounter_negotiate_button.text = "Negotiate (%.0f%% chance)" % negotiate_chance
	encounter_negotiate_button.disabled = not options.get("can_negotiate", true)
	encounter_negotiate_button.tooltip_text = "Attempt peaceful resolution. Uses DIPLOMACY stat.\nSuccess: Avoid combat entirely\nFailure: Forced into combat"

	encounter_fight_button.text = "Fight!"
	encounter_fight_button.disabled = not options.get("can_fight", true)
	encounter_fight_button.tooltip_text = "Engage in tactical combat.\nVictory brings loot and clues.\nDefeat brings casualties."


func update_combat_timer(value: float, max_value: float) -> void:
	combat_timer_bar.max_value = max_value
	combat_timer_bar.value = value
	if value < 5.0:
		combat_timer_bar.modulate = Color.RED
	elif value < 10.0:
		combat_timer_bar.modulate = Color.YELLOW
	else:
		combat_timer_bar.modulate = Color.WHITE


func disable_combat_buttons() -> void:
	if encounter_flee_button:
		encounter_flee_button.disabled = true
	if encounter_negotiate_button:
		encounter_negotiate_button.disabled = true
	if encounter_fight_button:
		encounter_fight_button.disabled = true


func set_combat_info_text(text: String) -> void:
	combat_info_label.text = text


func show_combat_result_overlay(result: CombatController.CombatResult, morale_before: float, morale_after: float) -> void:
	if result.victory:
		_play_sfx("play_player_victory")
	elif result.fled or result.negotiated:
		_play_sfx("play_ui_confirm")
	else:
		_play_sfx("play_player_defeat")

	# Displays the post-combat result overlay on top of the 3D battle scene:
	# 1. Creates overlay with result label (VICTORY/DEFEAT/FLED/NEGOTIATED)
	# 2. Moves morale bar into overlay and animates it from before to after value
	# 3. Spawns floating morale delta label (+15 or -20) that fades out
	# 4. After delay, restores morale bar to original parent and cleans up battle scene
	# e.g., result=VICTORY, morale 60→75 → shows green "VICTORY!" + morale bar tween + "+15.0 Morale" float
	combat_panel.visible = false
	combat_overlay.visible = true

	var original_parent = morale_panel.get_parent()
	var original_index = morale_panel.get_index()

	var overlay_container = Control.new()
	overlay_container.name = "BattleSummaryOverlay"
	overlay_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_overlay.add_child(overlay_container)

	var result_label = _create_result_label(result)
	overlay_container.add_child(result_label)

	original_parent.remove_child(morale_panel)
	overlay_container.add_child(morale_panel)

	morale_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	morale_panel.anchor_left = 0.1
	morale_panel.anchor_right = 0.9
	morale_panel.anchor_top = 0.02
	morale_panel.anchor_bottom = 0.08
	morale_panel.offset_left = 0
	morale_panel.offset_right = 0
	morale_panel.offset_top = 0
	morale_panel.offset_bottom = 0
	morale_panel.visible = true
	morale_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)

	morale_label.value = morale_before
	morale_label.visible = true

	await get_tree().create_timer(0.5).timeout

	var tween = create_tween()
	tween.tween_property(morale_label, "value", morale_after, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished

	if abs(result.morale_change) >= 0.1:
		_spawn_morale_delta_label_on_overlay(result.morale_change, overlay_container)

	if not result.equipment_loot.is_empty():
		_spawn_equipment_loot_display(result.equipment_loot, overlay_container)

	await get_tree().create_timer(1.2).timeout

	overlay_container.remove_child(morale_panel)
	original_parent.add_child(morale_panel)
	original_parent.move_child(morale_panel, original_index)

	morale_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	morale_panel.anchor_left = 0
	morale_panel.anchor_right = 1
	morale_panel.anchor_top = 0
	morale_panel.anchor_bottom = 0
	morale_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	overlay_container.queue_free()

	_cleanup_battle_children()
	combat_overlay.visible = false


func cleanup_battle_scene() -> void:
	_cleanup_battle_children()
	combat_overlay.visible = false


func _cleanup_battle_children() -> void:
	for child in battle_viewport.get_children():
		child.queue_free()
	for child in combat_overlay.get_children():
		if child is SquadBattleView2D:
			child.queue_free()

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
	# Passes the ActivityRunner reference to child menu views that need game state access
	# Called once during _setup_components by the presenter
	# e.g., travel_view needs actor to get reachable locations, investigation_view needs clues, etc.
	travel_view.setup(a)
	investigation_view.setup(a)
	recruitment_view.setup(a)


func show_travel_menu(scenario: GameScenario, locations) -> void:
	travel_view.show_travel_menu(scenario, locations)


func hide_travel_menu() -> void:
	travel_view.hide_travel_menu()


func set_travel_mode_autopilot() -> void:
	travel_view.set_mode_autopilot()


func show_continue_travel_button(dest_name: String) -> void:
	if continue_travel_button:
		continue_travel_button.text = "▶ Continue to %s" % dest_name
		continue_travel_button.visible = true


func hide_continue_travel_button() -> void:
	if continue_travel_button:
		continue_travel_button.visible = false


func show_investigation_menu() -> void:
	investigation_view.show_investigation_menu()


func hide_investigation_menu() -> void:
	investigation_view.hide_investigation_menu()


func show_recruitment_menu() -> void:
	recruitment_view.show_recruitment_menu()


func hide_recruitment_menu() -> void:
	recruitment_view.hide_recruitment_menu()


func show_manage_squad(squad: SquadStrategicData, p_actor: ActivityRunner) -> void:
	manage_squad_page.presenter.open(squad, p_actor)


func show_shop(shop: Shop, squad: SquadStrategicData, location: Location = null) -> void:
	shop_view.presenter.open(shop, squad, location)


func hide_shop() -> void:
	shop_view.presenter._on_closed()


func show_scouting(world: World, player_squad: SquadStrategicData) -> void:
	scouting_view.show_scouting(world, player_squad)


func hide_scouting() -> void:
	scouting_view.hide_scouting()


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

#region Result Summary

func show_result_summary(stat_changes: Dictionary, recruits: Array[Warrior]) -> void:
	var overlay = ColorRect.new()
	overlay.name = "ResultSummaryOverlay"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.3
	panel.anchor_right = 0.7
	panel.anchor_top = 0.25
	panel.anchor_bottom = 0.75
	panel.offset_left = 0
	panel.offset_right = 0
	panel.offset_top = 0
	panel.offset_bottom = 0
	overlay.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title_label = Label.new()
	title_label.text = "Results"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title_label)

	var separator = HSeparator.new()
	vbox.add_child(separator)

	for stat_name in stat_changes:
		var value: float = stat_changes[stat_name]
		if abs(value) < 0.01:
			continue
		var line = Label.new()
		line.add_theme_font_size_override("font_size", 18)
		if value >= 0:
			line.text = "+%.0f %s" % [value, stat_name.capitalize()]
			line.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		else:
			line.text = "%.0f %s" % [value, stat_name.capitalize()]
			line.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		vbox.add_child(line)

	for recruit in recruits:
		var line = Label.new()
		line.text = "New warrior: %s" % recruit.name
		line.add_theme_font_size_override("font_size", 18)
		line.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
		vbox.add_child(line)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var continue_btn = Button.new()
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(150, 40)
	continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(continue_btn)

	overlay.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)

	await continue_btn.pressed
	overlay.queue_free()

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

func _setup_notification_bar() -> void:
	notification_bar = NotificationBar.new()
	notification_bar.name = "NotificationBar"
	notification_bar.custom_minimum_size = Vector2(0, 36)
	notification_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var main_vbox = $PanelContainer/MainVBox
	var status_area = $PanelContainer/MainVBox/StatusArea
	var status_idx := status_area.get_index()
	main_vbox.add_child(notification_bar)
	main_vbox.move_child(notification_bar, status_idx)


func show_notifications(notifications: Array[NotificationData]) -> void:
	notification_bar.show_notifications(notifications)


func clear_notifications() -> void:
	notification_bar.clear()

#endregion

#region Game Over

func show_game_over(title_text: String, description: String) -> void:
	disable_all_activity_buttons()
	action_buttons.visible = false

	var overlay = ColorRect.new()
	overlay.name = "GameOverOverlay"
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.anchor_left = 0.2
	vbox.anchor_right = 0.8
	vbox.anchor_top = 0.3
	vbox.anchor_bottom = 0.7
	vbox.offset_left = 0
	vbox.offset_right = 0
	vbox.offset_top = 0
	vbox.offset_bottom = 0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(vbox)

	var title_label = Label.new()
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	vbox.add_child(title_label)

	var desc_label = Label.new()
	desc_label.text = description
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 20)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(desc_label)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer)

	var restart_btn = Button.new()
	restart_btn.text = "Restart Campaign"
	restart_btn.custom_minimum_size = Vector2(200, 50)
	restart_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart_btn.pressed.connect(func(): get_tree().reload_current_scene())
	vbox.add_child(restart_btn)

	overlay.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)

#endregion

#region Display Helpers

func _create_result_label(result: CombatController.CombatResult) -> Label:
	var result_label = Label.new()
	result_label.name = "ResultLabel"
	result_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	result_label.anchor_top = 0.15
	result_label.anchor_bottom = 0.25
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 48)
	result_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	result_label.add_theme_constant_override("shadow_offset_x", 3)
	result_label.add_theme_constant_override("shadow_offset_y", 3)

	if result.victory:
		result_label.text = "VICTORY!"
		result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	elif result.fled:
		result_label.text = "Escaped!"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	elif result.negotiated:
		result_label.text = "Negotiated!"
		result_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	else:
		result_label.text = "DEFEAT!"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

	return result_label


func _play_sfx(method_name: String) -> void:
	var sfx = get_tree().root.get_node_or_null("SFX")
	if sfx and sfx.has_method(method_name):
		sfx.call(method_name)


func _spawn_morale_delta_label_on_overlay(delta_value: float, parent: Control) -> void:
	var delta_label = Label.new()
	parent.add_child(delta_label)

	delta_label.text = "%+.1f Morale" % delta_value
	delta_label.add_theme_font_size_override("font_size", 28)
	delta_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	delta_label.add_theme_constant_override("shadow_offset_x", 2)
	delta_label.add_theme_constant_override("shadow_offset_y", 2)

	if delta_value >= 0:
		delta_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		delta_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

	delta_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	delta_label.anchor_top = 0.10
	delta_label.anchor_bottom = 0.14
	delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var tween = create_tween().set_parallel(true)
	tween.tween_property(delta_label, "anchor_top", 0.16, 1.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(delta_label, "anchor_bottom", 0.20, 1.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(delta_label, "modulate:a", 0.0, 0.8).set_delay(0.4)


func _spawn_equipment_loot_display(equipment_loot: Dictionary, parent: Control) -> void:
	var weapons: Array = equipment_loot.get("weapons", [])
	var armors: Array = equipment_loot.get("armors", [])
	if weapons.is_empty() and armors.is_empty():
		return

	var loot_container := VBoxContainer.new()
	loot_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	loot_container.anchor_top = 0.65
	loot_container.anchor_bottom = 0.92
	loot_container.anchor_left = 0.3
	loot_container.anchor_right = 0.7
	loot_container.offset_top = 0
	loot_container.offset_bottom = 0
	loot_container.add_theme_constant_override("separation", 4)
	parent.add_child(loot_container)

	var header := Label.new()
	header.text = "Equipment Looted"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	header.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	header.add_theme_constant_override("shadow_offset_x", 2)
	header.add_theme_constant_override("shadow_offset_y", 2)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loot_container.add_child(header)

	for w in weapons:
		if w is WeaponConfig:
			var label := Label.new()
			label.text = "+ %s" % w.weapon_name
			label.add_theme_font_size_override("font_size", 16)
			label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
			label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
			label.add_theme_constant_override("shadow_offset_x", 1)
			label.add_theme_constant_override("shadow_offset_y", 1)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			loot_container.add_child(label)

	for a in armors:
		if a is ArmorConfig:
			var label := Label.new()
			label.text = "+ %s" % a.armor_name
			label.add_theme_font_size_override("font_size", 16)
			label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55))
			label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
			label.add_theme_constant_override("shadow_offset_x", 1)
			label.add_theme_constant_override("shadow_offset_y", 1)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			loot_container.add_child(label)

	loot_container.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(loot_container, "modulate:a", 1.0, 0.5)

#endregion
