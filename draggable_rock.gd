extends StaticBody3D

@export var rock_size: int = 1  # 1 = kecil, 5 = besar

var is_dragging: bool = false
var drag_y: float = 1.0  # Y fixed waktu melayang
var current_slot: Node3D = null
var original_position: Vector3

func _ready() -> void:
	original_position = global_position
	RockPuzzleManager.register_rock(self)

func _input(event: InputEvent) -> void:
	if not RockPuzzleManager.is_puzzle_active:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_pick_up()
		else:
			if is_dragging:
				_drop()

func _try_pick_up() -> void:
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 100)
	var result = space.intersect_ray(query)
	
	if result and result.collider == self:
		# Lepas dari slot lama kalau ada
		if current_slot != null:
			current_slot.remove_rock()
			current_slot = null
		
		is_dragging = true
		drag_y = global_position.y + 0.5

func _drop() -> void:
	is_dragging = false
	
	# Cek slot terdekat
	var nearest_slot = _find_nearest_slot()
	
	if nearest_slot != null and nearest_slot.try_place(self):
		# Snap ke slot
		current_slot = nearest_slot
		var tween = create_tween()
		tween.tween_property(self, "global_position", nearest_slot.global_position, 0.2)
		RockPuzzleManager.check_complete()
	else:
		# Balik ke posisi asal
		var tween = create_tween()
		tween.tween_property(self, "global_position", original_position, 0.3)

func _find_nearest_slot() -> Node3D:
	var min_dist = 2.0  # radius snap
	var nearest = null
	
	for slot in RockPuzzleManager.slots:
		var dist = global_position.distance_to(slot.global_position)
		if dist < min_dist and not slot.is_occupied():
			min_dist = dist
			nearest = slot
	
	return nearest

func _physics_process(_delta: float) -> void:
	if not is_dragging:
		return
	
	# Ikuti mouse di Y fixed
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	
	# Hitung posisi di Y fixed plane
	var t = (drag_y - ray_origin.y) / ray_dir.y
	var world_pos = ray_origin + ray_dir * t
	
	global_position = Vector3(world_pos.x, drag_y, world_pos.z)
