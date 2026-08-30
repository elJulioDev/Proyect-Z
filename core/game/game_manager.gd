extends Node
## Flujo de partida: guarda qué personajes pelean y en qué escenario,
## orquesta la pelea: instancia stage, fighters, HUD y debug.

const Controllers := preload("res://core/character/controllers.gd")
const HUDScene := preload("res://ui/hud/hud.tscn")
const DebugScene := preload("res://ui/debug_overlay/debug_overlay.tscn")
const FightManagerScene := preload("res://core/game/fight_manager.gd")
const AnnouncerScene := preload("res://ui/fight_announcer/fight_announcer.tscn")
const PauseMenuScene := preload("res://ui/menus/pause_menu/pause_menu.tscn")
const BGM_DIR := "res://assets/audio/bgm"

## Roster de personajes disponibles. Agregar un personaje nuevo = agregar una entrada.
const ROSTER := {
	"goku": {
		"display_name": "Son Goku",
		"data": "res://characters/goku/goku.tres",
		"icon": "res://characters/goku/icon.png",
	},
}

const BASE_STAGE_SCENE := preload("res://stages/base/base_stage.tscn")
const BASE_CHARACTER_SCENE := preload("res://characters/base/base_character.tscn")

## id de stage -> path del .tres. Se llena automáticamente en _ready()
## escaneando res://stages/ (excluyendo la carpeta "base").
var stages: Dictionary = {}

var p1_data: CharacterData
var p2_data: CharacterData
var p2_dummy := true
var current_stage_path: String = ""
var match_time := 0
var _fight_manager: Node
var pending_p1: String
var pending_p2: String
var _bgm_player: AudioStreamPlayer
var _pause_menu: CanvasLayer = null


func _ready() -> void:
	_setup_custom_cursors()
	_discover_stages()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if get_tree().current_scene is BaseStage:
				_toggle_pause_menu()
				get_viewport().set_input_as_handled()

func _setup_custom_cursors() -> void:
	var base_path := "res://assets/ui/cursor/"

	# Usar constantes del enum Input.CursorShape directamente (Godot 4)
	Input.set_custom_mouse_cursor(load(base_path + "pointer_c.svg"), Input.CURSOR_ARROW, Vector2(0, 0))
	Input.set_custom_mouse_cursor(load(base_path + "line_vertical.svg"), Input.CURSOR_IBEAM, Vector2(16, 16))
	Input.set_custom_mouse_cursor(load(base_path + "hand_point.svg"), Input.CURSOR_POINTING_HAND, Vector2(8, 8))
	Input.set_custom_mouse_cursor(load(base_path + "cross_small.svg"), Input.CURSOR_CROSS, Vector2(16, 16))
	Input.set_custom_mouse_cursor(load(base_path + "busy_hourglass.svg"), Input.CURSOR_WAIT, Vector2(16, 16))
	Input.set_custom_mouse_cursor(load(base_path + "busy_circle.svg"), Input.CURSOR_BUSY, Vector2(16, 16))
	Input.set_custom_mouse_cursor(load(base_path + "cursor_help.svg"), Input.CURSOR_HELP, Vector2(16, 16))

	# Resize por eje (Godot 4 no tiene cursores individuales UP/DOWN/LEFT/RIGHT)
	Input.set_custom_mouse_cursor(load(base_path + "resize_a_vertical.svg"), Input.CURSOR_VSIZE, Vector2(16, 16))
	Input.set_custom_mouse_cursor(load(base_path + "resize_a_horizontal.svg"), Input.CURSOR_HSIZE, Vector2(16, 16))
	Input.set_custom_mouse_cursor(load(base_path + "arrow_nw.svg"), Input.CURSOR_BDIAGSIZE, Vector2(16, 16))
	Input.set_custom_mouse_cursor(load(base_path + "arrow_ne.svg"), Input.CURSOR_FDIAGSIZE, Vector2(16, 16))
	Input.set_custom_mouse_cursor(load(base_path + "resize_a_cross.svg"), Input.CURSOR_MOVE, Vector2(16, 16))

	# Opcionales disponibles en el enum (no mapeados por falta de assets):
	# Input.CURSOR_DRAG, Input.CURSOR_CAN_DROP, Input.CURSOR_FORBIDDEN
	# Input.CURSOR_VSPLIT, Input.CURSOR_HSPLIT

	# Cursor oculto: Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _discover_stages() -> void:
	stages.clear()
	var root := DirAccess.open("res://stages")
	if root == null:
		return
	root.list_dir_begin()
	var folder := root.get_next()
	while folder != "":
		if root.current_is_dir() and folder != "base" and not folder.begins_with("."):
			var sub := DirAccess.open("res://stages/%s" % folder)
			if sub:
				sub.list_dir_begin()
				var f := sub.get_next()
				while f != "":
					if not sub.current_is_dir() and f.ends_with(".tres") and not f.begins_with("filter_"):
						var path := "res://stages/%s/%s" % [folder, f]
						var data: StageData = load(path)
						if data and data.id != "":
							stages[data.id] = path
					f = sub.get_next()
				sub.list_dir_end()
		folder = root.get_next()
	root.list_dir_end()


func start_fight(p1_data_path: String, p2_data_path: String, stage_path: String, p_match_time: int = 0) -> void:
	p1_data = load(p1_data_path)
	p2_data = load(p2_data_path)
	current_stage_path = stage_path
	match_time = p_match_time
	_close_pause_menu()
	TransitionManager.transition(0.8, 0.5, 0.8, func():
		_do_fight()
	)


func _do_fight() -> void:
	# Stage: entra al árbol primero para que sus @onready se asignen
	var stage: BaseStage = BASE_STAGE_SCENE.instantiate()
	stage.stage_data = load(current_stage_path)
	var old_scene := get_tree().current_scene
	get_tree().root.add_child(stage)
	get_tree().current_scene = stage
	if old_scene:
		old_scene.queue_free()
	# BGM aleatorio
	_play_random_bgm()
	# Fighters
	var p1: BaseCharacter = BASE_CHARACTER_SCENE.instantiate()
	var p2: BaseCharacter = BASE_CHARACTER_SCENE.instantiate()
	p1.character_data = p1_data
	p2.character_data = p2_data
	p1.name = "BaseCharacter"
	p2.name = "Player2"
	# Controllers antes de add_child para evitar wasted instantiation
	if p2_dummy:
		p2.set_controller(Controllers.KeyboardControllerP2.new())
	stage.add_child(p1)
	stage.add_child(p2)
	p1.global_position = stage.p1_spawn.global_position
	p2.global_position = stage.p2_spawn.global_position
	p1.controller.opponent = p2
	p2.controller.opponent = p1
	# Player refs para cámara
	stage.player1 = p1
	stage.player2 = p2
	# HUD y debug
	var hud: CanvasLayer = HUDScene.instantiate()
	stage.add_child(hud)
	hud.setup(p1, p2)
	var debug: CanvasLayer = DebugScene.instantiate()
	stage.add_child(debug)
	debug.setup(p1, p2)
	# Fight manager
	_fight_manager = FightManagerScene.new()
	_fight_manager.setup(p1, p2, match_time, hud)
	_fight_manager.round_ended.connect(_on_round_ended.bind(stage))
	_fight_manager.fight_ended.connect(_on_fight_ended)
	add_child(_fight_manager)
	# Announcer
	var announcer: CanvasLayer = AnnouncerScene.instantiate()
	stage.add_child(announcer)
	announcer.show_text("ROUND 1", 1.35, 0.3)
	await get_tree().create_timer(1.8).timeout
	announcer.show_text("FIGHT!", 0.6, 0.3)
	await get_tree().create_timer(0.75).timeout
	_fight_manager.start_round()


func _on_round_ended(_winner: int, stage: BaseStage) -> void:
	var announcer := stage.get_node_or_null("FightAnnouncer") as CanvasLayer
	if announcer:
		announcer.show_ko()


func _on_fight_ended(_final_winner: int) -> void:
	await get_tree().create_timer(2.5).timeout
	return_to_menu()


func _toggle_pause_menu() -> void:
	if _pause_menu and is_instance_valid(_pause_menu):
		_pause_menu.hide_menu()
		_pause_menu.queue_free()
		_pause_menu = null
	else:
		_open_pause_menu()


func _open_pause_menu() -> void:
	_pause_menu = PauseMenuScene.instantiate()
	get_tree().current_scene.add_child(_pause_menu)
	_pause_menu.show_menu()


func _close_pause_menu() -> void:
	if _pause_menu and is_instance_valid(_pause_menu):
		_pause_menu.hide_menu()
		_pause_menu.queue_free()
		_pause_menu = null


func return_to_menu() -> void:
	_close_pause_menu()
	_stop_bgm()
	if _fight_manager:
		_fight_manager.queue_free()
		_fight_manager = null
	TransitionManager.transition(0.8, 0.5, 0.8, func():
		get_tree().change_scene_to_file("res://ui/menus/main_menu/menu.tscn")
	)


func _play_random_bgm() -> void:
	_stop_bgm()
	var dir := DirAccess.open(BGM_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var tracks: PackedStringArray = []
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.ends_with(".mp3"):
			tracks.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	if tracks.is_empty():
		return
	var idx := randi() % tracks.size()
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.stream = load(BGM_DIR + "/" + tracks[idx])
	add_child(_bgm_player)
	_bgm_player.finished.connect(_play_random_bgm)
	_bgm_player.play()


func _stop_bgm() -> void:
	if _bgm_player:
		_bgm_player.stop()
		_bgm_player.queue_free()
		_bgm_player = null
