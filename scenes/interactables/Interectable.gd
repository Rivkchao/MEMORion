class_name Interactable
extends StaticBody3D

@export var interact_label: String = "Interact"
@export var dialogue_lines: Array[String] = []
@export var is_important: bool = false
@export var has_challenge: bool = false
@export var challenge_question: String = ""
@export var challenge_answers: Array[String] = []

@onready var label_3d: Label3D = $Label3D
@onready var dialogue_bubble: Node3D = get_node_or_null("DialogueBubble")

func _ready() -> void:
	label_3d.show()

func show_prompt() -> void:
	label_3d.text = interact_label
	label_3d.show()

func hide_prompt() -> void:
	label_3d.hide()

func interact() -> void:
	if dialogue_lines.is_empty():
		return
	
	if is_important:
		if not StoryManager.dialogue_box.dialogue_finished.is_connected(_on_dialogue_finished):
			StoryManager.dialogue_box.dialogue_finished.connect(_on_dialogue_finished)
			StoryManager.start_dialogue(dialogue_lines, interact_label)
	else:
		if dialogue_bubble == null:
			return
		if dialogue_bubble.is_active():
			dialogue_bubble.next()
		else:
			dialogue_bubble.start(dialogue_lines)

func _on_dialogue_finished() -> void:
	StoryManager.dialogue_box.dialogue_finished.disconnect(_on_dialogue_finished)
	if has_challenge:
		StoryManager.start_challenge(challenge_question, challenge_answers)
			
func get_label() -> String:
	return interact_label
