extends Control
## Menú de configuración de controles P1. Filas dinámicas con reasignación por tecla.

const HOVER_SFX_PATH = "res://assets/audio/sfx/Cursor.wav"
const CLICK_SFX_PATH = "res://assets/audio/sfx/Decide_2.wav"
const MAIN_MENU_PATH = "res://ui/menus/main_menu/menu.tscn"

var hover_player: AudioStreamPlayer
var click_player: AudioStreamPlayer

var _listening := false
var _listen_action := ""
var _key_labels: Dictionary = {}   # action → Label de tecla
var _row_buttons: Dictionary = {}  # action → Button de reasignar


func _ready() -> void:
	_setup_audio()
	_build_ui()


func _input(event: InputEvent) -> void:
	if not _listening:
		return
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	if event is InputEventKey and not event.pressed:
		return
	if event is InputEventJoypadButton and not event.pressed:
		return
	if event is InputEventJoypadMotion and absf(event.axis_value) < 0.5:
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		_cancel_listen()
		return
	InputManager.remap_action(_listen_action, event)
	_listening = false
	_update_key_label(_listen_action)
	_set_listening_ui(false)
	click_player.play()


# ─── Construcción ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Fondo semi-transparente
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	move_child(bg, 0)

	# Panel central
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

	# Título
	var title := Label.new()
	title.text = "CONTROLES - JUGADOR 1"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sep)

	# Scroll con filas
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

	# Prompt de escucha
	var prompt := Label.new()
	prompt.name = "PromptLabel"
	prompt.text = "Presiona una tecla o botón..."
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 16)
	prompt.add_theme_color_override("font_color", Color(1, 0.4, 0.2))
	prompt.visible = false
	vbox.add_child(prompt)

	# Botones inferiores
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
	row.add_child(btn)
	_row_buttons[action] = btn

	return row


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 36)
	btn.add_theme_font_size_override("font_size", 16)
	btn.mouse_entered.connect(_on_hover)
	return btn


func _on_hover() -> void:
	hover_player.play()


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
	hover_player.stream = load(HOVER_SFX_PATH)
	hover_player.max_polyphony = 4
	add_child(hover_player)

	click_player = AudioStreamPlayer.new()
	click_player.stream = load(CLICK_SFX_PATH)
	add_child(click_player)
