class_name SquadLogView
extends Control

signal closed

const PANEL_WIDTH := 380.0
const SLIDE_DURATION := 0.3
const MAX_LOG_ENTRIES := 200

@onready var overlay_panel: PanelContainer = $OverlayPanel
@onready var log_tab: Button = $LogTab
@onready var log_container: VBoxContainer = $OverlayPanel/MarginContainer/VBoxContainer/ScrollContainer/LogContainer
@onready var scroll_container: ScrollContainer = $OverlayPanel/MarginContainer/VBoxContainer/ScrollContainer
@onready var close_button: Button = $OverlayPanel/MarginContainer/VBoxContainer/CloseButton

var _is_open := false
var _is_pinned := false
var _tween: Tween
var _entry_count := 0
var _unread_count := 0


func _ready() -> void:
	visible = true
	close_button.pressed.connect(_unpin_and_close)
	log_tab.pressed.connect(_on_tab_clicked)
	log_tab.mouse_entered.connect(_on_hover_enter)
	overlay_panel.mouse_entered.connect(_on_hover_enter)
	log_tab.mouse_exited.connect(_on_hover_exit)
	overlay_panel.mouse_exited.connect(_on_hover_exit)


func add_entry(text: String, color: Color = Color(0.78, 0.75, 0.68)) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_container.add_child(label)
	_entry_count += 1

	if _entry_count > MAX_LOG_ENTRIES:
		var oldest := log_container.get_child(0)
		oldest.queue_free()
		_entry_count -= 1

	if not _is_open:
		_unread_count += 1
		_update_tab_text()

	_scroll_to_bottom.call_deferred()


func add_separator() -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	log_container.add_child(sep)


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)


func _update_tab_text() -> void:
	if _unread_count > 0:
		log_tab.text = "L\nO\nG\n(%d)\n⟪" % _unread_count
	else:
		log_tab.text = "L\nO\nG\n⟪"


func _on_tab_clicked() -> void:
	if _is_pinned:
		_unpin_and_close()
	else:
		_is_pinned = true
		_slide_in()


func _unpin_and_close() -> void:
	_is_pinned = false
	_slide_out()


func _on_hover_enter() -> void:
	if _is_pinned:
		return
	_slide_in()


func _on_hover_exit() -> void:
	if not _is_open or _is_pinned:
		return
	var panel_rect := overlay_panel.get_global_rect()
	var tab_rect := log_tab.get_global_rect()
	var mouse_pos := get_global_mouse_position()
	if panel_rect.has_point(mouse_pos) or tab_rect.has_point(mouse_pos):
		return
	_slide_out()


func _slide_in() -> void:
	if _is_open:
		return
	_is_open = true
	_unread_count = 0
	_update_tab_text()
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(overlay_panel, "offset_left", -PANEL_WIDTH, SLIDE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(overlay_panel, "offset_right", 0.0, SLIDE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_scroll_to_bottom.call_deferred()


func _slide_out() -> void:
	if not _is_open:
		return
	_is_open = false
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(overlay_panel, "offset_left", 0.0, SLIDE_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(overlay_panel, "offset_right", PANEL_WIDTH, SLIDE_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	closed.emit()
