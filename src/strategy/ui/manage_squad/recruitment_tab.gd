class_name RecruitmentTab
extends Control

signal recruit_requested(class_enum: EntityClasses.Types, cost: float)

const CARD_SCENE = preload("res://scenes/ui/manage_squad/recruitment_card.tscn")

@onready var _money_label: Label = $ScrollContainer/VBox/MoneyLabel
@onready var _classes_container: VBoxContainer = $ScrollContainer/VBox/ClassesContainer

var _current_squad: SquadData

const RECRUITMENT_COSTS: Dictionary = {
	EntityClasses.Types.Landsknecht: 100.0,
	EntityClasses.Types.Healer: 150.0,
	EntityClasses.Types.Crossbowman: 120.0,
	EntityClasses.Types.Arquebusier: 200.0,
	EntityClasses.Types.Pikeman: 130.0,
	EntityClasses.Types.Feldprediger: 180.0,
	EntityClasses.Types.Gelehrter: 250.0,
}


func refresh(squad: SquadData, _actor: ActivityRunner) -> void:
	_current_squad = squad
	_money_label.text = "Available Gold: %.0f" % squad.money

	for child in _classes_container.get_children():
		child.queue_free()

	for class_enum in EntityClasses.Types.values():
		_classes_container.add_child(_create_class_card(class_enum))


func _create_class_card(class_enum: EntityClasses.Types) -> PanelContainer:
	var entity_template = EntityFactory.get_entity(class_enum)
	var cost: float = RECRUITMENT_COSTS.get(class_enum, 100.0)
	var can_afford := _current_squad.money >= cost

	var panel: PanelContainer = CARD_SCENE.instantiate()

	var icon_rect: TextureRect = panel.get_node("Margin/HBox/IconRect")
	if entity_template.icon:
		icon_rect.texture = entity_template.icon

	var name_label: Label = panel.get_node("Margin/HBox/InfoVBox/NameLabel")
	name_label.text = entity_template.entity_name

	var cost_label: Label = panel.get_node("Margin/HBox/InfoVBox/CostLabel")
	cost_label.text = "Cost: %.0f gold" % cost

	var stats_label: Label = panel.get_node("Margin/HBox/InfoVBox/StatsLabel")
	if entity_template.stats:
		stats_label.text = "STR:%.0f DEX:%.0f END:%.0f INT:%.0f" % [
			entity_template.stats.strength,
			entity_template.stats.dex,
			entity_template.stats.endurance,
			entity_template.stats.int_stat
		]

	var recruit_btn: Button = panel.get_node("Margin/HBox/RecruitButton")
	if can_afford:
		recruit_btn.text = "Recruit"
		recruit_btn.pressed.connect(func(): recruit_requested.emit(class_enum, cost))
	else:
		recruit_btn.text = "Can't Afford"
		recruit_btn.disabled = true
		recruit_btn.tooltip_text = "Need %.0f more gold" % (cost - _current_squad.money)

	UIAnimations.register_button(recruit_btn)
	return panel
