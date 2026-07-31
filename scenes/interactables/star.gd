extends Interactable

@export var star_id: String = "star_01"
@export var float_height: float = 0.3    # Tinggi naik-turun
@export var float_speed: float = 1.8     # Kecepatan mengambang
@export var rotate_speed: float = 1.2    # Kecepatan rotasi

var collected: bool = false
var _base_y: float = 0.0
var _time: float = 0.0

@onready var star_model: Node3D = $StarModel

func _ready() -> void:
	interact_label = "Ambil" 
	super._ready()           
	_base_y = position.y
	_time = randf_range(0.0, TAU)

func _process(delta: float) -> void:
	if collected:
		return
	_time += delta
	# Floating: naik turun pakai sin wave
	position.y = _base_y + sin(_time * float_speed) * float_height
	# Rotasi perlahan di sumbu Y (hanya model, bukan label)
	star_model.rotate_y(rotate_speed * delta)

func interact() -> void:
	if collected:
		return
	_collect()

func _collect() -> void:
	collected = true
	set_process(false)   # Hentikan animasi floating
	hide_prompt()
	_play_collect_animation()

func _play_collect_animation() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	# Scale up sedikit lalu menghilang
	tween.tween_property(self, "scale", Vector3(1.4, 1.4, 1.4), 0.15)
	tween.chain().tween_property(self, "scale", Vector3(0, 0, 0), 0.25)
	# Melayang ke atas sambil menghilang
	tween.tween_property(self, "position", position + Vector3(0, 1.5, 0), 0.4)
	tween.chain().tween_callback(_on_collected)

func _on_collected() -> void:
	GameManager.add_progress()
	queue_free()


func _on_interaction_area_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		show_prompt()

func _on_interaction_area_body_exited(body: Node3D) -> void:
	if body.name == "Player":
		hide_prompt()
