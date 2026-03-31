extends Node3D

## Singleton for displaying damage numbers in 3D space
## Uses Label3D for proper 3D text rendering with billboarding

@export var SPRING_TIME = .25
@export var FALL_TIME = .3
@export var DISAPPEAR_TIME = .25

func DisplayDamageNumber(amount: float, world_position: Vector3) -> void:
	var label_3d: Label3D = Label3D.new()
	label_3d.text = str(int(amount))
	
	label_3d.font_size = 200
	label_3d.outline_size = 1
	
	if amount < 0:
		label_3d.modulate = Color(1.0, 0.3, 0.3)  # Red for damage
	else:
		label_3d.modulate = Color(0.3, 1.0, 0.3)  # Green for healing
	
	label_3d.modulate.a = 0.0
	
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.render_priority = 100
	
	add_child(label_3d)
	
	if not label_3d.is_inside_tree():
		await label_3d.tree_entered
	
	var local_pos = to_local(world_position)
	
	label_3d.position = local_pos
	
	await get_tree().process_frame
	
	var start_pos = label_3d.position
	var float_distance = 1.0
	
	var target_color = label_3d.modulate
	label_3d.modulate = Color(target_color.r, target_color.g, target_color.b, 1.0)
	
	var tween = create_tween().set_parallel(true)
	
	tween\
		.tween_property(
			label_3d,
			"position:y",
			start_pos.y + float_distance,
			SPRING_TIME
		)\
		.set_ease(Tween.EASE_OUT)
	
	tween\
		.tween_property(
			label_3d,
			"modulate:a",
			0.0,
			DISAPPEAR_TIME
		)\
		.set_delay(SPRING_TIME)\
		.set_ease(Tween.EASE_IN)
	
	tween\
		.tween_property(
			label_3d,
			"scale",
			Vector3(0.5, 0.5, 0.5),
			DISAPPEAR_TIME
		)\
		.set_delay(SPRING_TIME)\
		.set_ease(Tween.EASE_IN)
	
	await tween.finished
	label_3d.queue_free()
