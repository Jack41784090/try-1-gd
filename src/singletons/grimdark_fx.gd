extends CanvasLayer

@onready var _vignette: ColorRect = $Vignette
@onready var _film_grain: ColorRect = $FilmGrain
@onready var _damage_pulse: ColorRect = $DamagePulse
@onready var _combat_atmosphere: ColorRect = $CombatAtmosphere

var _current_hour_of_day: float = 12.0
var _world_shader: Shader = preload("res://assets/shaders/fx/world_atmosphere.gdshader")
var _bg_material: ShaderMaterial
var _fg_material: ShaderMaterial
var _enabled: bool = true


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		visible = false
		return
	_damage_pulse.visible = false
	_combat_atmosphere.visible = false
	StrategyEventBus.strategy_hour_tick.connect(_on_hour_advanced)
	update_time(0)


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
	var dawn: float
	if _current_hour_of_day < 4.0:
		dawn = 0.0
	elif _current_hour_of_day < 6.0:
		dawn = _smooth(4.0, 5.5, _current_hour_of_day)
	elif _current_hour_of_day < 8.0:
		dawn = _smooth(8.0, 6.0, _current_hour_of_day)
	else:
		dawn = 0.0
	var fog := 0.06 + night * 0.18 + dawn * 0.12

	for mat: ShaderMaterial in [_bg_material, _fg_material]:
		if mat == null:
			continue
		mat.set_shader_parameter("hour_of_day", _current_hour_of_day)
		mat.set_shader_parameter("fog_intensity", fog)


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


static func _smooth(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
