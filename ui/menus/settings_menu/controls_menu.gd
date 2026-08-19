extends Control
## Menú de configuración de controles P1. Filas dinámicas con reasignación por tecla.

const HOVER_SFX_PATH = "res://assets/audio/sfx/Cursor.wav"
const CLICK_SFX_PATH = "res://assets/audio/sfx/Decide_2.wav"
const MAIN_MENU_PATH = "res://ui/menus/main_menu/menu.tscn"

var hover_player: AudioStreamPlayer
var click_player: AudioStreamPlayer

var _listening := false
var _listen_action := ""
var _key_labels: Dictionary = {}
var _row_buttons: Dictionary = {}
var _kb_active := false
var _btn_data: Dictionary = {}
var _all_buttons: Array = []
var _hovered_btn: Button = null


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if _listening:
			_handle_remap(event)
			return
		if _is_nav_key(event) and not _kb_active:
			_activate_kb_mode()
	elif event is InputEventMouseMotion:
		if _kb_active:
			_activate_mouse_mode()


func _is_nav_key(event: InputEventKey) -> bool:
	var kc := event.keycode if event.keycode else event.physical_keycode
	return kc in [KEY_UP, KEY_DOWN, KEY_W, KEY_S]


func _handle_remap(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		_cancel_listen()
		return
	InputManager.remap_action(_listen_action, event)
	_listening = false
	_update_key_label(_listen_action)
	_set_listening_ui(false)
	click_player.play()


func _ready() -> void:
	_setup_audio()
	_build_ui()


func _activate_kb_mode() -> void:
	_kb_active = true
	if _hovered_btn and is_instance_valid(_hovered_btn):
		_hovered_btn.visible = false
		_hovered_btn.visible = true
	_grab_first_button()
	get_viewport().set_input_as_handled()


func _activate_mouse_mode() -> void:
	_kb_active = false
	get_viewport().gui_release_focus()
	for btn in _all_buttons:
		if btn.name in _btn_data:
			btn.add_theme_stylebox_override("normal", _btn_data[btn.name].normal)
			btn.add_theme_stylebox_override("hover", _btn_data[btn.name].hover)


func _grab_first_button() -> void:
	var vbox := get_node_or_null("PanelContainer/VBoxContainer")
	if vbox == null:
		return
	for child in vbox.get_children():
		if child is Button and child.visible:
			child.grab_focus()
			return


func _on_focus_entered(button: Button) -> void:
	if not _kb_active:
		return
	hover_player.play()
	if button.name in _btn_data:
		button.add_theme_stylebox_override("normal", _btn_data[button.name].kb_hover)


func _on_focus_exited(button: Button) -> void:
	if button.name in _btn_data:
		button.add_theme_stylebox_override("normal", _btn_data[button.name].normal)


func _on_mouse_entered(button: Button) -> void:
	_hovered_btn = button
	if _kb_active:
		get_viewport().gui_release_focus()
		return
	hover_player.play()


func _on_button_pressed() -> void:
	click_player.play()


# ─── Construcción ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	move_child(bg, 0)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 480)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-260, -240)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.9, 0.6, 0.1, 0.8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "CONTROLES - JUGADOR 1"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 340
	vbox.add_child(scroll)

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 2)
	scroll.add_child(rows)

	for action in InputManager.ACTION_LABELS:
		var row := _make_row(action)
		rows.add_child(row)

	var prompt := Label.new()
	prompt.name = "PromptLabel"
	prompt.text = "Presiona una tecla o botón..."
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 16)
	prompt.add_theme_color_override("font_color", Color(1, 0.4, 0.2))
	prompt.visible = false
	vbox.add_child(prompt)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var reset_btn := _make_button("Restablecer")
	reset_btn.pressed.connect(_on_reset)
	btn_row.add_child(reset_btn)

	var back_btn := _make_button("Volver")
	back_btn.pressed.connect(_on_back)
	btn_row.add_child(back_btn)


func _make_row(action: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 32

	var lbl := Label.new()
	lbl.text = InputManager.ACTION_LABELS[action]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 15)
	row.add_child(lbl)

	var key_lbl := Label.new()
	key_lbl.custom_minimum_size.x = 100
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key_lbl.add_theme_font_size_override("font_size", 15)
	key_lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	key_lbl.text = InputManager.get_action_display(action)
	row.add_child(key_lbl)
	_key_labels[action] = key_lbl

	var btn := Button.new()
	btn.text = "Cambiar"
	btn.custom_minimum_size = Vector2(80, 0)
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(_on_remap_pressed.bind(action))
	_setup_button_visual(btn)
	row.add_child(btn)
	_row_buttons[action] = btn

	return row


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 36)
	btn.add_theme_font_size_override("font_size", 16)
	_setup_button_visual(btn)
	return btn


func _setup_button_visual(button: Button) -> void:
	var normal: StyleBox = button.get_theme_stylebox("normal").duplicate()
	var hover: StyleBox = button.get_theme_stylebox("hover").duplicate()
	if hover is StyleBoxFlat and normal is StyleBoxFlat:
		hover.content_margin_top = normal.content_margin_top
		hover.content_margin_bottom = normal.content_margin_bottom
		hover.content_margin_left = normal.content_margin_left
		hover.content_margin_right = normal.content_margin_right
	button.add_theme_stylebox_override("hover", hover)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	button.add_theme_stylebox_override("focus", focus)
	_btn_data[button.name] = {"normal": normal, "hover": hover, "kb_hover": hover}
	_all_buttons.append(button)
	button.focus_entered.connect(_on_focus_entered.bind(button))
	button.focus_exited.connect(_on_focus_exited.bind(button))
	button.mouse_entered.connect(_on_mouse_entered.bind(button))
	button.pressed.connect(_on_button_pressed)


func _update_key_label(action: String) -> void:
	if action in _key_labels:
		_key_labels[action].text = InputManager.get_action_display(action)


# ─── Reasignar ──────────────────────────────────────────────────────────────

func _on_remap_pressed(action: String) -> void:
	if _listening:
		_cancel_listen()
	_listening = true
	_listen_action = action
	_set_listening_ui(true)
	var prompt := get_node_or_null("PanelContainer/VBoxContainer/PromptLabel")
	if prompt:
		prompt.text = "Tecla para: %s — Presiona una tecla..." % InputManager.ACTION_LABELS[action]
		prompt.visible = true


func _set_listening_ui(active: bool) -> void:
	for action in _row_buttons:
		_row_buttons[action].disabled = active


func _cancel_listen() -> void:
	_listening = false
	_set_listening_ui(false)
	var prompt := get_node_or_null("PanelContainer/VBoxContainer/PromptLabel")
	if prompt:
		prompt.visible = false


func _on_reset() -> void:
	InputManager.reset_to_defaults()
	for action in _key_labels:
		_key_labels[action].text = InputManager.get_action_display(action)
	click_player.play()


func _on_back() -> void:
	if _listening:
		_cancel_listen()
		return
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
