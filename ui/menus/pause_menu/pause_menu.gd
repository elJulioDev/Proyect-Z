extends CanvasLayer
## Menú de pausa: muestra opciones cuando el juego está pausado.
## GameManager instancia/destruye este nodo y maneja el input de apertura.

const HOVER_SFX_PATH = "res://assets/audio/sfx/ui/Cursor.wav"
const CLICK_SFX_PATH = "res://assets/audio/sfx/ui/Decide_2.wav"
const CHARACTER_SELECT_PATH = "res://ui/menus/character_select/character_select.tscn"
const STAGE_SELECT_PATH = "res://ui/menus/stage_select/stage_select.tscn"
const MAIN_MENU_PATH = "res://ui/menus/main_menu/menu.tscn"

@onready var buttons_container: VBoxContainer = $CenterContainer/VBoxContainer/ButtonsContainer

var hover_player: AudioStreamPlayer
var click_player: AudioStreamPlayer
var _busy := false

var _btn_data: Dictionary = {}
var _hovered_btn: Button = null
var last_hover_time: int = 0
var last_click_time: int = 0


func _ready() -> void:
	hide()
	_setup_audio()
	_connect_buttons()


func show_menu() -> void:
	show()
	get_tree().paused = true
	if buttons_container.get_child_count() > 0:
		buttons_container.get_child(0).grab_focus()


func hide_menu() -> void:
	hide()
	get_tree().paused = false


func _setup_audio() -> void:
	hover_player = AudioStreamPlayer.new()
	hover_player.stream = preload(HOVER_SFX_PATH)
	hover_player.volume_db = -10
	hover_player.max_polyphony = 4
	add_child(hover_player)

	click_player = AudioStreamPlayer.new()
	click_player.stream = preload(CLICK_SFX_PATH)
	click_player.volume_db = -10
	add_child(click_player)


func _connect_buttons() -> void:
	for button in buttons_container.get_children():
		if not button is Button:
			continue
		_setup_button_visual(button)
		button.focus_entered.connect(_on_focus_entered.bind(button))
		button.focus_exited.connect(_on_focus_exited.bind(button))
		button.mouse_entered.connect(_on_mouse_entered.bind(button))
		button.pressed.connect(_on_button_pressed)
		if button.name == "continuar":
			button.pressed.connect(_on_continuar_pressed)
		elif button.name == "reiniciar":
			button.pressed.connect(_on_reiniciar_pressed)
		elif button.name == "personajes":
			button.pressed.connect(_on_personajes_pressed)
		elif button.name == "escenario":
			button.pressed.connect(_on_escenario_pressed)
		elif button.name == "menu_principal":
			button.pressed.connect(_on_menu_principal_pressed)


func _setup_button_visual(button: Button) -> void:
	var normal: StyleBoxFlat = button.get_theme_stylebox("normal").duplicate()
	var hover: StyleBoxFlat = button.get_theme_stylebox("hover").duplicate()
	hover.content_margin_top = normal.content_margin_top
	hover.content_margin_bottom = normal.content_margin_bottom
	hover.content_margin_left = normal.content_margin_left
	hover.content_margin_right = normal.content_margin_right
	button.add_theme_stylebox_override("hover", hover)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	button.add_theme_stylebox_override("focus", focus)
	_btn_data[button.name] = {"normal": normal, "hover": hover, "kb_hover": hover}


func _on_focus_entered(button: Button) -> void:
	hover_player.play()
	if button.name in _btn_data:
		button.add_theme_stylebox_override("normal", _btn_data[button.name].kb_hover)


func _on_focus_exited(button: Button) -> void:
	if button.name in _btn_data:
		button.add_theme_stylebox_override("normal", _btn_data[button.name].normal)


func _on_mouse_entered(button: Button) -> void:
	_hovered_btn = button
	get_viewport().gui_release_focus()
	var current_time = Time.get_ticks_msec()
	if current_time - last_hover_time > 150:
		hover_player.play()
		last_hover_time = current_time


func _on_button_pressed() -> void:
	var current_time = Time.get_ticks_msec()
	if current_time - last_click_time > 150:
		click_player.play()
		last_click_time = current_time


func _on_continuar_pressed() -> void:
	hide_menu()
	queue_free()


func _on_reiniciar_pressed() -> void:
	if _busy:
		return
	_set_busy(true)
	hide_menu()
	var gm := get_node_or_null("/root/GameManager")
	TransitionManager.transition(0.8, 0.5, 0.8, func():
		if gm:
			gm.start_fight(gm.p1_data.resource_path, gm.p2_data.resource_path, gm.current_stage_path)
	)


func _on_personajes_pressed() -> void:
	if _busy:
		return
	_set_busy(true)
	hide_menu()
	TransitionManager.transition(0.5, 0.3, 0.5, func():
		get_tree().change_scene_to_file(CHARACTER_SELECT_PATH)
	)


func _on_escenario_pressed() -> void:
	if _busy:
		return
	_set_busy(true)
	hide_menu()
	TransitionManager.transition(0.5, 0.3, 0.5, func():
		get_tree().change_scene_to_file(STAGE_SELECT_PATH)
	)


func _on_menu_principal_pressed() -> void:
	if _busy:
		return
	_set_busy(true)
	hide_menu()
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.return_to_menu()
	else:
		TransitionManager.transition(0.5, 0.3, 0.5, func():
			get_tree().change_scene_to_file(MAIN_MENU_PATH)
			)


func _set_busy(value: bool) -> void:
	_busy = value
	for button in buttons_container.get_children():
		if button is Button:
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP
