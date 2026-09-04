@tool
class_name CycleRow extends HBoxContainer
## Fila de opción tipo ciclo (reutilizable): Label + botón de valor que rota
## entre opciones predefinidas al hacer click, con color por opción — como
## "Quality Mode" / "TNT Lighting Quality" en Sodium. Se usa adjuntando este
## script a un HBoxContainer con los hijos "Label" y "ValueButton" definidos
## en la escena; las propiedades exportadas se editan directamente ahí, sin
## tocar código. Marcado @tool para previsualizar el texto/valor en el editor.

signal option_changed(index: int, value: String)

@export var label_text: String = "Opción":
	set(v):
		label_text = v
		if is_node_ready():
			_label.text = v
@export var options: Array[String] = []
@export var option_colors: Array[Color] = []
@export var selected_index: int = 0

const DEFAULT_COLOR := Color(0.99, 0.65, 0.2, 1.0)

@onready var _label: Label = $Label
@onready var _value_button: Button = $ValueButton


func _ready() -> void:
	_label.text = label_text
	if not _value_button.pressed.is_connected(_on_pressed):
		_value_button.pressed.connect(_on_pressed)
	_refresh()


func _on_pressed() -> void:
	if options.is_empty():
		return
	selected_index = (selected_index + 1) % options.size()
	_refresh()
	option_changed.emit(selected_index, get_value())


func _refresh() -> void:
	if options.is_empty():
		return
	selected_index = clampi(selected_index, 0, options.size() - 1)
	_value_button.text = options[selected_index]
	var col: Color = DEFAULT_COLOR
	if selected_index < option_colors.size():
		col = option_colors[selected_index]
	_value_button.add_theme_color_override("font_color", col)
	_value_button.add_theme_color_override("font_hover_color", col.lightened(0.25))


func get_value() -> String:
	return options[selected_index] if selected_index < options.size() else ""


func set_selected_index(i: int) -> void:
	selected_index = i
	_refresh()
