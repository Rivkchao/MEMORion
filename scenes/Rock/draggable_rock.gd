extends StaticBody3D

@export var respawn_y_threshold: float = -5.0

var is_dragging: bool = false
var drag_y: float = 1.2
var current_slot: Node3D = null
var original_position: Vector3

func _ready() -> void:
	original_position = global_position
	RockPuzzleManager.register_rock(self)

func return_to_original() -> void:
	if current_slot != null:
		current_slot.occupied_by = null
		current_slot = null
	var tween = create_tween()
	tween.tween_property(self, "global_position", original_position, 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _physics_process(_delta: float) -> void:
	if global_position.y < respawn_y_threshold:
		return_to_original()
		return
	
	if not is_dragging:
		return
	
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	
	if abs(ray_dir.y) > 0.001:
		var t = (drag_y - ray_origin.y) / ray_dir.y
		var world_pos = ray_origin + ray_dir * t
		global_position = Vector3(world_pos.x, drag_y, world_pos.z)

func _input(event: InputEvent) -> void:
	if not RockPuzzleManager.is_puzzle_active or RockPuzzleManager.is_previewing:
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
		if current_slot != null:
			current_slot.occupied_by = null
			current_slot = null
		is_dragging = true
		RockPuzzleManager.dragging_rock = self # Set batu aktif

func _drop() -> void:
	is_dragging = false
	RockPuzzleManager.dragging_rock = null # Reset saat dilepas
	
	var nearest_slot = _find_nearest_slot()
	
	if nearest_slot != null:
		current_slot = nearest_slot
		var tween = create_tween()
		tween.tween_property(self, "global_position", nearest_slot.global_position + Vector3(0, 0.1, 0), 0.2)
		nearest_slot.try_place(self)
	else:
		return_to_original()

func _find_nearest_slot() -> Node3D:
	var min_dist = 2.2
	var nearest = null
	for slot in RockPuzzleManager.slots:
		if slot.is_occupied():
			continue
		var dist = global_position.distance_to(slot.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = slot
	return nearest
