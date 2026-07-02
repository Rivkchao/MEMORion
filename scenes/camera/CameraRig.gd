extends Node3D

@export var target: Node3D
@export var offset: Vector3 = Vector3(0, 7, 5)
@export var follow_speed: float = 8.0
@export var fov_default: float = 55.0
@export var fov_walking: float = 63.0
@export var fov_speed: float = 5.0

@onready var camera: Camera3D = $Camera3D

func _physics_process(delta: float) -> void:
	if target == null:
		return
	
	var target_pos = Vector3(
		target.global_position.x + offset.x,
		offset.y,
		target.global_position.z + offset.z
	)
	
	global_position = global_position.lerp(target_pos, follow_speed * delta)
	_handle_fov(delta)

func _handle_fov(delta: float) -> void:
	var player = target.get_parent()
	var is_moving = Vector2(player.velocity.x, player.velocity.z).length() > 0.1
	
	var target_fov = fov_walking if is_moving else fov_default
	camera.fov = lerp(camera.fov, target_fov, fov_speed * delta)
