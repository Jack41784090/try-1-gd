extends CanvasLayer

@onready var _time_of_day: ColorRect = $TimeOfDay
@onready var _vignette: ColorRect = $Vignette
@onready var _film_grain: ColorRect = $FilmGrain
@onready var _fog_wisps: ColorRect = $FogWisps
@onready var _damage_pulse: ColorRect = $DamagePulse
@onready var _combat_atmosphere: ColorRect = $CombatAtmosphere

var _current_hour_of_day: float = 12.0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		visible = false
		return
	_damage_pulse.visible = false
	_combat_atmosphere.visible = false
	StrategyEventBus.hour_advanced.connect(_on_hour_advanced)
	update_time(8)


func _on_hour_advanced(hour: int) -> void:
	update_time(hour)


func update_time(hour: int) -> void:
	_current_hour_of_day = float(hour % 24)

	var tod_mat: ShaderMaterial = _time_of_day.material
	tod_mat.set_shader_parameter("hour_of_day", _current_hour_of_day)

	var night := _get_night_factor(_current_hour_of_day)

	var vig_mat: ShaderMaterial = _vignette.material
	vig_mat.set_shader_parameter("intensity", 0.35 + night * 0.25)

	var fog_mat: ShaderMaterial = _fog_wisps.material
	var dawn := _get_dawn_factor(_current_hour_of_day)
	fog_mat.set_shader_parameter("intensity", 0.06 + night * 0.14 + dawn * 0.12)


func trigger_damage_pulse() -> void:
	if not visible:
		return
	_damage_pulse.visible = true
	var mat: ShaderMaterial = _damage_pulse.material
	mat.set_shader_parameter("pulse_intensity", 0.7)
	var tw := create_tween()
	tw.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("pulse_intensity", v),
		0.7, 0.0, 0.6
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(func() -> void: _damage_pulse.visible = false)


func set_combat_mode(active: bool) -> void:
	if not visible:
		return
	if active:
		_combat_atmosphere.visible = true
		var mat: ShaderMaterial = _combat_atmosphere.material
		var tw := create_tween()
		tw.tween_method(
			func(v: float) -> void: mat.set_shader_parameter("mix_amount", v),
			0.0, 1.0, 0.5
		).set_ease(Tween.EASE_OUT)
	else:
		var mat: ShaderMaterial = _combat_atmosphere.material
		var tw := create_tween()
		tw.tween_method(
			func(v: float) -> void: mat.set_shader_parameter("mix_amount", v),
			1.0, 0.0, 0.5
		).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void: _combat_atmosphere.visible = false)


func _get_night_factor(h: float) -> float:
	if h < 4.0:
		return 1.0
	if h < 7.0:
		return _smooth(7.0, 4.0, h)
	if h < 18.0:
		return 0.0
	if h < 21.0:
		return _smooth(18.0, 21.0, h)
	return 1.0


func _get_dawn_factor(h: float) -> float:
	if h < 4.0:
		return 0.0
	if h < 6.0:
		return _smooth(4.0, 5.5, h)
	if h < 8.0:
		return _smooth(8.0, 6.0, h)
	return 0.0


static func _smooth(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
