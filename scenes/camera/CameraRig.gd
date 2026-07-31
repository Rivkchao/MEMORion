extends Node3D

@export var target: Node3D
@export var follow_speed: float = 8.0
@export var fov_default: float = 55.0
@export var fov_walking: float = 63.0
@export var fov_speed: float = 5.0

# Orbit settings
@export var orbit_sensitivity: float = 0.3
@export var min_pitch: float = -70.0
@export var max_pitch: float = 0.0

# Zoom settings
@export var zoom_speed: float = 0.5
@export var min_zoom: float = 1.5
@export var max_zoom: float = 4.0

@onready var camera: Camera3D = $Camera3D

var yaw: float = 0.0
var pitch: float = -45.0
var zoom_distance: float = 10.0
var is_orbiting: bool = false

func _ready() -> void:
	pitch = 0.0 
	zoom_distance = 4.0

func _input(event: InputEvent) -> void:
	# Hold klik kanan untuk orbit
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_orbiting = event.pressed
		
		# Scroll zoom
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_distance = clamp(zoom_distance - zoom_speed, min_zoom, max_zoom)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_distance = clamp(zoom_distance + zoom_speed, min_zoom, max_zoom)
	
	# Mouse drag untuk rotate
	if event is InputEventMouseMotion and is_orbiting:
		yaw -= event.relative.x * orbit_sensitivity
		pitch -= event.relative.y * orbit_sensitivity
		pitch = clamp(pitch, min_pitch, max_pitch)

func _physics_process(delta: float) -> void:
	if target == null:
		return
	
	# Hitung posisi orbit
	var rotation_quat = Quaternion.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0))
	var offset = rotation_quat * Vector3(0, 0, zoom_distance)
	
	var target_pos = target.global_position + offset
	global_position = global_position.lerp(target_pos, follow_speed * delta)
	
	# Kamera selalu look at player
	look_at(target.global_position, Vector3.UP)
	
	_handle_fov(delta)

func _handle_fov(delta: float) -> void:
	var player = target.get_parent()
	var is_moving = Vector2(player.velocity.x, player.velocity.z).length() > 0.1
	var target_fov = fov_walking if is_moving else fov_default
	camera.fov = lerp(camera.fov, target_fov, fov_speed * delta)
