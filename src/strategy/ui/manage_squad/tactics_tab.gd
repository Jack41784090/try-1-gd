class_name TacticsTab
extends Control

signal tactic_selected(tactic: Tactic)

const CARD_SCENE = preload("res://scenes/ui/manage_squad/tactic_card.tscn")

@onready var _cards_container: VBoxContainer = $ScrollContainer/CardsContainer

var _current_tactic_id: String = ""

const TACTIC_DEFS: Array[Dictionary] = [
	{
		"type": Tactic.TacticType.BALANCED,
		"name": "Balanced",
		"desc": "Standard formation. Equal actions and reactions.",
		"stats": "ATK: x1.0  DEF: x1.0  Actions: 1  Reactions: 1",
	},
	{
		"type": Tactic.TacticType.AGGRESSIVE_CHARGE,
		"name": "Aggressive Charge",
		"desc": "Push forward with extra attacks at the cost of defense.",
		"stats": "ATK: x1.0  DEF: x0.8  Actions: 2  Reactions: 1",
	},
	{
		"type": Tactic.TacticType.GUERILLA_DEFENCE,
		"name": "Guerilla Defence",
		"desc": "Reactive stance that favors counter-attacks.",
		"stats": "ATK: x0.8  DEF: x1.0  Actions: 1  Reactions: 2",
	},
	{
		"type": Tactic.TacticType.FULL_ASSAULT,
		"name": "Full Assault",
		"desc": "All-out attack. Maximum aggression, minimal protection.",
		"stats": "ATK: x1.2  DEF: x0.6  Actions: 3  Reactions: 0",
	},
	{
		"type": Tactic.TacticType.DEFENSIVE_FORMATION,
		"name": "Defensive Formation",
		"desc": "Hold the line. Maximum defense, no attacks.",
		"stats": "ATK: x0.6  DEF: x1.2  Actions: 0  Reactions: 3",
	},
]


func _ready() -> void:
	pass


func refresh(squad: SquadData) -> void:
	_current_tactic_id = squad.current_tactic.tactic_id if squad.current_tactic else "balanced"
	_rebuild_cards()


func _rebuild_cards() -> void:
	for child in _cards_container.get_children():
		child.queue_free()

	for def in TACTIC_DEFS:
		_cards_container.add_child(_create_card(def))


func _create_card(def: Dictionary) -> PanelContainer:
	var tactic := Tactic.create_from_type(def["type"] as Tactic.TacticType)
	var is_active := tactic.tactic_id == _current_tactic_id

	var panel: PanelContainer = CARD_SCENE.instantiate()

	if is_active:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.22, 0.15, 0.95)
		style.border_width_left = 3
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.8, 0.7, 0.3, 1.0)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		panel.add_theme_stylebox_override("panel", style)

	var name_label: Label = panel.get_node("Margin/HBox/InfoVBox/NameLabel")
	name_label.text = def["name"]
	if is_active:
		name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7, 1.0))

	var desc_label: Label = panel.get_node("Margin/HBox/InfoVBox/DescLabel")
	desc_label.text = def["desc"]

	var stats_label: Label = panel.get_node("Margin/HBox/InfoVBox/StatsLabel")
	stats_label.text = def["stats"]

	var active_label: Label = panel.get_node("Margin/HBox/ActiveLabel")
	var select_btn: Button = panel.get_node("Margin/HBox/SelectButton")

	if is_active:
		active_label.visible = true
		select_btn.visible = false
	else:
		active_label.visible = false
		select_btn.visible = true
		UIAnimations.register_button(select_btn)
		select_btn.pressed.connect(func(): tactic_selected.emit(tactic))

	return panel
