class_name SpeechBubble extends PanelContainer

signal typewriter_finished()
signal word_revealed(word: String)

const CHAR_DELAY: float = 0.03
const COMMA_DELAY: float = 0.12
const SENTENCE_DELAY: float = 0.22

var target_character_id: String
var is_active: bool = true

var _tw_active: bool = false
var _tw_full_text: String = ""
var _tw_char_index: int = 0
var _tw_accumulator: float = 0.0
var _tw_speed: float = 1.0
var _tw_current_word: String = ""

@onready var speaker_label: Label = $MarginContainer/VBoxContainer/SpeakerLabel
@onready var text_label: Label = $MarginContainer/VBoxContainer/TextLabel
@onready var tail: TextureRect = $Tail

func setup(character_id: String, speaker_name: String, text: String) -> void:
	target_character_id = character_id
	if speaker_label:
		speaker_label.text = speaker_name
	if text_label:
		text_label.text = text
		text_label.visible_characters = 0
	_tw_full_text = text

func start_typewriter() -> void:
	_tw_active = true
	_tw_char_index = 0
	_tw_accumulator = 0.0
	_tw_speed = 1.0
	_tw_current_word = ""
	if text_label:
		text_label.visible_characters = 0

func set_speed(multiplier: float) -> void:
	_tw_speed = multiplier

func is_typewriting() -> bool:
	return _tw_active

func stop_typewriter() -> void:
	if not _tw_active:
		return
	_tw_active = false
	if not _tw_current_word.is_empty():
		word_revealed.emit(_tw_current_word)
		_tw_current_word = ""

func set_screen_position(pos: Vector2) -> void:
	position = pos - Vector2(size.x * 0.5, size.y)

func appear() -> void:
	scale = Vector2.ZERO
	pivot_offset = size * 0.5
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func dismiss() -> void:
	is_active = false
	_tw_active = false
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func _process(delta: float) -> void:
	if not _tw_active:
		return
	_tw_accumulator += delta * _tw_speed
	while _tw_accumulator > 0.0 and _tw_char_index < _tw_full_text.length():
		var ch = _tw_full_text[_tw_char_index]
		_tw_char_index += 1
		if text_label:
			text_label.visible_characters = _tw_char_index
		var _wc_code = ch.unicode_at(0)
		var _is_wc = (_wc_code >= 65 and _wc_code <= 90) or (_wc_code >= 97 and _wc_code <= 122) or (_wc_code >= 48 and _wc_code <= 57) or ch == "'" or ch == "-"
		if _is_wc:
			_tw_current_word += ch
		elif not _tw_current_word.is_empty():
			word_revealed.emit(_tw_current_word)
			_tw_current_word = ""
		var _char_delay: float
		match ch:
			".", "!", "?":
				_char_delay = SENTENCE_DELAY
			",", ";", ":", "\u2014":
				_char_delay = COMMA_DELAY
			_:
				_char_delay = CHAR_DELAY
		_tw_accumulator -= _char_delay

	if _tw_char_index >= _tw_full_text.length():
		_tw_active = false
		if not _tw_current_word.is_empty():
			word_revealed.emit(_tw_current_word)
			_tw_current_word = ""
		typewriter_finished.emit()

