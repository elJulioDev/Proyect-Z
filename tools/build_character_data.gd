extends SceneTree
## Genera un CharacterData (.tres) escaneando una carpeta de sprites individuales:
## cada subcarpeta de <sprite_dir> es una animación (nombre = id de la animación).
## Uso:
##   godot --headless -s tools/build_character_data.gd -- <sprite_dir> <salida.tres> [fps]
## Ej:
##   godot --headless -s tools/build_character_data.gd -- res://characters/goku/sprites res://characters/goku/goku.tres 8

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Uso: -- <sprite_dir> <salida.tres> [fps]")
		quit(1)
		return
	var sprite_dir := args[0].trim_suffix("/")
	var out := args[1]
	var fps := float(args[2]) if args.size() > 2 else 8.0

	var data: CharacterData = load("res://core/character_data.gd").new()
	data.id = sprite_dir.get_file()
	data.display_name = sprite_dir.get_file()
	data.sprite_dir = sprite_dir

	var d := DirAccess.open(sprite_dir)
	if d == null:
		push_error("No se pudo abrir: " + sprite_dir)
		quit(1)
		return
	var anims: Array = d.get_directories()
	anims.sort()
	for anim_id in anims:
		var ad: AnimData = load("res://core/anim_data.gd").new()
		ad.fps = fps
		ad.loop = true
		data.animations[anim_id] = ad

	if data.animations.is_empty():
		push_error("No hay animaciones en " + sprite_dir)
		quit(1)
		return
	ResourceSaver.save(data, out)
	print("Guardado: ", out, " | ", data.animations.size(), " animaciones: ", anims)
	quit(0)
