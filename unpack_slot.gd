extends Control
class_name UnpackSlot

@export var accepts: String = ""
@export var slot_label: String = ""
@export var slot_size: Vector2 = Vector2(110, 110)

var occupied: bool = false
var is_highlighted: bool = false

func _ready() -> void:
	custom_minimum_size = slot_size
	size = slot_size
	queue_redraw()

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	
	# Draw background
	if is_highlighted and not occupied:
		draw_rect(rect, Color(1, 1, 1, 0.2))
	elif occupied:
		draw_rect(rect, Color(0.8, 0.9, 0.8, 0.3))
	else:
		draw_rect(rect, Color(0.5, 0.5, 0.5, 0.1))
		
	# Draw dashed border
	var border_color = Color(0.8, 0.8, 0.8, 0.8)
	if occupied:
		border_color = Color(0.4, 0.8, 0.4, 0.8)
	elif is_highlighted:
		border_color = Color(1, 1, 1, 1)
		
	_draw_dashed_rect(rect, border_color, 2.0, 10.0, 5.0)
	
	# Draw label
	if not occupied:
		var font = ThemeDB.fallback_font
		var font_size = 16
		var string_size = font.get_string_size(slot_label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = (size - string_size) / 2.0
		text_pos.y += font.get_ascent(font_size)
		draw_string(font, text_pos, slot_label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.7, 0.7, 0.7, 1.0))

func _draw_dashed_rect(rect: Rect2, color: Color, width: float, dash_length: float, gap_length: float) -> void:
	var pts = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	]
	
	for i in range(4):
		var p1 = pts[i]
		var p2 = pts[(i + 1) % 4]
		_draw_dashed_line(p1, p2, color, width, dash_length, gap_length)

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_length: float, gap_length: float) -> void:
	var length = from.distance_to(to)
	var dir = (to - from).normalized()
	var current_dist = 0.0
	
	while current_dist < length:
		var start = from + dir * current_dist
		current_dist += dash_length
		var end = from + dir * min(current_dist, length)
		draw_line(start, end, color, width)
		current_dist += gap_length

func set_highlight(highlight: bool) -> void:
	if is_highlighted != highlight:
		is_highlighted = highlight
		queue_redraw()

func get_world_rect() -> Rect2:
	return Rect2(global_position, size)
