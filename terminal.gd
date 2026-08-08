extends Interactable

@onready var omni_light: OmniLight3D = $OmniLight3D

@export var flicker_min_energy: float = 0.7
@export var flicker_max_energy: float = 3.0
@export var flicker_speed: float = 0.3

@export var solved_color: Color = Color(0.2, 1.0, 0.3) # hijau
@export var solved_energy: float = 1.5

var _flicker_timer: float = 0.0
var _puzzle_solved: bool = false

func _ready() -> void:
	super._ready()
	interact_label = "Gunakan Terminal"
	StoryManager.wire_puzzle_completed.connect(_on_wire_puzzle_completed)

func _process(delta: float) -> void:
	if _puzzle_solved:
		return
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		omni_light.light_energy = randf_range(flicker_min_energy, flicker_max_energy)
		_flicker_timer = flicker_speed

func interact() -> void:
	if _puzzle_solved:
		return
	StoryManager.start_wire_puzzle()

func _on_wire_puzzle_completed(is_correct: bool) -> void:
	if is_correct:
		_puzzle_solved = true
		omni_light.light_color = solved_color
		omni_light.light_energy = solved_energy
		interact_label = "" # biar prompt "Gunakan Terminal" ilang juga
