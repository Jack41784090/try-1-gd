extends CanvasLayer

@onready var _vignette: ColorRect = $Vignette
@onready var _film_grain: ColorRect = $FilmGrain
@onready var _damage_pulse: ColorRect = $DamagePulse
@onready var _combat_atmosphere: ColorRect = $CombatAtmosphere

var _current_hour_of_day: float = 12.0
var _world_shader: Shader = preload("res://assets/shaders/fx/world_atmosphere.gdshader")
var _bg_material: ShaderMaterial
var _fg_material: ShaderMaterial


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		visible = false
		return
	_damage_pulse.visible = false
	_combat_atmosphere.visible = false
	StrategyEventBus.hour_advanced.connect(_on_hour_advanced)
	update_time(0)


func register_world_textures(bg: TextureRect, fg: TextureRect) -> void:
	_bg_material = ShaderMaterial.new()
	_bg_material.shader = _world_shader
	bg.material = _bg_material

	_fg_material = ShaderMaterial.new()
	_fg_material.shader = _world_shader
	fg.material = _fg_material

	_apply_world_shader_params()


func _on_hour_advanced(hour: int) -> void:
	update_time(hour)


func update_time(hour: int) -> void:
	_current_hour_of_day = float(hour % 24)
	_apply_world_shader_params()

	var night := _get_night_factor(_current_hour_of_day)

	var vig_mat: ShaderMaterial = _vignette.material
	vig_mat.set_shader_parameter("intensity", 0.35 + night * 0.25)


func _apply_world_shader_params() -> void:
	var night := _get_night_factor(_current_hour_of_day)
	var dawn := _get_dawn_factor(_current_hour_of_day)
	var fog := 0.06 + night * 0.18 + dawn * 0.12

	for mat: ShaderMaterial in [_bg_material, _fg_material]:
		if mat == null:
			continue
		mat.set_shader_parameter("hour_of_day", _current_hour_of_day)
		mat.set_shader_parameter("fog_intensity", fog)


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
