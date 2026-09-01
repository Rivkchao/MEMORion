# draggable_rock.gd
extends StaticBody3D

@export var rock_size: int = 1
@export var respawn_y_threshold: float = -5.0

var is_dragging: bool = false
var drag_y: float = 1.2
var current_slot: Node3D = null
var original_position: Vector3
var original_rotation: Vector3
var is_solved: bool = false

var _tween: Tween = null

func _ready() -> void:
	original_position = global_position
	original_rotation = global_rotation
	RockPuzzleManager.register_rock(self)
	input_ray_pickable = true

func return_to_original() -> void:
	is_solved = false
	is_dragging = false
	if current_slot != null:
		current_slot.occupied_by = null
		current_slot = null
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "global_position", original_position, 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "global_rotation", original_rotation, 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func stop_drag() -> void:
	is_dragging = false
	if RockPuzzleManager.dragging_rock == self:
		RockPuzzleManager.dragging_rock = null

func set_solved() -> void:
	is_solved = true

func _physics_process(_delta: float) -> void:
	if global_position.y < respawn_y_threshold:
		return_to_original()
		return
	if not is_dragging:
		return
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	if abs(ray_dir.y) > 0.001:
		var t = (drag_y - ray_origin.y) / ray_dir.y
		var world_pos = ray_origin + ray_dir * t
		global_position = Vector3(world_pos.x, drag_y, world_pos.z)

# Deteksi klik langsung pada batu
func _input_event(_camera: Camera3D, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if not RockPuzzleManager.is_puzzle_active or RockPuzzleManager.is_previewing or RockPuzzleManager.is_resetting or is_solved:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if RockPuzzleManager.dragging_rock == null:
			_pick_up()

func _input(event: InputEvent) -> void:
	# Lepas drag di mana saja layar diklik-lepas
	if is_dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_drop()

func _pick_up() -> void:
	if current_slot != null:
		current_slot.occupied_by = null
		current_slot = null
	is_dragging = true
	RockPuzzleManager.dragging_rock = self
	# Langsung tempelkan batu ke bidang drag di bawah kursor (responsif sekali klik)
	_snap_to_cursor()

func _snap_to_cursor() -> void:
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	if abs(ray_dir.y) > 0.001:
		var t = (drag_y - ray_origin.y) / ray_dir.y
		var world_pos = ray_origin + ray_dir * t
		global_position = Vector3(world_pos.x, drag_y, world_pos.z)

func _drop() -> void:
	is_dragging = false
	RockPuzzleManager.dragging_rock = null
	var nearest_slot = _find_nearest_slot()
	if nearest_slot != null:
		current_slot = nearest_slot
		if _tween and _tween.is_valid():
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(self, "global_position", nearest_slot.global_position + Vector3(0, 0.1, 0), 0.2)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(self, "global_rotation", nearest_slot.global_rotation, 0.2)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		nearest_slot.try_place(self)
	else:
		return_to_original()

func _find_nearest_slot() -> Node3D:
	# Jarak dihitung pada bidang XZ (abaikan Y) agar tidak gagal karena tinggi drag
	var min_dist = 1.8
	var nearest = null
	var rock_xz = Vector2(global_position.x, global_position.z)
	for slot in RockPuzzleManager.slots:
		if slot.is_occupied():
			continue
		var slot_xz = Vector2(slot.global_position.x, slot.global_position.z)
		var dist = rock_xz.distance_to(slot_xz)
		if dist < min_dist:
			min_dist = dist
			nearest = slot
	return nearest
