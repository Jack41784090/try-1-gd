extends Node2D


@export var SPRING_TIME = .25
@export var FALL_TIME = .3
@export var DISAPPEAR_TIME = .25

func DisplayDamageNumber(amount: int, _global_position: Vector2) -> void:
	var main_label: Label = Label.new()
	main_label.text = str(amount)
	main_label.global_position = _global_position
	main_label.label_settings = LabelSettings.new()
	# add_child(main_label)

	main_label.label_settings.font_size = 18
	main_label.label_settings.outline_color = "#000"
	main_label.label_settings.outline_size = 1

	call_deferred("add_child", main_label)

	await main_label.resized
	main_label.pivot_offset = Vector2(main_label.size / 2)

	var tween = get_tree().create_tween()\
		.set_parallel(true)

	tween\
		.tween_property(
			main_label,
			"position:y",
			main_label.position.y - 24,
			SPRING_TIME
		)\
		.set_ease(Tween.EASE_OUT)
	tween\
		.tween_property(
			main_label,
			"position:y",
			main_label.position.y,
			FALL_TIME
		)\
		.set_delay(SPRING_TIME)\
		.set_ease(Tween.EASE_IN)
	tween\
		.tween_property(
			main_label,
			"scale",
			Vector2.ZERO,
			DISAPPEAR_TIME
		)\
		.set_delay(SPRING_TIME)\
		.set_ease(Tween.EASE_IN)
	
	await tween.finished
	main_label.queue_free()
