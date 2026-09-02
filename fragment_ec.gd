extends Node3D

@export var rotation_speed: float = 1.5   # Kecepatan putar (radian/detik)
@export var float_speed: float = 2.0      # Kecepatan naik-turun
@export var float_distance: float = 0.25  # Jarak tinggi naik-turun

var initial_y: float = 0.0
var time_passed: float = 0.0

func _ready() -> void:
	# Simpan ketinggian awal objek
	initial_y = position.y

func _process(delta: float) -> void:
	# 1. Rotasi 360 derajat infinity pada sumbu Y
	rotate_y(rotation_speed * delta)

	# 2. Gerakan mengambang perlahan (sine wave)
	time_passed += delta * float_speed
	position.y = initial_y + sin(time_passed) * float_distance
