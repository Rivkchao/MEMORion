extends Node3D
class_name UnpackingManager3D

@export var camera: Camera3D
@export var hold_distance: float = 1.8
@export_flags_3d_physics var item_collision_mask: int = 2  # Layer 2 (Area3D Item)
@export_flags_3d_physics var slot_collision_mask: int = 8  # Layer 4 (Area3D Slot)

var held_item: UnpackItem3D = null
var current_hovered_slot: UnpackingSlot3D = null
var total_items: int = 0
var placed_items: int = 0

signal puzzle_completed

func _ready() -> void:
	if camera == null:
		camera = get_viewport().get_camera_3d()
		if camera:
			print("[UnpackingManager] Menggunakan kamera aktif: ", camera.name)
		else:
			push_warning("[UnpackingManager] PERINGATAN: Camera3D tidak ditemukan! Drag node Camera ke Inspector.")
		
	var all_items = get_tree().get_nodes_in_group("unpack_items")
	total_items = all_items.size()
	print("[UnpackingManager] Inisialisasi selesai. Total barang terdaftar: ", total_items)

func _process(_delta: float) -> void:
	if held_item != null and camera != null:
		# Posisikan barang melayang halus di depan kamera
		var target_pos = camera.global_position + (-camera.global_transform.basis.z * hold_distance)
		held_item.global_position = held_item.global_position.lerp(target_pos, 0.2)
		_check_slot_hover()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if held_item == null:
			_try_pickup()
		else:
			_try_place()

func _try_pickup() -> void:
	var hit = _raycast_from_mouse(item_collision_mask)
	print("[UnpackingManager] Cek Pickup Klik -> Hit Data: ", hit)
	
	if hit.is_empty():
		print("[UnpackingManager] Raycast tidak mengenai objek apa pun pada mask: ", item_collision_mask)
		return
		
	var target = hit.collider
	# Tangani jika collider adalah child atau Area3D langsung
	var item: UnpackItem3D = target as UnpackItem3D
	if item == null and target is Node:
		item = target.get_parent() as UnpackItem3D
		
	if item != null:
		if not item.is_placed:
			held_item = item
			print("[UnpackingManager] BERHASIL AMBIL: ", item.item_name, " (Type: ", item.item_type, ")")
			_highlight_matching_slots(item.item_type, true)
		else:
			print("[UnpackingManager] Barang sudah terpasang di rak sebelumnya.")
	else:
		print("[UnpackingManager] Objek tertabrak (", target.name, ") BUKAN UnpackItem3D.")

func _try_place() -> void:
	if held_item == null:
		return
		
	var hit = _raycast_from_mouse(slot_collision_mask)
	print("[UnpackingManager] Cek Place Klik -> Hit Data: ", hit)
	
	var target = hit.get("collider", null)
	var slot: UnpackingSlot3D = target as UnpackingSlot3D
	if slot == null and target is Node:
		slot = target.get_parent() as UnpackingSlot3D
		
	if slot != null:
		if not slot.occupied and slot.accepts_item_type == held_item.item_type:
			print("[UnpackingManager] BERHASIL PASANG ke slot: ", slot.slot_name)
			slot.snap_item(held_item)
			held_item.is_placed = true
			held_item = null
			placed_items += 1
			_highlight_matching_slots("", false)
			_check_finish()
			return
		else:
			print("[UnpackingManager] Tipe barang tidak cocok! Item: ", held_item.item_type, " | Butuh: ", slot.accepts_item_type)
	else:
		print("[UnpackingManager] Klik di luar slot yang valid. Mengembalikan barang ke lantai...")

	held_item.return_to_origin()
	held_item = null
	_highlight_matching_slots("", false)

func _check_slot_hover() -> void:
	var hit = _raycast_from_mouse(slot_collision_mask)
	var target = hit.get("collider", null)
	var slot: UnpackingSlot3D = target as UnpackingSlot3D
	if slot == null and target is Node:
		slot = target.get_parent() as UnpackingSlot3D
		
	if slot != null:
		if current_hovered_slot != slot:
			if current_hovered_slot:
				current_hovered_slot.set_highlight(false)
			current_hovered_slot = slot
			if not slot.occupied and slot.accepts_item_type == held_item.item_type:
				slot.set_highlight(true)
	else:
		if current_hovered_slot:
			current_hovered_slot.set_highlight(false)
			current_hovered_slot = null

func _highlight_matching_slots(type: String, active: bool) -> void:
	var slots = get_tree().get_nodes_in_group("unpack_slots")
	for s in slots:
		if s is UnpackingSlot3D and not s.occupied:
			if active and s.accepts_item_type == type:
				s.set_highlight(true)
			else:
				s.set_highlight(false)

func _check_finish() -> void:
	print("[UnpackingManager] Progress: ", placed_items, " / ", total_items)
	if placed_items >= total_items and total_items > 0:
		print("[UnpackingManager] PUZZLE SELESAI!")
		puzzle_completed.emit()
		if ClassDB.class_exists("StoryManager"):
			StoryManager.start_dialogue(["Wah rapiiii! Kamu jago banget bebenahin barang!"], "Rion")

func _raycast_from_mouse(collision_layer_mask: int) -> Dictionary:
	if camera == null:
		return {}
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 100.0
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end, collision_layer_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	return space.intersect_ray(query)
