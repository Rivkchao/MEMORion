extends Node3D

@export var room_lights: Array[Light3D] = [] # Lampu interior ruangan ini
@export var target_energy: float = 1.5

var is_cleared: bool = false

func _ready() -> void:
	# Awal game: matikan semua lampu ruangan ini
	for l in room_lights:
		if l:
			l.light_energy = 0.0

func turn_on_lights() -> void:
	is_cleared = true
	var tween = create_tween()
	for l in room_lights:
		if l:
			tween.parallel().tween_property(l, "light_energy", target_energy, 1.5)
