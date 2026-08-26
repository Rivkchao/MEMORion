extends CanvasLayer

@onready var wire_panel: Control = $WirePanel

signal puzzle_completed(is_correct: bool)

func _ready() -> void:
	hide()
	wire_panel.puzzle_completed.connect(_on_puzzle_completed)

func start() -> void:
	wire_panel.setup()
	show()
		
func _on_puzzle_completed(is_correct: bool) -> void:
	puzzle_completed.emit(is_correct)
