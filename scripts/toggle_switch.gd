@tool
extends Control
class_name ToggleSwitch

signal toggled(value: bool)

@export var value: bool = true:
	set(v):
		value = v
		_snap_or_animate()

@export var on_color := Color(0.3, 0.78, 0.35)
@export var off_color := Color(0.32, 0.32, 0.38)
@export var knob_color := Color(0.96, 0.96, 0.96)

var _knob_pos := 1.0
var _tween: Tween

func _ready() -> void:
	custom_minimum_size = Vector2(52, 26)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_knob_pos = 1.0 if value else 0.0
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		value = not value
		toggled.emit(value)
		accept_event()

func _snap_or_animate() -> void:
	var target := 1.0 if value else 0.0
	if not is_inside_tree():
		_knob_pos = target
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_knob, _knob_pos, target, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _set_knob(v: float) -> void:
	_knob_pos = v
	queue_redraw()

func _draw() -> void:
	var h := size.y
	var r := h * 0.5
	var bg := off_color.lerp(on_color, _knob_pos)
	draw_circle(Vector2(r, r), r, bg)
	draw_circle(Vector2(size.x - r, r), r, bg)
	if size.x > h:
		draw_rect(Rect2(r, 0.0, size.x - h, h), bg)
	var knob_r := r - 3.0
	var knob_x: float = lerpf(r, size.x - r, _knob_pos)
	draw_circle(Vector2(knob_x, r), knob_r, knob_color)
