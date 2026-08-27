extends Node3D
class_name UnpackingManager3D

@export var player: Node3D
@export var interact_distance: float = 3.5
@export var hold_offset: Vector3 = Vector3(0.0, 0.8, -1.2)

var held_item: UnpackItem3D = null
var total_items: int = 0
var placed_items: int = 0

signal puzzle_completed

func _ready() -> void:
	if player == null:
		player = get_tree().root.find_child("Player", true, false) as Node3D
		if player == null:
			player = get_tree().root.find_child("player", true, false) as Node3D

	var all_items: Array[Node] = get_tree().get_nodes_in_group("unpack_items")
	total_items = all_items.size()

func _process(delta: float) -> void:
	# Hanya update posisi jika item sedang dipegang DAN belum terpasang
	if held_item != null and not held_item.is_placed and player != null:
		var target_pos: Vector3 = player.global_position + (player.global_transform.basis * hold_offset)
		held_item.global_position = held_item.global_position.lerp(target_pos, 15.0 * delta)
		held_item.global_rotation = player.global_rotation

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			if held_item == null:
				_try_interact_pickup()
			else:
				_try_interact_place()

func _try_interact_pickup() -> void:
	if player == null:
		return

	var nearest_item: UnpackItem3D = null
	var min_dist: float = interact_distance

	for node in get_tree().get_nodes_in_group("unpack_items"):
		var item: UnpackItem3D = node as UnpackItem3D
		if item and not item.is_placed:
			var d: float = player.global_position.distance_to(item.global_position)
			if d < min_dist:
				min_dist = d
				nearest_item = item

	if nearest_item != null:
		held_item = nearest_item
		_highlight_matching_slots(nearest_item.item_type, true)

func _try_interact_place() -> void:
	if player == null or held_item == null:
		return

	var matching_slot: UnpackingSlot3D = null
	var min_dist: float = interact_distance

	var player_flat: Vector3 = Vector3(player.global_position.x, 0.0, player.global_position.z)

	# Cari slot terdekat KHUSUS yang menerima tipe barang yang sedang dipegang
	for node in get_tree().get_nodes_in_group("unpack_slots"):
		var slot: UnpackingSlot3D = node as UnpackingSlot3D
		if slot and not slot.occupied and slot.accepts_item_type == held_item.item_type:
			var slot_flat: Vector3 = Vector3(slot.global_position.x, 0.0, slot.global_position.z)
			var d: float = player_flat.distance_to(slot_flat)
			
			if d < min_dist:
				min_dist = d
				matching_slot = slot

	if matching_slot != null:
		var item_to_snap = held_item
		held_item = null
		item_to_snap.is_placed = true
		matching_slot.snap_item(item_to_snap)
		placed_items += 1
		_highlight_matching_slots("", false)
		_check_finish()
		
func _highlight_matching_slots(type: String, active: bool) -> void:
	for node in get_tree().get_nodes_in_group("unpack_slots"):
		var s: UnpackingSlot3D = node as UnpackingSlot3D
		if s and not s.occupied:
			s.set_highlight(active and (s.accepts_item_type == type))

func _check_finish() -> void:
	if placed_items >= total_items and total_items > 0:
		puzzle_completed.emit()
