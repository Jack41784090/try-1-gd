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
@onready var scouting_view: ScoutingView = $ScoutingView
@onready var missions_view: MissionsView = $MissionsView
@onready var market_view: MarketView = $MarketView

@onready var skip_button: Button = $PanelContainer/MainVBox/BottomNavBar/NavMargin/NavContent/SkipButton
@onready var short_button: Button = $PanelContainer/MainVBox/BottomNavBar/NavMargin/NavContent/ShortButton
@onready var scout_button: Button = $PanelContainer/MainVBox/BottomNavBar/NavMargin/NavContent/ScoutButton
@onready var missions_button: Button = $PanelContainer/MainVBox/BottomNavBar/NavMargin/NavContent/MissionsButton
@onready var market_button: Button = $PanelContainer/MainVBox/BottomNavBar/NavMargin/NavContent/MarketButton

@onready var combat_intermission_node: PanelContainer = $CombatIntermission
@onready var combat_overlay_node: CanvasLayer = $CombatOverlay
var combat_ui: CombatUI
var _contact_bars_panel: PanelContainer
var _contact_bars_container: VBoxContainer
var _contact_rows: Dictionary = {}

var battle_viewport: SubViewport:
	get: return combat_ui.viewport if combat_ui else null
var combat_overlay: CanvasLayer:
	get: return combat_ui.overlay if combat_ui else null
#endregion

#region Components
@onready var presenter: StrategyPresenter = $StrategyPresenter
@onready var vn_view: VnView = $PanelContainer/MainVBox/MainScreenArea/VnView
@onready var stage_view: StageView = $PanelContainer/Foreground/StageView
@onready var stat_animator: StatChangeAnimator = $PanelContainer
@onready var actor: ActivityRunner = $ActivityExecuteManager
@onready var ai_fleet: AIFleetManager = $AIFleetManager
var notification_bar: NotificationBar
var _travel_arrow_bar: PanelContainer
var _go_back_btn: Button
var _continue_btn: Button
var _travel_arrow_label: Label
#endregion

#region Lifecycle

func _init() -> void:
	print(" --- main gui init --- ")


func _ready() -> void:
	print(" --- Main gui is ready --- ")
	combat_ui = CombatUI.create(self, combat_intermission_node, combat_overlay_node, morale_panel, morale_label)
	_setup_notification_bar()
	_setup_contact_bars()
	_setup_travel_arrows()
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

	var nav_btns: Array[Button] = [skip_button, short_button, scout_button, missions_button, market_button]
	for btn in nav_btns:
		UIAnimations.register_button(btn)

	combat_ui.register_button_animations()

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

	skip_button.pressed.connect(func(): presenter.on_skip_pressed())
	short_button.pressed.connect(func(): presenter.on_summary_pressed())
	scout_button.pressed.connect(func(): presenter.on_scouting_requested())
	missions_button.pressed.connect(func(): presenter.on_missions_requested())
	market_button.pressed.connect(func(): presenter.on_market_requested())

	if scouting_view:
		scouting_view.closed.connect(func(): presenter.on_scouting_closed())

	combat_ui.connect_signals(presenter)

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


func update_contact_bars(contacts_data: Array[Dictionary]) -> void:
	var new_ids: Dictionary = {}
	for data in contacts_data:
		new_ids[data["target_id"]] = data

	var removed: Array[String] = []
	for tid in _contact_rows:
		if not new_ids.has(tid):
			removed.append(tid)
	for tid in removed:
		_animate_contact_remove(tid)

	for data in contacts_data:
		var tid: String = data["target_id"]
		if _contact_rows.has(tid):
			_update_existing_contact_row(tid, data)
		else:
			_create_contact_mini_bar(data)
			_animate_contact_appear(tid)

	_contact_bars_panel.visible = not _contact_rows.is_empty()


func update_stats(money: float, food: int, karma: float, stability: float, development: int) -> void:
	stat_animator.stability_label.text = "%.0f" % stability
	stat_animator.development_label.text = "%d" % development
	stat_animator.money_label.text = "%.0f" % money
	stat_animator.food_label.text = "%d" % food
	stat_animator.karma_label.text = "%.0f" % karma


func update_activity_button(key: String, text: String, disabled: bool, tooltip: String) -> void:
	var button: Button = _get_activity_button(key)
	if button:
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
	hide_travel_arrows()


func _get_activity_button(key: String) -> Button:
	match key:
		"rest": return rest_button
		"drill": return drill_button
		"patrol": return patrol_button
		"investigate": return investigate_button
		"hold_mass": return hold_mass_button
		"travel": return travel_button
		"attack": return attack_button
		"manage_squad": return manage_squad_button
		"shop": return shop_button
		"market": return market_button
	return null

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


func show_travel_arrows(dest_name: String, from_name: String) -> void:
	if not _travel_arrow_bar:
		return
	_travel_arrow_label.text = dest_name
	_go_back_btn.text = "← %s" % from_name
	_continue_btn.text = "%s →" % dest_name
	if not _travel_arrow_bar.visible:
		_travel_arrow_bar.visible = true
		_travel_arrow_bar.modulate = Color(1, 1, 1, 0)
		_travel_arrow_bar.position.y = 30
		var tw = create_tween().set_parallel(true)
		tw.tween_property(_travel_arrow_bar, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(_travel_arrow_bar, "position:y", 0.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func show_continue_travel_button(dest_name: String) -> void:
	show_travel_arrows(dest_name, "")


func hide_travel_arrows() -> void:
	if not _travel_arrow_bar or not _travel_arrow_bar.visible:
		return
	var tw = create_tween().set_parallel(true)
	tw.tween_property(_travel_arrow_bar, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_travel_arrow_bar, "position:y", 30.0, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.chain().tween_callback(func():
		_travel_arrow_bar.visible = false
		_travel_arrow_bar.position.y = 0.0
	)


func hide_continue_travel_button() -> void:
	hide_travel_arrows()


func show_investigation_menu() -> void:
	investigation_view.show_investigation_menu()


func hide_investigation_menu() -> void:
	investigation_view.hide_investigation_menu()


func show_recruitment_menu() -> void:
	recruitment_view.show_recruitment_menu()


func hide_recruitment_menu() -> void:
	recruitment_view.hide_recruitment_menu()


func show_manage_squad(squad: SquadData, p_actor: ActivityRunner) -> void:
	manage_squad_page.presenter.open(squad, p_actor)


func show_shop(shop: Shop, squad: SquadData, location: Location = null) -> void:
	shop_view.presenter.open(shop, squad, location)


func hide_shop() -> void:
	shop_view.presenter._on_closed()


func show_scouting(world: World, player_squad: SquadData, ai_decisions: Dictionary = {}) -> void:
	scouting_view.show_scouting(world, player_squad, ai_decisions)


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


func _setup_travel_arrows() -> void:
	var main_vbox = $PanelContainer/MainVBox
	var action_idx := action_buttons.get_index()

	_travel_arrow_bar = PanelContainer.new()
	_travel_arrow_bar.name = "TravelArrowBar"
	_travel_arrow_bar.visible = false
	_travel_arrow_bar.custom_minimum_size = Vector2(0, 56)
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	bar_style.border_width_top = 1
	bar_style.border_width_bottom = 1
	bar_style.border_color = Color(0.35, 0.55, 0.4, 0.6)
	bar_style.content_margin_left = 20
	bar_style.content_margin_right = 20
	bar_style.content_margin_top = 6
	bar_style.content_margin_bottom = 6
	_travel_arrow_bar.add_theme_stylebox_override("panel", bar_style)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	_travel_arrow_bar.add_child(hbox)

	_go_back_btn = Button.new()
	_go_back_btn.name = "GoBackBtn"
	_go_back_btn.text = "← Go Back"
	_go_back_btn.custom_minimum_size = Vector2(160, 40)
	_go_back_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var back_normal = StyleBoxFlat.new()
	back_normal.bg_color = Color(0.25, 0.18, 0.12, 0.9)
	back_normal.corner_radius_top_left = 6
	back_normal.corner_radius_top_right = 6
	back_normal.corner_radius_bottom_right = 6
	back_normal.corner_radius_bottom_left = 6
	back_normal.border_width_left = 1
	back_normal.border_width_top = 1
	back_normal.border_width_right = 1
	back_normal.border_width_bottom = 1
	back_normal.border_color = Color(0.6, 0.45, 0.3, 0.5)
	_go_back_btn.add_theme_stylebox_override("normal", back_normal)
	var back_hover = back_normal.duplicate()
	back_hover.bg_color = Color(0.35, 0.25, 0.18, 0.95)
	back_hover.border_color = Color(0.8, 0.6, 0.4, 0.7)
	_go_back_btn.add_theme_stylebox_override("hover", back_hover)
	var back_pressed = back_normal.duplicate()
	back_pressed.bg_color = Color(0.18, 0.12, 0.08, 0.9)
	_go_back_btn.add_theme_stylebox_override("pressed", back_pressed)
	_go_back_btn.add_theme_color_override("font_color", Color(0.9, 0.75, 0.55))
	_go_back_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.7))
	_go_back_btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.55, 0.4))
	_go_back_btn.add_theme_font_size_override("font_size", 16)
	hbox.add_child(_go_back_btn)

	_travel_arrow_label = Label.new()
	_travel_arrow_label.name = "TravelLabel"
	_travel_arrow_label.text = ""
	_travel_arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_travel_arrow_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_travel_arrow_label.add_theme_font_size_override("font_size", 15)
	_travel_arrow_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 0.8))
	hbox.add_child(_travel_arrow_label)

	_continue_btn = Button.new()
	_continue_btn.name = "ContinueBtn"
	_continue_btn.text = "Continue →"
	_continue_btn.custom_minimum_size = Vector2(160, 40)
	_continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	var cont_normal = StyleBoxFlat.new()
	cont_normal.bg_color = Color(0.12, 0.22, 0.15, 0.9)
	cont_normal.corner_radius_top_left = 6
	cont_normal.corner_radius_top_right = 6
	cont_normal.corner_radius_bottom_right = 6
	cont_normal.corner_radius_bottom_left = 6
	cont_normal.border_width_left = 1
	cont_normal.border_width_top = 1
	cont_normal.border_width_right = 1
	cont_normal.border_width_bottom = 1
	cont_normal.border_color = Color(0.3, 0.6, 0.4, 0.5)
	_continue_btn.add_theme_stylebox_override("normal", cont_normal)
	var cont_hover = cont_normal.duplicate()
	cont_hover.bg_color = Color(0.18, 0.32, 0.22, 0.95)
	cont_hover.border_color = Color(0.4, 0.85, 0.5, 0.7)
	_continue_btn.add_theme_stylebox_override("hover", cont_hover)
	var cont_pressed = cont_normal.duplicate()
	cont_pressed.bg_color = Color(0.08, 0.15, 0.1, 0.9)
	_continue_btn.add_theme_stylebox_override("pressed", cont_pressed)
	_continue_btn.add_theme_color_override("font_color", Color(0.5, 0.9, 0.6))
	_continue_btn.add_theme_color_override("font_hover_color", Color(0.6, 1.0, 0.7))
	_continue_btn.add_theme_color_override("font_pressed_color", Color(0.4, 0.7, 0.5))
	_continue_btn.add_theme_font_size_override("font_size", 16)
	hbox.add_child(_continue_btn)

	UIAnimations.register_button(_go_back_btn)
	UIAnimations.register_button(_continue_btn)

	_go_back_btn.pressed.connect(func():
		_play_sfx("play_ui_cancel")
		presenter.on_go_back_travel()
	)
	_continue_btn.pressed.connect(func():
		_play_sfx("play_ui_confirm")
		presenter.on_continue_travel()
	)

	main_vbox.add_child(_travel_arrow_bar)
	main_vbox.move_child(_travel_arrow_bar, action_idx + 1)


func _setup_contact_bars() -> void:
	var screen_area = $PanelContainer/MainVBox/MainScreenArea

	_contact_bars_panel = PanelContainer.new()
	_contact_bars_panel.name = "ContactBarsPanel"
	_contact_bars_panel.visible = false
	_contact_bars_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contact_bars_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_contact_bars_panel.anchor_right = 0.5
	_contact_bars_panel.anchor_bottom = 1.0
	_contact_bars_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	panel_style.border_width_left = 0
	panel_style.border_width_top = 0
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.6, 0.5, 0.3, 0.6)
	panel_style.corner_radius_bottom_right = 8
	panel_style.shadow_color = Color(0, 0, 0, 0.4)
	panel_style.shadow_size = 3
	panel_style.shadow_offset = Vector2(1, 1)
	_contact_bars_panel.add_theme_stylebox_override("panel", panel_style)
	screen_area.add_child(_contact_bars_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	_contact_bars_panel.add_child(margin)

	_contact_bars_container = VBoxContainer.new()
	_contact_bars_container.name = "ContactBars"
	_contact_bars_container.add_theme_constant_override("separation", 4)
	margin.add_child(_contact_bars_container)



func _create_contact_mini_bar(data: Dictionary) -> void:
	var state: StrategyTypes.ContactState = data["state"]
	var progress: float = data["progress"]
	var delta: float = data.get("progress_delta", 0.0)
	var title: String = data.get("title", "Unknown")
	var target_id: String = data.get("target_id", "")

	var state_color := _get_contact_state_color(state)

	var row = HBoxContainer.new()
	row.name = "Contact_" + target_id
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(0, 22)
	row.clip_contents = true
	_contact_bars_container.add_child(row)

	var symbol = Label.new()
	symbol.name = "Symbol"
	symbol.add_theme_font_size_override("font_size", 11)
	symbol.custom_minimum_size = Vector2(14, 0)
	if not is_zero_approx(delta):
		if delta > 0.0:
			symbol.text = "▲"
			symbol.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			symbol.text = "▼"
			symbol.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	else:
		symbol.text = "●"
		symbol.add_theme_color_override("font_color", state_color * Color(1, 1, 1, 0.5))
	row.add_child(symbol)

	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = title
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", state_color)
	name_label.custom_minimum_size = Vector2(90, 0)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)

	var bar_bg = PanelContainer.new()
	bar_bg.name = "BarBg"
	bar_bg.custom_minimum_size = Vector2(100, 8)
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.12, 0.12, 0.16)
	bar_style.corner_radius_top_left = 3
	bar_style.corner_radius_top_right = 3
	bar_style.corner_radius_bottom_right = 3
	bar_style.corner_radius_bottom_left = 3
	bar_style.border_width_left = 1
	bar_style.border_width_top = 1
	bar_style.border_width_right = 1
	bar_style.border_width_bottom = 1
	bar_style.border_color = Color(0.25, 0.25, 0.3)
	bar_bg.add_theme_stylebox_override("panel", bar_style)
	row.add_child(bar_bg)

	var bar_fill = ColorRect.new()
	bar_fill.name = "Fill"
	var fill_fraction := clampf(progress / 100.0, 0.0, 1.0)
	bar_fill.color = state_color * Color(1, 1, 1, 0.8)
	bar_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	bar_fill.anchor_right = fill_fraction
	bar_bg.add_child(bar_fill)

	if not is_zero_approx(delta):
		var prev_progress := clampf(progress - delta, 0.0, 100.0)
		var prev_fraction := clampf(prev_progress / 100.0, 0.0, 1.0)
		var delta_mark = ColorRect.new()
		delta_mark.name = "DeltaMark"
		if delta > 0.0:
			delta_mark.color = Color(0.4, 1.0, 0.4, 0.35)
			delta_mark.set_anchors_preset(Control.PRESET_LEFT_WIDE)
			delta_mark.anchor_left = prev_fraction
			delta_mark.anchor_right = fill_fraction
		else:
			delta_mark.color = Color(1.0, 0.4, 0.4, 0.35)
			delta_mark.set_anchors_preset(Control.PRESET_LEFT_WIDE)
			delta_mark.anchor_left = fill_fraction
			delta_mark.anchor_right = prev_fraction
		bar_bg.add_child(delta_mark)

	var pct_label = Label.new()
	pct_label.name = "PctLabel"
	pct_label.text = "%.0f%%" % progress
	pct_label.add_theme_font_size_override("font_size", 11)
	pct_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	row.add_child(pct_label)

	if not is_zero_approx(delta):
		var delta_label = Label.new()
		delta_label.name = "DeltaLabel"
		delta_label.add_theme_font_size_override("font_size", 10)
		if delta > 0.0:
			delta_label.text = "+%.1f" % delta
			delta_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			delta_label.text = "%.1f" % delta
			delta_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		row.add_child(delta_label)

	_contact_rows[target_id] = row


func _update_existing_contact_row(target_id: String, data: Dictionary) -> void:
	var row: HBoxContainer = _contact_rows[target_id]
	var state: StrategyTypes.ContactState = data["state"]
	var progress: float = data["progress"]
	var delta: float = data.get("progress_delta", 0.0)
	var title: String = data.get("title", "Unknown")
	var state_color := _get_contact_state_color(state)

	var symbol: Label = row.get_node("Symbol")
	if not is_zero_approx(delta):
		if delta > 0.0:
			symbol.text = "▲"
			symbol.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			symbol.text = "▼"
			symbol.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	else:
		symbol.text = "●"
		symbol.add_theme_color_override("font_color", state_color * Color(1, 1, 1, 0.5))

	var name_label: Label = row.get_node("NameLabel")
	name_label.text = title
	name_label.add_theme_color_override("font_color", state_color)

	var bar_bg: PanelContainer = row.get_node("BarBg")
	var bar_fill: ColorRect = bar_bg.get_node("Fill")
	var new_fraction := clampf(progress / 100.0, 0.0, 1.0)
	var old_fraction := bar_fill.anchor_right

	bar_fill.color = state_color * Color(1, 1, 1, 0.8)
	var tween = create_tween()
	tween.tween_property(bar_fill, "anchor_right", new_fraction, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	var old_delta_mark = bar_bg.get_node_or_null("DeltaMark")
	if old_delta_mark:
		old_delta_mark.queue_free()
	if not is_zero_approx(delta):
		var delta_mark = ColorRect.new()
		delta_mark.name = "DeltaMark"
		if delta > 0.0:
			delta_mark.color = Color(0.4, 1.0, 0.4, 0.35)
			delta_mark.set_anchors_preset(Control.PRESET_LEFT_WIDE)
			delta_mark.anchor_left = old_fraction
			delta_mark.anchor_right = new_fraction
		else:
			delta_mark.color = Color(1.0, 0.4, 0.4, 0.35)
			delta_mark.set_anchors_preset(Control.PRESET_LEFT_WIDE)
			delta_mark.anchor_left = new_fraction
			delta_mark.anchor_right = old_fraction
		bar_bg.add_child(delta_mark)
		tween.parallel().tween_property(delta_mark, "modulate:a", 0.0, 1.5).set_delay(0.5)

	var pct_label: Label = row.get_node("PctLabel")
	pct_label.text = "%.0f%%" % progress

	var old_delta_label = row.get_node_or_null("DeltaLabel")
	if old_delta_label:
		old_delta_label.queue_free()
	if not is_zero_approx(delta):
		var delta_label = Label.new()
		delta_label.name = "DeltaLabel"
		delta_label.add_theme_font_size_override("font_size", 10)
		if delta > 0.0:
			delta_label.text = "+%.1f" % delta
			delta_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			delta_label.text = "%.1f" % delta
			delta_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		row.add_child(delta_label)


func _animate_contact_appear(target_id: String) -> void:
	var row: HBoxContainer = _contact_rows.get(target_id)
	if not row:
		return
	row.modulate.a = 0.0
	row.position.y = 30.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(row, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(row, "position:y", 0.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _animate_contact_remove(target_id: String) -> void:
	var row: HBoxContainer = _contact_rows.get(target_id)
	if not row:
		_contact_rows.erase(target_id)
		return
	_contact_rows.erase(target_id)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(row, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(row, "position:y", 40.0, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_callback(row.queue_free)


func _get_contact_state_color(state: StrategyTypes.ContactState) -> Color:
	match state:
		StrategyTypes.ContactState.SUSPECTED:
			return Color(0.6, 0.6, 0.6)
		StrategyTypes.ContactState.TRACKED:
			return Color(1.0, 0.9, 0.4)
		StrategyTypes.ContactState.LOCKED:
			return Color(0.4, 1.0, 0.4)
		_:
			return Color(0.5, 0.5, 0.5)


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

func _play_sfx(method_name: String) -> void:
	var sfx = get_tree().root.get_node_or_null("SFX")
	if sfx and sfx.has_method(method_name):
		sfx.call(method_name)

#endregion
