class_name FloatingPanel
extends PanelContainer

signal drag_started(panel: FloatingPanel)
signal dragging(panel: FloatingPanel, global_pos: Vector2)
signal drag_ended(panel: FloatingPanel, global_pos: Vector2)

@export var panel_title: String = "Panel":
	set(value):
		panel_title = value
		if is_node_ready():
			_title_label.text = value

@onready var _title_bar: Control = %TitleBar
@onready var _title_label: Label = %TitleLabel

var original_size: Vector2:
	set(_v):
		original_size = _v
		print('new os: ', _v)

var floating_rect: Rect2 = Rect2()

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_title_label.text = panel_title
	floating_rect = Rect2(position, size)
	_title_bar.gui_input.connect(_on_title_bar_input)
	#_collapse_button.pressed.connect(func() -> void: collapse_requested.emit(self))

	original_size = Vector2(self.size)


func _on_title_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = get_global_mouse_position() - global_position
			move_to_front()
			drag_started.emit(self)
		elif _dragging:
			_dragging = false
			drag_ended.emit(self, get_global_mouse_position())
	elif event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() - _drag_offset
		dragging.emit(self, get_global_mouse_position())
