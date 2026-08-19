extends Node

func _ready() -> void:
	var rect := TextureRect.new()
	add_child(rect)
	rect.size = Vector2(102, 102)
	await get_tree().process_frame
	print("sin textura:", rect.size)
	rect.texture = load("res://icon.svg")
	await get_tree().process_frame
	print("con textura:", rect.size, " expand:", rect.expand_mode)
	get_tree().quit()
