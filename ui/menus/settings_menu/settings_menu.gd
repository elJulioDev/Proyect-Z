extends Control
## Menú de configuraciones: 3 categorías (Rendimiento, Sonido, Juego)
## con navegación fluida por flechas + dots. Persiste en user://settings.cfg.

const CONTROLS_MENU_PATH := "res://ui/menus/settings_menu/controls_menu.tscn"
const MAIN_MENU_PATH := "res://ui/menus/main_menu/menu.tscn"
const HOVER_SFX_PATH := "res://assets/audio/sfx/ui/Cursor.wav"
const CLICK_SFX_PATH := "res://assets/audio/sfx/ui/Decide_2.wav"
const SAVE_PATH := "user://settings.cfg"

var _categories: Array = []
var _current_index := 0
var _values: Dictionary = {}
var _busy := false

@onready var _title_label: Label = $Panel/Clip/PageRoot/Header/TitleLabel
@onready var _icon: TextureRect = $Panel/Clip/PageRoot/Header/Icon
@onready var _rows_container: VBoxContainer = $Panel/Clip/PageRoot/Scroll/RowsContainer
@onready var _page_root: VBoxContainer = $Panel/Clip/PageRoot
@onready var _dots: HBoxContainer = $Dots
@onready var _arrow_left: Button = $ArrowLeft
@onready var _arrow_right: Button = $ArrowRight
@onready var _reset_button: Button = $BottomMargin/BottomBar/ResetButton
@onready var _back_button: Button = $BottomMargin/BottomBar/BackButton

var hover_player: AudioStreamPlayer
var click_player: AudioStreamPlayer


func _ready() -> void:
	_define_categories()
	_load_defaults()
	_load_saved()
	_setup_audio()
	_connect_signals()
	_render_category(0, false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT:
			_on_nav_pressed(true)
		elif event.keycode == KEY_RIGHT:
			_on_nav_pressed(false)


# ─── Datos ──────────────────────────────────────────────────────────────────

func _define_categories() -> void:
	_categories = [
		{
			"title": "Rendimiento",
			"icon": "res://assets/ui/menus/display.png",
			"rows": [
				{"id": "resolution", "label": "Resolución", "type": "dropdown", "options": ["1280 x 720", "1920 x 1080", "2560 x 1440"], "default": 0},
				{"id": "fullscreen", "label": "Pantalla completa", "type": "toggle", "default": false},
				{"id": "fps", "label": "FPS máximo", "type": "limit_slider", "min": 30, "max": 240, "step": 10, "default": 60, "limited_default": true, "suffix": ""},
				{"id": "vsync", "label": "VSync", "type": "dropdown", "options": ["Desactivado", "Activado", "Adaptativo"], "default": 1},
			],
		},
		{
			"title": "Sonido",
			"icon": "res://assets/ui/menus/sound.png",
			"rows": [
				{"id": "vol_master", "label": "Volumen general", "type": "slider", "min": 0, "max": 100, "step": 5, "default": 80, "suffix": "%"},
				{"id": "vol_music", "label": "Música", "type": "slider", "min": 0, "max": 100, "step": 5, "default": 80, "suffix": "%"},
				{"id": "vol_ui", "label": "Interfaz", "type": "slider", "min": 0, "max": 100, "step": 5, "default": 80, "suffix": "%"},
				{"id": "vol_sfx", "label": "Efectos de sonido", "type": "slider", "min": 0, "max": 100, "step": 5, "default": 80, "suffix": "%"},
				{"id": "vol_gameplay_fx", "label": "Efectos de gameplay", "type": "slider", "min": 0, "max": 100, "step": 5, "default": 80, "suffix": "%"},
			],
		},
		{
			"title": "Juego",
			"icon": "res://assets/ui/menus/game.png",
			"rows": [
				{"id": "match_time", "label": "Tiempo de juego", "type": "limit_slider", "min": 30, "max": 999, "step": 10, "default": 120, "limited_default": false, "suffix": " s"},
				{"id": "rounds", "label": "Total de rondas", "type": "slider", "min": 1, "max": 4, "step": 1, "default": 2, "suffix": ""},
				{"id": "controls", "label": "Ver controles", "type": "dual_button"},
				{"id": "language", "label": "", "type": "segmented", "options": ["Español", "Ingles"], "default": 0},
			],
		},
	]


func _load_defaults() -> void:
	for cat in _categories:
		for row in cat.rows:
			match row.type:
				"toggle": _values[row.id] = row.default
				"dropdown": _values[row.id] = row.default
				"segmented": _values[row.id] = row.default
				"slider": _values[row.id] = row.default
				"limit_slider": _values[row.id] = {"limited": row.limited_default, "value": row.default}


func _load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for key in _values.keys():
		if not cfg.has_section_key("settings", key):
			continue
		var stored = cfg.get_value("settings", key)
		if typeof(stored) == typeof(_values[key]):
			_values[key] = stored


func _save() -> void:
	var cfg := ConfigFile.new()
	for key in _values.keys():
		cfg.set_value("settings", key, _values[key])
	cfg.save(SAVE_PATH)


# ─── Señales ────────────────────────────────────────────────────────────────

func _connect_signals() -> void:
	_arrow_left.pressed.connect(_on_nav_pressed.bind(true))
	_arrow_right.pressed.connect(_on_nav_pressed.bind(false))
	_arrow_left.mouse_entered.connect(func(): hover_player.play())
	_arrow_right.mouse_entered.connect(func(): hover_player.play())
	_reset_button.pressed.connect(_on_reset_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_reset_button.mouse_entered.connect(func(): hover_player.play())
	_back_button.mouse_entered.connect(func(): hover_player.play())


# ─── Render de categoría ────────────────────────────────────────────────────

func _render_category(index: int, animate: bool) -> void:
	_current_index = index
	var cat: Dictionary = _categories[index]
	_title_label.text = cat.title
	_icon.texture = load(cat.icon)
	_update_dots()

	for c in _rows_container.get_children():
		c.queue_free()

	var grid_cols: int = cat.get("grid", 1)
	if grid_cols > 1:
		var grid := GridContainer.new()
		grid.columns = grid_cols
		grid.add_theme_constant_override("h_separation", 24)
		grid.add_theme_constant_override("v_separation", 18)
		_rows_container.add_child(grid)
		for row in cat.rows:
			grid.add_child(_build_row(row))
	else:
		for row in cat.rows:
			_rows_container.add_child(_build_row(row))

	if animate:
		_page_root.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_page_root, "modulate:a", 1.0, 0.18)


func _update_dots() -> void:
	for i in _dots.get_child_count():
		var dot: Panel = _dots.get_child(i)
		var style: StyleBoxFlat = dot.get_theme_stylebox("panel")
		style.bg_color = Color(1, 1, 1, 0.95) if i == _current_index else Color(1, 1, 1, 0.3)


# ─── Filas ──────────────────────────────────────────────────────────────────

func _card() -> PanelContainer:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.05)
	style.border_color = Color(1, 1, 1, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	box.add_theme_stylebox_override("panel", style)
	return box


func _build_row(row: Dictionary) -> Control:
	match row.type:
		"toggle": return _build_toggle_row(row)
		"dropdown": return _build_dropdown_row(row)
		"slider": return _build_slider_row(row)
		"limit_slider": return _build_limit_slider_row(row)
		"segmented": return _build_segmented_row(row)
		"dual_button": return _build_dual_button_row(row)
	return Control.new()


func _build_toggle_row(row: Dictionary) -> Control:
	var box := _card()
	var h := HBoxContainer.new()
	box.add_child(h)
	var lbl := Label.new()
	lbl.text = row.label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	h.add_child(lbl)

	var sw := ToggleSwitch.new()
	sw.value = _values[row.id]
	sw.toggled.connect(func(v):
		_values[row.id] = v
		_save()
	)
	h.add_child(sw)
	return box


func _make_big_toggle(on: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 34)
	b.add_theme_font_size_override("font_size", 14)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.mouse_entered.connect(func(): hover_player.play())
	b.pressed.connect(func(): click_player.play())
	_update_big_toggle(b, on)
	return b


func _update_big_toggle(b: Button, on: bool) -> void:
	b.text = "Activado" if on else "Desactivado"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.62, 0.28, 0.9) if on else Color(0.62, 0.16, 0.16, 0.9)
	style.set_corner_radius_all(8)
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", style)
	b.add_theme_stylebox_override("pressed", style)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 1))


func _styled_slider(min_v: float, max_v: float, step: float, value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, 22)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.1)
	track.set_corner_radius_all(6)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.99, 0.55, 0.02, 1)
	fill.set_corner_radius_all(6)
	fill.content_margin_top = 8
	fill.content_margin_bottom = 8
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	return s


func _build_slider_row(row: Dictionary) -> Control:
	var box := _card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	box.add_child(v)
	var lbl := Label.new()
	lbl.text = row.label
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	v.add_child(lbl)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	var suffix: String = row.get("suffix", "")
	var slider := _styled_slider(row.get("min", 0), row.get("max", 100), row.get("step", 1), _values[row.id])
	h.add_child(slider)
	var value_lbl := Label.new()
	value_lbl.custom_minimum_size.x = 56
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_lbl.add_theme_font_size_override("font_size", 14)
	value_lbl.add_theme_color_override("font_color", Color(0.99, 0.85, 0.2, 1))
	value_lbl.text = "%d%s" % [int(_values[row.id]), suffix]
	h.add_child(value_lbl)
	slider.value_changed.connect(func(nv):
		_values[row.id] = int(nv)
		value_lbl.text = "%d%s" % [int(nv), suffix]
		_save()
	)
	return box


func _build_limit_slider_row(row: Dictionary) -> Control:
	var box := _card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	box.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var lbl := Label.new()
	lbl.text = row.label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	top.add_child(lbl)
	var state: Dictionary = _values[row.id]
	var limited: bool = state.get("limited", row.get("limited_default", false))
	var pill := _make_big_toggle(limited)
	pill.custom_minimum_size.x = 120
	top.add_child(pill)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	var suffix: String = row.get("suffix", "")
	var val: int = state.get("value", row.get("default", 0))
	var slider := _styled_slider(row.get("min", 0), row.get("max", 100), row.get("step", 1), val)
	slider.editable = limited
	slider.modulate.a = 1.0 if limited else 0.4
	h.add_child(slider)
	var value_lbl := Label.new()
	value_lbl.custom_minimum_size.x = 56
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_lbl.add_theme_font_size_override("font_size", 14)
	value_lbl.add_theme_color_override("font_color", Color(0.99, 0.85, 0.2, 1))
	value_lbl.text = ("%d%s" % [val, suffix]) if limited else "∞"
	h.add_child(value_lbl)
	slider.value_changed.connect(func(nv):
		state["value"] = int(nv)
		value_lbl.text = "%d%s" % [int(nv), suffix]
		_save()
	)
	pill.pressed.connect(func():
		limited = not limited
		state["limited"] = limited
		_update_big_toggle(pill, limited)
		slider.editable = limited
		slider.modulate.a = 1.0 if limited else 0.4
		value_lbl.text = ("%d%s" % [state.get("value", 0), suffix]) if limited else "∞"
		_save()
	)
	return box


func _build_dropdown_row(row: Dictionary) -> Control:
	var box := _card()
	var h := HBoxContainer.new()
	box.add_child(h)
	var lbl := Label.new()
	lbl.text = row.label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	h.add_child(lbl)
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(180, 34)
	opt.add_theme_font_size_override("font_size", 14)
	for text in row.options:
		opt.add_item(text)
	opt.selected = _values[row.id]
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.08)
	style.border_color = Color(1, 1, 1, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	opt.add_theme_stylebox_override("normal", style)
	opt.add_theme_stylebox_override("hover", style)
	opt.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	opt.item_selected.connect(func(idx):
		_values[row.id] = idx
		click_player.play()
		_save()
	)
	h.add_child(opt)
	return box


func _build_dual_button_row(_row: Dictionary) -> Control:
	var box := _card()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	box.add_child(h)
	var b1 := _make_nav_button("Jugador 1")
	var b2 := _make_nav_button("Jugador 2")
	h.add_child(b1)
	h.add_child(b2)
	b1.pressed.connect(func():
		click_player.play()
		get_tree().change_scene_to_file(CONTROLS_MENU_PATH)
	)
	b2.pressed.connect(func():
		click_player.play()
		get_tree().change_scene_to_file(CONTROLS_MENU_PATH)
	)
	return box


func _make_nav_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 15)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.06)
	style.border_color = Color(1, 1, 1, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	var hover := style.duplicate()
	hover.bg_color = Color(0.99, 0.55, 0.02, 0.85)
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	b.mouse_entered.connect(func(): hover_player.play())
	return b


func _build_segmented_row(row: Dictionary) -> Control:
	var h := HBoxContainer.new()
	var options: Array = row.options
	var selected: int = _values[row.id]
	var buttons: Array = []
	for opt in options:
		var b := Button.new()
		b.text = opt
		b.custom_minimum_size = Vector2(0, 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 15)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.mouse_entered.connect(func(): hover_player.play())
		buttons.append(b)
		h.add_child(b)
	for i in buttons.size():
		buttons[i].pressed.connect(func():
			_values[row.id] = i
			for j in buttons.size():
				_style_segmented(buttons[j], j == i)
			click_player.play()
			_save()
		)
		_style_segmented(buttons[i], i == selected)
	return h


func _style_segmented(b: Button, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.99, 0.55, 0.02, 0.9) if active else Color(1, 1, 1, 0.08)
	style.border_color = Color(1, 1, 1, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", style)
	b.add_theme_stylebox_override("pressed", style)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 1))


# ─── Navegación ─────────────────────────────────────────────────────────────

func _on_nav_pressed(is_left: bool) -> void:
	if _busy:
		return
	click_player.play()
	var next := _current_index - 1 if is_left else _current_index + 1
	next = (next + _categories.size()) % _categories.size()
	_swap_category(next, is_left)


func _swap_category(next: int, is_left: bool) -> void:
	_busy = true
	var dir := 1.0 if is_left else -1.0
	var tw := create_tween()
	tw.tween_property(_page_root, "position:x", 30.0 * dir, 0.12).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(_page_root, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func():
		_render_category(next, false)
		_page_root.position.x = -30.0 * dir
		var tw2 := create_tween()
		tw2.tween_property(_page_root, "position:x", 0.0, 0.14).set_trans(Tween.TRANS_QUAD)
		tw2.parallel().tween_property(_page_root, "modulate:a", 1.0, 0.14)
		tw2.tween_callback(func(): _busy = false)
	)


# ─── Acciones ───────────────────────────────────────────────────────────────

func _on_reset_pressed() -> void:
	click_player.play()
	_load_defaults()
	_save()
	_render_category(_current_index, false)


func _on_back_pressed() -> void:
	click_player.play()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


# ─── Audio ──────────────────────────────────────────────────────────────────

func _setup_audio() -> void:
	hover_player = AudioStreamPlayer.new()
	hover_player.stream = preload(HOVER_SFX_PATH)
	hover_player.volume_db = -10
	hover_player.max_polyphony = 4
	add_child(hover_player)

	click_player = AudioStreamPlayer.new()
	click_player.stream = preload(CLICK_SFX_PATH)
	click_player.volume_db = -10
	add_child(click_player)
