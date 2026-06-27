class_name RecruitmentTab
extends Control

signal recruit_requested(background: WarriorBackground)

const CARD_SCENE = preload("res://scenes/ui/manage_squad/recruitment_card.tscn")

@onready var _money_label: Label = $ScrollContainer/VBox/MoneyLabel
@onready var _classes_container: VBoxContainer = $ScrollContainer/VBox/ClassesContainer

var _squad: StrategySquad


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)


func setup(squad: StrategySquad, _actor: ActivityRunner) -> void:
	_squad = squad


func _pull() -> void:
	_money_label.text = "Available Gold: %.0f" % _squad.money
	for child in _classes_container.get_children():
		child.queue_free()
	for bg in WarriorBackgroundFactory.all():
		_classes_container.add_child(_create_class_card(bg))


func _connect_signals() -> void:
	if not _squad.money_changed.is_connected(_pull):
		_squad.money_changed.connect(_pull)
	if not _squad.warriors_changed.is_connected(_pull):
		_squad.warriors_changed.connect(_pull)


func _disconnect_signals() -> void:
	if _squad and _squad.money_changed.is_connected(_pull):
		_squad.money_changed.disconnect(_pull)
	if _squad and _squad.warriors_changed.is_connected(_pull):
		_squad.warriors_changed.disconnect(_pull)


func _on_visibility_changed() -> void:
	if _squad == null:
		return
	if visible:
		_connect_signals()
		_pull()
	else:
		_disconnect_signals()


func _create_class_card(background: WarriorBackground) -> PanelContainer:
	var cost: int = background.cost
	var can_afford := _squad.money >= cost

	var panel: PanelContainer = CARD_SCENE.instantiate()

	var icon_rect: TextureRect = panel.get_node("Margin/HBox/IconRect")
	if background.icon:
		icon_rect.texture = background.icon

	var name_label: Label = panel.get_node("Margin/HBox/InfoVBox/NameLabel")
	name_label.text = background.display_name

	var cost_label: Label = panel.get_node("Margin/HBox/InfoVBox/CostLabel")
	cost_label.text = "Cost: %d gold" % cost

	var stats_label: Label = panel.get_node("Margin/HBox/InfoVBox/StatsLabel")
	if not background.stats_template_path.is_empty():
		var stats := load(background.stats_template_path) as CombatEntityBaseStats
		if stats:
			stats_label.text = "STR:%.0f DEX:%.0f END:%.0f INT:%.0f" % [
				stats.strength,
				stats.dex,
				stats.endurance,
				stats.int_stat
			]

	var recruit_btn: Button = panel.get_node("Margin/HBox/RecruitButton")
	if can_afford:
		recruit_btn.text = "Recruit"
		recruit_btn.pressed.connect(func(): recruit_requested.emit(background))
	else:
		recruit_btn.text = "Can't Afford"
		recruit_btn.disabled = true
		recruit_btn.tooltip_text = "Need %.0f more gold" % (cost - _squad.money)

	UIAnimations.register_button(recruit_btn)
	return panel
