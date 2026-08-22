extends Control
## Herramienta visual: instancia BaseCharacter real para renderizar
## exactamente como en gameplay. Ajusta hitbox/hurtbox/dust y guarda al .tres
## (y los offsets del dust al .gd correspondiente).

const CharacterScene := preload("res://characters/base/base_character.tscn")

const BASE_HITBOX_SIZE := Vector2(50, 40)
const BASE_HURTBOX_SIZE := Vector2(30, 45)
const MIN_BOX_SIZE := 4.0
const HANDLE_MARGIN := 8.0
const DUST_SCRIPT_PATH := "res://characters/base/dust_vfx.gd"


var character_data: CharacterData
var _character: BaseCharacter
var _anims: Array = []
var _current_anim := ""
var _current_frame := 0
var _attacks: Array = []
var _current_attack: AttackData = null
var _hk_by_frame: Dictionary = {}
var _hbk_by_frame: Dictionary = {}
var _show_hitbox := true
var _show_hurtbox := true
var _show_dust := true
var _dust_keys := ["dust1", "dust2", "dust3", "dust4"]
var _current_dust := "dust1"
var _playing := false
var _floor_y := 45.0

# --- Arrastre / redimensionado (hitbox, hurtbox y dust) ---
var _dragging := false
var _drag_kind: String = ""       # "hitbox" | "hurtbox" | "dust"
var _drag_handle: String = ""     # "move","n","s","e","w","ne","nw","se","sw"
var _drag_start_offset: Vector2 = Vector2.ZERO
var _drag_start_size: Vector2 = Vector2.ZERO
var _drag_start_mouse_world: Vector2 = Vector2.ZERO

# --- Dust: reproducción y edición de frame ---
var _dust_playing := false
var _dust_play_accum := 0.0
var _dust_frame_index := 0

var _panning := false
var _pan_start := Vector2.ZERO

var _preview: SubViewport
var _camera: Camera2D
var _draw_node: Node2D
var _floor_body: StaticBody2D
var _frame_label: Label
var _anim_option: OptionButton
var _attack_option: OptionButton
var _info_label: Label
var _hb_detail_label: Label
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
var _create_mode_option: OptionButton

var _dust_offset_x: SpinBox
var _dust_offset_y: SpinBox
var _dust_frame_off_x: SpinBox
var _dust_frame_off_y: SpinBox
var _dust_frame_spin: SpinBox
var _dust_play_btn: Button
var _dust_edit_frame_toggle: CheckBox
var _dust_info_label: Label


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
	right.custom_minimum_size.x = 300
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

	inner.add_child(_lbl("Crear keyframe con Shift+Click como:"))
	_create_mode_option = OptionButton.new()
	_create_mode_option.add_item("Hitbox")
	_create_mode_option.add_item("Hurtbox")
	inner.add_child(_create_mode_option)

	var drag_hint := Label.new()
	drag_hint.text = "Arrastra el CENTRO de la caja para moverla. Arrastra un BORDE o ESQUINA para redimensionarla."
	drag_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	drag_hint.add_theme_font_size_override("font_size", 10)
	inner.add_child(drag_hint)

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
	ch3.toggled.connect(func(v): _show_dust = v; _update_dust_preview(); _draw_node.queue_redraw())
	dv.add_child(ch3)
	var ds := HBoxContainer.new()
	inner.add_child(ds)
	ds.add_child(_lbl("Tipo:"))
	_dust_option = OptionButton.new()
	for dk in _dust_keys:
		_dust_option.add_item(dk)
	_dust_option.item_selected.connect(_on_dust_selected)
	ds.add_child(_dust_option)
	_dust_play_btn = Button.new()
	_dust_play_btn.text = "Play"
	_dust_play_btn.toggle_mode = true
	_dust_play_btn.pressed.connect(_toggle_dust_play)
	ds.add_child(_dust_play_btn)

	var dfr := HBoxContainer.new()
	inner.add_child(dfr)
	dfr.add_child(_lbl("Frame dust:"))
	_dust_frame_spin = _sb(0, 30, 0)
	_dust_frame_spin.value_changed.connect(_on_dust_frame_changed)
	dfr.add_child(_dust_frame_spin)

	_dust_info_label = Label.new()
	_dust_info_label.add_theme_font_size_override("font_size", 11)
	inner.add_child(_dust_info_label)

	inner.add_child(_lbl("Offset base:"))
	var d_off := HBoxContainer.new()
	inner.add_child(d_off)
	_dust_offset_x = _sb(-500, 500, 0); _dust_offset_x.value_changed.connect(_on_dust_base_changed)
	_dust_offset_y = _sb(-500, 500, 0); _dust_offset_y.value_changed.connect(_on_dust_base_changed)
	d_off.add_child(_lbl("X:")); d_off.add_child(_dust_offset_x)
	d_off.add_child(_lbl("Y:")); d_off.add_child(_dust_offset_y)

	inner.add_child(_lbl("Offset extra del frame actual:"))
	var d_foff := HBoxContainer.new()
	inner.add_child(d_foff)
	_dust_frame_off_x = _sb(-500, 500, 0); _dust_frame_off_x.value_changed.connect(_on_dust_frame_offset_changed)
	_dust_frame_off_y = _sb(-500, 500, 0); _dust_frame_off_y.value_changed.connect(_on_dust_frame_offset_changed)
	d_foff.add_child(_lbl("X:")); d_foff.add_child(_dust_frame_off_x)
	d_foff.add_child(_lbl("Y:")); d_foff.add_child(_dust_frame_off_y)

	_dust_edit_frame_toggle = CheckBox.new()
	_dust_edit_frame_toggle.text = "Arrastrar ajusta el offset del FRAME (no el base)"
	inner.add_child(_dust_edit_frame_toggle)

	var dust_hint := Label.new()
	dust_hint.text = "Arrastra el marcador amarillo en la vista para mover el offset."
	dust_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	dust_hint.add_theme_font_size_override("font_size", 10)
	inner.add_child(dust_hint)

	var save_dust_btn := Button.new()
	save_dust_btn.text = "Guardar Dust en dust_vfx.gd"
	save_dust_btn.pressed.connect(_on_save_dust)
	inner.add_child(save_dust_btn)
	inner.add_child(HSeparator.new())

	var fb := HBoxContainer.new()
	inner.add_child(fb)
	fb.add_child(_lbl("Floor Y: "))
	_floor_spin = _sb(0, 400, 45)
	_floor_spin.value_changed.connect(func(v): _floor_y = v; _update_dust_preview(); _draw_node.queue_redraw())
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
	# DESPUÉS de add_child: _ready() ya corrió (animator.setup, state_machine, dust_vfx)
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
	_dust_frame_index = 0
	if _character.dust_vfx:
		_character.dust_vfx.preview_hide()
	_sync_dust_ui()
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


func _toggle_dust_play() -> void:
	_dust_playing = not _dust_playing
	_dust_play_accum = 0.0


func _process(delta: float) -> void:
	if _playing and _character and _character.animator:
		if _character.animator.is_playing():
			_current_frame = _character.animator.frame
			_update_shadow_tool()
			_update_frame_label()
			_update_frame_info()
			_draw_node.queue_redraw()

	if _dust_playing and _character and _character.dust_vfx:
		var dvfx := _character.dust_vfx
		var fps := dvfx.get_dust_fps(_current_dust)
		var count := dvfx.get_dust_frame_count(_current_dust)
		if count > 0 and fps > 0.0:
			_dust_play_accum += delta
			var frame_time := 1.0 / fps
			var loop := dvfx.get_dust_loop(_current_dust)
			while _dust_play_accum >= frame_time:
				_dust_play_accum -= frame_time
				_dust_frame_index += 1
				if _dust_frame_index >= count:
					if loop:
						_dust_frame_index = 0
					else:
						_dust_frame_index = count - 1
						_dust_playing = false
			_dust_frame_spin.set_value_no_signal(_dust_frame_index)
			_update_dust_preview()
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
	var feet_y: float = _character.global_position.y + (-22.5 * sc.y) + (tex_h * sc.y / 2.0)
	_character.shadow_sprite.visible = true
	_character.shadow_sprite.global_position = Vector2(_character.global_position.x, feet_y)
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

	# IMPORTANTE: set_value_no_signal, no ".value =" — de lo contrario cada
	# navegación de frame disparaba _sync_hb/_sync_hr y creaba keyframes solos.
	if hk:
		_hb_offset_x.set_value_no_signal(hk.offset.x); _hb_offset_y.set_value_no_signal(hk.offset.y)
		_hb_size_x.set_value_no_signal(hk.size.x); _hb_size_y.set_value_no_signal(hk.size.y)
	else:
		_hb_offset_x.set_value_no_signal(_current_attack.hitbox_offset.x if _current_attack else 0.0)
		_hb_offset_y.set_value_no_signal(_current_attack.hitbox_offset.y if _current_attack else 0.0)
		_hb_size_x.set_value_no_signal(BASE_HITBOX_SIZE.x); _hb_size_y.set_value_no_signal(BASE_HITBOX_SIZE.y)
	if hbk:
		_hr_offset_x.set_value_no_signal(hbk.offset.x); _hr_offset_y.set_value_no_signal(hbk.offset.y)
		_hr_size_x.set_value_no_signal(hbk.size.x); _hr_size_y.set_value_no_signal(hbk.size.y)
	else:
		_hr_offset_x.set_value_no_signal(0.0); _hr_offset_y.set_value_no_signal(0.0)
		_hr_size_x.set_value_no_signal(BASE_HURTBOX_SIZE.x); _hr_size_y.set_value_no_signal(BASE_HURTBOX_SIZE.y)

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
	while anim.offsets.size() <= _current_frame:
		anim.offsets.append(Vector2.ZERO)
	anim.offsets[_current_frame] = Vector2(_frame_offset_x.value, _frame_offset_y.value)
	_draw_node.queue_redraw()


# ─── Dust: sincronización y preview ─────────────────────────────────────────

func _get_dust_world_pos() -> Vector2:
	if _character == null or _character.dust_vfx == null:
		return Vector2.ZERO
	var cp := _character.global_position
	var anchor := Vector2(cp.x, cp.y + _floor_y)
	return anchor + _character.dust_vfx.get_preview_offset(_current_dust, _dust_frame_index)


func _update_dust_preview() -> void:
	if _character == null or _character.dust_vfx == null:
		return
	if not _show_dust:
		_character.dust_vfx.preview_hide()
		return
	var cp := _character.global_position
	var anchor := Vector2(cp.x, cp.y + _floor_y)
	_character.dust_vfx.preview_show(_current_dust, _dust_frame_index, anchor)


func _sync_dust_ui() -> void:
	if _character == null or _character.dust_vfx == null:
		return
	var dvfx := _character.dust_vfx
	dvfx.ensure_frame_offsets(_current_dust)
	var base: Vector2 = dvfx.base_offsets.get(_current_dust, Vector2.ZERO)
	_dust_offset_x.set_value_no_signal(base.x)
	_dust_offset_y.set_value_no_signal(base.y)
	var count := dvfx.get_dust_frame_count(_current_dust)
	_dust_frame_spin.max_value = maxf(0, count - 1)
	_dust_frame_index = clampi(_dust_frame_index, 0, maxi(count - 1, 0))
	_dust_frame_spin.set_value_no_signal(_dust_frame_index)
	var arr: Array = dvfx.frame_offsets.get(_current_dust, [])
	var extra: Vector2 = arr[_dust_frame_index] if _dust_frame_index < arr.size() else Vector2.ZERO
	_dust_frame_off_x.set_value_no_signal(extra.x)
	_dust_frame_off_y.set_value_no_signal(extra.y)
	_dust_info_label.text = "%s | frame %d/%d | fps=%.0f | loop=%s" % [
		_current_dust, _dust_frame_index, maxi(count - 1, 0), dvfx.get_dust_fps(_current_dust), dvfx.get_dust_loop(_current_dust)]
	_update_dust_preview()


func _on_dust_selected(i: int) -> void:
	_current_dust = _dust_keys[i]
	_dust_frame_index = 0
	_sync_dust_ui()
	_draw_node.queue_redraw()


func _on_dust_frame_changed(v: float) -> void:
	_dust_frame_index = int(v)
	_sync_dust_ui()
	_draw_node.queue_redraw()


func _on_dust_base_changed(_v: float) -> void:
	if _character == null or _character.dust_vfx == null:
		return
	_character.dust_vfx.base_offsets[_current_dust] = Vector2(_dust_offset_x.value, _dust_offset_y.value)
	_update_dust_preview()
	_draw_node.queue_redraw()


func _on_dust_frame_offset_changed(_v: float) -> void:
	if _character == null or _character.dust_vfx == null:
		return
	var dvfx := _character.dust_vfx
	dvfx.ensure_frame_offsets(_current_dust)
	dvfx.frame_offsets[_current_dust][_dust_frame_index] = Vector2(_dust_frame_off_x.value, _dust_frame_off_y.value)
	_update_dust_preview()
	_draw_node.queue_redraw()


func _on_save_dust() -> void:
	if _character == null or _character.dust_vfx == null:
		_info_label.text = "No hay personaje cargado"
		return
	var dvfx := _character.dust_vfx
	var f := FileAccess.open(DUST_SCRIPT_PATH, FileAccess.READ)
	if f == null:
		_info_label.text = "No se pudo leer dust_vfx.gd"
		return
	var text := f.get_as_text()
	f = null
	text = _replace_gd_dict_block(text, "base_offsets", _format_vec2_dict(dvfx.base_offsets))
	text = _replace_gd_dict_block(text, "frame_offsets", _format_vec2_array_dict(dvfx.frame_offsets))
	var out := FileAccess.open(DUST_SCRIPT_PATH, FileAccess.WRITE)
	if out == null:
		_info_label.text = "No se pudo escribir dust_vfx.gd"
		return
	out.store_string(text)
	out = null
	_info_label.text = "Dust guardado en dust_vfx.gd (reinicia el juego para verlo en runtime)"


func _fmt_num(n: float) -> String:
	if is_equal_approx(n, roundf(n)):
		return str(int(roundf(n)))
	return str(n)


func _format_vec2_dict(d: Dictionary) -> String:
	var keys := d.keys()
	keys.sort()
	var lines: PackedStringArray = []
	for k in keys:
		var v: Vector2 = d[k]
		lines.append('\t"%s": Vector2(%s, %s),' % [k, _fmt_num(v.x), _fmt_num(v.y)])
	return "\n".join(lines)


func _format_vec2_array_dict(d: Dictionary) -> String:
	var keys := d.keys()
	keys.sort()
	var lines: PackedStringArray = []
	for k in keys:
		var arr: Array = d[k]
		var items: PackedStringArray = []
		for v in arr:
			items.append("Vector2(%s, %s)" % [_fmt_num(v.x), _fmt_num(v.y)])
		lines.append('\t"%s": [%s],' % [k, ", ".join(items)])
	return "\n".join(lines)


## Reemplaza el contenido de "var <var_name> := { ... }" en un script .gd,
## respetando llaves anidadas (busca la llave de cierre balanceada).
func _replace_gd_dict_block(text: String, var_name: String, new_inner: String) -> String:
	var marker := "var %s" % var_name
	var start := text.find(marker)
	if start == -1:
		return text
	var brace_start := text.find("{", start)
	if brace_start == -1:
		return text
	var depth := 0
	var i := brace_start
	var brace_end := -1
	while i < text.length():
		var c := text[i]
		if c == "{":
			depth += 1
		elif c == "}":
			depth -= 1
			if depth == 0:
				brace_end = i
				break
		i += 1
	if brace_end == -1:
		return text
	var before := text.substr(0, brace_start + 1)
	var after := text.substr(brace_end)
	var body := ("\n" + new_inner + "\n") if new_inner.strip_edges() != "" else ""
	return before + body + after


# ─── Render overlay (hitbox / hurtbox / dust) ───────────────────────────────

func _get_hb_rect_world(cp: Vector2, sc: Vector2, facing: float) -> Rect2:
	var hk: HitboxKeyframe = _hk_by_frame.get(_current_frame, null)
	var off := Vector2.ZERO
	var sz := BASE_HITBOX_SIZE
	if hk:
		off = hk.offset; sz = hk.size
	elif _current_attack:
		off = _current_attack.hitbox_offset; sz = BASE_HITBOX_SIZE * _current_attack.hitbox_scale
	var center := cp + Vector2(off.x * facing, off.y) * sc
	var size := sz * sc
	return Rect2(center - size * 0.5, size)


func _get_hr_rect_world(cp: Vector2, sc: Vector2, facing: float) -> Rect2:
	var hbk: HurtboxKeyframe = _hbk_by_frame.get(_current_frame, null)
	var off := Vector2.ZERO
	var sz := BASE_HURTBOX_SIZE
	if hbk:
		off = hbk.offset; sz = hbk.size
	var center := cp + Vector2(off.x * facing, off.y) * sc
	var size := sz * sc
	return Rect2(center - size * 0.5, size)


func _render_overlay(d: Node2D) -> void:
	if _character == null:
		return
	var cp := _character.global_position
	var sc := _character.scale
	var facing := 1.0 if _character.facing_right else -1.0

	d.draw_line(Vector2(0, cp.y + _floor_y), Vector2(640, cp.y + _floor_y), Color(1, 1, 1, 0.15), 1.0)

	if _show_hitbox:
		var hb_rect := _get_hb_rect_world(cp, sc, facing)
		var hk: HitboxKeyframe = _hk_by_frame.get(_current_frame, null)
		var active := hk.active if hk else true
		if active:
			d.draw_rect(hb_rect, Color(1, 0, 0, 0.45), true)
			d.draw_rect(hb_rect, Color(1, 0.3, 0.3, 0.9), false, 1.5)
			_draw_handles(d, hb_rect, Color(1, 0.6, 0.6))

	if _show_hurtbox:
		var hr_rect := _get_hr_rect_world(cp, sc, facing)
		d.draw_rect(hr_rect, Color(0.2, 0.8, 0.2, 0.3), true)
		d.draw_rect(hr_rect, Color(0.3, 1, 0.3, 0.8), false, 1.5)
		_draw_handles(d, hr_rect, Color(0.6, 1, 0.6))

	if _show_dust and _character.dust_vfx:
		var dust_pos := _get_dust_world_pos()
		d.draw_line(dust_pos - Vector2(8, 0), dust_pos + Vector2(8, 0), Color.YELLOW, 1.5)
		d.draw_line(dust_pos - Vector2(0, 8), dust_pos + Vector2(0, 8), Color.YELLOW, 1.5)
		d.draw_string(ThemeDB.fallback_font, dust_pos + Vector2(10, -5), _current_dust, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.YELLOW)


func _draw_handles(d: Node2D, rect: Rect2, color: Color) -> void:
	var s := 5.0
	var pts := [
		rect.position,
		Vector2(rect.position.x + rect.size.x, rect.position.y),
		Vector2(rect.position.x, rect.position.y + rect.size.y),
		rect.position + rect.size,
	]
	for p in pts:
		d.draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), color, true)


# ─── Input del viewport: pan/zoom + drag/resize de hitbox/hurtbox/dust ──────

func _on_viewport_input(event: InputEvent) -> void:
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
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_panning = true
				_pan_start = mb.position
			else:
				_panning = false
			return
	if event is InputEventMouseMotion and _panning:
		var mm: InputEventMouseMotion = event
		var delta: Vector2 = (_pan_start - mm.position) / _camera.zoom
		_camera.position += delta
		_pan_start = mm.position
		return
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
			_drag_kind = ""
			_drag_handle = ""
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
	var off := (local - cp) / sc
	off = Vector2(roundf(off.x), roundf(off.y))
	var mode := _create_mode_option.selected if _create_mode_option else 0
	if mode == 0:
		if _hk_by_frame.has(_current_frame):
			return
		var hk := HitboxKeyframe.new()
		hk.frame = _current_frame
		hk.offset = off
		hk.size = Vector2(_hb_size_x.value, _hb_size_y.value)
		hk.active = true
		_current_attack.hitbox_keyframes.append(hk)
		_hk_by_frame[_current_frame] = hk
	else:
		if _hbk_by_frame.has(_current_frame):
			return
		var hbk := HurtboxKeyframe.new()
		hbk.frame = _current_frame
		hbk.offset = off
		hbk.size = Vector2(_hr_size_x.value, _hr_size_y.value)
		_current_attack.hurtbox_keyframes.append(hbk)
		_hbk_by_frame[_current_frame] = hbk
	_update_frame_info()
	_draw_node.queue_redraw()


func _handle_at_rect(local: Vector2, rect: Rect2) -> String:
	var margin: float = HANDLE_MARGIN / _camera.zoom.x
	var l := rect.position.x
	var r := rect.position.x + rect.size.x
	var t := rect.position.y
	var b := rect.position.y + rect.size.y
	var near_l := absf(local.x - l) <= margin
	var near_r := absf(local.x - r) <= margin
	var near_t := absf(local.y - t) <= margin
	var near_b := absf(local.y - b) <= margin
	var within_x := local.x >= l - margin and local.x <= r + margin
	var within_y := local.y >= t - margin and local.y <= b + margin
	if not (within_x and within_y):
		return ""
	if near_l and near_t: return "nw"
	if near_r and near_t: return "ne"
	if near_l and near_b: return "sw"
	if near_r and near_b: return "se"
	if near_l: return "w"
	if near_r: return "e"
	if near_t: return "n"
	if near_b: return "s"
	if rect.has_point(local): return "move"
	return ""


func _start_drag(kind: String, handle: String, offset: Vector2, size: Vector2, mouse_world: Vector2) -> void:
	_dragging = true
	_drag_kind = kind
	_drag_handle = handle
	_drag_start_offset = offset
	_drag_start_size = size
	_drag_start_mouse_world = mouse_world


func _try_drag(local: Vector2, cp: Vector2) -> void:
	if _character == null:
		return
	var sc := _character.scale
	var facing := 1.0 if _character.facing_right else -1.0

	if _show_hurtbox and _hbk_by_frame.has(_current_frame):
		var hr_rect := _get_hr_rect_world(cp, sc, facing)
		var handle := _handle_at_rect(local, hr_rect)
		if handle != "":
			var hbk = _hbk_by_frame[_current_frame]
			_start_drag("hurtbox", handle, hbk.offset, hbk.size, local)
			return

	if _show_hitbox and _hk_by_frame.has(_current_frame):
		var hb_rect := _get_hb_rect_world(cp, sc, facing)
		var handle := _handle_at_rect(local, hb_rect)
		if handle != "":
			var hk = _hk_by_frame[_current_frame]
			_start_drag("hitbox", handle, hk.offset, hk.size, local)
			return

	if _show_dust and _character.dust_vfx:
		var dust_pos := _get_dust_world_pos()
		var margin: float = 12.0 / _camera.zoom.x
		if local.distance_to(dust_pos) <= margin:
			var dvfx := _character.dust_vfx
			dvfx.ensure_frame_offsets(_current_dust)
			var base: Vector2 = dvfx.base_offsets.get(_current_dust, Vector2.ZERO)
			var arr: Array = dvfx.frame_offsets.get(_current_dust, [])
			var extra: Vector2 = arr[_dust_frame_index] if _dust_frame_index < arr.size() else Vector2.ZERO
			_start_drag("dust", "move", base, extra, local)
			return


func _do_drag(local: Vector2) -> void:
	if _character == null:
		return
	if _drag_kind == "hitbox" or _drag_kind == "hurtbox":
		_do_drag_box(local)
	elif _drag_kind == "dust":
		_do_drag_dust(local)


func _do_drag_box(local: Vector2) -> void:
	var kf = _hk_by_frame.get(_current_frame, null) if _drag_kind == "hitbox" else _hbk_by_frame.get(_current_frame, null)
	if kf == null:
		return
	var sc := _character.scale
	var world_delta := local - _drag_start_mouse_world
	var dd := Vector2(world_delta.x / sc.x, world_delta.y / sc.y)
	var new_offset := _drag_start_offset
	var new_size := _drag_start_size
	match _drag_handle:
		"move":
			new_offset = _drag_start_offset + dd
		"e":
			new_size.x = maxf(_drag_start_size.x + dd.x, MIN_BOX_SIZE)
			new_offset.x = _drag_start_offset.x + dd.x * 0.5
		"w":
			new_size.x = maxf(_drag_start_size.x - dd.x, MIN_BOX_SIZE)
			new_offset.x = _drag_start_offset.x + dd.x * 0.5
		"s":
			new_size.y = maxf(_drag_start_size.y + dd.y, MIN_BOX_SIZE)
			new_offset.y = _drag_start_offset.y + dd.y * 0.5
		"n":
			new_size.y = maxf(_drag_start_size.y - dd.y, MIN_BOX_SIZE)
			new_offset.y = _drag_start_offset.y + dd.y * 0.5
		"se":
			new_size.x = maxf(_drag_start_size.x + dd.x, MIN_BOX_SIZE)
			new_size.y = maxf(_drag_start_size.y + dd.y, MIN_BOX_SIZE)
			new_offset = _drag_start_offset + dd * 0.5
		"sw":
			new_size.x = maxf(_drag_start_size.x - dd.x, MIN_BOX_SIZE)
			new_size.y = maxf(_drag_start_size.y + dd.y, MIN_BOX_SIZE)
			new_offset.x = _drag_start_offset.x + dd.x * 0.5
			new_offset.y = _drag_start_offset.y + dd.y * 0.5
		"ne":
			new_size.x = maxf(_drag_start_size.x + dd.x, MIN_BOX_SIZE)
			new_size.y = maxf(_drag_start_size.y - dd.y, MIN_BOX_SIZE)
			new_offset.x = _drag_start_offset.x + dd.x * 0.5
			new_offset.y = _drag_start_offset.y + dd.y * 0.5
		"nw":
			new_size.x = maxf(_drag_start_size.x - dd.x, MIN_BOX_SIZE)
			new_size.y = maxf(_drag_start_size.y - dd.y, MIN_BOX_SIZE)
			new_offset = _drag_start_offset + dd * 0.5
	new_offset = Vector2(roundf(new_offset.x), roundf(new_offset.y))
	new_size = Vector2(roundf(new_size.x), roundf(new_size.y))
	kf.offset = new_offset
	kf.size = new_size
	_update_frame_info()
	_draw_node.queue_redraw()


func _do_drag_dust(local: Vector2) -> void:
	var dvfx := _character.dust_vfx
	var world_delta := local - _drag_start_mouse_world
	if _dust_edit_frame_toggle.button_pressed:
		dvfx.ensure_frame_offsets(_current_dust)
		var new_extra: Vector2 = _drag_start_size + world_delta
		new_extra = Vector2(roundf(new_extra.x), roundf(new_extra.y))
		dvfx.frame_offsets[_current_dust][_dust_frame_index] = new_extra
		_dust_frame_off_x.set_value_no_signal(new_extra.x)
		_dust_frame_off_y.set_value_no_signal(new_extra.y)
	else:
		var new_base: Vector2 = _drag_start_offset + world_delta
		new_base = Vector2(roundf(new_base.x), roundf(new_base.y))
		dvfx.base_offsets[_current_dust] = new_base
		_dust_offset_x.set_value_no_signal(new_base.x)
		_dust_offset_y.set_value_no_signal(new_base.y)
	_update_dust_preview()
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
