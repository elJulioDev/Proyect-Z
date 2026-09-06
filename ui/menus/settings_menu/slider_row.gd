@tool
class_name SliderRow extends HBoxContainer
## Fila de opción tipo slider (reutilizable): Label + HSlider + valor
## formateado (ej. "80%"). Se usa adjuntando este script a un HBoxContainer
## con los hijos "Label", "Slider" (HSlider) y "ValueLabel" definidos en la
## escena; las propiedades exportadas se editan directamente ahí, sin tocar
## código. Marcado @tool para previsualizar el texto/valor en el editor.

signal value_changed(value: float)

@export var label_text: String = "Opción":
	set(v):
		label_text = v
		if is_node_ready():
			_label.text = v
@export var value_suffix: String = "%"
@export var value_multiplier: float = 100.0
@export var decimals: int = 0
@export var slider_min: float = 0.0
@export var slider_max: float = 1.0
@export var slider_step: float = 0.01
@export var initial_value: float = 1.0
@export var special_labels: Dictionary = {}

@onready var _label: Label = $Label
@onready var _slider: HSlider = $Slider
@onready var _value_label: Label = $ValueLabel


func _ready() -> void:
	_label.text = label_text
	_slider.min_value = slider_min
	_slider.max_value = slider_max
	_slider.step = slider_step
	_slider.value = initial_value
	if not _slider.value_changed.is_connected(_on_value_changed):
		_slider.value_changed.connect(_on_value_changed)
	_refresh_value_label(_slider.value)


func _on_value_changed(v: float) -> void:
	_refresh_value_label(v)
	value_changed.emit(v)


func _refresh_value_label(v: float) -> void:
	if special_labels.has(v):
		_value_label.text = special_labels[v]
	else:
		_value_label.text = "%s%s" % [String.num(v * value_multiplier, decimals), value_suffix]


func get_value() -> float:
	return _slider.value


func set_value(v: float) -> void:
	_slider.value = v
	_refresh_value_label(v)
