class_name CombatUI
extends RefCounted

const SUMMARY_SCENE = preload("res://scenes/ui/battle_summary_overlay.tscn")

var _host: Control

var panel: PanelContainer
var _enemy_label: Label
var _flee_button: Button
var _negotiate_button: Button
var _fight_button: Button
var _timer_bar: ProgressBar
var _info_label: Label

var overlay: CanvasLayer
var viewport: SubViewport
var _close_button: Button

var _morale_panel: PanelContainer
var _morale_bar: ProgressBar


static func create(host: Control, intermission: PanelContainer, p_overlay: CanvasLayer, morale_panel: PanelContainer, morale_bar: ProgressBar) -> CombatUI:
	var ui := CombatUI.new()
	ui._host = host
	ui.panel = intermission
	ui._enemy_label = intermission.get_node("MarginContainer/VBoxContainer/EnemyInfoLabel")
	ui._flee_button = intermission.get_node("MarginContainer/VBoxContainer/ButtonContainer/FleeButton")
	ui._negotiate_button = intermission.get_node("MarginContainer/VBoxContainer/ButtonContainer/NegotiateButton")
	ui._fight_button = intermission.get_node("MarginContainer/VBoxContainer/ButtonContainer/FightButton")
	ui._timer_bar = intermission.get_node("MarginContainer/VBoxContainer/TimerBar")
	ui._info_label = intermission.get_node("MarginContainer/VBoxContainer/InfoLabel")
	ui.overlay = p_overlay
	ui.viewport = p_overlay.get_node("BattleViewportContainer/BattleViewport")
	ui._close_button = p_overlay.get_node("CloseButton")
	ui._morale_panel = morale_panel
	ui._morale_bar = morale_bar
	return ui


func register_button_animations() -> void:
	if _flee_button:
		UIAnimations.register_button(_flee_button)
	if _negotiate_button:
		UIAnimations.register_button(_negotiate_button)
	if _fight_button:
		UIAnimations.register_button(_fight_button)


func connect_signals(presenter) -> void:
	if _flee_button:
		_flee_button.pressed.connect(func():
			_play_sfx("play_ui_cancel")
			presenter.on_combat_choice(CombatController.IntermissionChoice.FLEE)
		)
	if _negotiate_button:
		_negotiate_button.pressed.connect(func():
			_play_sfx("play_ui_confirm")
			presenter.on_combat_choice(CombatController.IntermissionChoice.NEGOTIATE)
		)
	if _fight_button:
		_fight_button.pressed.connect(func():
			_play_sfx("play_ui_confirm")
			presenter.on_combat_choice(CombatController.IntermissionChoice.FIGHT)
		)


func show_ui() -> void:
	_host.get_node("PanelContainer/MainVBox/ActionButtons").visible = false
	await UIAnimations.slide_in_panel(panel)


func hide_panel() -> void:
	if panel.visible:
		await UIAnimations.slide_out_panel(panel)
	else:
		panel.visible = false


func update_intermission(enemy_name: String, enemy_count: int, flee_chance: float, negotiate_chance: float, options: Dictionary) -> void:
	_enemy_label.text = "Encountered: %s (%d warriors)" % [enemy_name, enemy_count]

	_flee_button.text = "Flee (%.0f%% chance)" % flee_chance
	_flee_button.disabled = not options.get("can_flee", true)
	_flee_button.tooltip_text = "Attempt to escape. Uses SURVIVAL stat.\nSuccess: Escape with morale penalty\nFailure: Forced into combat"

	_negotiate_button.text = "Negotiate (%.0f%% chance)" % negotiate_chance
	_negotiate_button.disabled = not options.get("can_negotiate", true)
	_negotiate_button.tooltip_text = "Attempt peaceful resolution. Uses DIPLOMACY stat.\nSuccess: Avoid combat entirely\nFailure: Forced into combat"

	_fight_button.text = "Fight!"
	_fight_button.disabled = not options.get("can_fight", true)
	_fight_button.tooltip_text = "Engage in tactical combat.\nVictory brings loot and clues.\nDefeat brings casualties."


func update_timer(value: float, max_value: float) -> void:
	_timer_bar.max_value = max_value
	_timer_bar.value = value
	if value < 5.0:
		_timer_bar.modulate = Color.RED
	elif value < 10.0:
		_timer_bar.modulate = Color.YELLOW
	else:
		_timer_bar.modulate = Color.WHITE


func disable_buttons() -> void:
	if _flee_button:
		_flee_button.disabled = true
	if _negotiate_button:
		_negotiate_button.disabled = true
	if _fight_button:
		_fight_button.disabled = true


func set_info_text(text: String) -> void:
	_info_label.text = text


func show_result_overlay(result: CombatController.CombatResult, morale_before: float, morale_after: float) -> void:
	if result.victory:
		_play_sfx("play_player_victory")
	elif result.fled or result.negotiated:
		_play_sfx("play_ui_confirm")
	else:
		_play_sfx("play_player_defeat")

	panel.visible = false
	overlay.visible = true

	var original_parent = _morale_panel.get_parent()
	var original_index = _morale_panel.get_index()

	var summary: BattleSummaryOverlay = SUMMARY_SCENE.instantiate()
	overlay.add_child(summary)
	summary.configure_result(result.victory, result.fled, result.negotiated)

	original_parent.remove_child(_morale_panel)
	summary.add_child(_morale_panel)

	_morale_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_morale_panel.anchor_left = 0.1
	_morale_panel.anchor_right = 0.9
	_morale_panel.anchor_top = 0.02
	_morale_panel.anchor_bottom = 0.08
	_morale_panel.offset_left = 0
	_morale_panel.offset_right = 0
	_morale_panel.offset_top = 0
	_morale_panel.offset_bottom = 0
	_morale_panel.visible = true
	_morale_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)

	_morale_bar.value = morale_before
	_morale_bar.visible = true

	await _host.get_tree().create_timer(0.5).timeout

	var tween = _host.create_tween()
	tween.tween_property(_morale_bar, "value", morale_after, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished

	if abs(result.morale_change) >= 0.1:
		summary.animate_morale_delta(result.morale_change)

	if not result.equipment_loot.is_empty():
		summary.show_equipment_loot(result.equipment_loot)

	await _host.get_tree().create_timer(1.2).timeout

	summary.remove_child(_morale_panel)
	original_parent.add_child(_morale_panel)
	original_parent.move_child(_morale_panel, original_index)

	_morale_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_morale_panel.anchor_left = 0
	_morale_panel.anchor_right = 1
	_morale_panel.anchor_top = 0
	_morale_panel.anchor_bottom = 0
	_morale_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	summary.queue_free()

	_cleanup_battle_children()
	overlay.visible = false


func cleanup_battle_scene() -> void:
	_cleanup_battle_children()
	overlay.visible = false


func _cleanup_battle_children() -> void:
	for child in viewport.get_children():
		child.queue_free()
	for child in overlay.get_children():
		if child is SquadBattleNode:
			child.queue_free()


func _play_sfx(method_name: String) -> void:
	var sfx = _host.get_tree().root.get_node_or_null("SFX")
	if sfx and sfx.has_method(method_name):
		sfx.call(method_name)
