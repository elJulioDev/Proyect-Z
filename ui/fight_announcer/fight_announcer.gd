extends CanvasLayer
## Anunciador de pelea: muestra "KO!" o textos ("ROUND 1", "FIGHT!") con fade controlado.

@onready var label: Label = $Label

var _tween: Tween = null


func _ready() -> void:
	label.modulate.a = 0.0


func show_ko() -> void:
	_play_sequence("KO!", 0.15, 1.5, 0.5)


func show_text(text: String, hold: float = 0.8, fade_out: float = 0.3) -> void:
	_play_sequence(text, 0.15, hold, fade_out)


func _play_sequence(text: String, fade_in: float, hold: float, fade_out: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	label.text = text
	_tween = create_tween()
	_tween.tween_property(label, "modulate:a", 1.0, fade_in)
	_tween.tween_interval(hold)
	_tween.tween_property(label, "modulate:a", 0.0, fade_out)
