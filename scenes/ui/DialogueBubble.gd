extends Node3D

@onready var label: Label3D = $Label3D

var lines: Array[String] = []
var current_line: int = 0
var is_typing: bool = false
var full_text: String = ""
var displayed_text: String = ""

@export var type_speed: float = 0.05
@export var auto_hide_duration: float = 5.0

var magic_time: float = 0.0

func start(dialogue_lines: Array[String]) -> void:
	lines = dialogue_lines
	current_line = 0
	show()
	_show_line()

func _process(delta: float) -> void:
	if visible:
		magic_time += delta
		# Magical shimmer effect for the 3D label
		var shimmer = (sin(magic_time * 3.0) + 1.0) / 2.0
		var base_color = Color(0.8, 0.6, 1, 1)
		var shimmer_color = Color(1.0, 0.8, 1.0, 1)
		label.modulate = base_color.lerp(shimmer_color, shimmer * 0.3)
		
		# Subtle floating animation
		label.position.y = sin(magic_time * 2.0) * 0.05

func _show_line() -> void:
	full_text = lines[current_line]
	displayed_text = ""
	is_typing = true
	_type_next_char()

func _type_next_char() -> void:
	if displayed_text.length() < full_text.length():
		displayed_text += full_text[displayed_text.length()]
		label.text = displayed_text
		await get_tree().create_timer(type_speed).timeout
		_type_next_char()
	else:
		is_typing = false
		# Auto hide setelah 5 detik
		await get_tree().create_timer(auto_hide_duration).timeout
		hide()

func next() -> void:
	if is_typing:
		is_typing = false
		displayed_text = full_text
		label.text = displayed_text
		return
	
	current_line += 1
	if current_line < lines.size():
		_show_line()
	else:
		hide()

func is_active() -> bool:
	return visible
