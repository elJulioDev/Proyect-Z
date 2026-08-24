extends CanvasLayer
## Capa de filtro visual: construye un ColorRect full-screen con el shader
## combinado de efectos de escenario (color grading, viñeta, distorsión).

const SHADER_PATH := "res://core/shaders/stage_effects.gdshader"

var _filter: ColorRect
var _shader: Shader
var _material: ShaderMaterial
var _pending_filter: StageFilter


func _init() -> void:
	layer = 0
	_shader = load(SHADER_PATH)
	_material = ShaderMaterial.new()
	_material.shader = _shader


func _ready() -> void:
	_filter = ColorRect.new()
	_filter.name = "Filter"
	_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filter.set_anchors_preset(Control.PRESET_FULL_RECT)
	_filter.material = _material
	add_child(_filter)

	# Aplicar filtro pendiente si apply() fue llamado antes de _ready()
	if _pending_filter != null:
		_apply_to_material(_pending_filter)
		_pending_filter = null


func apply(filter_data: StageFilter) -> void:
	if filter_data == null:
		visible = false
		return

	if _filter == null:
		# _ready() aún no corrió, guardar para después
		_pending_filter = filter_data
		visible = filter_data.has_effects()
		return

	_apply_to_material(filter_data)
	visible = filter_data.has_effects()


func _apply_to_material(filter_data: StageFilter) -> void:
	# Color grading
	_material.set_shader_parameter("color_grading_enabled", filter_data.color_grading_enabled)
	_material.set_shader_parameter("tint_color", filter_data.tint_color)
	_material.set_shader_parameter("saturation", filter_data.saturation)
	_material.set_shader_parameter("brightness", filter_data.brightness)
	_material.set_shader_parameter("contrast", filter_data.contrast)

	# Viñeta
	_material.set_shader_parameter("vignette_enabled", filter_data.vignette_enabled)
	_material.set_shader_parameter("vignette_intensity", filter_data.vignette_intensity)
	_material.set_shader_parameter("vignette_opacity", filter_data.vignette_opacity)

	# Distorsión
	_material.set_shader_parameter("distortion_enabled", filter_data.distortion_enabled)
	_material.set_shader_parameter("distortion_strength", filter_data.distortion_strength)
	_material.set_shader_parameter("distortion_speed", filter_data.distortion_speed)
