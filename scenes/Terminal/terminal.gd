extends Interactable

@onready var omni_light_1: OmniLight3D = $OmniLight3D
@onready var omni_light_2: OmniLight3D = $OmniLight3D2
	
@export var flicker_min_energy: float = 200.0
@export var flicker_max_energy: float = 500.0
@export var flicker_speed: float = 0.2

@export var solved_color: Color = Color(0.2, 1.0, 0.3) # Hijau
@export var solved_energy: float = 100.0

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
		var energy = randf_range(flicker_min_energy, flicker_max_energy)
		omni_light_1.light_energy = energy
		omni_light_2.light_energy = energy * 0.8
		_flicker_timer = flicker_speed

func interact() -> void:
	if _puzzle_solved:
		return
	StoryManager.start_wire_puzzle()
	
func _on_wire_puzzle_completed(is_correct: bool) -> void:
	if is_correct:
		_puzzle_solved = true
		omni_light_1.light_color = solved_color
		omni_light_1.light_energy = solved_energy
		omni_light_2.light_color = solved_color
		omni_light_2.light_energy = solved_energy
		interact_label = ""
