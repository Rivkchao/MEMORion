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

func _ready() -> void:
	hide()

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

func is_active() -> bool:
	return visible
