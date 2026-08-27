extends Node3D

@export var target: Node3D
@export var look_offset_height: float = 1.4

@export var follow_speed: float = 12.0
@export var auto_align_speed: float = 2.0 # Kecepatan kamera mengalir ke belakang player
@export var orbit_sensitivity: float = 0.2

# Batas sudut pitch
@export var min_pitch: float = -35.0
@export var max_pitch: float = 65.0

# Zoom
@export var zoom_speed: float = 0.5
@export var min_zoom: float = 2.0
@export var max_zoom: float = 7.0

@onready var camera: Camera3D = $Camera3D

var yaw: float = 0.0
var pitch: float = 20.0
var zoom_distance: float = 4.0
var is_orbiting: bool = false
var orbit_cooldown: float = 0.0

var _last_target_pos: Vector3 = Vector3.ZERO

func _ready() -> void:
	top_level = true
	if target == null:
		target = get_tree().root.find_child("Player", true, false) as Node3D

	if target:
		_last_target_pos = target.global_position
		yaw = target.global_rotation.y + PI
		global_position = target.global_position + Vector3(0, look_offset_height, 0)
		
	if camera:
		camera.position = Vector3.ZERO
		camera.rotation = Vector3.ZERO
		_apply_scene_camera_settings()

func _apply_scene_camera_settings() -> void:
	if camera == null:
		return
	
	# Deklarasi tipe eksplisit (Node & String) agar tidak memicu Variant Warning
	var current_scene: Node = get_tree().current_scene
	@warning_ignore("incompatible_ternary")
	var scene_name: String = current_scene.name if current_scene != null else ""
	var file_path: String = ""
	
	if current_scene != null and not current_scene.scene_file_path.is_empty():
		file_path = current_scene.scene_file_path.get_file().get_basename()

	# Cek apakah masuk ke BengkelRallux / R1 (Interior) atau LEV1 (Outdoor)
	if scene_name in ["BengkelRallux", "R1"] or file_path in ["BengkelRallux", "R1"]:
		camera.near = 0.05
		camera.far = 1000.0       # Jarak render jauh tanpa batas kabut/clipping di interior
		zoom_distance = 3.5       # Sedikit lebih dekat agar pas di dalam ruangan
	elif scene_name == "LEV1" or file_path == "LEV1":
		camera.near = 0.05
		camera.far = 300.0        # Optimal untuk outdoor / terrain
		zoom_distance = 4.0
	else:
		# Fallback default untuk scene lain
		camera.near = 0.05
		camera.far = 500.0

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_orbiting = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if is_orbiting else Input.MOUSE_MODE_VISIBLE
			if not is_orbiting:
				orbit_cooldown = 1.0

		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_distance = clamp(zoom_distance - zoom_speed, min_zoom, max_zoom)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_distance = clamp(zoom_distance + zoom_speed, min_zoom, max_zoom)

	if event is InputEventMouseMotion and is_orbiting:
		yaw -= deg_to_rad(event.relative.x * orbit_sensitivity)
		pitch -= event.relative.y * orbit_sensitivity
		pitch = clamp(pitch, min_pitch, max_pitch)

func _physics_process(delta: float) -> void:
	if target == null:
		return

	if orbit_cooldown > 0.0:
		orbit_cooldown -= delta

	# Hitung perpindahan posisi
	var current_pos := target.global_position
	var move_delta := current_pos - _last_target_pos
	var is_moving := move_delta.length_squared() > 0.0005
	_last_target_pos = current_pos

	var focus_point := current_pos + Vector3(0.0, look_offset_height, 0.0)

	# Auto-align hanya saat jalan & tidak sedang manual orbit
	if is_moving and not is_orbiting and orbit_cooldown <= 0.0:
		var facing_node := target
		if target.has_node("RionMesh"):
			facing_node = target.get_node("RionMesh")
		elif target.has_node("Model"):
			facing_node = target.get_node("Model")

		var target_yaw := facing_node.global_rotation.y + PI
		
		# Cek selisih sudut hadap target terhadap sudut yaw kamera saat ini
		var angle_diff: float = absf(wrapf(target_yaw - yaw, -PI, PI))
		
		# KUNCI: Cegah looping spin jika bergerak ke arah kamera
		if angle_diff < deg_to_rad(130.0):
			yaw = lerp_angle(yaw, target_yaw, auto_align_speed * delta)

	# Kalkulasi posisi bola orbit kamera
	var pitch_rad := deg_to_rad(pitch)
	var offset := Vector3(
		sin(yaw) * cos(pitch_rad),
		sin(pitch_rad),
		cos(yaw) * cos(pitch_rad)
	) * zoom_distance

	var desired_pos := focus_point + offset

	# Raycast Collision (Anti tembus tanah / dinding)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(focus_point, desired_pos)
	var excludes: Array[RID] = []
	if target is CollisionObject3D:
		excludes.append(target.get_rid())
	for child in target.get_children():
		if child is CollisionObject3D:
			excludes.append(child.get_rid())
	query.exclude = excludes

	var result: Dictionary = space.intersect_ray(query)
	var final_pos: Vector3 = desired_pos
	if not result.is_empty():
		var hit_pos: Vector3 = result["position"]
		var hit_normal: Vector3 = result["normal"]
		final_pos = hit_pos + (hit_normal * 0.25)

	# Terapkan posisi & arah pandang
	global_position = global_position.lerp(final_pos, follow_speed * delta)
	
	if global_position.distance_squared_to(focus_point) > 0.01:
		look_at(focus_point, Vector3.UP)
