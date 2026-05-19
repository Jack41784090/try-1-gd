class_name RecruitmentTab
extends Control

signal recruit_requested(background: WarriorBackground)

const CARD_SCENE = preload("res://scenes/ui/manage_squad/recruitment_card.tscn")

@onready var _money_label: Label = $ScrollContainer/VBox/MoneyLabel
@onready var _classes_container: VBoxContainer = $ScrollContainer/VBox/ClassesContainer

var _current_squad: SquadData


func refresh(squad: SquadData, _actor: ActivityRunner) -> void:
	_current_squad = squad
	_money_label.text = "Available Gold: %.0f" % squad.money

	for child in _classes_container.get_children():
		child.queue_free()

	for bg in WarriorBackgroundFactory.all():
		_classes_container.add_child(_create_class_card(bg))


func _create_class_card(background: WarriorBackground) -> PanelContainer:
	var cost: int = background.cost
	var can_afford := _current_squad.money >= cost

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
		var stats := load(background.stats_template_path) as EntityBaseStats
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
		recruit_btn.tooltip_text = "Need %.0f more gold" % (cost - _current_squad.money)

	UIAnimations.register_button(recruit_btn)
	return panel
