class_name InvestigationClueItem extends PanelContainer

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var age_label: Label = $MarginContainer/VBoxContainer/AgeLabel
@onready var destination_label: Label = $MarginContainer/VBoxContainer/DestinationLabel
@onready var squad_label: Label = $MarginContainer/VBoxContainer/SquadLabel

func populate(clue: Clue, perception_roll: int, current_hour: int, squad_name: String) -> void:
	name_label.text = "🔍 %s" % clue.clue_name
	age_label.text = "Age: %s" % clue.get_age_description(current_hour)

	var destination_hint := clue.get_destination_hint(perception_roll)
	destination_label.text = "Direction: %s" % destination_hint

	if not clue.left_by_squad_id.is_empty():
		squad_label.visible = true
		squad_label.text = "Left by: %s" % squad_name
	else:
		squad_label.visible = false

	visible = true
