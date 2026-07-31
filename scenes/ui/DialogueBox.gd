extends CanvasLayer

@onready var name_label: Label = $PanelContainer/MarginContainer/VBoxContainer/NameLabel
@onready var dialogue_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DialogueLabel
@onready var continue_label: Label = $PanelContainer/ContinueLabel

var lines: Array[String] = []
var current_line: int = 0
var is_typing: bool = false
var full_text: String = ""
var speaker_name: String = ""

@export var type_speed: float = 0.03

var magic_time: float = 0.0

func _ready() -> void:
	hide()

func _process(delta: float) -> void:
	if visible:
		magic_time += delta
		# Magical shimmer effect for name label
		var shimmer = (sin(magic_time * 3.0) + 1.0) / 2.0
		var base_color = Color(0.8, 0.6, 1, 1)
		var shimmer_color = Color(1.0, 0.8, 1.0, 1)
		name_label.modulate = base_color.lerp(shimmer_color, shimmer * 0.3)
		
		# Subtle glow for dialogue label
		var glow = (sin(magic_time * 2.0) + 1.0) / 2.0
		dialogue_label.modulate = Color(1.0, 0.95, 1.0, 1.0).lerp(Color(0.9, 0.85, 1.0, 1.0), glow * 0.2)
		
		# Magical typing effect - each character slightly varies in color
		if is_typing:
			_apply_magical_typing_effect()

func _apply_magical_typing_effect() -> void:
	var time_offset = magic_time * 5.0
	for i in range(dialogue_label.text.length()):
		var char_offset = (sin(time_offset + i * 0.5) + 1.0) / 2.0
		var _char_color = Color(0.9, 0.85, 1.0, 1.0).lerp(Color(1.0, 0.9, 1.0, 1.0), char_offset * 0.2)

func start(dialogue_lines: Array[String], npc_name: String = "") -> void:
	lines = dialogue_lines
	speaker_name = npc_name
	current_line = 0
	name_label.text = speaker_name
	continue_label.hide()
	show()
	_show_line()

func _show_line() -> void:
	full_text = lines[current_line]
	dialogue_label.text = ""
	is_typing = true
	continue_label.hide()
	_type_next_char()

func _type_next_char() -> void:
	if dialogue_label.text.length() < full_text.length():
		dialogue_label.text += full_text[dialogue_label.text.length()]
		await get_tree().create_timer(type_speed).timeout
		_type_next_char()
	else:
		is_typing = false
		continue_label.show()
signal dialogue_finished

func next() -> void:
	if is_typing:
		dialogue_label.text = full_text
		is_typing = false
		continue_label.show()
		return
	
	current_line += 1
	if current_line < lines.size():
		_show_line()
	else:
		hide()
		dialogue_finished.emit()

func is_active() -> bool:
	return visible
