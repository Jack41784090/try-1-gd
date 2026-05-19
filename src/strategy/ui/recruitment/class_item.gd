class_name RecruitmentClassItem extends PanelContainer

signal recruit_pressed(background: WarriorBackground)

@onready var icon_rect: TextureRect = $MarginContainer/HBoxContainer/IconRect
@onready var name_label: Label = $MarginContainer/HBoxContainer/InfoVBox/NameLabel
@onready var cost_label: Label = $MarginContainer/HBoxContainer/InfoVBox/CostLabel
@onready var stats_label: Label = $MarginContainer/HBoxContainer/InfoVBox/StatsLabel
@onready var recruit_button: Button = $MarginContainer/HBoxContainer/RecruitButton

var _background: WarriorBackground

func _ready() -> void:
	recruit_button.pressed.connect(func(): recruit_pressed.emit(_background))

func populate(background: WarriorBackground, can_afford: bool) -> void:
	_background = background
	if background.icon:
		icon_rect.texture = background.icon
	name_label.text = background.display_name
	cost_label.text = "Cost: %d gold" % background.cost

	if not background.stats_template_path.is_empty():
		var stats := load(background.stats_template_path) as EntityBaseStats
		if stats:
			stats_label.text = "STR:%.0f DEX:%.0f END:%.0f INT:%.0f" % [
				stats.strength,
				stats.dex,
				stats.endurance,
				stats.int_stat
			]
		else:
			stats_label.text = ""
	else:
		stats_label.text = ""

	recruit_button.disabled = not can_afford
	if not can_afford:
		recruit_button.text = "Can't Afford"
	else:
		recruit_button.text = "Recruit"

	visible = true
