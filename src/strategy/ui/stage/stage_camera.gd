class_name StageCamera extends Camera2D

var _active_tween: Tween

func focus_on(target: Vector2, zoom_level: float, duration: float = 0.5) -> void:
	_kill_tween()
	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(self, "global_position", target, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_active_tween.tween_property(self, "zoom", Vector2(zoom_level, zoom_level), duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await _active_tween.finished

func focus_between(targets: Array[Vector2], padding: float, duration: float = 0.5) -> void:
	if targets.is_empty():
		return
	var center = Vector2.ZERO
	for t in targets:
		center += t
	center /= targets.size()

	var max_dist: float = 0.0
	for t in targets:
		max_dist = maxf(max_dist, center.distance_to(t))

	var viewport_size = get_viewport_rect().size
	var min_dim = minf(viewport_size.x, viewport_size.y)
	var needed = (max_dist + padding) * 2.0
	var zoom_level = clampf(min_dim / maxf(needed, 1.0), 0.5, 3.0)

	_kill_tween()
	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(self, "global_position", center, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_active_tween.tween_property(self, "zoom", Vector2(zoom_level, zoom_level), duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await _active_tween.finished

func reset_to_wide(duration: float = 0.5) -> void:
	_kill_tween()
	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(self, "global_position", Vector2.ZERO, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_active_tween.tween_property(self, "zoom", Vector2.ONE, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await _active_tween.finished

func get_screen_position(world_pos: Vector2) -> Vector2:
	var viewport = get_viewport()
	if not viewport:
		return world_pos
	var canvas_transform = viewport.canvas_transform
	return canvas_transform * world_pos

func _kill_tween() -> void:
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()
	_active_tween = null
