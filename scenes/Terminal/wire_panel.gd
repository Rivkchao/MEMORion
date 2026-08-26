extends Control

const WIRE_COLORS = [
	Color(0.95, 0.2, 0.2),   # Merah
	Color(0.15, 0.55, 1.0),  # Biru
	Color(0.1, 0.85, 0.3),   # Hijau
	Color(1.0, 0.75, 0.1),   # Kuning
	Color(0.75, 0.2, 0.95),  # Ungu
]

const WIRE_LABELS = ["★", "♦", "●", "▲", "♥"]
const WIRE_COUNT = 5

var left_points: Array = []
var right_points: Array = []
var right_order: Array = []
var connections: Dictionary = {}
var correct_status: Dictionary = {}

var dragging_from: int = -1
var drag_pos: Vector2 = Vector2.ZERO
var is_complete: bool = false
var is_preview_phase: bool = false
var bnw_blend: float = 0.0 # 0.0 = Berwarna, 1.0 = Full Hitam-Putih

var wire_lines: Array[Line2D] = []
var drag_line: Line2D
var electric_shader: Shader = preload("res://scenes/Terminal/electric_wire.gdshader")

var panel_rect: Rect2
var close_button_rect: Rect2
signal puzzle_completed(is_correct: bool)

func _ready() -> void:
	for i in range(WIRE_COUNT):
		var line = Line2D.new()
		line.width = 14.0
		line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		
		var mat = ShaderMaterial.new()
		mat.shader = electric_shader
		mat.set_shader_parameter("wire_color", WIRE_COLORS[i])
		mat.set_shader_parameter("is_powered", false)
		line.material = mat
		
		add_child(line)
		wire_lines.append(line)
		
	drag_line = Line2D.new()
	drag_line.width = 14.0
	drag_line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	drag_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	drag_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var drag_mat = ShaderMaterial.new()
	drag_mat.shader = electric_shader
	drag_line.material = drag_mat
	drag_line.visible = false
	add_child(drag_line)

func _process(_delta: float) -> void:
	if correct_status.values().has(true) or is_preview_phase or dragging_from >= 0 or bnw_blend > 0.0:
		queue_redraw()

func setup() -> void:
	connections.clear()
	correct_status.clear()
	dragging_from = -1
	is_complete = false
	is_preview_phase = true
	bnw_blend = 0.0
	
	# Acak urutan soket kanan
	right_order = range(WIRE_COUNT)
	right_order.shuffle()
	
	left_points.clear()
	right_points.clear()
	
	var panel_width = 440
	var panel_height = 540
	var panel_x = (size.x - panel_width) / 2
	var panel_y = (size.y - panel_height) / 2
	panel_rect = Rect2(panel_x, panel_y, panel_width, panel_height)
	close_button_rect = Rect2(panel_rect.position.x + panel_rect.size.x - 38, panel_rect.position.y + 8, 30, 30)
	
	var wire_spacing = (panel_height - 60) / float(WIRE_COUNT + 1)
	var left_offset = panel_x + 65
	var right_offset = panel_x + panel_width - 65
	
	for i in range(WIRE_COUNT):
		left_points.append(Vector2(left_offset, panel_y + 40 + wire_spacing * (i + 1)))
		right_points.append(Vector2(right_offset, panel_y + 40 + wire_spacing * (i + 1)))
	
	_update_wire_lines()
	queue_redraw()
	_start_preview_sequence()

func _start_preview_sequence() -> void:
	# 1. Berikan waktu 3 detik bagi user untuk menghafal warna & simbol kanan
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree() or is_complete: return

	# 2. Transisi halus memudarkan warna soket kanan menjadi BnW (Grayscale)
	var tween = create_tween()
	tween.tween_property(self, "bnw_blend", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	if not is_inside_tree(): return

	# 3. Masuk ke fase interaksi
	is_preview_phase = false
	queue_redraw()

func _generate_curved_points(start: Vector2, end: Vector2) -> PackedVector2Array:
	var pts = PackedVector2Array()
	var dist = start.distance_to(end)
	var sag = clamp(dist * 0.12, 10.0, 45.0)
	var mid = (start + end) * 0.5 + Vector2(0, sag)
	
	for step in range(21):
		var t = float(step) / 20.0
		var pt = (1.0 - t) * (1.0 - t) * start + 2.0 * (1.0 - t) * t * mid + t * t * end
		pts.append(pt)
	return pts

func _update_wire_lines() -> void:
	for i in range(WIRE_COUNT):
		var line = wire_lines[i]
		if connections.has(i):
			var r_idx = connections[i]
			line.points = _generate_curved_points(left_points[i], right_points[r_idx])
			line.visible = true
			
			var is_correct = correct_status.get(i, false)
			var mat = line.material as ShaderMaterial
			mat.set_shader_parameter("wire_color", WIRE_COLORS[i])
			mat.set_shader_parameter("is_powered", is_correct)
		else:
			line.visible = false

func _draw_socket(pos: Vector2, color: Color, symbol: String, is_active: bool, is_left: bool) -> void:
	# 1. Bezel Besi Luar
	draw_circle(pos, 22, Color(0.12, 0.12, 0.14))
	draw_circle(pos, 20, Color(0.35, 0.35, 0.4))
	draw_circle(pos, 18, Color(0.18, 0.18, 0.22))
	
	# 2. Inti Warna Terminal
	draw_circle(pos, 14, color)
	draw_circle(pos, 12, color.darkened(0.25))
	
	# 3. Simbol Icon Rata Tengah Presisi
	var font = ThemeDB.fallback_font
	var font_size = 15
	var text_size = font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_pos = pos - Vector2(text_size.x * 0.5, -font_size * 0.35)
	draw_string(font, text_pos, symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

	# 4. LED Indikator Status
	var led_offset = Vector2(-28 if is_left else 28, 0)
	var led_pos = pos + led_offset
	var led_color = Color(0.1, 0.9, 0.3) if is_active else Color(0.7, 0.15, 0.15)
	draw_circle(led_pos, 4, Color(0.08, 0.08, 0.1))
	draw_circle(led_pos, 3, led_color)
	if is_active:
		draw_circle(led_pos, 5, Color(0.2, 1.0, 0.4, 0.4))

func _draw_panel_background() -> void:
	# Box Luar Logam
	draw_rect(panel_rect, Color(0.14, 0.15, 0.17), true)
	draw_rect(panel_rect, Color(0.3, 0.32, 0.36), false, 4)
	
	# Area Plat Dalam
	var inner = panel_rect.grow(-18)
	draw_rect(inner, Color(0.09, 0.09, 0.11), true)
	draw_rect(inner, Color(0.2, 0.22, 0.25), false, 2)
	
	# Baut Sudut
	var bolts = [
		panel_rect.position + Vector2(10, 10),
		Vector2(panel_rect.end.x - 10, panel_rect.position.y + 10),
		Vector2(panel_rect.position.x + 10, panel_rect.end.y - 10),
		panel_rect.end - Vector2(10, 10)
	]
	for b in bolts:
		draw_circle(b, 5, Color(0.4, 0.42, 0.45))
		draw_circle(b, 3, Color(0.2, 0.2, 0.22))
		draw_line(b + Vector2(-2, 0), b + Vector2(2, 0), Color.BLACK, 1)

	# Banner Header Dinamis
	var hdr = Rect2(panel_rect.position.x + 25, panel_rect.position.y + 8, panel_rect.size.x - 70, 28)
	var hdr_color = Color(0.1, 0.45, 0.8) if is_preview_phase else Color(0.75, 0.18, 0.18)
	draw_rect(hdr, hdr_color, true)
	draw_rect(hdr, Color.WHITE, false, 1.5)
	
	var title = "HAFALKAN WARNA KANAN!" if is_preview_phase else "SAMBUNGKAN KABEL"
	var font = ThemeDB.fallback_font
	var fsize = 13
	var tsize = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	draw_string(font, hdr.position + Vector2((hdr.size.x - tsize.x) * 0.5, 18), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color.WHITE)

func _draw() -> void:
	_draw_panel_background()
	
	# Render Soket Kiri (Selalu berwarna normal)
	for i in range(WIRE_COUNT):
		var active = correct_status.get(i, false)
		_draw_socket(left_points[i], WIRE_COLORS[i], WIRE_LABELS[i], active, true)
	
	# Render Soket Kanan (Menggunakan perhitungan Grayscale / BnW)
	for i in range(WIRE_COUNT):
		var orig_idx = right_order[i]
		var orig_col = WIRE_COLORS[orig_idx]
		
		# Hitung nilai Luminance untuk Hitam-Putih yang proporsional
		var lum = orig_col.get_luminance() * 0.7 + 0.15 # Tetap kontras dari background
		var bnw_col = Color(lum, lum, lum)
		
		# Cek apakah soket ini sudah terpasang dengan benar
		var is_active = false
		for l_k in connections:
			if connections[l_k] == i and correct_status.get(l_k, false):
				is_active = true
				break
		
		# Jika sudah benar, kembalikan warna aslinya. Jika belum, terapkan blend BnW
		var final_socket_col = orig_col if is_active else orig_col.lerp(bnw_col, bnw_blend)
		
		_draw_socket(right_points[i], final_socket_col, WIRE_LABELS[orig_idx], is_active, false)
	
	# Tombol Tutup (X)
	draw_rect(close_button_rect, Color(0.7, 0.15, 0.15))
	draw_rect(close_button_rect, Color.WHITE, false, 1.5)
	draw_line(close_button_rect.position + Vector2(7, 7), close_button_rect.end - Vector2(7, 7), Color.WHITE, 2.5)
	draw_line(Vector2(close_button_rect.end.x - 7, close_button_rect.position.y + 7), Vector2(close_button_rect.position.x + 7, close_button_rect.end.y - 7), Color.WHITE, 2.5)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if close_button_rect.has_point(event.position):
			_on_close_pressed()
			return
	
	if is_complete or is_preview_phase:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			for i in range(WIRE_COUNT):
				if event.position.distance_to(left_points[i]) < 28:
					dragging_from = i
					drag_pos = event.position
					connections.erase(i)
					correct_status.erase(i)
					
					drag_line.points = _generate_curved_points(left_points[i], drag_pos)
					var mat = drag_line.material as ShaderMaterial
					mat.set_shader_parameter("wire_color", WIRE_COLORS[i])
					mat.set_shader_parameter("is_powered", false)
					drag_line.visible = true
					
					_update_wire_lines()
					queue_redraw()
					break
		else:
			if dragging_from >= 0:
				for i in range(WIRE_COUNT):
					if event.position.distance_to(right_points[i]) < 28:
						connections[dragging_from] = i
						var is_pair_correct = (right_order[i] == dragging_from)
						correct_status[dragging_from] = is_pair_correct
						break
				
				dragging_from = -1
				drag_line.visible = false
				_update_wire_lines()
				queue_redraw()
				
				if connections.size() == WIRE_COUNT:
					_check_complete()
	
	if event is InputEventMouseMotion and dragging_from >= 0:
		drag_pos = event.position
		drag_line.points = _generate_curved_points(left_points[dragging_from], drag_pos)

func _check_complete() -> void:
	var all_correct = true
	for left_idx in range(WIRE_COUNT):
		if not correct_status.get(left_idx, false):
			all_correct = false
			break
	
	is_complete = true
	await get_tree().create_timer(0.8).timeout
	puzzle_completed.emit(all_correct)
	
	if all_correct:
		StoryManager.start_dialogue(["Daya terminal berhasil dipulihkan! Ingatanmu tajam sekali!"], "Rion")
	else:
		StoryManager.start_dialogue(["Ada kabel yang korslet! Coba ingat-ingat lagi polanya ya!"], "Rion")
	
	get_parent().hide()

func _on_close_pressed() -> void:
	get_parent().hide()
