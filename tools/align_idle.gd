extends SceneTree
## Alinea frames por posición de pies y centro horizontal.
## Uso: godot --headless -s tools/align_idle.gd -- 28,29,30,31,32,33,34
## (frames separados por coma, índices 1-based como en el .tres)

const GRID_W: int = 170
const GRID_H: int = 92
const COLS: int = 10
const SPRITESHEET: String = "res://characters/goku/forms/spritesheet.png"


func _init() -> void:
	var tex: Texture2D = load(SPRITESHEET)
	if tex == null:
		quit(1)
		return
	var img: Image = tex.get_image()
	if img == null:
		quit(1)
		return

	# Leer frame indices de args
	var frame_str: String = ""
	var args: PackedStringArray = OS.get_cmdline_args()
	print("# args: %s" % str(args))
	for i in range(args.size()):
		var a: String = args[i]
		if a == "--" and i + 1 < args.size():
			frame_str = args[i + 1]
			break
		elif a.find(",") >= 0:
			frame_str = a
			break

	if frame_str == "":
		# Default: idle frames 1-4
		frame_str = "1,2,3,4"

	var raw: PackedStringArray = frame_str.split(",")
	var frames: Array = []
	for r in raw:
		var trimmed: String = r.strip_edges()
		if trimmed != "":
			frames.append(int(trimmed) - 1)  # convertir a 0-based

	# Analizar cada frame
	var feet_y: Array = []
	var center_xs: Array = []
	for idx in frames:
		var col: int = int(idx) % COLS
		var row: int = int(idx) / COLS
		var cx: int = col * GRID_W
		var cy: int = row * GRID_H
		var feet: int = _find_feet(img, cx, cy, GRID_W, GRID_H)
		var centerX: float = _find_center_x(img, cx, cy, GRID_W, GRID_H)
		feet_y.append(feet)
		center_xs.append(centerX)

	# Referencia: pies más abajo, centro promedio
	var ref_feet: int = 0
	for f in feet_y:
		if f > ref_feet:
			ref_feet = f

	var ref_cx: float = 0.0
	for c in center_xs:
		ref_cx += c
	var n: int = center_xs.size()
	ref_cx /= float(n)

	print("# Frames: %s" % frame_str)
	print("# ref_feet=%d  ref_cx=%.1f" % [ref_feet, ref_cx])
	print()

	var rects: Array = []
	for i in frames.size():
		var idx: int = frames[i]
		var col: int = int(idx) % COLS
		var row: int = int(idx) / COLS
		var cell_x: int = col * GRID_W
		var cell_y: int = row * GRID_H
		var fy: int = feet_y[i]
		var cx_val: float = center_xs[i]
		var off_x: float = cx_val - ref_cx
		var off_y: float = float(fy - ref_feet)
		var rx: int = int(float(cell_x) - off_x)
		var ry: int = int(float(cell_y) - off_y)
		rects.append("Rect2(%d, %d, %d, %d)" % [rx, ry, GRID_W, GRID_H])
		print("  frame %d → Rect2(%d, %d, %d, %d)" % [idx + 1, rx, ry, GRID_W, GRID_H])

	print()
	var out: String = ""
	for i_rect in rects:
		if out != "":
			out += ", "
		out += i_rect
	print("frames = Array[Rect2]([%s])" % out)

	quit()


func _find_feet(img: Image, cx: int, cy: int, cw: int, ch: int) -> int:
	for y in range(cy + ch - 1, cy - 1, -1):
		for x in range(cx, cx + cw):
			if x < 0 or x >= img.get_width() or y < 0 or y >= img.get_height():
				continue
			if img.get_pixel(x, y).a > 0.1:
				return y
	return cy + ch - 1


func _find_center_x(img: Image, cx: int, cy: int, cw: int, ch: int) -> float:
	var min_x: int = cw
	var max_x: int = 0
	for y in range(cy, cy + ch):
		for x in range(cx, cx + cw):
			if x < 0 or x >= img.get_width() or y < 0 or y >= img.get_height():
				continue
			if img.get_pixel(x, y).a > 0.1:
				if x < min_x:
					min_x = x
				if x > max_x:
					max_x = x
	if max_x <= min_x:
		return float(cx + cw / 2)
	return float(min_x + max_x) / 2.0
