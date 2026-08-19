@tool
extends Control
class_name DiamondIcon

@export var border_width: float = 5.0:
	set(v):
		border_width = v
		_layout_portrait()

@export var shadow_offset := Vector2(3, 3)
@export var fill_color := Color(0.35, 0.2, 0.55):
	set(v):
		fill_color = v
		_sync_material()
@export_range(0.0, 0.4) var fill_margin: float = 0.0:
	set(v):
		fill_margin = v
		_sync_material()
@export var border_color := Color.BLACK:
	set(v):
		border_color = v
		_sync_material()
@export var shadow_color := Color(0, 0, 0, 0.35)
@export var flip_h: bool = false:
	set(v):
		flip_h = v
		_sync_material()

@export var portrait_texture: Texture2D:
	set(v):
		portrait_texture = v
		_apply_texture()

static var _blank_texture: ImageTexture

@export_range(20.0, 500.0) var icon_width: float = 0.0:
	set(v):
		icon_width = v
		if icon_width > 0.0:
			if anchor_left > 0.5:
				offset_left = offset_right - icon_width
			else:
				offset_right = offset_left + icon_width
		_layout_portrait()

@export_range(20.0, 500.0) var icon_height: float = 0.0:
	set(v):
		icon_height = v
		if icon_height > 0.0:
			offset_bottom = offset_top + icon_height
		_layout_portrait()

func _ready() -> void:
	if icon_width <= 0.0:
		icon_width = size.x
	if icon_height <= 0.0:
		icon_height = size.y
	var rect := get_node_or_null("Portrait") as TextureRect
	if portrait_texture == null and rect and rect.texture:
		portrait_texture = rect.texture
	else:
		_apply_texture()
	_layout_portrait()

func _process(_delta: float) -> void:
	var rect := get_node_or_null("Portrait") as TextureRect
	if rect:
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sync_material()

func _layout_portrait() -> void:
	var rect := get_node_or_null("Portrait") as TextureRect
	if rect:
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.offset_left = 0.0
		rect.offset_top = 0.0
		rect.offset_right = size.x
		rect.offset_bottom = size.y
		_sync_material()

func _sync_material() -> void:
	var rect := get_node_or_null("Portrait") as TextureRect
	if not rect or not rect.material is ShaderMaterial:
		return
	var mat := rect.material as ShaderMaterial
	mat.set_shader_parameter("u_node_size", rect.size)
	mat.set_shader_parameter("u_border_width", border_width / max(size.x, 1.0))
	mat.set_shader_parameter("u_border_color", border_color)
	mat.set_shader_parameter("u_fill_color", fill_color)
	mat.set_shader_parameter("u_fill_margin", fill_margin)
	mat.set_shader_parameter("u_flip_h", flip_h)
	mat.set_shader_parameter("u_has_texture", portrait_texture != null)
	if portrait_texture:
		mat.set_shader_parameter("u_texture", portrait_texture)
		mat.set_shader_parameter("u_texture_size", portrait_texture.get_size())

func _apply_texture() -> void:
	var rect := get_node_or_null("Portrait") as TextureRect
	if not rect:
		return
	rect.texture = portrait_texture if portrait_texture else _get_blank_texture()
	_sync_material()

static func _get_blank_texture() -> ImageTexture:
	if not _blank_texture:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		_blank_texture = ImageTexture.create_from_image(img)
	return _blank_texture

func _draw() -> void:
	draw_colored_polygon(_diamond(size, shadow_offset), shadow_color)

func _diamond(s: Vector2, off: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(s.x / 2, 0) + off,
		Vector2(s.x, s.y / 2) + off,
		Vector2(s.x / 2, s.y) + off,
		Vector2(0, s.y / 2) + off
	])