class_name RecruitmentClassItem extends PanelContainer

signal recruit_pressed(class_enum: EntityClasses.Types)

@onready var icon_rect: TextureRect = $MarginContainer/HBoxContainer/IconRect
@onready var name_label: Label = $MarginContainer/HBoxContainer/InfoVBox/NameLabel
@onready var cost_label: Label = $MarginContainer/HBoxContainer/InfoVBox/CostLabel
@onready var stats_label: Label = $MarginContainer/HBoxContainer/InfoVBox/StatsLabel
@onready var recruit_button: Button = $MarginContainer/HBoxContainer/RecruitButton

var _class_enum: EntityClasses.Types

func _ready() -> void:
	recruit_button.pressed.connect(func(): recruit_pressed.emit(_class_enum))

func populate(class_enum: EntityClasses.Types, entity_template: CombatEntity, cost: float, can_afford: bool) -> void:
	_class_enum = class_enum
	icon_rect.texture = entity_template.icon
	name_label.text = entity_template.entity_name
	cost_label.text = "Cost: %.0f gold" % cost

	if entity_template.stats:
		stats_label.text = "STR:%.0f DEX:%.0f END:%.0f INT:%.0f" % [
			entity_template.stats.strength,
			entity_template.stats.dex,
			entity_template.stats.endurance,
			entity_template.stats.int_stat
		]
	else:
		stats_label.text = "No stats available"

	recruit_button.disabled = not can_afford
	if not can_afford:
		recruit_button.text = "Can't Afford"
	else:
		recruit_button.text = "Recruit"

	visible = true
