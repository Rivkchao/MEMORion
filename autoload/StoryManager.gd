extends Node

var dialogue_box: Node = null

func init(db: Node) -> void:
	dialogue_box = db

func start_dialogue(lines: Array[String], npc_name: String = "") -> void:
	if dialogue_box == null:
		return
	dialogue_box.start(lines, npc_name)
