@tool
extends Control
class_name SlantBar

@export var slant: float = 30.0
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
	_damage_timer = 0.5

func _start_chip_animation() -> void:
	if _tween_chip and _tween_chip.is_valid():
		_tween_chip.kill()
	_tween_chip = create_tween()
	_tween_chip.tween_property(self, "chip", _pending_chip_target, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _ready() -> void:
	if bar_width <= 0.0:
		bar_width = size.x
	if bar_height <= 0.0:
		bar_height = size.y
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

func _draw() -> void:
	_poly(size.x, Color(0, 0, 0, 0.35), shadow_offset)
	_poly(size.x, bg_color, Vector2.ZERO)
	_poly(size.x * chip, chip_color, Vector2.ZERO)
	_draw_gradient_fill(_points(size.x * value, Vector2.ZERO))
	var border = _points(size.x, Vector2.ZERO)
	border.append(border[0])
	draw_polyline(border, border_color, 3.0, true)

func _points(w: float, off: Vector2) -> PackedVector2Array:
	var h = size.y
	var right = size.x
	if size.x <= 0.0 or w <= 0.0:
		return PackedVector2Array()
	# El borde móvil avanza a lo largo de la anchura inclinada (size.x - slant);
	# así el relleno colapsa a cero en el borde de la barra cuando value -> 0
	# en vez de degenerar en un triángulo fantasma que simula energía extra.
	var usable = maxf(size.x - slant, 0.0)
	var fw = usable * (w / size.x)
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
			Vector2(0, 0) + off, Vector2(fw, 0) + off,
			Vector2(slant + fw, h) + off, Vector2(slant, h) + off
		])
	return PackedVector2Array([
		Vector2(slant, 0) + off, Vector2(slant + fw, 0) + off,
		Vector2(fw, h) + off, Vector2(0, h) + off
	])

func _poly(w: float, col: Color, off: Vector2) -> void:
	var pts := _points(w, off)
	if pts.size() < 3:
		return
	draw_colored_polygon(pts, col)

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
	if points.size() < 3 or size.x <= 0.0:
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
