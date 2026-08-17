extends Node
## Flujo de partida: guarda qué personajes pelean y en qué escenario,
## y cambia de escena. Los personajes se instancian en el escenario
## (ver BaseStage._spawn_fighters).

var p1_scene: PackedScene = preload("res://characters/goku/goku.tscn")
var p2_scene: PackedScene = preload("res://characters/goku/goku.tscn")
var p2_dummy := true


func start_fight(stage: PackedScene, fighter1: PackedScene, fighter2: PackedScene) -> void:
	p1_scene = fighter1
	p2_scene = fighter2
	get_tree().change_scene_to_packed(stage)
