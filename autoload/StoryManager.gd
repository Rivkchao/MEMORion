extends Node

signal wire_puzzle_completed(is_correct: bool)
signal dialogue_finished

var dialogue_box: Node = null
var matching_puzzle: Node = null
var wire_puzzle: Node = null

func init(db: Node, mp: Node = null, wp: Node = null) -> void:
	dialogue_box = db
	matching_puzzle = mp
	wire_puzzle = wp

	if wire_puzzle != null:
		wire_puzzle.puzzle_completed.connect(_on_wire_puzzle_completed)

	if dialogue_box != null and dialogue_box.has_signal("dialogue_finished"):
		dialogue_box.dialogue_finished.connect(_on_dialogue_finished)

func _on_dialogue_finished() -> void:
	dialogue_finished.emit()

func _on_wire_puzzle_completed(is_correct: bool) -> void:
	wire_puzzle_completed.emit(is_correct)

func start_wire_puzzle() -> void:
	wire_puzzle.start()

func start_dialogue(lines: Array[String], npc_name: String = "") -> void:
	if dialogue_box == null:
		return

	dialogue_box.start(lines, npc_name)
