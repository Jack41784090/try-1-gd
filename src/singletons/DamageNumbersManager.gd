extends Node3D

## Singleton for displaying damage numbers in 3D space
## Uses Label3D for proper 3D text rendering with billboarding

@export var SPRING_TIME = .25
@export var FALL_TIME = .3
@export var DISAPPEAR_TIME = .25

func DisplayDamageNumber(amount: float, world_position: Vector3) -> void:
	# Generate unique ID for debugging
	# var debug_id = RandomNumberGenerator.new().randf_range(1000, 9999)
	# var debug_id_str = "DAMAGE[%.0f]" % debug_id
	
	# Create Label3D for 3D space
	var label_3d: Label3D = Label3D.new()
	label_3d.text = str(int(amount))
	
	# print("[%s] Creating damage number: %.0f at world position: %s" % [debug_id_str, amount, world_position])
	
	# Configure Label3D properties directly (Label3D doesn't use label_settings)
	label_3d.font_size = 200
	label_3d.outline_size = 1
	# label_3d.outline = Color.BLACK
	
	# Set color based on damage type (negative = damage, positive = heal)
	if amount < 0:
		label_3d.modulate = Color(1.0, 0.3, 0.3)  # Red for damage
	else:
		label_3d.modulate = Color(0.3, 1.0, 0.3)  # Green for healing
	
	# Hide label initially to prevent flashing at (0,0,0) before position is set
	label_3d.modulate.a = 0.0
	# print("[%s] Label hidden initially (alpha=0) to prevent visual glitch" % debug_id_str)
	
	# Enable billboard so text always faces camera
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	
	# Set render priority to appear above other objects
	label_3d.render_priority = 1
	
	# Add to scene first (required before setting global_position)
	add_child(label_3d)
	# print("[%s] Label3D added to tree. In tree: %s" % [debug_id_str, label_3d.is_inside_tree()])
	
	# Wait for node to be fully in tree before setting position (fixes race condition)
	# This ensures the node's parent transform is ready
	if not label_3d.is_inside_tree():
		# print("[%s] Waiting for tree entry..." % debug_id_str)
		await label_3d.tree_entered
		# print("[%s] Node entered tree. In tree: %s" % [debug_id_str, label_3d.is_inside_tree()])
	
	# Convert world position to local space relative to this node (DamageNumbersManager)
	# This accounts for the parent's transform properly
	var local_pos = to_local(world_position)
	# print("[%s] Position conversion - World: %s -> Local: %s" % [debug_id_str, world_position, local_pos])
	# print("[%s] Parent (DamageNumbersManager) global_position: %s, global_transform: %s" % [debug_id_str, global_position, global_transform.origin])
	
	label_3d.position = local_pos
	
	# Wait one frame to ensure transform is applied
	await get_tree().process_frame
	
	# Get initial local position for animation (already in local space)
	var start_pos = label_3d.position
	# var verified_global = label_3d.global_position
	var float_distance = 1.0  # Distance to float upward in 3D space
	
	# print("[%s] Final position - Local: %s, Verified Global: %s (offset from target: %s)" % [debug_id_str, start_pos, verified_global, verified_global - world_position])
	# print("[%s] Animation will move from Y=%.3f to Y=%.3f (distance: %.3f)" % [debug_id_str, start_pos.y, start_pos.y + float_distance, float_distance])
	
	# Restore full alpha now that position is correct
	var target_color = label_3d.modulate
	label_3d.modulate = Color(target_color.r, target_color.g, target_color.b, 1.0)
	# print("[%s] Label made visible (alpha=1.0) at correct position" % debug_id_str)
	
	# Create tween for animation
	var tween = create_tween().set_parallel(true)
	
	# Float upward using local position
	tween\
		.tween_property(
			label_3d,
			"position:y",
			start_pos.y + float_distance,
			SPRING_TIME
		)\
		.set_ease(Tween.EASE_OUT)
	
	# Fade out and scale down
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
	
	# Wait for animation to complete, then remove
	await tween.finished
	# print("[%s] Animation completed, cleaning up label" % debug_id_str)
	label_3d.queue_free()
