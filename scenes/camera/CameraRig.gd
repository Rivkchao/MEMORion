extends Node3D

@export var target: Node3D
@export var look_offset_height: float = 1.2 # Ketinggian fokus pandang (dada/kepala)

@export var follow_speed: float = 8.0
@export var auto_align_speed: float = 1.0

# FOV
@export var fov_default: float = 65.0
@export var fov_walking: float = 72.0
@export var fov_speed: float = 5.0

# Orbit
@export var orbit_sensitivity: float = 0.3
@export var min_pitch: float = -45.0
@export var max_pitch: float = 60.0

# Zoom
@export var zoom_speed: float = 0.5
@export var min_zoom: float = 2.0
@export var max_zoom: float = 5.0

@onready var camera: Camera3D = $Camera3D

var yaw: float = 0.0
var pitch: float = 15.0 # Sudut sedikit melihat ke bawah secara natural
var zoom_distance: float = 3.5

var is_orbiting: bool = false

func _ready() -> void:
	if target:
		yaw = target.global_rotation.y + PI
		# Pastikan child Camera3D posisinya di (0,0,0) lokal rig
		if camera:
			camera.position = Vector3.ZERO
			camera.rotation = Vector3.ZERO

func _input(event: InputEvent) -> void:
	# 1. Deteksi Klik Kanan & Scroll Zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_orbiting = event.pressed
			# Sembunyikan dan kunci kursor saat orbit agar pergerakan mouse mulus
			if is_orbiting:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		# Zoom scroll
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_distance = clamp(zoom_distance - zoom_speed, min_zoom, max_zoom)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_distance = clamp(zoom_distance + zoom_speed, min_zoom, max_zoom)

	# 2. Geser mouse saat klik kanan -> putar kamera
	if event is InputEventMouseMotion and is_orbiting:
		yaw -= deg_to_rad(event.relative.x * orbit_sensitivity)
		# Gunakan += agar geser mouse ke bawah mengarahkan kamera ke bawah
		pitch += event.relative.y * orbit_sensitivity
		pitch = clamp(pitch, min_pitch, max_pitch)
		
func _physics_process(delta: float) -> void:
	if target == null:
		return

	# Dapatkan referensi CharacterBody3D player
	var player_body: CharacterBody3D = null
	if target is CharacterBody3D:
		player_body = target as CharacterBody3D
	elif target.get_parent() is CharacterBody3D:
		player_body = target.get_parent() as CharacterBody3D

	if not is_orbiting and player_body != null:
		var h_vel := Vector2(player_body.velocity.x, player_body.velocity.z)
		if h_vel.length() > 0.3:
			var move_yaw := atan2(h_vel.x, h_vel.y) + PI
			yaw = lerp_angle(yaw, move_yaw, auto_align_speed * delta)

	# Titik fokus (dada/kepala target)
	var focus_point := target.global_position + Vector3(0.0, look_offset_height, 0.0)

	# Hitung posisi orbit kamera
	var rotation_basis := Basis.from_euler(Vector3(deg_to_rad(-pitch), yaw, 0.0))
	var offset := rotation_basis * Vector3(0.0, 0.0, zoom_distance)
	var desired_pos := focus_point + offset

	# Raycast collision agar tidak menembus dinding/lantai
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(focus_point, desired_pos)
	
	# Exclude target dan root player agar raycast tidak terhalang tubuh sendiri
	var excludes: Array[RID] = []
	if player_body:
		excludes.append(player_body.get_rid())
	if target is CollisionObject3D:
		excludes.append((target as CollisionObject3D).get_rid())
	query.exclude = excludes

	var result := space.intersect_ray(query)
	if result:
		global_position = result.position + result.normal * 0.2
	else:
		global_position = global_position.lerp(desired_pos, follow_speed * delta)

	# Kamera selalu memandang ke titik fokus dada/kepala
	look_at(focus_point, Vector3.UP)

	_handle_fov(delta, player_body)

func _handle_fov(delta: float, player_body: CharacterBody3D) -> void:
	if player_body == null or camera == null:
		if camera:
			camera.fov = lerp(camera.fov, fov_default, fov_speed * delta)
		return

	var h_speed := Vector2(player_body.velocity.x, player_body.velocity.z).length()
	var t_fov := fov_walking if h_speed > 0.1 else fov_default
	camera.fov = lerp(camera.fov, t_fov, fov_speed * delta)
