class_name StrategyView extends Control

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
@onready var travel_view: TravelView = $TravelView
@onready var investigation_view: InvestigationView = $InvestigationView
@onready var recruitment_view: RecruitmentView = $RecruitmentView
@onready var manage_squad_view: ManageSquadView = $ManageSquadView

@onready var skip_button: Button = $PanelContainer/MainVBox/BottomNavBar/NavMargin/NavContent/SkipButton
@onready var short_button: Button = $PanelContainer/MainVBox/BottomNavBar/NavMargin/NavContent/ShortButton

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
@onready var vn_view: VnView = $PanelContainer/MainVBox/MainScreenArea
@onready var stat_animator: StatChangeAnimator = $PanelContainer
@onready var actor: ActivityRunner = $ActivityExecuteManager
@onready var ai_fleet: AIFleetManager = $AIFleetManager
#endregion

#region Lifecycle

func _init() -> void:
	print(" --- main gui init --- ")

func _ready() -> void:
	print(" --- Main gui is ready --- ")
	_connect_signals()
	presenter.bind_view(self )

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

	skip_button.pressed.connect(func(): presenter.on_skip_pressed())
	short_button.pressed.connect(func(): presenter.on_summary_pressed())

	if encounter_flee_button:
		encounter_flee_button.pressed.connect(func(): presenter.on_combat_choice(CombatController.IntermissionChoice.FLEE))
	if encounter_negotiate_button:
		encounter_negotiate_button.pressed.connect(func(): presenter.on_combat_choice(CombatController.IntermissionChoice.NEGOTIATE))
	if encounter_fight_button:
		encounter_fight_button.pressed.connect(func(): presenter.on_combat_choice(CombatController.IntermissionChoice.FIGHT))

	if travel_view:
		travel_view.travel_confirmed.connect(func(id): presenter.on_travel_confirmed(id))
		travel_view.travel_cancelled.connect(func(): presenter.on_travel_cancelled())

	if investigation_view:
		investigation_view.investigation_closed.connect(func(): presenter.on_investigation_closed())

	if recruitment_view:
		recruitment_view.recruitment_completed.connect(func(warrior): presenter.on_recruitment_completed(warrior))
		recruitment_view.closed.connect(func(): presenter.on_recruitment_closed())

	if manage_squad_view:
		manage_squad_view.closed.connect(func(): presenter.on_manage_squad_closed())

	if battle_close_button:
		battle_close_button.pressed.connect(func(): presenter.on_battle_close())

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
	button.text = text
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

#endregion

#region UI Mode Transitions

func show_strategy_ui() -> void:
	action_buttons.visible = true

func show_combat_ui() -> void:
	action_buttons.visible = false
	combat_panel.visible = true

func hide_combat_panel() -> void:
	combat_panel.visible = false

func transition_to_strategy() -> void:
	await SceneManager.transition_quick(func():
		vn_view.exit()
		show_strategy_ui())

func transition_to_vn() -> void:
	await SceneManager.transition_quick(func():
		vn_view.enter())

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
	if encounter_flee_button: encounter_flee_button.disabled = true
	if encounter_negotiate_button: encounter_negotiate_button.disabled = true
	if encounter_fight_button: encounter_fight_button.disabled = true

func set_combat_info_text(text: String) -> void:
	combat_info_label.text = text

func show_combat_result_overlay(result: CombatController.CombatResult, morale_before: float, morale_after: float) -> void:
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

	for child in battle_viewport.get_children():
		child.queue_free()
	combat_overlay.visible = false

func cleanup_battle_scene() -> void:
	for child in battle_viewport.get_children():
		child.queue_free()
	combat_overlay.visible = false

#endregion

#region VN Delegation

func queue_vn_chain(path: String) -> void:
	vn_view.queue_event_chain(path)

func play_next_queued_chain() -> bool:
	return vn_view.play_next_queued_chain()

func get_chain_completed_signal() -> Signal:
	return vn_view.chain_completed

#endregion

#region Child GUI Delegation

func setup_child_guis(a: ActivityRunner) -> void:
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

func show_manage_squad(squad) -> void:
	manage_squad_view.call("show_squad", squad)

#endregion

#region Animation

func animate_stat_changes(deltas: Dictionary) -> void:
	await stat_animator.animate_changes(deltas)

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

#endregion
