extends Control

# Rutas de audio
const HOVER_SFX_PATH = "res://assets/audio/sfx/Cursor.wav"
const CLICK_SFX_PATH = "res://assets/audio/sfx/Decide_2.wav"
const CONTROLS_MENU_PATH = "res://ui/menus/settings_menu/controls_menu.tscn"

var hover_player: AudioStreamPlayer
var click_player: AudioStreamPlayer

@onready var logo = $Logo
@onready var buttons_container = $VBoxContainer

var last_hover_time: int = 0
var last_click_time: int = 0

func _ready():
	_setup_audio()
	_connect_buttons()
	_start_logo_animation()

func _setup_audio():
	hover_player = AudioStreamPlayer.new()
	hover_player.stream = load(HOVER_SFX_PATH)
	hover_player.max_polyphony = 4 
	add_child(hover_player)
	
	click_player = AudioStreamPlayer.new()
	click_player.stream = load(CLICK_SFX_PATH)
	add_child(click_player)

func _connect_buttons():
	for button in buttons_container.get_children():
		if button is Button:
			button.mouse_entered.connect(_on_button_hover)
			button.pressed.connect(_on_button_pressed)
		if button.name == "play":
			button.pressed.connect(_on_play_pressed)
		elif button.name == "settings":
			button.pressed.connect(_on_settings_pressed)
		elif button.name == "exit":
			button.pressed.connect(_on_exit_pressed)


func _on_play_pressed():
	const GOKU := preload("res://characters/goku/goku.tscn")
	const ARCHIPELAGO := preload("res://stages/Archipelago/archipelago.tscn")
	GameManager.start_fight(ARCHIPELAGO, GOKU, GOKU)

func _on_settings_pressed():
	get_tree().change_scene_to_file(CONTROLS_MENU_PATH)

func _on_exit_pressed():
	get_tree().quit()

func _on_button_hover():
	var current_time = Time.get_ticks_msec()
	# Cooldown exacto de 150ms. Sonido intacto.
	if current_time - last_hover_time > 150:
		hover_player.play()
		last_hover_time = current_time

func _on_button_pressed():
	var current_time = Time.get_ticks_msec()
	if current_time - last_click_time > 150:
		click_player.play()
		last_click_time = current_time

func _start_logo_animation():
	# Toma la escala gigante (7.5) que le diste en el editor
	var base_scale = logo.scale 
	var target_scale = base_scale * 1.04 # Crece un 4%
	
	var tween = create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Animación fluida
	tween.tween_property(logo, "scale", target_scale, 2.0)
	tween.tween_property(logo, "scale", base_scale, 2.0)
