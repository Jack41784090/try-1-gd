class_name BattleSummaryOverlay
extends Control

const LOOT_ITEM_SCENE = preload("res://scenes/ui/loot_item_label.tscn")

@onready var result_label: Label = $ResultLabel
@onready var morale_delta_label: Label = $MoraleDeltaLabel
@onready var loot_display: VBoxContainer = $LootDisplay
@onready var loot_items_container: VBoxContainer = $LootDisplay/ItemsContainer


func configure_result(victory: bool, fled: bool, negotiated: bool) -> void:
	if victory:
		result_label.text = "VICTORY!"
		result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	elif fled:
		result_label.text = "Escaped!"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	elif negotiated:
		result_label.text = "Negotiated!"
		result_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	else:
		result_label.text = "DEFEAT!"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))


func animate_morale_delta(delta_value: float) -> void:
	morale_delta_label.text = "%+.1f Morale" % delta_value
	if delta_value >= 0:
		morale_delta_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		morale_delta_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	morale_delta_label.visible = true

	var tween = create_tween().set_parallel(true)
	tween.tween_property(morale_delta_label, "anchor_top", 0.16, 1.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(morale_delta_label, "anchor_bottom", 0.20, 1.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(morale_delta_label, "modulate:a", 0.0, 0.8).set_delay(0.4)


func show_equipment_loot(equipment_loot: Dictionary) -> void:
	var weapons: Array = equipment_loot.get("weapons", [])
	var armors: Array = equipment_loot.get("armors", [])
	if weapons.is_empty() and armors.is_empty():
		return

	loot_display.visible = true
	for w in weapons:
		if w is WeaponConfig:
			_add_loot_item("+ %s" % SquadBattleTypes.WeaponClasses.keys()[w.weapon_class], Color(0.7, 0.85, 1.0))
	for a in armors:
		if a is ArmorConfig:
			_add_loot_item("+ %s" % SquadBattleTypes.ArmorClasses.keys()[a.armor_class], Color(0.85, 0.75, 0.55))

	loot_display.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(loot_display, "modulate:a", 1.0, 0.5)


func _add_loot_item(text: String, color: Color) -> void:
	var label: Label = LOOT_ITEM_SCENE.instantiate()
	label.text = text
	label.add_theme_color_override("font_color", color)
	loot_items_container.add_child(label)
