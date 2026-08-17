extends SceneTree
## Convierte un SpriteFrames .tres (spritesheetgenerator.online) a CharacterData .tres
## Uso:
##   godot --headless -s tools/spriteframes_to_character_data.gd -- <spriteframes.tres> <output.tres> [fps]

const DEFAULT_FPS := 8


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Uso: -- <spriteframes.tres> <output.tres> [fps]")
		quit(1)
		return
	var sf_path := args[0]
	var out_path := args[1]
	var fps := int(args[2]) if args.size() > 2 else DEFAULT_FPS
	var sf := load(sf_path) as SpriteFrames
	if sf == null:
		push_error("No se pudo cargar SpriteFrames: " + sf_path)
		quit(1)
		return
	var anim_names: PackedStringArray = sf.get_animation_names()
	if anim_names.is_empty():
		push_error("SpriteFrames sin animaciones")
		quit(1)
	# Resolve sheet path relative to project
	var sheet_res_path := ""
	var anim := anim_names[0]
	var frame_count := sf.get_frame_count(anim)
	var frames_str := ""
	for i in frame_count:
		var tex: Texture2D = sf.get_frame_texture(anim, i)
		if tex == null:
			continue
		if tex is AtlasTexture:
			var atlas: AtlasTexture = tex
			if sheet_res_path.is_empty() and atlas.atlas != null:
				sheet_res_path = atlas.atlas.resource_path
			var r: Rect2 = atlas.region
			if frames_str != "":
				frames_str += ", "
			frames_str += "Rect2(%d, %d, %d, %d)" % [int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)]
	if sheet_res_path.is_empty():
		push_error("No se encontró textura del spritesheet")
		quit(1)
	# Make path relative
	if sheet_res_path.begins_with("res://"):
		sheet_res_path = sheet_res_path.substr(6)
	# Write CharacterData .tres
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("No se pudo escribir: " + out_path)
		quit(1)
		f = null
		return
	f.store_string('''[gd_resource type="Resource" script_class="CharacterData" load_steps=3 format=3]

[ext_resource type="Script" path="res://core/character_data.gd" id="1"]
[ext_resource type="Script" path="res://core/anim_data.gd" id="2"]

[sub_resource type="Resource" script_class="AnimData" id="AnimData_1"]
script = ExtResource("2")
frames = [%s]
fps = %d
loop = true

[resource]
script = ExtResource("1")
stats = {
"speed": 420,
"life": 100,
"defense": 17
}
sprite_dir = ""
sprite = "%s"
animations = {
"default": SubResource("AnimData_1")
}
attacks = {}
combos = {}
mechanics = {}
forms = {}
sfx = {}
''' % [frames_str, fps, sheet_res_path])
	f = null
	print("Generado: ", out_path)
	print("  sheet: ", sheet_res_path)
	print("  frames: ", frame_count)
	print("  fps: ", fps)
	print("")
	print("NOTA: Todos los frames están en 'default'. Edita el .tres para")
	print("separar en animaciones (idle, walk, punch, etc.) reorganizando")
	print("los Rect2 en los campos de 'animations'.")
	quit(0)
