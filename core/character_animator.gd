class_name CharacterAnimator extends AnimatedSprite2D
## Anima al personaje a partir de su CharacterData.
## Dos fuentes:
##  - sprite_dir: una carpeta por animación (<sprite_dir>/<anim>/<anim>_000.png...)
##  - sprite + AnimData.frames (Rect2 sobre una hoja)
## No hay que editar animaciones a mano: usa tools/slice_sprite.gd y
## tools/build_character_data.gd para generarlas.
## offsets en AnimData ajustan la posición Y del region Rect2 por frame
## (desplaza qué fila de píxeles se captura de la hoja, sin afectar colisión).

var _current_data: CharacterData

func setup(data: CharacterData) -> void:
	if data == null:
		return
	_current_data = data
	var frames: SpriteFrames
	if data.sprite_dir != "":
		frames = _frames_from_dir(data)
	else:
		frames = _frames_from_sheet(data)
	if frames == null:
		return
	sprite_frames = frames
	play("idle")


func _frames_from_dir(data: CharacterData) -> SpriteFrames:
	var frames := SpriteFrames.new()
	for anim_id in data.animations:
		var anim: AnimData = data.animations[anim_id]
		var dir := DirAccess.open(data.sprite_dir + "/" + anim_id)
		if dir == null:
			continue
		var pngs: Array = []
		for f in dir.get_files():
			if f.ends_with(".png"):
				pngs.append(f)
		pngs.sort_custom(func(a: String, b: String) -> bool:
			return _frame_number(a) < _frame_number(b))
		if pngs.is_empty():
			continue
		frames.add_animation(anim_id)
		frames.set_animation_speed(anim_id, anim.fps)
		frames.set_animation_loop(anim_id, anim.loop)
		for f in pngs:
			frames.add_frame(anim_id, load(data.sprite_dir + "/" + anim_id + "/" + f))
	return frames


func _frames_from_sheet(data: CharacterData) -> SpriteFrames:
	if data.sprite == null:
		return null
	
	var frames := SpriteFrames.new()
	for anim_id in data.animations:
		var anim: AnimData = data.animations[anim_id]
		if anim == null or anim.frames.is_empty():
			continue
			
		frames.add_animation(anim_id)
		frames.set_animation_speed(anim_id, anim.fps)
		frames.set_animation_loop(anim_id, anim.loop)
		
		for i in anim.frames.size():
			var rect: Rect2 = anim.frames[i]
			
			# ¡ELIMINADO! Ya no sumamos el offset al rect.position
			
			var at := AtlasTexture.new()
			at.atlas = data.sprite
			at.region = rect
			frames.add_frame(anim_id, at)
			
	return frames


func _frame_number(file_name: String) -> int:
	var m := RegEx.create_from_string(r"(\d+)")
	var r := m.search(file_name)
	return int(r.get_string(1)) if r else 0


func play_anim(anim_id: String) -> void:
	if sprite_frames == null:
		return
	if sprite_frames.has_animation(anim_id):
		if animation != anim_id:
			play(anim_id)

func _process(_delta: float) -> void:
	if _current_data == null:
		return
		
	var anim_name = animation
	if _current_data.animations.has(anim_name):
		var anim: AnimData = _current_data.animations[anim_name]
		if frame < anim.offsets.size():
			var cur_offset = anim.offsets[frame]
			# Aplicamos el offset visual, invirtiendo X si Goku mira al otro lado
			offset = Vector2(-cur_offset.x if flip_h else cur_offset.x, cur_offset.y)
		else:
			offset = Vector2.ZERO