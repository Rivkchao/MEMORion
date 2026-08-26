extends Node3D

func _ready() -> void:
	# Cari node WirePuzzle & HUD secara dinamis
	var wire_puzzle_node = find_child("WirePuzzle", true, false)
	var dialogue_node = find_child("DialogueBox", true, false)
	if dialogue_node == null:
		dialogue_node = find_child("HUD", true, false)
	
	if wire_puzzle_node:
		print("[Main] Menemukan node WirePuzzle di: ", wire_puzzle_node.get_path())
	else:
		print("[Main] PERINGATAN: Node WirePuzzle tidak ditemukan di dalam scene tree!")

	# Inisialisasi ke StoryManager
	StoryManager.init(dialogue_node, null, wire_puzzle_node)
