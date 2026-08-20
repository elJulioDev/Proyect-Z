extends Node
## Flujo de partida: guarda qué personajes pelean y en qué escenario,
## orquesta la pelea: instancia stage, fighters, HUD y debug.

const Controllers := preload("res://core/controllers.gd")
const HUDScene := preload("res://ui/hud/hud.tscn")
const DebugScene := preload("res://ui/debug_overlay/debug_overlay.tscn")
const FightManagerScene := preload("res://core/fight_manager.gd")
const AnnouncerScene := preload("res://ui/fight_announcer/fight_announcer.tscn")

## Roster de personajes disponibles. Agregar un personaje nuevo = agregar una entrada.
const ROSTER := {
	"goku": {
		"display_name": "Son Goku",
		"scene": "res://characters/goku/goku.tscn",
		"icon": "res://characters/goku/icon.png",
	},
}

const BASE_STAGE_SCENE := preload("res://stages/base/base_stage.tscn")

## id de stage -> path del .tres. Se llena automáticamente en _ready()
## escaneando res://stages/ (excluyendo la carpeta "base").
var stages: Dictionary = {}

var p1_scene: PackedScene
var p2_scene: PackedScene
var p2_dummy := true
var current_stage_path: String = ""
var _fight_manager: Node
var pending_p1: PackedScene
var pending_p2: PackedScene


func _ready() -> void:
	_discover_stages()


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
					if not sub.current_is_dir() and f.ends_with(".tres"):
						var path := "res://stages/%s/%s" % [folder, f]
						var data: StageData = load(path)
						if data and data.id != "":
							stages[data.id] = path
					f = sub.get_next()
				sub.list_dir_end()
		folder = root.get_next()
	root.list_dir_end()


func start_fight(p1: PackedScene, p2: PackedScene, stage_path: String) -> void:
	p1_scene = p1
	p2_scene = p2
	current_stage_path = stage_path
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
	# Fighters
	var p1: BaseCharacter = p1_scene.instantiate()
	var p2: BaseCharacter = p2_scene.instantiate()
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
	_fight_manager.setup(p1, p2)
	_fight_manager.round_ended.connect(_on_round_ended.bind(stage))
	_fight_manager.fight_ended.connect(_on_fight_ended)
	add_child(_fight_manager)
	# Announcer
	var announcer: CanvasLayer = AnnouncerScene.instantiate()
	stage.add_child(announcer)
	announcer.show_text("ROUND 1")
	await get_tree().create_timer(1.5).timeout
	announcer.show_text("FIGHT!")
	await get_tree().create_timer(0.8).timeout
	announcer.label.modulate.a = 0.0
	_fight_manager.start_round()


func _on_round_ended(_winner: int, stage: BaseStage) -> void:
	var announcer := stage.get_node_or_null("FightAnnouncer") as CanvasLayer
	if announcer:
		announcer.show_ko()


func _on_fight_ended(_final_winner: int) -> void:
	await get_tree().create_timer(2.5).timeout
	return_to_menu()


func return_to_menu() -> void:
	if _fight_manager:
		_fight_manager.queue_free()
		_fight_manager = null
	TransitionManager.transition(0.8, 0.5, 0.8, func():
		get_tree().change_scene_to_file("res://ui/menus/main_menu/menu.tscn")
	)
