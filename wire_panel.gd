extends Control

const WIRE_COLORS = [
	Color(1, 0.2, 0.2),    # Merah
	Color(0.2, 0.6, 1),    # Biru
	Color(0.2, 1, 0.4),    # Hijau
	Color(1, 0.8, 0.1),    # Kuning
	Color(0.8, 0.2, 1),    # Ungu
]

const WIRE_LABELS = ["★", "♦", "●", "▲", "♥"]
const WIRE_COUNT = 5

var left_points: Array = []   # posisi titik kiri
var right_points: Array = []  # posisi titik kanan (diacak)
var right_order: Array = []   # urutan acak kanan
var connections: Dictionary = {}  # left_index: right_index
var dragging_from: int = -1
var drag_pos: Vector2 = Vector2.ZERO
var is_complete: bool = false
var panel_rect: Rect2
var close_button_rect: Rect2
signal puzzle_completed(is_correct: bool)

func setup() -> void:
	connections.clear()
	dragging_from = -1
	is_complete = false
	
	# Acak posisi kanan
	right_order = range(WIRE_COUNT)
	right_order.shuffle()
	
	# Hitung posisi titik - Among Us style (lebih pendek)
	left_points.clear()
	right_points.clear()
	
	# Panel box di tengah layar
	var panel_width = 400
	var panel_height = 500
	var panel_x = (size.x - panel_width) / 2
	var panel_y = (size.y - panel_height) / 2
	panel_rect = Rect2(panel_x, panel_y, panel_width, panel_height)
	close_button_rect = Rect2(
		panel_rect.position.x + panel_rect.size.x - 40,
		panel_rect.position.y - 15,
		30, 30
	)
	# Jarak antar kabel lebih pendek seperti Among Us
	var wire_spacing = panel_height / float(WIRE_COUNT + 1)
	var left_offset = panel_x + 80
	var right_offset = panel_x + panel_width - 80
	
	for i in range(WIRE_COUNT):
		left_points.append(Vector2(left_offset, panel_y + wire_spacing * (i + 1)))
		right_points.append(Vector2(right_offset, panel_y + wire_spacing * (i + 1)))
	
	queue_redraw()

func _draw_panel_background() -> void:
	# Main panel box - dark metallic gray
	var panel_color = Color(0.2, 0.2, 0.25)
	var panel_border = Color(0.4, 0.4, 0.45)
	
	# Draw main panel background
	draw_rect(panel_rect, panel_color)
	draw_rect(panel_rect, panel_border, false, 4)
	
	# Draw inner panel (lighter area for wires)
	var inner_margin = 20
	var inner_rect = Rect2(
		panel_rect.position.x + inner_margin,
		panel_rect.position.y + inner_margin,
		panel_rect.size.x - inner_margin * 2,
		panel_rect.size.y - inner_margin * 2
	)
	var inner_color = Color(0.15, 0.15, 0.18)
	draw_rect(inner_rect, inner_color)
	draw_rect(inner_rect, Color(0.3, 0.3, 0.35), false, 2)
	
	# Draw screws at corners
	var screw_positions = [
		panel_rect.position + Vector2(15, 15),
		panel_rect.position + Vector2(panel_rect.size.x - 15, 15),
		panel_rect.position + Vector2(15, panel_rect.size.y - 15),
		panel_rect.position + Vector2(panel_rect.size.x - 15, panel_rect.size.y - 15)
	]
	
	for screw_pos in screw_positions:
		draw_circle(screw_pos, 6, Color(0.5, 0.5, 0.55))
		draw_circle(screw_pos, 4, Color(0.3, 0.3, 0.35))
		# Draw screw slot (cross)
		draw_line(screw_pos + Vector2(-3, 0), screw_pos + Vector2(3, 0), Color(0.6, 0.6, 0.65), 1)
		draw_line(screw_pos + Vector2(0, -3), screw_pos + Vector2(0, 3), Color(0.6, 0.6, 0.65), 1)
	
	# Draw warning label at top
	var label_rect = Rect2(
		panel_rect.position.x + 30,
		panel_rect.position.y + 10,
		panel_rect.size.x - 60,
		25
	)
	draw_rect(label_rect, Color(0.8, 0.2, 0.2))
	draw_rect(label_rect, Color(1, 0.3, 0.3), false, 2)
	
	# Draw electrical hazard symbol
	var hazard_center = panel_rect.position + Vector2(panel_rect.size.x / 2, 22)
	draw_circle(hazard_center, 8, Color.BLACK)
	
	# Draw lightning bolt
	var bolt_points = [
		hazard_center + Vector2(0, -6),
		hazard_center + Vector2(-3, 0),
		hazard_center + Vector2(-1, 0),
		hazard_center + Vector2(-1, 6),
		hazard_center + Vector2(3, 0),
		hazard_center + Vector2(1, 0),
		hazard_center + Vector2(1, -6)
	]
	draw_colored_polygon(PackedVector2Array(bolt_points), Color.YELLOW)

func _draw() -> void:
	# Draw electrical panel background (Among Us style)
	_draw_panel_background()
	
	# Gambar titik kiri
	for i in range(WIRE_COUNT):
		var color = WIRE_COLORS[i]
		draw_circle(left_points[i], 18, color)
		draw_string(ThemeDB.fallback_font, left_points[i] - Vector2(6, -5), WIRE_LABELS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	
	# Gambar titik kanan (diacak)
	for i in range(WIRE_COUNT):
		var original_idx = right_order[i]
		var color = WIRE_COLORS[original_idx]
		draw_circle(right_points[i], 18, color)
		draw_string(ThemeDB.fallback_font, right_points[i] - Vector2(6, -5), WIRE_LABELS[original_idx], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	
	# Gambar koneksi yang sudah dibuat
	for left_idx in connections:
		var right_idx = connections[left_idx]
		var color = WIRE_COLORS[left_idx]
		draw_line(left_points[left_idx], right_points[right_idx], color, 10)
	
	# Gambar kabel yang sedang di-drag
	if dragging_from >= 0:
		var color = WIRE_COLORS[dragging_from]
		draw_line(left_points[dragging_from], drag_pos, color, 10)
		draw_circle(drag_pos, 12, color)
	
	# Tombol close (X)
	draw_rect(close_button_rect, Color(0.7, 0.15, 0.15))
	draw_rect(close_button_rect, Color(1, 0.3, 0.3), false, 2)
	var pad = 8
	draw_line(
		close_button_rect.position + Vector2(pad, pad),
		close_button_rect.position + close_button_rect.size - Vector2(pad, pad),
		Color.WHITE, 3
	)
	draw_line(
		close_button_rect.position + Vector2(close_button_rect.size.x - pad, pad),
		close_button_rect.position + Vector2(pad, close_button_rect.size.y - pad),
		Color.WHITE, 3
	)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if close_button_rect.has_point(event.position):
			_on_close_pressed()
			return
	
	if is_complete:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Cek klik di titik kiri
				for i in range(WIRE_COUNT):
					if event.position.distance_to(left_points[i]) < 20:
						dragging_from = i
						drag_pos = event.position
						# Hapus koneksi lama kalau ada
						connections.erase(i)
						queue_redraw()
						break
			else:
				# Mouse release — cek apakah di atas titik kanan
				if dragging_from >= 0:
					var _connected = false
					for i in range(WIRE_COUNT):
						if event.position.distance_to(right_points[i]) < 20:
							connections[dragging_from] = i
							_connected = true
							break
					
					dragging_from = -1
					queue_redraw()
					
					# Cek apakah semua sudah terhubung
					if connections.size() == WIRE_COUNT:
						_check_complete()
	
	if event is InputEventMouseMotion and dragging_from >= 0:
		# Only redraw if position changed significantly
		if drag_pos.distance_to(event.position) > 2:
			drag_pos = event.position
			queue_redraw()
	
	
func _check_complete() -> void:
	var all_correct = true
	for left_idx in connections:
		var right_idx = connections[left_idx]
		# Benar kalau right_order[right_idx] == left_idx
		if right_order[right_idx] != left_idx:
			all_correct = false
			break
	
	is_complete = true
	
	await get_tree().create_timer(0.5).timeout
	
	puzzle_completed.emit(all_correct)
	
	if all_correct:
		StoryManager.start_dialogue(["Kamu berhasil menyambungkan semua kabel! Hebat!"], "Rion")
	else:
		StoryManager.start_dialogue(["Hampir benar! Gak papa, kita coba lagi ya!"], "Rion")
	
	get_parent().hide()

func _on_close_pressed() -> void:
	get_parent().hide()
