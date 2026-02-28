class_name StageCamera
extends Camera2D

var _active_tween: Tween
var _include_targets: Array[String] = []
var _rig_lookup: Callable
var _include_padding: float = 100.0


func _process(_delta: float) -> void:
	if not _include_targets.is_empty() and _rig_lookup.is_valid():
		_update_include_framing()


func focus_on(target: Vector2, zoom_level: float, duration: float = 0.5) -> void:
	_kill_tween()
	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(self, "global_position", target, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_active_tween.tween_property(self, "zoom", Vector2(zoom_level, zoom_level), duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)


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


func reset_to_wide(duration: float = 0.5) -> void:
	_include_targets.clear()
	_kill_tween()
	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(self, "global_position", Vector2.ZERO, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_active_tween.tween_property(self, "zoom", Vector2.ONE, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)


func move_by(offset: Vector2, duration: float) -> void:
	_kill_tween()
	var target = global_position + offset
	_active_tween = create_tween()
	_active_tween.tween_property(self, "global_position", target, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)


func zoom_to(zoom_level: float, duration: float) -> void:
	_kill_tween()
	_active_tween = create_tween()
	_active_tween.tween_property(self, "zoom", Vector2(zoom_level, zoom_level), duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)


func set_include_targets(ids: Array[String], rig_lookup: Callable, duration: float = 0.4) -> void:
	_include_targets = ids.duplicate()
	_rig_lookup = rig_lookup
	if not _include_targets.is_empty():
		var positions: Array[Vector2] = []
		for id in _include_targets:
			var rig = _rig_lookup.call(id)
			if rig and is_instance_valid(rig):
				positions.append(rig.global_position)
		if not positions.is_empty():
			focus_between(positions, _include_padding, duration)


func get_screen_position(world_pos: Vector2) -> Vector2:
	var viewport = get_viewport()
	if not viewport:
		return world_pos
	var canvas_transform = viewport.canvas_transform
	return canvas_transform * world_pos


func _update_include_framing() -> void:
	var positions: Array[Vector2] = []
	for id in _include_targets:
		var rig = _rig_lookup.call(id)
		if rig and is_instance_valid(rig):
			positions.append(rig.global_position)
	if positions.is_empty():
		return

	var center = Vector2.ZERO
	for p in positions:
		center += p
	center /= positions.size()

	var max_dist: float = 0.0
	for p in positions:
		max_dist = maxf(max_dist, center.distance_to(p))

	var viewport_size = get_viewport_rect().size
	var min_dim = minf(viewport_size.x, viewport_size.y)
	var needed = (max_dist + _include_padding) * 2.0
	var target_zoom = clampf(min_dim / maxf(needed, 1.0), 0.5, 3.0)

	global_position = global_position.lerp(center, 0.1)
	var z = zoom.x
	z = lerpf(z, target_zoom, 0.1)
	zoom = Vector2(z, z)


func _kill_tween() -> void:
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()
	_active_tween = null
