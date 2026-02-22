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

func complete_immediately() -> void:
	if not _tw_active:
		return
	_tw_active = false
	_tw_char_index = _tw_full_text.length()
	if text_label:
		text_label.visible_characters = -1
	if not _tw_current_word.is_empty():
		word_revealed.emit(_tw_current_word)
		_tw_current_word = ""
	typewriter_finished.emit()

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
		_track_word(ch)
		_tw_accumulator -= _get_char_delay(ch)

	if _tw_char_index >= _tw_full_text.length():
		_tw_active = false
		if not _tw_current_word.is_empty():
			word_revealed.emit(_tw_current_word)
			_tw_current_word = ""
		typewriter_finished.emit()

func _track_word(ch: String) -> void:
	if _is_word_char(ch):
		_tw_current_word += ch
	elif not _tw_current_word.is_empty():
		word_revealed.emit(_tw_current_word)
		_tw_current_word = ""

func _is_word_char(ch: String) -> bool:
	var code = ch.unicode_at(0)
	if code >= 65 and code <= 90:
		return true
	if code >= 97 and code <= 122:
		return true
	if code >= 48 and code <= 57:
		return true
	if ch == "'" or ch == "-":
		return true
	return false

func _get_char_delay(ch: String) -> float:
	match ch:
		".", "!", "?":
			return SENTENCE_DELAY
		",", ";", ":", "\u2014":
			return COMMA_DELAY
		_:
			return CHAR_DELAY
