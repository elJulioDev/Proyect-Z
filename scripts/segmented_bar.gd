@tool
extends Control
class_name SegmentedBar

@export var slant: float = 20.0
@export var flip: bool = false
@export var invert_slant := false
@export var bg_color := Color(0.05, 0.2, 0.22)
@export var chip_color := Color(0.65, 0.85, 1.0, 0.7)
@export var fill_base_color := Color(1.0, 0.5, 0.1)
@export var fill_tip_color := Color(1.0, 0.5, 0.1)
## Velocidad del flujo del degradado tipo barra de carga (0 = estático).
@export_range(0.0, 10.0) var anim_speed: float = 1.5
@export var border_color := Color.BLACK
@export var shadow_offset := Vector2(3, 3)

@export_range(1, 30) var segments: int = 6:
	set(v):
		segments = max(v, 1)
		queue_redraw()

## Espacio visual real entre segmentos (0 = pegados). Compensa el slant internamente.
@export_range(0.0, 40.0) var segment_gap: float = 4.0:
	set(v):
		segment_gap = v
		queue_redraw()

@export_range(20.0, 2000.0) var bar_width: float = 0.0:
	set(v):
		bar_width = v
		if bar_width > 0.0:
			if flip:
				offset_left = offset_right - bar_width
			else:
				offset_right = offset_left + bar_width

@export_range(4.0, 200.0) var bar_height: float = 0.0:
	set(v):
		bar_height = v
		if bar_height > 0.0:
			offset_bottom = offset_top + bar_height

@export_range(0.0, 1.0) var value: float = 1.0:
	set(v):
		value = clamp(v, 0.0, 1.0)
		queue_redraw()

@export_range(0.0, 1.0) var chip: float = 1.0:
	set(v):
		chip = clamp(v, 0.0, 1.0)
		queue_redraw()

var _tween_chip: Tween = null
var _damage_timer: float = 0.0
var _pending_chip_target: float = 1.0
var _redraw_accum := 0.0

func _process(delta: float) -> void:
	if _damage_timer > 0.0:
		_damage_timer -= delta
		if _damage_timer <= 0.0:
			_start_chip_animation()
	if anim_speed > 0.0:
		# El flujo usa tiempo de pared (Time.get_ticks_msec): redibujar a 60 Hz
		# es indistinguible de 1000 Hz pero evita redraws desperdiciados.
		_redraw_accum += delta
		if _redraw_accum >= 1.0 / 60.0:
			_redraw_accum = 0.0
			queue_redraw()

func apply_damage(target_val: float) -> void:
	value = target_val
	_pending_chip_target = target_val
	if _tween_chip and _tween_chip.is_valid():
		_tween_chip.kill()
	_tween_chip = create_tween()
	_tween_chip.tween_property(self, "chip", _pending_chip_target, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Carga de energía: relleno instantáneo con el chip pegado a la barra,
## para que la animación de pérdida siempre baje desde el valor cargado
## y no suba desde un chip rezagado.
func fill(target_val: float) -> void:
	_damage_timer = 0.0
	value = target_val
	if target_val >= chip:
		if _tween_chip and _tween_chip.is_valid():
			_tween_chip.kill()
		chip = target_val

func _start_chip_animation() -> void:
	if _tween_chip and _tween_chip.is_valid():
		_tween_chip.kill()
	_tween_chip = create_tween()
	_tween_chip.tween_property(self, "chip", _pending_chip_target, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _ready() -> void:
	if bar_width <= 0.0:
		bar_width = size.x
	if bar_height <= 0.0:
		bar_height = size.y
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

# El slant desplaza cada borde ~slant px, así que aunque las cajas se
# toquen (box_gap = 0) queda un hueco visual de ese tamaño. Restamos
# slant al gap de caja para que segment_gap sea el hueco visual real.
func _box_gap() -> float:
	return segment_gap - slant

func _seg_width() -> float:
	var total_gap = _box_gap() * (segments - 1)
	return max((size.x - total_gap) / float(segments), 1.0)

func _draw() -> void:
	var sw = _seg_width()
	var bg = _box_gap()
	for i in segments:
		var x0 = i * (sw + bg)
		var right = x0 + sw
		var order_index = i if not flip else (segments - 1 - i)
		var seg_value = clampf(value * segments - order_index, 0.0, 1.0)
		var seg_chip = clampf(chip * segments - order_index, 0.0, 1.0)
		_draw_segment(x0, right, sw, seg_value, seg_chip)

func _draw_segment(x0: float, right: float, sw: float, seg_value: float, seg_chip: float) -> void:
	_seg_poly(x0, right, sw, Color(0, 0, 0, 0.35), shadow_offset)
	_seg_poly(x0, right, sw, bg_color, Vector2.ZERO)
	if seg_chip > 0.0:
		_seg_poly(x0, right, sw * seg_chip, chip_color, Vector2.ZERO)
	if seg_value > 0.0:
		_draw_gradient_fill(_seg_points(x0, right, sw * seg_value, Vector2.ZERO))
	var border = _seg_points(x0, right, sw, Vector2.ZERO)
	border.append(border[0])
	draw_polyline(border, border_color, 3.0, true)

func _seg_poly(x0: float, right: float, w: float, col: Color, off: Vector2) -> void:
	draw_colored_polygon(_seg_points(x0, right, w, off), col)

var _gradient_tex: GradientTexture2D = null
var _grad_base := Color.TRANSPARENT
var _grad_tip := Color.TRANSPARENT

func _gradient_texture() -> GradientTexture2D:
	if _gradient_tex == null:
		_gradient_tex = GradientTexture2D.new()
		_gradient_tex.gradient = Gradient.new()
		_gradient_tex.gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		_gradient_tex.fill_from = Vector2(0, 0)
		_gradient_tex.fill_to = Vector2(1, 0)
		_grad_base = fill_base_color
		_grad_tip = fill_tip_color
		_gradient_tex.gradient.set_color(0, _grad_base)
		_gradient_tex.gradient.set_color(1, _grad_tip)
		_gradient_tex.gradient.set_color(2, _grad_base)
	elif _grad_base != fill_base_color or _grad_tip != fill_tip_color:
		_grad_base = fill_base_color
		_grad_tip = fill_tip_color
		_gradient_tex.gradient.set_color(0, _grad_base)
		_gradient_tex.gradient.set_color(1, _grad_tip)
		_gradient_tex.gradient.set_color(2, _grad_base)
	return _gradient_tex

func _draw_gradient_fill(points: PackedVector2Array) -> void:
	if size.x <= 0.0:
		return
	# Sin fposmod por vértice: el wrap lo hace la GPU por fragmento,
	# evita el seam que interpolaba mal dentro del quad/segmento.
	var shift: float = fmod(float(Time.get_ticks_msec()) * 0.001 * anim_speed, 1.0)
	if flip:
		shift = -shift
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	for p in points:
		var ux: float = p.x / size.x + shift
		uvs.append(Vector2(ux, 0.5))
		colors.append(Color.WHITE)
	draw_polygon(points, colors, uvs, _gradient_texture())

func _seg_points(x0: float, right: float, w: float, off: Vector2) -> PackedVector2Array:
	var h = size.y
	var sw = right - x0
	if sw <= 0.0 or w <= 0.0:
		return PackedVector2Array()
	# Igual que SlantBar: el borde móvil avanza a lo largo de la anchura
	# inclinada del segmento para que el relleno colapse a cero sin triángulo fantasma.
	var usable = maxf(sw - slant, 0.0)
	var fw = usable * (w / sw)
	if flip:
		if invert_slant:
			return PackedVector2Array([
				Vector2(right - fw, 0) + off, Vector2(right, 0) + off,
				Vector2(right - slant, h) + off, Vector2(right - slant - fw, h) + off
			])
		return PackedVector2Array([
			Vector2(right - slant - fw, 0) + off, Vector2(right - slant, 0) + off,
			Vector2(right, h) + off, Vector2(right - fw, h) + off
		])
	if invert_slant:
		return PackedVector2Array([
			Vector2(x0, 0) + off, Vector2(x0 + fw, 0) + off,
			Vector2(x0 + slant + fw, h) + off, Vector2(x0 + slant, h) + off
		])
	return PackedVector2Array([
		Vector2(x0 + slant, 0) + off, Vector2(x0 + slant + fw, 0) + off,
		Vector2(x0 + fw, h) + off, Vector2(x0, h) + off
	])