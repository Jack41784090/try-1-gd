extends Node

const _SFX_PATHS := {
	"ui_click": "res://assets/sfx/ui_click.wav",
	"ui_hover": "res://assets/sfx/ui_hover.wav",
	"ui_confirm": "res://assets/sfx/ui_confirm.wav",
	"ui_cancel": "res://assets/sfx/ui_cancel.wav",
	"text_blip": "res://assets/sfx/text_blip.wav",
	"sword_hit": "res://assets/sfx/sword_hit.wav",
	"sword_swing": "res://assets/sfx/sword_swing.wav",
	"arrow_fire": "res://assets/sfx/arrow_fire.wav",
	"arquebus_fire": "res://assets/sfx/arquebus_fire.wav",
	"pike_thrust": "res://assets/sfx/pike_thrust.wav",
	"shield_block": "res://assets/sfx/shield_block.wav",
	"fire_spell": "res://assets/sfx/fire_spell.wav",
	"heal": "res://assets/sfx/heal.wav",
	"death": "res://assets/sfx/death.wav",
	"suppression": "res://assets/sfx/suppression.wav",
	"march_step": "res://assets/sfx/march_step.wav",
	"coin": "res://assets/sfx/coin.wav",
	"turn_start": "res://assets/sfx/turn_start.wav",
	"morale_boost": "res://assets/sfx/morale_boost.wav",
	"victory_fanfare": "res://assets/sfx/victory_fanfare.wav",
	"defeat": "res://assets/sfx/defeat.wav",
}

const _DEFAULT_POOL_SIZE := 8

var _cache: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _disabled: bool = false


func _ready() -> void:
	_disabled = DisplayServer.get_name() == "headless"
	if _disabled:
		return
	for _i in _DEFAULT_POOL_SIZE:
		_players.append(_create_player())


func play(sfx_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if _disabled:
		return
	if not _SFX_PATHS.has(sfx_name):
		return
	var stream = _get_stream(sfx_name)
	if stream == null:
		return
	var player = _get_available_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


func play_ui_hover() -> void:
	play("ui_hover", -12.0)


func play_ui_click() -> void:
	play("ui_click", -7.0)


func play_ui_confirm() -> void:
	play("ui_confirm", -5.0)


func play_ui_cancel() -> void:
	play("ui_cancel", -6.0)


func play_attack_for_weapon(weapon_class: int) -> void:
	match weapon_class:
		WeaponFactory.WeaponClasses.Crossbow:
			play("arrow_fire", -4.0)
		WeaponFactory.WeaponClasses.Arquebus:
			play("arquebus_fire", -3.0)
		WeaponFactory.WeaponClasses.Pike:
			play("pike_thrust", -4.0)
		WeaponFactory.WeaponClasses.Mace:
			play("shield_block", -6.0)
		WeaponFactory.WeaponClasses.AlchemicalFire:
			play("fire_spell", -4.0)
		_:
			play("sword_hit", -5.0)


func play_combat_clink() -> void:
	play("shield_block", -7.0)


func play_death() -> void:
	play("death", -3.0)


func play_player_victory() -> void:
	play("victory_fanfare", -4.0)


func play_player_defeat() -> void:
	play("defeat", -3.0)


func _get_stream(sfx_name: String) -> AudioStream:
	if _cache.has(sfx_name):
		return _cache[sfx_name]
	var stream = load(_SFX_PATHS[sfx_name])
	if stream == null:
		return null
	_cache[sfx_name] = stream
	return stream


func _get_available_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	var created = _create_player()
	_players.append(created)
	return created


func _create_player() -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.bus = "Master"
	add_child(player)
	return player
