extends Control
## Herramienta visual: instancia BaseCharacter real para renderizar
## exactamente como en gameplay. Ajusta hitbox/hurtbox/dust y guarda al .tres.

const CharacterScene := preload("res://characters/base/base_character.tscn")

const BASE_HITBOX_SIZE := Vector2(50, 40)
const BASE_HURTBOX_SIZE := Vector2(30, 45)


var character_data: CharacterData
var _character: BaseCharacter
var _anims: Array = []
var _current_anim := ""
var _current_frame := 0
var _attacks: Array = []
var _current_attack: AttackData = null
var _hk_by_frame: Dictionary = {}
var _hbk_by_frame: Dictionary = {}
var _dragging := false
var _drag_type := ""
var _drag_offset := Vector2.ZERO
var _show_hitbox := true
var _show_hurtbox := true
var _show_dust := true
var _dust_keys := ["dust1", "dust2", "dust3", "dust4"]
var _current_dust := "dust1"
var _playing := false
var _floor_y := 45.0

var _preview: SubViewport
var _camera: Camera2D
var _panning := false
var _pan_start := Vector2.ZERO
var _draw_node: Node2D
var _floor_body: StaticBody2D
var _frame_label: Label
var _anim_option: OptionButton
var _attack_option: OptionButton
var _info_label: Label
var _hb_detail_label: Label
var _dust_offset_x: SpinBox
var _dust_offset_y: SpinBox
var _dust_frame_offsets: TextEdit
var _data_path_label: Label
var _hb_size_x: SpinBox
var _hb_size_y: SpinBox
var _hr_size_x: SpinBox
var _hr_size_y: SpinBox
var _dust_option: OptionButton
var _floor_spin: SpinBox
var _hb_offset_x: SpinBox
var _hb_offset_y: SpinBox
var _hr_offset_x: SpinBox
var _hr_offset_y: SpinBox
var _frame_offset_x: SpinBox
var _frame_offset_y: SpinBox
var _frame_offset_label: Label


func _ready() -> void:
	_build_ui()
	_setup_viewport()
	call_deferred("_load_data", "res://characters/goku/goku.tres")


func _setup_viewport() -> void:
	_draw_node = Node2D.new()
	_draw_node.set_script(preload("res://tools/character_tool/draw_overlay.gd"))
	_draw_node.tool_ref = self
	_draw_node.name = "DrawOverlay"
	_draw_node.z_index = 10
	_preview.add_child(_draw_node)

	# Suelo estático para que FloorRay detecte suelo y sombra se renderice
	_floor_body = StaticBody2D.new()
	_floor_body.position = Vector2(320, 370)
	var shape := WorldBoundaryShape2D.new()
	shape.normal = Vector2.UP
	shape.distance = 330.0
	var col := CollisionShape2D.new()
	col.shape = shape
	_floor_body.add_child(col)
	_preview.add_child(_floor_body)

func _build_ui() -> void:
	var split := HSplitContainer.new()
	split.set_anchors_preset(PRESET_FULL_RECT)
	split.split_offset = 500
	add_child(split)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	left.size_flags_vertical = SIZE_EXPAND_FILL
	split.add_child(left)

	var tb1 := HBoxContainer.new()
	left.add_child(tb1)
	_data_path_label = Label.new()
	_data_path_label.text = "Sin datos"
	_data_path_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_data_path_label.clip_text = true
	tb1.add_child(_data_path_label)
	var load_btn := Button.new()
	load_btn.text = "Cargar .tres"
	load_btn.pressed.connect(_on_load_pressed)
	tb1.add_child(load_btn)

	var tb2 := HBoxContainer.new()
	left.add_child(tb2)
	tb2.add_child(_lbl("Anim: "))
	_anim_option = OptionButton.new()
	_anim_option.size_flags_horizontal = SIZE_EXPAND_FILL
	_anim_option.item_selected.connect(_on_anim_selected)
	tb2.add_child(_anim_option)
	tb2.add_child(_lbl(" Ataque: "))
	_attack_option = OptionButton.new()
	_attack_option.size_flags_horizontal = SIZE_EXPAND_FILL
	_attack_option.item_selected.connect(_on_attack_selected)
	tb2.add_child(_attack_option)

	var tb3 := HBoxContainer.new()
	tb3.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(tb3)
	_nav(tb3, "|<", func(): _goto_frame(0))
	_nav(tb3, "<", func(): _goto_frame(_current_frame - 1))
	_frame_label = Label.new()
	_frame_label.text = "0 / 0"
	_frame_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_frame_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tb3.add_child(_frame_label)
	_nav(tb3, ">", func(): _goto_frame(_current_frame + 1))
	_nav(tb3, ">|", func(): _goto_frame(9999))
	var bp := Button.new()
	bp.text = "Play"
	bp.toggle_mode = true
	bp.pressed.connect(_toggle_play)
	tb3.add_child(bp)
	var cam_reset := Button.new()
	cam_reset.text = "Reset Cam"
	cam_reset.pressed.connect(func(): _camera.position = Vector2(320, 240); _camera.zoom = Vector2(2, 2))
	tb3.add_child(cam_reset)

	var vc := SubViewportContainer.new()
	vc.size_flags_horizontal = SIZE_EXPAND_FILL
	vc.size_flags_vertical = SIZE_EXPAND_FILL
	vc.stretch = true
	vc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	left.add_child(vc)

	_preview = SubViewport.new()
	_preview.size = Vector2i(640, 480)
	_preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vc.add_child(_preview)
	RenderingServer.viewport_set_default_canvas_item_texture_filter(
		_preview.get_viewport_rid(), RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	vc.gui_input.connect(_on_viewport_input)

	_camera = Camera2D.new()
	_camera.position = Vector2(320, 240)
	_camera.zoom = Vector2(2, 2)
	_preview.add_child(_camera)
	_camera.make_current()

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 280
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	split.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	right.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(inner)

	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	inner.add_child(_info_label)
	_hb_detail_label = Label.new()
	_hb_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_hb_detail_label.add_theme_font_size_override("font_size", 12)
	inner.add_child(_hb_detail_label)
	inner.add_child(HSeparator.new())

	inner.add_child(_sec("-- Hitbox --"))
	var hbv := HBoxContainer.new()
	inner.add_child(hbv)
	var ch := CheckBox.new()
	ch.text = "Visible"
	ch.button_pressed = true
	ch.toggled.connect(func(v): _show_hitbox = v; _draw_node.queue_redraw())
	hbv.add_child(ch)
	inner.add_child(_lbl("Offset:"))
	var hbo := HBoxContainer.new()
	inner.add_child(hbo)
	_hb_offset_x = _sb(-300, 300, 0); _hb_offset_x.value_changed.connect(_sync_hb)
	_hb_offset_y = _sb(-300, 300, 0); _hb_offset_y.value_changed.connect(_sync_hb)
	hbo.add_child(_lbl("X:")); hbo.add_child(_hb_offset_x)
	hbo.add_child(_lbl("Y:")); hbo.add_child(_hb_offset_y)
	inner.add_child(_lbl("Size:"))
	var hbs := HBoxContainer.new()
	inner.add_child(hbs)
	_hb_size_x = _sb(1, 500, 50); _hb_size_x.value_changed.connect(_sync_hb)
	_hb_size_y = _sb(1, 500, 40); _hb_size_y.value_changed.connect(_sync_hb)
	hbs.add_child(_lbl("X:")); hbs.add_child(_hb_size_x)
	hbs.add_child(_lbl("Y:")); hbs.add_child(_hb_size_y)
	inner.add_child(HSeparator.new())

	inner.add_child(_sec("-- Hurtbox --"))
	var hrv := HBoxContainer.new()
	inner.add_child(hrv)
	var ch2 := CheckBox.new()
	ch2.text = "Visible"
	ch2.button_pressed = true
	ch2.toggled.connect(func(v): _show_hurtbox = v; _draw_node.queue_redraw())
	hrv.add_child(ch2)
	inner.add_child(_lbl("Offset:"))
	var hro := HBoxContainer.new()
	inner.add_child(hro)
	_hr_offset_x = _sb(-300, 300, 0); _hr_offset_x.value_changed.connect(_sync_hr)
	_hr_offset_y = _sb(-300, 300, 0); _hr_offset_y.value_changed.connect(_sync_hr)
	hro.add_child(_lbl("X:")); hro.add_child(_hr_offset_x)
	hro.add_child(_lbl("Y:")); hro.add_child(_hr_offset_y)
	inner.add_child(_lbl("Size:"))
	var hrs := HBoxContainer.new()
	inner.add_child(hrs)
	_hr_size_x = _sb(1, 500, 30); _hr_size_x.value_changed.connect(_sync_hr)
	_hr_size_y = _sb(1, 500, 45); _hr_size_y.value_changed.connect(_sync_hr)
	hrs.add_child(_lbl("X:")); hrs.add_child(_hr_size_x)
	hrs.add_child(_lbl("Y:")); hrs.add_child(_hr_size_y)

	var del := Button.new()
	del.text = "Eliminar keyframe"
	del.pressed.connect(_on_delete)
	inner.add_child(del)
	inner.add_child(HSeparator.new())

	inner.add_child(_sec("-- Sprite Offset (AnimData) --"))
	_frame_offset_label = Label.new()
	_frame_offset_label.text = "Frame 0 / sin anim"
	_frame_offset_label.add_theme_font_size_override("font_size", 11)
	inner.add_child(_frame_offset_label)
	var so := HBoxContainer.new()
	inner.add_child(so)
	so.add_child(_lbl("X:"))
	_frame_offset_x = _sb(-500, 500, 0)
	_frame_offset_x.value_changed.connect(_sync_frame_offset)
	so.add_child(_frame_offset_x)
	so.add_child(_lbl("Y:"))
	_frame_offset_y = _sb(-500, 500, 0)
	_frame_offset_y.value_changed.connect(_sync_frame_offset)
	so.add_child(_frame_offset_y)
	inner.add_child(HSeparator.new())

	inner.add_child(_sec("-- Dust VFX --"))
	var dv := HBoxContainer.new()
	inner.add_child(dv)
	var ch3 := CheckBox.new()
	ch3.text = "Visible"
	ch3.button_pressed = true
	ch3.toggled.connect(func(v): _show_dust = v; _draw_node.queue_redraw())
	dv.add_child(ch3)
	var ds := HBoxContainer.new()
	inner.add_child(ds)
	_dust_option = OptionButton.new()
	for dk in _dust_keys:
		_dust_option.add_item(dk)
	_dust_option.item_selected.connect(func(i): _current_dust = _dust_keys[i])
	ds.add_child(_dust_option)
	var d_off := HBoxContainer.new()
	inner.add_child(d_off)
	d_off.add_child(_lbl("Offset:"))
	_dust_offset_x = _sb(-500, 500, 0); _dust_offset_x.value_changed.connect(func(_v): _draw_node.queue_redraw())
	_dust_offset_y = _sb(-500, 500, 0); _dust_offset_y.value_changed.connect(func(_v): _draw_node.queue_redraw())
	d_off.add_child(_dust_offset_x); d_off.add_child(_dust_offset_y)
	_dust_frame_offsets = TextEdit.new()
	_dust_frame_offsets.custom_minimum_size.y = 60
	_dust_frame_offsets.placeholder_text = "[Vector2(0,0), ...]"
	inner.add_child(_lbl("Offsets por frame:"))
	inner.add_child(_dust_frame_offsets)
	inner.add_child(HSeparator.new())

	var fb := HBoxContainer.new()
	inner.add_child(fb)
	fb.add_child(_lbl("Floor Y: "))
	_floor_spin = _sb(0, 400, 45)
	_floor_spin.value_changed.connect(func(v): _floor_y = v; _draw_node.queue_redraw())
	fb.add_child(_floor_spin)
	inner.add_child(HSeparator.new())

	var sv := Button.new()
	sv.text = "Guardar .tres"
	sv.pressed.connect(_on_save)
	inner.add_child(sv)


func _lbl(t: String) -> Label:
	var l := Label.new(); l.text = t; return l

func _sec(t: String) -> Label:
	var l := Label.new(); l.text = t; l.add_theme_font_size_override("font_size", 14); return l

func _sb(mn: float, mx: float, v: float) -> SpinBox:
	var s := SpinBox.new(); s.min_value = mn; s.max_value = mx; s.value = v; s.custom_minimum_size.x = 80; return s

func _nav(p: HBoxContainer, t: String, cb: Callable) -> void:
	var b := Button.new(); b.text = t; b.custom_minimum_size.x = 36; b.pressed.connect(cb); p.add_child(b)

func _on_load_pressed() -> void:
	var d := FileDialog.new()
	d.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	d.access = FileDialog.ACCESS_RESOURCES
	d.filters = PackedStringArray(["*.tres ; Character Data"])
	d.file_selected.connect(_load_data)
	add_child(d)
	d.popup_centered(Vector2i(800, 500))


func _load_data(path: String) -> void:
	var res := load(path)
	if res == null or not res is CharacterData:
		_info_label.text = "Error: " + path
		return
	character_data = res
	_data_path_label.text = path
	_load_animations()
	_load_attacks()
	_spawn_character()
	_info_label.text = "Cargado: " + path


func _load_animations() -> void:
	_anim_option.clear()
	_anims.clear()
	_anim_option.add_item("-- Seleccionar --")
	for key in character_data.animations:
		_anims.append(key)
	_anims.sort()
	for a in _anims:
		_anim_option.add_item(a)
	if _anims.size() > 0:
		_anim_option.selected = 1
		_on_anim_selected(1)


func _load_attacks() -> void:
	_attack_option.clear()
	_attacks.clear()
	_attack_option.add_item("-- Ninguno --")
	for key in character_data.attacks:
		_attacks.append(key)
		_attack_option.add_item(key)
	if _attacks.size() > 0:
		_attack_option.selected = 0


func _spawn_character() -> void:
	if _character:
		_character.queue_free()
		_character = null
	if character_data == null:
		push_warning("Tool: character_data es null")
		return
	_character = CharacterScene.instantiate()
	_character.character_data = character_data
	_character.position = Vector2(320, 285)
	_character.facing_right = true
	_preview.add_child(_character)
	if not (_character is BaseCharacter):
		push_error("La escena instanciada no es BaseCharacter — revisa que base_character.gd compile sin errores")
		return
	# DESPUÉS de add_child: _ready() ya corrió (animator.setup, state_machine)
	# Congelar física y estado
	_character.set_physics_process(false)
	_character.velocity = Vector2.ZERO
	if _character.state_machine:
		_character.state_machine.set_physics_process(false)
	if _character.combat:
		_character.combat.set_physics_process(false)
	# Congelar animación
	if _character.animator.sprite_frames:
		_character.animator.play_anim("idle")
		_character.animator.stop()
		_character.animator.frame = 0
	# Posicionar sombra directamente (FloorRay puede no colisionar en SubViewport)
	_update_shadow_tool()
	_current_frame = 0
	_update_frame_label()
	_draw_node.queue_redraw()


func _on_anim_selected(idx: int) -> void:
	if idx <= 0 or idx > _anims.size():
		return
	_current_anim = _anims[idx - 1]
	_current_frame = 0
	if _character:
		_character.animator.play_anim(_current_anim)
		_character.animator.stop()
		_character.animator.frame = 0
		_update_shadow_tool()
	_load_attack_keyframes()
	_update_frame_label()
	_update_frame_info()
	_draw_node.queue_redraw()


func _on_attack_selected(idx: int) -> void:
	if idx <= 0 or idx > _attacks.size():
		_current_attack = null
		_hk_by_frame.clear()
		_hbk_by_frame.clear()
		_update_frame_info()
		_draw_node.queue_redraw()
		return
	_current_attack = character_data.attacks.get(_attacks[idx - 1], null)
	_load_attack_keyframes()
	_update_frame_info()
	_draw_node.queue_redraw()


func _load_attack_keyframes() -> void:
	_hk_by_frame.clear()
	_hbk_by_frame.clear()
	if _current_attack == null:
		return
	for hk in _current_attack.hitbox_keyframes:
		_hk_by_frame[hk.frame] = hk
	for hbk in _current_attack.hurtbox_keyframes:
		_hbk_by_frame[hbk.frame] = hbk

func _goto_frame(f: int) -> void:
	if _character == null or _character.animator == null:
		return
	var sf := _character.animator.sprite_frames
	if sf == null:
		return
	var max_f := sf.get_frame_count(_current_anim) - 1
	_current_frame = clampi(f, 0, max_f)
	_character.animator.stop()
	_character.animator.frame = _current_frame
	_update_shadow_tool()
	_update_frame_label()
	_update_frame_info()
	_draw_node.queue_redraw()


func _toggle_play() -> void:
	if _character == null:
		return
	_playing = not _playing
	if _playing:
		_character.animator.play(_current_anim)
	else:
		_character.animator.stop()
		_current_frame = _character.animator.frame
		_update_shadow_tool()
		_update_frame_label()
		_update_frame_info()
		_draw_node.queue_redraw()


func _process(_delta: float) -> void:
	if _playing and _character and _character.animator:
		if _character.animator.is_playing():
			_current_frame = _character.animator.frame
			_update_shadow_tool()
			_update_frame_label()
			_update_frame_info()
			_draw_node.queue_redraw()


func _update_shadow_tool() -> void:
	if _character == null or _character.shadow_sprite == null:
		return
	if _character.animator == null or _character.animator.sprite_frames == null:
		return
	var tex: Texture2D = _character.animator.sprite_frames.get_frame_texture(
		_character.animator.animation, _character.animator.frame)
	if tex == null:
		return
	var sc: Vector2 = _character.scale
	var tex_h: float = tex.get_size().y
	# Pies del sprite: Animator en (0, -22.5) local, sprite centered
	# pies_y = character.y + (animator_local_y * sc.y) + (tex_h * sc.y / 2)
	var feet_y: float = _character.global_position.y + (-22.5 * sc.y) + (tex_h * sc.y / 2.0)
	_character.shadow_sprite.visible = true
	_character.shadow_sprite.global_position = Vector2(_character.global_position.x, feet_y)
	# Escala y alpha según distancia al suelo
	var floor_y: float = _character.global_position.y + _floor_y
	var distance := absf(_character.global_position.y - floor_y)
	var ratio := clampf(distance / _character.max_jump_height, 0.0, 1.0)
	_character.shadow_sprite.scale = _character.base_shadow_scale * Vector2(
		lerpf(1.0, 1.3, ratio), lerpf(1.0, 0.8, ratio))
	_character.shadow_sprite.modulate.a = lerpf(0.6, 0.15, distance / _character.max_jump_height)


func _update_frame_label() -> void:
	var total := 0
	if _character and _character.animator and _character.animator.sprite_frames:
		total = _character.animator.sprite_frames.get_frame_count(_current_anim)
	_frame_label.text = "%d / %d" % [_current_frame, total]


func _update_frame_info() -> void:
	if _character == null:
		return
	var hk: HitboxKeyframe = _hk_by_frame.get(_current_frame, null)
	var hbk: HurtboxKeyframe = _hbk_by_frame.get(_current_frame, null)

	var txt := ""
	if _current_attack:
		txt += "Ataque: %s | Startup: %d | Active: %d | Recovery: %d\n" % [
			_current_attack.id, _current_attack.startup_frames,
			_current_attack.active_frames, _current_attack.recovery_frames]
		var phase := "idle"
		if _current_frame < _current_attack.startup_frames:
			phase = "startup"
		elif _current_frame < _current_attack.startup_frames + _current_attack.active_frames:
			phase = "ACTIVE"
		else:
			phase = "recovery"
		txt += "Fase: %s\n" % phase
	_info_label.text = txt

	var d := ""
	if hk:
		d += "HB frame %d: offset=Vector2(%s, %s) size=Vector2(%s, %s) active=%s" % [
			hk.frame, hk.offset.x, hk.offset.y, hk.size.x, hk.size.y, hk.active]
	else:
		d += "HB: sin keyframe"
	if hbk:
		d += "\nHR frame %d: offset=Vector2(%s, %s) size=Vector2(%s, %s)" % [
			hbk.frame, hbk.offset.x, hbk.offset.y, hbk.size.x, hbk.size.y]
	else:
		d += "\nHR: sin keyframe"
	_hb_detail_label.text = d

	if hk:
		_hb_offset_x.value = hk.offset.x; _hb_offset_y.value = hk.offset.y
		_hb_size_x.value = hk.size.x; _hb_size_y.value = hk.size.y
	else:
		_hb_offset_x.value = _current_attack.hitbox_offset.x if _current_attack else 0.0
		_hb_offset_y.value = _current_attack.hitbox_offset.y if _current_attack else 0.0
		_hb_size_x.value = BASE_HITBOX_SIZE.x; _hb_size_y.value = BASE_HITBOX_SIZE.y
	if hbk:
		_hr_offset_x.value = hbk.offset.x; _hr_offset_y.value = hbk.offset.y
		_hr_size_x.value = hbk.size.x; _hr_size_y.value = hbk.size.y
	else:
		_hr_offset_x.value = 0.0; _hr_offset_y.value = 0.0
		_hr_size_x.value = BASE_HURTBOX_SIZE.x; _hr_size_y.value = BASE_HURTBOX_SIZE.y

	# Offset del sprite (AnimData.offsets)
	if character_data and character_data.animations.has(_current_anim):
		var anim: AnimData = character_data.animations[_current_anim]
		_frame_offset_label.text = "Frame %d / %d (de %d)" % [_current_frame, anim.offsets.size(), anim.frames.size()]
		if _current_frame < anim.offsets.size():
			_frame_offset_x.set_value_no_signal(anim.offsets[_current_frame].x)
			_frame_offset_y.set_value_no_signal(anim.offsets[_current_frame].y)
		else:
			_frame_offset_x.set_value_no_signal(0.0)
			_frame_offset_y.set_value_no_signal(0.0)
	else:
		_frame_offset_label.text = "Sin anim seleccionada"
		_frame_offset_x.set_value_no_signal(0.0)
		_frame_offset_y.set_value_no_signal(0.0)


func _sync_frame_offset(_v: float) -> void:
	if character_data == null or not character_data.animations.has(_current_anim):
		return
	var anim: AnimData = character_data.animations[_current_anim]
	# Asegurar que el array offsets cubra este frame
	while anim.offsets.size() <= _current_frame:
		anim.offsets.append(Vector2.ZERO)
	anim.offsets[_current_frame] = Vector2(_frame_offset_x.value, _frame_offset_y.value)
	_draw_node.queue_redraw()


func _render_overlay(d: Node2D) -> void:
	if _character == null:
		return
	var cp := _character.global_position
	var sc := _character.scale
	var facing := 1.0 if _character.facing_right else -1.0

	d.draw_line(Vector2(0, cp.y + _floor_y), Vector2(640, cp.y + _floor_y), Color(1, 1, 1, 0.15), 1.0)

	var hk: HitboxKeyframe = _hk_by_frame.get(_current_frame, null)
	var hbk: HurtboxKeyframe = _hbk_by_frame.get(_current_frame, null)

	var hb_off := Vector2.ZERO; var hb_sz := BASE_HITBOX_SIZE; var hb_active := true
	if hk:
		hb_off = hk.offset; hb_sz = hk.size; hb_active = hk.active
	elif _current_attack:
		hb_off = _current_attack.hitbox_offset; hb_sz = BASE_HITBOX_SIZE * _current_attack.hitbox_scale

	var hr_off := Vector2.ZERO; var hr_sz := BASE_HURTBOX_SIZE
	if hbk:
		hr_off = hbk.offset; hr_sz = hbk.size

	# Replicar exactamente attack_state: position = offset * facing, luego escala del CharacterBody2D
	var hb_pos := cp + Vector2(hb_off.x * facing, hb_off.y) * sc
	var hb_size := hb_sz * sc
	if _show_hitbox and hb_active:
		var r := Rect2(hb_pos - hb_size * 0.5, hb_size)
		d.draw_rect(r, Color(1, 0, 0, 0.45), true)
		d.draw_rect(r, Color(1, 0.3, 0.3, 0.9), false, 1.5)

	var hr_pos := cp + Vector2(hr_off.x * facing, hr_off.y) * sc
	var hr_size := hr_sz * sc
	if _show_hurtbox:
		var r := Rect2(hr_pos - hr_size * 0.5, hr_size)
		d.draw_rect(r, Color(0.2, 0.8, 0.2, 0.3), true)
		d.draw_rect(r, Color(0.3, 1, 0.3, 0.8), false, 1.5)

	if _show_dust:
		var feet := Vector2(cp.x, cp.y + _floor_y)
		var off := Vector2(_dust_offset_x.value, _dust_offset_y.value)
		var pos := feet + off
		d.draw_line(pos - Vector2(8, 0), pos + Vector2(8, 0), Color.YELLOW, 1.5)
		d.draw_line(pos - Vector2(0, 8), pos + Vector2(0, 8), Color.YELLOW, 1.5)
		d.draw_string(ThemeDB.fallback_font, pos + Vector2(10, -5), _current_dust, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.YELLOW)


func _on_viewport_input(event: InputEvent) -> void:
	# Zoom con rueda del mouse
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.zoom *= 1.1
			_camera.zoom = _camera.zoom.clamp(Vector2(0.1, 0.1), Vector2(10, 10))
			return
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.zoom /= 1.1
			_camera.zoom = _camera.zoom.clamp(Vector2(0.1, 0.1), Vector2(10, 10))
			return
		# Pan con botón medio
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_panning = true
				_pan_start = mb.position
			else:
				_panning = false
			return
	# Pan con movimiento + botón medio
	if event is InputEventMouseMotion and _panning:
		var mm: InputEventMouseMotion = event
		var delta: Vector2 = (_pan_start - mm.position) / _camera.zoom
		_camera.position += delta
		_pan_start = mm.position
		return
	# Hitbox/hurtbox drag con botón izquierdo
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		var world := _screen_to_world(mb.position)
		var cp := _character.global_position if _character else Vector2(320, 300)
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.shift_pressed:
				_create_kf(world, cp)
			else:
				_try_drag(world, cp)
		elif not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		_do_drag(_screen_to_world(event.position))


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var vp_size := Vector2(_preview.size)
	var cam_center := vp_size / 2.0
	return (screen_pos - cam_center) / _camera.zoom + _camera.position


func _create_kf(local: Vector2, cp: Vector2) -> void:
	if _current_attack == null:
		return
	var sc := _character.scale if _character else Vector2.ONE
	var facing := 1.0 if _character and _character.facing_right else 1.0
	var off := (local - cp) / sc
	off = Vector2(off.x / facing, off.y)
	if not _hk_by_frame.has(_current_frame):
		var hk := HitboxKeyframe.new()
		hk.frame = _current_frame; hk.offset = off
		hk.size = Vector2(_hb_size_x.value, _hb_size_y.value); hk.active = true
		_current_attack.hitbox_keyframes.append(hk)
		_hk_by_frame[_current_frame] = hk
	elif not _hbk_by_frame.has(_current_frame):
		var hbk := HurtboxKeyframe.new()
		hbk.frame = _current_frame; hbk.offset = off
		hbk.size = Vector2(_hr_size_x.value, _hr_size_y.value)
		_current_attack.hurtbox_keyframes.append(hbk)
		_hbk_by_frame[_current_frame] = hbk
	_update_frame_info()
	_draw_node.queue_redraw()


func _try_drag(local: Vector2, cp: Vector2) -> void:
	var sc := _character.scale if _character else Vector2.ONE
	var facing := 1.0 if _character and _character.facing_right else 1.0
	if _show_hurtbox and _hbk_by_frame.has(_current_frame):
		var hbk: HurtboxKeyframe = _hbk_by_frame[_current_frame]
		var center := cp + Vector2(hbk.offset.x * facing, hbk.offset.y) * sc
		var sz := hbk.size * sc
		var r := Rect2(center - sz * 0.5, sz)
		if r.has_point(local):
			_dragging = true; _drag_type = "hurtbox"
			_drag_offset = local - center
			return
	if _show_hitbox and _hk_by_frame.has(_current_frame):
		var hk: HitboxKeyframe = _hk_by_frame[_current_frame]
		var center := cp + Vector2(hk.offset.x * facing, hk.offset.y) * sc
		var sz := hk.size * sc
		var r := Rect2(center - sz * 0.5, sz)
		if r.has_point(local):
			_dragging = true; _drag_type = "hitbox"
			_drag_offset = local - center
			return


func _do_drag(local: Vector2) -> void:
	if _character == null:
		return
	var cp := _character.global_position
	var sc := _character.scale
	var facing := 1.0 if _character.facing_right else -1.0
	var center := local - _drag_offset
	var no := (center - cp) / sc
	no = Vector2(no.x / facing, no.y)
	no = Vector2(roundi(no.x), roundi(no.y))
	if _drag_type == "hitbox" and _hk_by_frame.has(_current_frame):
		_hk_by_frame[_current_frame].offset = no
	elif _drag_type == "hurtbox" and _hbk_by_frame.has(_current_frame):
		_hbk_by_frame[_current_frame].offset = no
	_update_frame_info()
	_draw_node.queue_redraw()


func _on_delete() -> void:
	if _current_attack == null:
		return
	if _hk_by_frame.has(_current_frame):
		_current_attack.hitbox_keyframes.erase(_hk_by_frame[_current_frame])
		_hk_by_frame.erase(_current_frame)
	if _hbk_by_frame.has(_current_frame):
		_current_attack.hurtbox_keyframes.erase(_hbk_by_frame[_current_frame])
		_hbk_by_frame.erase(_current_frame)
	_update_frame_info()
	_draw_node.queue_redraw()


func _sync_hb(_v: float) -> void:
	if _current_attack == null:
		return
	var no := Vector2(_hb_offset_x.value, _hb_offset_y.value)
	var ns := Vector2(_hb_size_x.value, _hb_size_y.value)
	if _hk_by_frame.has(_current_frame):
		_hk_by_frame[_current_frame].offset = no
		_hk_by_frame[_current_frame].size = ns
	else:
		var hk := HitboxKeyframe.new()
		hk.frame = _current_frame; hk.offset = no; hk.size = ns; hk.active = true
		_current_attack.hitbox_keyframes.append(hk)
		_hk_by_frame[_current_frame] = hk
	_update_frame_info()
	_draw_node.queue_redraw()


func _sync_hr(_v: float) -> void:
	if _current_attack == null:
		return
	var no := Vector2(_hr_offset_x.value, _hr_offset_y.value)
	var ns := Vector2(_hr_size_x.value, _hr_size_y.value)
	if _hbk_by_frame.has(_current_frame):
		_hbk_by_frame[_current_frame].offset = no
		_hbk_by_frame[_current_frame].size = ns
	else:
		var hbk := HurtboxKeyframe.new()
		hbk.frame = _current_frame; hbk.offset = no; hbk.size = ns
		_current_attack.hurtbox_keyframes.append(hbk)
		_hbk_by_frame[_current_frame] = hbk
	_update_frame_info()
	_draw_node.queue_redraw()


func _on_save() -> void:
	if character_data == null:
		_info_label.text = "No hay datos"
		return
	var path := character_data.resource_path
	if path.is_empty():
		_info_label.text = "Error: sin path"
		return
	var err := ResourceSaver.save(character_data, path)
	if err == OK:
		_info_label.text = "Guardado: " + path
	else:
		_info_label.text = "Error: " + error_string(err)
