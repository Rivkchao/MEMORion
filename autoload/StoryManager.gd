extends Node

signal wire_puzzle_completed(is_correct: bool)

var dialogue_box: Node = null
var matching_puzzle: Node = null
var wire_puzzle: Node = null

func init(db: Node, mp: Node = null, wp: Node = null) -> void:
	dialogue_box = db
	matching_puzzle = mp
	wire_puzzle = wp
	if wire_puzzle != null:
		wire_puzzle.puzzle_completed.connect(_on_wire_puzzle_completed)

func _on_wire_puzzle_completed(is_correct: bool) -> void:
	wire_puzzle_completed.emit(is_correct)

func start_wire_puzzle() -> void:
	if wire_puzzle == null:
		print("[StoryManager] ERROR: wire_puzzle belum di-assign (masih null)!")
		return
	print("[StoryManager] Memulai wire puzzle...")
	wire_puzzle.start()

func start_dialogue(lines: Array[String], npc_name: String = "") -> void:
	if dialogue_box == null:
		return
	dialogue_box.start(lines, npc_name)
