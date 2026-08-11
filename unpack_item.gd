extends Control
class_name UnpackItem

signal picked(item: UnpackItem)

@export var item_type: String = ""
@export var item_label: String = ""
@export var item_size: Vector2 = Vector2(100, 100)
@export var item_color: Color = Color(0.3, 0.6, 1.0)

var placed: bool = false
var original_pos: Vector2
var is_hovered: bool = false
var is_dragged: bool = false

func _ready() -> void:
	original_pos = position
	custom_minimum_size = item_size
	size = item_size
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	queue_redraw()

func _on_mouse_entered() -> void:
	if not placed and not is_dragged:
		is_hovered = true
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		queue_redraw()

func _on_mouse_exited() -> void:
	if not placed:
		is_hovered = false
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		queue_redraw()

func set_dragged(dragged: bool) -> void:
	is_dragged = dragged
	is_hovered = false
	if dragged:
		z_index = 10
	else:
		z_index = 0
	queue_redraw()

func set_placed(p: bool) -> void:
	placed = p
	mouse_default_cursor_shape = Control.CURSOR_ARROW if placed else Control.CURSOR_POINTING_HAND
	queue_redraw()

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	var bg_color = item_color
	
	if placed:
		bg_color = bg_color.lerp(Color(0.5, 0.5, 0.5), 0.5)
		bg_color.a = 0.8
	elif is_dragged:
		bg_color = bg_color.lightened(0.2)
		rect.position -= Vector2(4, 4) # Lift effect
		
		# Draw shadow
		var shadow_rect = Rect2(Vector2(4, 4), size)
		draw_rect(shadow_rect, Color(0, 0, 0, 0.3), true, -1.0)
	elif is_hovered:
		bg_color = bg_color.lightened(0.1)
		
	# Draw main body
	draw_rect(rect, bg_color, true, -1.0)
	
	# Draw label
	var font = ThemeDB.fallback_font
	var font_size = 18
	var string_size = font.get_string_size(item_label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = rect.position + (size - string_size) / 2.0
	text_pos.y += font.get_ascent(font_size)
	
	var text_color = Color.WHITE
	if bg_color.get_luminance() > 0.6:
		text_color = Color.BLACK
		
	draw_string(font, text_pos, item_label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)

func _gui_input(event: InputEvent) -> void:
	if placed:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			picked.emit(self)
