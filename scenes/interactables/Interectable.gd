class_name Interactable
extends StaticBody3D

@export var interact_label: String = "Interact"
@export var dialogue_lines: Array[String] = []
@export var is_important: bool = false

@onready var label_3d: Label3D = $Label3D
@onready var dialogue_bubble: Node3D = $DialogueBubble

func _ready() -> void:
	label_3d.hide()

func show_prompt() -> void:
	label_3d.text = interact_label
	label_3d.show()

func hide_prompt() -> void:
	label_3d.hide()

func interact() -> void:
	if dialogue_lines.is_empty():
		return
	
	if is_important:
		StoryManager.start_dialogue(dialogue_lines, interact_label)
	else:
		if dialogue_bubble == null:
			return
		if dialogue_bubble.is_active():
			dialogue_bubble.next()
		else:
			dialogue_bubble.start(dialogue_lines)
			
func get_label() -> String:
	return interact_label
