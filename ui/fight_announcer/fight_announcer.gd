extends CanvasLayer
## Anunciador de pelea: muestra "KO!" al finalizar una ronda.

@onready var label: Label = $Label


func _ready() -> void:
	label.modulate.a = 0.0


func show_ko() -> void:
	label.text = "KO!"
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.5)
	tw.tween_property(label, "modulate:a", 0.0, 0.5)


func show_text(text: String) -> void:
	label.text = text
	label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.15)
