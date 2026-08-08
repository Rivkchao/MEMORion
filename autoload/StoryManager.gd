extends Node

signal wire_puzzle_completed(is_correct: bool)

var dialogue_box: Node = null
var puzzle_ui: Node = null
var matching_puzzle: Node = null
var wire_puzzle: Node = null
var unpacking_puzzle: Node = null

func init(db: Node, pu: Node, mp: Node = null, wp: Node = null, up: Node = null) -> void:
	dialogue_box = db
	puzzle_ui = pu
	matching_puzzle = mp
	wire_puzzle = wp
	unpacking_puzzle = up
	if wire_puzzle != null:
		wire_puzzle.puzzle_completed.connect(_on_wire_puzzle_completed)

func _on_wire_puzzle_completed(is_correct: bool) -> void:
	wire_puzzle_completed.emit(is_correct)

func start_unpacking(puzzle_data: Dictionary) -> void:
	if unpacking_puzzle == null:
		return
	unpacking_puzzle.start(puzzle_data)

func start_wire_puzzle() -> void:
	if wire_puzzle == null:
		return
	wire_puzzle.start()

func start_dialogue(lines: Array[String], npc_name: String = "") -> void:
	if dialogue_box == null:
		return
	dialogue_box.start(lines, npc_name)

func start_challenge(question: String, answers: Array[String]) -> void:
	if puzzle_ui == null:
		return
	puzzle_ui.start(question, answers)
