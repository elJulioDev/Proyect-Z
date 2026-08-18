extends CanvasLayer

## Transición con shader de diamantes en ola diagonal.
## Uso: TransitionManager.transition() o fade_out()/fade_in().

@onready var color_rect: ColorRect = $ColorRect

@export var base_color := Color.BLACK


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	color_rect.visible = false
	_setup_material()


func _setup_material() -> void:
	var mat := color_rect.material as ShaderMaterial
	mat.set_shader_parameter("dot_color", base_color)

func _set_factor(value: float) -> void:
	var mat := color_rect.material as ShaderMaterial
	mat.set_shader_parameter("animation_progress", value)


func fade_out(duration: float = 0.8, callback: Callable = Callable()) -> void:
	color_rect.visible = true
	_set_factor(0.0)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_IN)
	tw.tween_method(_set_factor, 0.0, 1.0, duration)
	if callback.is_valid():
		tw.tween_callback(callback)
	await tw.finished


func fade_in(duration: float = 0.8, callback: Callable = Callable()) -> void:
	color_rect.visible = true
	_set_factor(1.0)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_factor, 1.0, 0.0, duration)
	if callback.is_valid():
		tw.tween_callback(callback)
	tw.tween_callback(func(): color_rect.visible = false)
	await tw.finished


func transition(out_dur: float = 0.8, wait: float = 1.5, in_dur: float = 0.8, callback: Callable = Callable()) -> void:
	await fade_out(out_dur)
	if callback.is_valid():
		callback.call()
	await get_tree().create_timer(wait).timeout
	await fade_in(in_dur)
