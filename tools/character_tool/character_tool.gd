extends Control
## Herramienta visual: instancia BaseCharacter real para renderizar
## exactamente como en gameplay. Ajusta hitbox/hurtbox/dust y guarda al .tres
## (y los offsets del dust al .gd correspondiente).

const CharacterScene := preload("res://characters/base/base_character.tscn")

const BASE_HITBOX_SIZE := Vector2(50, 40)
const BASE_HURTBOX_SIZE := Vector2(30, 45)
const MIN_BOX_SIZE := 4.0
const HANDLE_MARGIN := 14.0

## Mismos valores que base_stage.gd para consistencia gameplay↔editor.
const VIEWPORT_SIZE := Vector2(1280, 720)
const ZOOM_PADDING := 240.0
const MAX_ZOOM_WORLD_WIDTH := 850.0
const DEFAULT_FLOOR_Y := 200.0


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
var _show_anim_offset := true
var _dust_keys := ["dust1", "dust2", "dust3", "dust4"]
var _current_dust := "dust1"
var _floor_y := DEFAULT_FLOOR_Y

# --- Stage ---
var _stages: Dictionary = {}  # id → path (.tres)
var _stage_ids: Array = []
var _current_stage_path := ""

# --- Reproduccion de la animacion del personaje (control manual) ---
var _anim_playing := false
var _anim_loop_override := true
var _anim_play_accum := 0.0
var _anim_speed := 1.0

# --- Arrastre / redimensionado ---
var _dragging := false
var _drag_kind: String = ""
var _drag_handle: String = ""
var _drag_start_offset: Vector2 = Vector2.ZERO
var _drag_start_size: Vector2 = Vector2.ZERO
var _drag_start_mouse_world: Vector2 = Vector2.ZERO

# --- Dust ---
var _dust_playing := false
var _dust_play_accum := 0.0
var _dust_frame_index := 0

var _panning := false
var _pan_start := Vector2.ZERO

# --- Físicas ---
var _physics_enabled := false

var _preview: SubViewport
var _camera: Camera2D
var _draw_node: Node2D
var _floor_body: StaticBody2D
var _left_wall: StaticBody2D
var _right_wall: StaticBody2D
var _frame_label: Label
var _anim_option: OptionButton
var _attack_option: OptionButton
var _info_label: Label
var _hb_detail_label: Label
var _kf_warning_label: Label
var _data_path_label: Label
var _hb_size_x: SpinBox
var _hb_size_y: SpinBox
var _hr_size_x: SpinBox
var _hr_size_y: SpinBox
var _hb_active_check: CheckBox
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

var _play_btn: Button
var _stop_btn: Button
var _loop_check: CheckBox
var _speed_spin: SpinBox

var _dust_offset_x: SpinBox
var _dust_offset_y: SpinBox
var _dust_frame_spin: SpinBox
var _dust_play_btn: Button
var _dust_loop_check: CheckBox
var _dust_info_label: Label
var _dust_fps_spin: SpinBox
var _dust_frame_offset_x: SpinBox
var _dust_frame_offset_y: SpinBox
var _dust_z_index_option: OptionButton

var _stage_option: OptionButton
var _physics_check: CheckBox


func _ready() -> void:
	_build_ui()
	_setup_viewport()
	_discover_stages()
	call_deferred("_load_data", "res://characters/goku/goku.tres")


func _setup_viewport() -> void:
	_draw_node = Node2D.new()
	_draw_node.set_script(preload("res://tools/character_tool/draw_overlay.gd"))
	_draw_node.tool_ref = self
	_draw_node.name = "DrawOverlay"
	_draw_node.z_index = 10
	_preview.add_child(_draw_node)

	# Suelo: ancho infinito (como base_stage.gd floor_body.scale.x = 100000)
	_floor_body = StaticBody2D.new()
	_floor_body.position = Vector2(0, _floor_y)
	var floor_shape := RectangleShape2D.new()
	floor_shape.size = Vector2(200000, 20)
	var floor_col := CollisionShape2D.new()
	floor_col.shape = floor_shape
	_floor_body.add_child(floor_col)
	_preview.add_child(_floor_body)

	# Paredes (como base_stage.gd)
	_left_wall = StaticBody2D.new()
	_left_wall.position = Vector2(-600, _floor_y)
	var wall_shape := RectangleShape2D.new()
	wall_shape.size = Vector2(20, 400)
	var lcol := CollisionShape2D.new()
	lcol.shape = wall_shape
	_left_wall.add_child(lcol)
	_preview.add_child(_left_wall)

	_right_wall = StaticBody2D.new()
	_right_wall.position = Vector2(600, _floor_y)
	var rcol := CollisionShape2D.new()
	rcol.shape = wall_shape
	_right_wall.add_child(rcol)
	_preview.add_child(_right_wall)

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

	# --- Selector de stage ---
	var tb_stage := HBoxContainer.new()
	left.add_child(tb_stage)
	tb_stage.add_child(_lbl("Stage: "))
	_stage_option = OptionButton.new()
	_stage_option.size_flags_horizontal = SIZE_EXPAND_FILL
	_stage_option.item_selected.connect(_on_stage_selected)
	tb_stage.add_child(_stage_option)
	_physics_check = CheckBox.new()
	_physics_check.text = "Físicas"
	_physics_check.button_pressed = false
	_physics_check.toggled.connect(_on_physics_toggled)
	tb_stage.add_child(_physics_check)

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
	_play_btn = Button.new()
	_play_btn.text = "Play"
	_play_btn.toggle_mode = true
	_play_btn.pressed.connect(_toggle_play)
	tb3.add_child(_play_btn)
	_stop_btn = Button.new()
	_stop_btn.text = "Stop"
	_stop_btn.pressed.connect(_on_stop_pressed)
	tb3.add_child(_stop_btn)
	var cam_reset := Button.new()
	cam_reset.text = "Reset Cam"
	cam_reset.pressed.connect(func(): _camera.position = Vector2(0, _floor_y - 80); _camera.zoom = Vector2(1.0, 1.0))
	tb3.add_child(cam_reset)

	var tb4 := HBoxContainer.new()
	tb4.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(tb4)
	_loop_check = CheckBox.new()
	_loop_check.text = "Forzar loop"
	_loop_check.button_pressed = true
	_loop_check.toggled.connect(func(v): _anim_loop_override = v)
	tb4.add_child(_loop_check)
	tb4.add_child(_lbl(" Vel:"))
	_speed_spin = SpinBox.new()
	_speed_spin.min_value = 0.1
	_speed_spin.max_value = 3.0
	_speed_spin.step = 0.1
	_speed_spin.value = 1.0
	_speed_spin.custom_minimum_size.x = 70
	_speed_spin.value_changed.connect(func(v): _anim_speed = v)
	tb4.add_child(_speed_spin)

	var vc := SubViewportContainer.new()
	vc.size_flags_horizontal = SIZE_EXPAND_FILL
	vc.size_flags_vertical = SIZE_EXPAND_FILL
	vc.stretch = true
	vc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	left.add_child(vc)

	_preview = SubViewport.new()
	_preview.size = Vector2i(1280, 720)
	_preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vc.add_child(_preview)
	RenderingServer.viewport_set_default_canvas_item_texture_filter(
		_preview.get_viewport_rid(), RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	vc.gui_input.connect(_on_viewport_input)

	_camera = Camera2D.new()
	# Posición inicial: centro del viewport, mirando un poco arriba del suelo (como base_stage.gd)
	_camera.position = Vector2(0, _floor_y - 80)
	# Zoom inicial: 1.0 para ver la misma área que el juego (1280×720 world units)
	_camera.zoom = Vector2(1.0, 1.0)
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
	_kf_warning_label = Label.new()
	_kf_warning_label.text = "Selecciona un ataque para editar keyframes."
	_kf_warning_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	_kf_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	inner.add_child(_kf_warning_label)
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
	_hb_active_check = CheckBox.new()
	_hb_active_check.text = "Activa"
	_hb_active_check.button_pressed = true
	_hb_active_check.toggled.connect(_on_hb_active_toggled)
	inner.add_child(_hb_active_check)
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

	inner.add_child(_lbl("Alt+Click = crear keyframe:"))
	_create_mode_option = OptionButton.new()
	_create_mode_option.add_item("Hitbox")
	_create_mode_option.add_item("Hurtbox")
	inner.add_child(_create_mode_option)

	var drag_hint := Label.new()
	drag_hint.text = "Arrastra CENTRO para mover, BORDE/ESQUINA para redimensionar."
	drag_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	drag_hint.add_theme_font_size_override("font_size", 10)
	inner.add_child(drag_hint)

	var del := Button.new()
	del.text = "Eliminar keyframe"
	del.pressed.connect(_on_delete)
	inner.add_child(del)
	var copy_kf := Button.new()
	copy_kf.text = "CopiarKF \u2190"
	copy_kf.pressed.connect(_on_copy_keyframe)
	inner.add_child(copy_kf)
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
	var tog := CheckBox.new()
	tog.text = "Ver offset"
	tog.button_pressed = true
	tog.toggled.connect(_on_anim_offset_toggled)
	inner.add_child(tog)
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
	_dust_loop_check = CheckBox.new()
	_dust_loop_check.text = "Loop"
	_dust_loop_check.button_pressed = false
	ds.add_child(_dust_loop_check)

	var dfr := HBoxContainer.new()
	inner.add_child(dfr)
	dfr.add_child(_lbl("Frame:"))
	_dust_frame_spin = _sb(0, 30, 0)
	_dust_frame_spin.value_changed.connect(_on_dust_frame_changed)
	dfr.add_child(_dust_frame_spin)
	dfr.add_child(_lbl(" FPS:"))
	_dust_fps_spin = _sb(1.0, 60.0, 12.0)
	_dust_fps_spin.step = 0.5
	_dust_fps_spin.custom_minimum_size.x = 65
	_dust_fps_spin.value_changed.connect(_on_dust_fps_changed)
	dfr.add_child(_dust_fps_spin)

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

	inner.add_child(_lbl("Offset frame:"))
	var d_foff := HBoxContainer.new()
	inner.add_child(d_foff)
	_dust_frame_offset_x = _sb(-500, 500, 0); _dust_frame_offset_x.value_changed.connect(_on_dust_frame_offset_changed)
	_dust_frame_offset_y = _sb(-500, 500, 0); _dust_frame_offset_y.value_changed.connect(_on_dust_frame_offset_changed)
	d_foff.add_child(_lbl("X:")); d_foff.add_child(_dust_frame_offset_x)
	d_foff.add_child(_lbl("Y:")); d_foff.add_child(_dust_frame_offset_y)

	inner.add_child(_lbl("Z-Index:"))
	var d_z := HBoxContainer.new()
	inner.add_child(d_z)
	_dust_z_index_option = OptionButton.new()
	_dust_z_index_option.add_item("Detrás (-2)", -2)
	_dust_z_index_option.add_item("Detrás (-1)", -1)
	_dust_z_index_option.add_item("Base (0)", 0)
	_dust_z_index_option.add_item("Encima (1)", 1)
	_dust_z_index_option.add_item("Encima (2)", 2)
	_dust_z_index_option.add_item("Encima (3)", 3)
	_dust_z_index_option.add_item("Encima (4)", 4)
	_dust_z_index_option.add_item("Encima (5)", 5)
	_dust_z_index_option.selected = 4
	_dust_z_index_option.item_selected.connect(_on_dust_z_index_changed)
	d_z.add_child(_dust_z_index_option)

	var dust_hint := Label.new()
	dust_hint.text = "Arrastra el marcador amarillo. Offset frame se suma al base."
	dust_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	dust_hint.add_theme_font_size_override("font_size", 10)
	inner.add_child(dust_hint)

	var save_dust_btn := Button.new()
	save_dust_btn.text = "Guardar Dust"
	save_dust_btn.pressed.connect(_on_save_dust)
	inner.add_child(save_dust_btn)
	inner.add_child(HSeparator.new())

	var fb := HBoxContainer.new()
	inner.add_child(fb)
	fb.add_child(_lbl("Floor Y: "))
	_floor_spin = _sb(0, 720, DEFAULT_FLOOR_Y)
	_floor_spin.value_changed.connect(func(v): _floor_y = v; _floor_body.position.y = v; _left_wall.position.y = v; _right_wall.position.y = v; _update_dust_preview(); _draw_node.queue_redraw())
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


func _discover_stages() -> void:
	_stages.clear()
	_stage_ids.clear()
	_stage_option.clear()
	_stage_option.add_item("-- Sin stage --")
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
							_stages[data.id] = path
							_stage_ids.append(data.id)
					f = sub.get_next()
				sub.list_dir_end()
		folder = root.get_next()
	root.list_dir_end()
	# Ordenar por display_name y reconstruir OptionButton
	var pairs: Array = []  # [[display_name, id], ...]
	for id in _stage_ids:
		var data: StageData = load(_stages[id])
		var display: String = data.display_name if data and data.display_name != "" else id
		pairs.append([display, id])
	pairs.sort_custom(func(a, b): return a[0] < b[0])
	_stage_ids.clear()
	for p in pairs:
		_stage_ids.append(p[1])
		_stage_option.add_item(p[0])


func _on_stage_selected(idx: int) -> void:
	if idx <= 0 or idx > _stage_ids.size():
		_current_stage_path = ""
		return
	var id: String = _stage_ids[idx - 1]
	_current_stage_path = _stages[id]
	_apply_stage()


func _apply_stage() -> void:
	if _current_stage_path.is_empty():
		return
	var data: StageData = load(_current_stage_path)
	if data == null:
		return
	_floor_y = data.floor_y
	_floor_body.position.y = _floor_y
	_left_wall.position.y = _floor_y
	_right_wall.position.y = _floor_y
	# Paredes según wall_limit
	var wall_limit := data.wall_limit
	if data.background and wall_limit <= 0.0:
		wall_limit = data.background.get_size().x / 2.0 - data.wall_margin
	if wall_limit > 0.0:
		_left_wall.position.x = -wall_limit
		_right_wall.position.x = wall_limit
	_floor_spin.set_value_no_signal(_floor_y)
	if _character:
		_character.position.y = _settle_y()
		_update_shadow_tool()
		_draw_node.queue_redraw()
	_update_dust_preview()


func _on_physics_toggled(v: bool) -> void:
	_physics_enabled = v
	if _character == null:
		return
	_character.set_physics_process(v)
	if _character.state_machine:
		_character.state_machine.set_physics_process(v)
	if _character.combat:
		_character.combat.set_physics_process(v)
	if not v:
		# Al desactivar, detener movimiento y resetear posición
		_character.velocity = Vector2.ZERO
		_character.position.y = _settle_y()
		_update_shadow_tool()
		_draw_node.queue_redraw()


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
	_current_attack = null
	_hk_by_frame.clear()
	_hbk_by_frame.clear()
	_update_kf_editors_enabled()


func _spawn_character() -> void:
	if _character:
		_character.queue_free()
		_character = null
	if character_data == null:
		push_warning("Tool: character_data es null")
		return
	_character = CharacterScene.instantiate()
	_character.character_data = character_data
	# Centrado en el viewport, sobre el suelo (como _do_fight en gameplay)
	_character.position = Vector2(0, _settle_y())
	_character.facing_right = true
	_preview.add_child(_character)
	if not (_character is BaseCharacter):
		push_error("La escena instanciada no es BaseCharacter")
		return
	if _character.dust_vfx:
		_character.dust_vfx.init_offsets(character_data)
	_character.animator.skip_offsets = not _show_anim_offset
	# Respetar el estado del toggle de físicas
	_character.set_physics_process(_physics_enabled)
	_character.velocity = Vector2.ZERO
	if _character.state_machine:
		_character.state_machine.set_physics_process(_physics_enabled)
	if _character.combat:
		_character.combat.set_physics_process(_physics_enabled)
	if _character.animator.sprite_frames:
		_character.animator.play_anim("idle")
		_character.animator.stop()
		_character.animator.frame = 0
	_anim_playing = false
	_anim_play_accum = 0.0
	if _play_btn:
		_play_btn.set_pressed_no_signal(false)
	_dust_playing = false
	_dust_play_accum = 0.0
	if _dust_play_btn:
		_dust_play_btn.set_pressed_no_signal(false)
	_update_shadow_tool()
	_current_frame = 0
	_dust_frame_index = 0
	if _character.dust_vfx:
		_character.dust_vfx.preview_hide()
	_sync_dust_ui()
	_update_kf_editors_enabled()
	_update_frame_label()
	_draw_node.queue_redraw()


func _on_anim_selected(idx: int) -> void:
	if idx <= 0 or idx > _anims.size():
		return
	_current_anim = _anims[idx - 1]
	_current_frame = 0
	_anim_playing = false
	_anim_play_accum = 0.0
	if _play_btn:
		_play_btn.set_pressed_no_signal(false)
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
		_update_kf_editors_enabled()
		_update_frame_info()
		_draw_node.queue_redraw()
		return
	_current_attack = character_data.attacks.get(_attacks[idx - 1], null)
	_load_attack_keyframes()
	_update_kf_editors_enabled()
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


func _update_kf_editors_enabled() -> void:
	var enabled := _current_attack != null
	if _kf_warning_label:
		_kf_warning_label.visible = not enabled
	for sb in [_hb_offset_x, _hb_offset_y, _hb_size_x, _hb_size_y, _hr_offset_x, _hr_offset_y, _hr_size_x, _hr_size_y]:
		if sb:
			sb.editable = enabled
	if _hb_active_check:
		_hb_active_check.disabled = not enabled


func _goto_frame(f: int) -> void:
	if _character == null or _character.animator == null:
		return
	var sf := _character.animator.sprite_frames
	if sf == null:
		return
	var max_f := sf.get_frame_count(_current_anim) - 1
	if max_f < 0:
		return
	_current_frame = clampi(f, 0, max_f)
	_anim_playing = false
	if _play_btn:
		_play_btn.set_pressed_no_signal(false)
	_character.animator.stop()
	_character.animator.frame = _current_frame
	_update_shadow_tool()
	_update_frame_label()
	_update_frame_info()
	_draw_node.queue_redraw()


func _toggle_play() -> void:
	if _character == null:
		return
	_anim_playing = _play_btn.button_pressed
	_anim_play_accum = 0.0
	if _anim_playing:
		_character.animator.stop()


func _on_stop_pressed() -> void:
	_anim_playing = false
	if _play_btn:
		_play_btn.set_pressed_no_signal(false)
	_goto_frame(0)


func _toggle_dust_play() -> void:
	_dust_playing = _dust_play_btn.button_pressed
	_dust_play_accum = 0.0
	if _dust_playing and _dust_frame_index > 0:
		_dust_frame_index = 0
		_sync_dust_ui()


func _process(delta: float) -> void:
	if _anim_playing and _character and _character.animator and _character.animator.sprite_frames:
		var sf := _character.animator.sprite_frames
		if sf.has_animation(_current_anim):
			var frame_count := sf.get_frame_count(_current_anim)
			if frame_count > 0:
				var fps := sf.get_animation_speed(_current_anim)
				if fps <= 0.0:
					fps = 8.0
				var loop := _anim_loop_override or sf.get_animation_loop(_current_anim)
				_anim_play_accum += delta * _anim_speed
				var frame_time := 1.0 / fps
				var stopped := false
				while _anim_play_accum >= frame_time:
					_anim_play_accum -= frame_time
					_current_frame += 1
					if _current_frame >= frame_count:
						if loop:
							_current_frame = 0
						else:
							_current_frame = frame_count - 1
							stopped = true
							break
				_character.animator.frame = _current_frame
				_update_shadow_tool()
				_update_frame_label()
				_update_frame_info()
				_draw_node.queue_redraw()
				if stopped:
					_anim_playing = false
					if _play_btn:
						_play_btn.set_pressed_no_signal(false)

	if _dust_playing and _character and _character.dust_vfx:
		var dvfx := _character.dust_vfx
		var fps := dvfx.get_dust_fps_value(_current_dust)
		var count := dvfx.get_dust_frame_count(_current_dust)
		if count > 0 and fps > 0.0:
			_dust_play_accum += delta
			var frame_time := 1.0 / fps
			var loop := _dust_loop_check.button_pressed or dvfx.get_dust_loop(_current_dust)
			while _dust_play_accum >= frame_time:
				_dust_play_accum -= frame_time
				_dust_frame_index += 1
				if _dust_frame_index >= count:
					if loop:
						_dust_frame_index = 0
					else:
						_dust_frame_index = count - 1
						_dust_playing = false
						_dust_play_btn.set_pressed_no_signal(false)
			_dust_frame_spin.set_value_no_signal(_dust_frame_index)
			_update_dust_preview()
			_draw_node.queue_redraw()


func _settle_y() -> float:
	# CharacterBody2D origin = center of collision.
	# floor_body at _floor_y, shape (w, 20) → top surface = _floor_y - 10.
	# character shape default (100, 100), scale (2,2) → half_h = 50 * 2 = 100.
	# origin.y + 100 = _floor_y - 10  →  origin.y = _floor_y - 110
	return _floor_y - 110.0


func _get_floor_global_y() -> float:
	if _character == null:
		return 0.0
	_character.floor_ray.force_raycast_update()
	if _character.floor_ray.is_colliding():
		return _character.floor_ray.get_collision_point().y
	return _floor_y


func _update_shadow_tool() -> void:
	if _character == null:
		return
	_character.floor_ray.force_raycast_update()
	_character.update_shadow()


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
		d += "HB frame %d: off=Vec2(%s,%s) sz=Vec2(%s,%s) act=%s" % [
			hk.frame, hk.offset.x, hk.offset.y, hk.size.x, hk.size.y, hk.active]
	else:
		d += "HB: sin keyframe"
	if hbk:
		d += "\nHR frame %d: off=Vec2(%s,%s) sz=Vec2(%s,%s)" % [
			hbk.frame, hbk.offset.x, hbk.offset.y, hbk.size.x, hbk.size.y]
	else:
		d += "\nHR: sin keyframe"
	_hb_detail_label.text = d

	if hk:
		_hb_offset_x.set_value_no_signal(hk.offset.x); _hb_offset_y.set_value_no_signal(hk.offset.y)
		_hb_size_x.set_value_no_signal(hk.size.x); _hb_size_y.set_value_no_signal(hk.size.y)
		_hb_active_check.set_pressed_no_signal(hk.active)
	else:
		_hb_offset_x.set_value_no_signal(_current_attack.hitbox_offset.x if _current_attack else 0.0)
		_hb_offset_y.set_value_no_signal(_current_attack.hitbox_offset.y if _current_attack else 0.0)
		_hb_size_x.set_value_no_signal(BASE_HITBOX_SIZE.x); _hb_size_y.set_value_no_signal(BASE_HITBOX_SIZE.y)
		_hb_active_check.set_pressed_no_signal(true)
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


func _on_anim_offset_toggled(v: bool) -> void:
	_show_anim_offset = v
	if _character == null or _character.animator == null:
		return
	_character.animator.skip_offsets = not v


# ─── Dust ───────────────────────────────────────────────────────────────────

func _get_dust_anchor() -> Vector2:
	if _character == null:
		return Vector2.ZERO
	return Vector2(_character.global_position.x, _get_floor_global_y())


func _get_dust_world_pos() -> Vector2:
	if _character == null or _character.dust_vfx == null:
		return Vector2.ZERO
	return _get_dust_anchor() + _character.dust_vfx.get_base_offset(_current_dust)


func _update_dust_preview() -> void:
	if _character == null or _character.dust_vfx == null:
		return
	if not _show_dust:
		_character.dust_vfx.preview_hide()
		return
	_character.dust_vfx.preview_show(_current_dust, _dust_frame_index, _get_dust_anchor())


func _sync_dust_ui() -> void:
	if _character == null or _character.dust_vfx == null:
		return
	var dvfx := _character.dust_vfx
	var base: Vector2 = dvfx.get_base_offset(_current_dust)
	_dust_offset_x.set_value_no_signal(base.x)
	_dust_offset_y.set_value_no_signal(base.y)
	var frame_off: Vector2 = dvfx.get_frame_offset(_current_dust, _dust_frame_index)
	_dust_frame_offset_x.set_value_no_signal(frame_off.x)
	_dust_frame_offset_y.set_value_no_signal(frame_off.y)
	# Z-index: buscar el índice en el OptionButton
	var zi: int = dvfx.get_dust_z_index(_current_dust)
	for i in _dust_z_index_option.item_count:
		if _dust_z_index_option.get_item_id(i) == zi:
			_dust_z_index_option.selected = i
			break
	_dust_fps_spin.set_value_no_signal(dvfx.get_dust_fps_value(_current_dust))
	var count := dvfx.get_dust_frame_count(_current_dust)
	_dust_frame_spin.max_value = maxf(0, count - 1)
	_dust_frame_index = clampi(_dust_frame_index, 0, maxi(count - 1, 0))
	_dust_frame_spin.set_value_no_signal(_dust_frame_index)
	_dust_info_label.text = "%s | %d/%d | fps=%.1f | loop=%s" % [
		_current_dust, _dust_frame_index, maxi(count - 1, 0),
		dvfx.get_dust_fps_value(_current_dust), dvfx.get_dust_loop(_current_dust)]
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
	var val := Vector2(_dust_offset_x.value, _dust_offset_y.value)
	_character.dust_vfx.set_base_offset(_current_dust, val)
	_update_dust_preview()
	_draw_node.queue_redraw()


func _on_dust_frame_offset_changed(_v: float) -> void:
	if _character == null or _character.dust_vfx == null:
		return
	var val := Vector2(_dust_frame_offset_x.value, _dust_frame_offset_y.value)
	_character.dust_vfx.set_frame_offset(_current_dust, _dust_frame_index, val)
	_update_dust_preview()
	_draw_node.queue_redraw()


func _on_dust_z_index_changed(_idx: int) -> void:
	if _character == null or _character.dust_vfx == null:
		return
	var zi: int = _dust_z_index_option.get_item_id(_idx)
	_character.dust_vfx.set_dust_z_index(_current_dust, zi)
	_draw_node.queue_redraw()


func _on_dust_fps_changed(_v: float) -> void:
	if _character == null or _character.dust_vfx == null:
		return
	_character.dust_vfx.set_dust_fps_value(_current_dust, _dust_fps_spin.value)
	_sync_dust_ui()


func _on_save_dust() -> void:
	if character_data == null:
		_info_label.text = "No hay datos cargados"
		return
	if _character == null or _character.dust_vfx == null:
		_info_label.text = "No hay personaje instanciado"
		return
	character_data.dust_offsets = _character.dust_vfx.to_character_dust_offsets()
	var path := character_data.resource_path
	if path.is_empty():
		_info_label.text = "Error: sin path"
		return
	var err := ResourceSaver.save(character_data, path)
	if err == OK:
		_info_label.text = "Dust guardado en %s" % path.get_file()
	else:
		_info_label.text = "Error guardando: " + error_string(err)


# ─── Render overlay ─────────────────────────────────────────────────────────

func _get_hb_rect_world(cp: Vector2, sc: Vector2, facing: float) -> Rect2:
	var hk: HitboxKeyframe = _hk_by_frame.get(_current_frame, null)
	var off := Vector2.ZERO
	var sz := BASE_HITBOX_SIZE
	if hk:
		off = hk.offset; sz = hk.size
	elif _current_attack:
		off = _current_attack.hitbox_offset; sz = BASE_HITBOX_SIZE * _current_attack.hitbox_scale
	var center := cp + Vector2(off.x * facing, off.y) * sc
	var box_size := sz * sc
	return Rect2(center - box_size * 0.5, box_size)


func _get_hr_rect_world(cp: Vector2, sc: Vector2, facing: float) -> Rect2:
	var hbk: HurtboxKeyframe = _hbk_by_frame.get(_current_frame, null)
	var off := Vector2.ZERO
	var sz := BASE_HURTBOX_SIZE
	if hbk:
		off = hbk.offset; sz = hbk.size
	var center := cp + Vector2(off.x * facing, off.y) * sc
	var box_size := sz * sc
	return Rect2(center - box_size * 0.5, box_size)


func _get_attack_phase() -> String:
	if _current_attack == null:
		return ""
	if _current_frame < _current_attack.startup_frames:
		return "startup"
	elif _current_frame < _current_attack.startup_frames + _current_attack.active_frames:
		return "active"
	else:
		return "recovery"


func _render_overlay(d: Node2D) -> void:
	if _character == null:
		return
	var cp := _character.global_position
	var sc := _character.scale
	var facing := 1.0 if _character.facing_right else -1.0
	var editable := _current_attack != null

	var floor_y := _get_floor_global_y()
	d.draw_line(Vector2(-1000, floor_y), Vector2(1000, floor_y), Color(1, 1, 1, 0.15), 1.0)

	# Phase overlay on character sprite
	if editable:
		var phase := _get_attack_phase()
		var phase_color: Color
		match phase:
			"startup": phase_color = Color(1, 1, 0, 0.18)
			"active": phase_color = Color(1, 0.2, 0.2, 0.22)
			_: phase_color = Color(0.3, 0.5, 1, 0.18)
		# Sprite rect: 170×92 original × scale(2,2) = 340×184, origin at center
		var sprite_half := Vector2(85, 46) * sc
		var sprite_rect := Rect2(cp - sprite_half, sprite_half * 2.0)
		d.draw_rect(sprite_rect, phase_color, true)
		# Phase label
		var label_color: Color
		match phase:
			"startup": label_color = Color(1, 1, 0.3, 0.9)
			"active": label_color = Color(1, 0.4, 0.4, 0.9)
			_: label_color = Color(0.5, 0.7, 1, 0.9)
		d.draw_string(ThemeDB.fallback_font, sprite_rect.position + Vector2(4, 14),
			phase.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, label_color)

	if _show_hitbox:
		var hb_rect := _get_hb_rect_world(cp, sc, facing)
		var hk: HitboxKeyframe = _hk_by_frame.get(_current_frame, null)
		var active := hk.active if hk else true
		var fill_color := Color(1, 0, 0, 0.45) if active else Color(0.5, 0.5, 0.5, 0.25)
		var line_color := Color(1, 0.3, 0.3, 0.9) if active else Color(0.7, 0.7, 0.7, 0.6)
		if not editable:
			fill_color.a *= 0.4
			line_color.a *= 0.5
		d.draw_rect(hb_rect, fill_color, true)
		d.draw_rect(hb_rect, line_color, false, 1.5)
		if editable:
			_draw_handles(d, hb_rect, Color(1, 0.6, 0.6) if active else Color(0.7, 0.7, 0.7))

	if _show_hurtbox:
		var hr_rect := _get_hr_rect_world(cp, sc, facing)
		d.draw_rect(hr_rect, Color(0.2, 0.8, 0.2, 0.3 if editable else 0.12), true)
		d.draw_rect(hr_rect, Color(0.3, 1, 0.3, 0.8 if editable else 0.35), false, 1.5)
		if editable:
			_draw_handles(d, hr_rect, Color(0.6, 1, 0.6))

	if _show_dust and _character.dust_vfx:
		var dust_pos := _get_dust_world_pos()
		d.draw_line(dust_pos - Vector2(8, 0), dust_pos + Vector2(8, 0), Color.YELLOW, 1.5)
		d.draw_line(dust_pos - Vector2(0, 8), dust_pos + Vector2(0, 8), Color.YELLOW, 1.5)
		d.draw_string(ThemeDB.fallback_font, dust_pos + Vector2(10, -5), _current_dust, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.YELLOW)

	# Timeline bar (only when an attack is selected)
	if editable:
		_draw_timeline(d, floor_y)


func _draw_handles(d: Node2D, rect: Rect2, color: Color) -> void:
	var s := 7.0
	var pts := [
		rect.position,
		Vector2(rect.position.x + rect.size.x, rect.position.y),
		Vector2(rect.position.x, rect.position.y + rect.size.y),
		rect.position + rect.size,
	]
	for p in pts:
		d.draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), color, true)


const TIMELINE_Y_OFFSET := 50.0
const TIMELINE_HEIGHT := 14.0


func _draw_timeline(d: Node2D, floor_y: float) -> void:
	if _current_attack == null:
		return
	var total_frames := _current_attack.startup_frames + _current_attack.active_frames + _current_attack.recovery_frames
	if total_frames <= 0:
		return
	var sf := _character.animator.sprite_frames if _character and _character.animator else null
	var anim_frames := sf.get_frame_count(_current_anim) if sf and sf.has_animation(_current_anim) else total_frames
	var display_frames := maxi(total_frames, anim_frames)

	# Bar dimensions
	var bar_w := minf(display_frames * 18.0, 600.0)
	var bar_x := -bar_w * 0.5
	var bar_y := floor_y + TIMELINE_Y_OFFSET
	var bar_size := Vector2(bar_w, TIMELINE_HEIGHT)

	# Background
	d.draw_rect(Rect2(Vector2(bar_x, bar_y), bar_size), Color(0.15, 0.15, 0.15, 0.85), true)

	# Phase segments
	var startup_w := bar_w * (_current_attack.startup_frames / float(display_frames))
	var active_w := bar_w * (_current_attack.active_frames / float(display_frames))
	var recovery_w := bar_w * (_current_attack.recovery_frames / float(display_frames))
	var x := bar_x
	if _current_attack.startup_frames > 0:
		d.draw_rect(Rect2(Vector2(x, bar_y), Vector2(startup_w, TIMELINE_HEIGHT)), Color(1, 0.85, 0, 0.45), true)
		x += startup_w
	if _current_attack.active_frames > 0:
		d.draw_rect(Rect2(Vector2(x, bar_y), Vector2(active_w, TIMELINE_HEIGHT)), Color(1, 0.25, 0.25, 0.55), true)
		x += active_w
	if _current_attack.recovery_frames > 0:
		d.draw_rect(Rect2(Vector2(x, bar_y), Vector2(recovery_w, TIMELINE_HEIGHT)), Color(0.3, 0.5, 1, 0.45), true)

	# Border
	d.draw_rect(Rect2(Vector2(bar_x, bar_y), bar_size), Color(0.5, 0.5, 0.5, 0.7), false, 1.0)

	# Frame cursor
	var cursor_x := bar_x + bar_w * (_current_frame / float(display_frames))
	var cursor_color: Color
	match _get_attack_phase():
		"startup": cursor_color = Color(1, 1, 0, 1)
		"active": cursor_color = Color(1, 0.3, 0.3, 1)
		_: cursor_color = Color(0.4, 0.6, 1, 1)
	d.draw_line(Vector2(cursor_x, bar_y - 3), Vector2(cursor_x, bar_y + TIMELINE_HEIGHT + 3), cursor_color, 2.0)

	# Frame label below cursor
	d.draw_string(ThemeDB.fallback_font, Vector2(cursor_x - 4, bar_y + TIMELINE_HEIGHT + 15),
		str(_current_frame), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, cursor_color)

	# Phase boundary ticks
	var tick_y_end := bar_y + TIMELINE_HEIGHT
	var sf2 := bar_x + startup_w
	var af2 := sf2 + active_w
	if _current_attack.startup_frames > 0 and _current_attack.active_frames > 0:
		d.draw_line(Vector2(sf2, bar_y), Vector2(sf2, tick_y_end), Color(0.5, 0.5, 0.5, 0.6), 1.0)
	if _current_attack.active_frames > 0 and _current_attack.recovery_frames > 0:
		d.draw_line(Vector2(af2, bar_y), Vector2(af2, tick_y_end), Color(0.5, 0.5, 0.5, 0.6), 1.0)


# ─── Input ──────────────────────────────────────────────────────────────────

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
		var cp := _character.global_position if _character else Vector2(0, _settle_y())
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.alt_pressed:
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
		hk.frame = _current_frame; hk.offset = off
		hk.size = Vector2(_hb_size_x.value, _hb_size_y.value); hk.active = true
		_current_attack.hitbox_keyframes.append(hk)
		_hk_by_frame[_current_frame] = hk
	else:
		if _hbk_by_frame.has(_current_frame):
			return
		var hbk := HurtboxKeyframe.new()
		hbk.frame = _current_frame; hbk.offset = off
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


func _start_drag(kind: String, handle: String, offset: Vector2, box_size: Vector2, mouse_world: Vector2) -> void:
	_dragging = true
	_drag_kind = kind
	_drag_handle = handle
	_drag_start_offset = offset
	_drag_start_size = box_size
	_drag_start_mouse_world = mouse_world


func _get_or_create_hitbox_keyframe() -> HitboxKeyframe:
	if _hk_by_frame.has(_current_frame):
		return _hk_by_frame[_current_frame]
	var hk := HitboxKeyframe.new()
	hk.frame = _current_frame
	if _current_attack:
		hk.offset = _current_attack.hitbox_offset
		hk.size = BASE_HITBOX_SIZE * _current_attack.hitbox_scale
	else:
		hk.size = BASE_HITBOX_SIZE
	hk.active = true
	_current_attack.hitbox_keyframes.append(hk)
	_hk_by_frame[_current_frame] = hk
	return hk


func _get_or_create_hurtbox_keyframe() -> HurtboxKeyframe:
	if _hbk_by_frame.has(_current_frame):
		return _hbk_by_frame[_current_frame]
	var hbk := HurtboxKeyframe.new()
	hbk.frame = _current_frame
	hbk.size = BASE_HURTBOX_SIZE
	_current_attack.hurtbox_keyframes.append(hbk)
	_hbk_by_frame[_current_frame] = hbk
	return hbk


func _try_drag(local: Vector2, cp: Vector2) -> void:
	if _character == null:
		return
	var sc := _character.scale
	var facing := 1.0 if _character.facing_right else -1.0

	if _current_attack != null:
		if _show_hurtbox:
			var hr_rect := _get_hr_rect_world(cp, sc, facing)
			var handle := _handle_at_rect(local, hr_rect)
			if handle != "":
				var hbk := _get_or_create_hurtbox_keyframe()
				_start_drag("hurtbox", handle, hbk.offset, hbk.size, local)
				_update_frame_info()
				return

		if _show_hitbox:
			var hb_rect := _get_hb_rect_world(cp, sc, facing)
			var handle := _handle_at_rect(local, hb_rect)
			if handle != "":
				var hk := _get_or_create_hitbox_keyframe()
				_start_drag("hitbox", handle, hk.offset, hk.size, local)
				_update_frame_info()
				return

	if _show_dust and _character.dust_vfx:
		var dust_pos := _get_dust_world_pos()
		var margin: float = HANDLE_MARGIN / _camera.zoom.x
		if local.distance_to(dust_pos) <= margin:
			var base := _character.dust_vfx.get_base_offset(_current_dust)
			_start_drag("dust", "move", base, Vector2.ZERO, local)
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
	var world_delta := local - _drag_start_mouse_world
	var new_base: Vector2 = _drag_start_offset + world_delta
	new_base = Vector2(roundf(new_base.x), roundf(new_base.y))
	_character.dust_vfx.set_base_offset(_current_dust, new_base)
	_dust_offset_x.set_value_no_signal(new_base.x)
	_dust_offset_y.set_value_no_signal(new_base.y)
	_update_dust_preview()
	_draw_node.queue_redraw()


func _on_hb_active_toggled(v: bool) -> void:
	if _current_attack == null:
		return
	var hk := _get_or_create_hitbox_keyframe()
	hk.active = v
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


func _on_copy_keyframe() -> void:
	if _current_attack == null or _current_frame <= 0:
		return
	var prev_frame := _current_frame - 1
	# Copy hitbox keyframe
	if _hk_by_frame.has(prev_frame) and not _hk_by_frame.has(_current_frame):
		var src: HitboxKeyframe = _hk_by_frame[prev_frame]
		var hk := HitboxKeyframe.new()
		hk.frame = _current_frame; hk.offset = src.offset; hk.size = src.size; hk.active = src.active
		_current_attack.hitbox_keyframes.append(hk)
		_hk_by_frame[_current_frame] = hk
	elif _hk_by_frame.has(prev_frame) and _hk_by_frame.has(_current_frame):
		var src: HitboxKeyframe = _hk_by_frame[prev_frame]
		var dst: HitboxKeyframe = _hk_by_frame[_current_frame]
		dst.offset = src.offset; dst.size = src.size; dst.active = src.active
	# Copy hurtbox keyframe
	if _hbk_by_frame.has(prev_frame) and not _hbk_by_frame.has(_current_frame):
		var src: HurtboxKeyframe = _hbk_by_frame[prev_frame]
		var hbk := HurtboxKeyframe.new()
		hbk.frame = _current_frame; hbk.offset = src.offset; hbk.size = src.size
		_current_attack.hurtbox_keyframes.append(hbk)
		_hbk_by_frame[_current_frame] = hbk
	elif _hbk_by_frame.has(prev_frame) and _hbk_by_frame.has(_current_frame):
		var src: HurtboxKeyframe = _hbk_by_frame[prev_frame]
		var dst: HurtboxKeyframe = _hbk_by_frame[_current_frame]
		dst.offset = src.offset; dst.size = src.size
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
