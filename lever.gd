extends Node3D

@export var hold_time := 3.0
@export var room_material: ShaderMaterial
@export var lever_light: OmniLight3D

@onready var progress_label: Label3D = $ProgressLabel

var holding := false
var progress := 0.0
var completed := false


func _ready() -> void:
	progress_label.visible = false

	# Awal game: ruangan gelap
	room_material.set_shader_parameter("darkness", 0.75)

	# Tuas tetap terang
	lever_light.visible = true


func _process(delta: float) -> void:
	if completed:
		return

	if holding:
		progress += delta / hold_time
		progress = clamp(progress, 0.0, 1.0)

		var percentage := int(progress * 100.0)
		progress_label.text = str(percentage) + "%"

		if progress >= 1.0:
			complete_lever()


func _input(event: InputEvent) -> void:
	if completed:
		return

	if event.is_action_pressed("interact"):
		holding = true
		progress_label.visible = true

	if event.is_action_released("interact"):
		holding = false

		if progress < 1.0:
			progress = 0.0
			progress_label.text = "0%"
			progress_label.visible = false


func complete_lever() -> void:
	completed = true
	holding = false

	progress = 1.0
	progress_label.text = "100%"

	# Hilangkan overlay secara perlahan
	var tween := create_tween()

	tween.tween_method(
		set_room_darkness,
		0.75,
		0.0,
		1.5
	)

	# Setelah ruangan terang, matikan lampu kecil tuas
	tween.tween_callback(func():
		lever_light.visible = false
	)

	print("LIGHT ON")


func set_room_darkness(value: float) -> void:
	room_material.set_shader_parameter("darkness", value)
