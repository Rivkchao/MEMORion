extends Node

var next_scene_path: String = ""
var loading_progress: Array = []

func goto_scene(path: String) -> void:
	next_scene_path = path
	get_tree().change_scene_to_file("res://loading_screen.tscn")
