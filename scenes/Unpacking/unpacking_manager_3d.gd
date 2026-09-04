extends Node3D
class_name UnpackingManager3D

@export var player: Node3D
@export var interact_distance: float = 3.5
@export var hold_offset: Vector3 = Vector3(0.0, 0.8, -1.2)
@export var speaker_name: String = "Rion"
@export var rak1_complete_dialogue: String = "Rak pertama sudah rapi! Sekarang mari bereskan rak kedua."
@export var rak2_complete_dialogue: String = "Semua rak sudah selesai dirapikan! Kerja bagus!"
@onready var rak1_container: Node3D = $RakUnpacking1
@onready var rak2_container: Node3D = $RakUnpacking2
var current_phase: int = 1

var held_item: UnpackItem3D = null
var current_total_items: int = 0
var current_placed_items: int = 0
var phase_completed: bool = false
var waiting_for_dialog: bool = false

signal rak1_completed
signal all_completed

func _ready() -> void:
	if player == null:
		player = get_tree().root.find_child("Player", true, false) as Node3D
		if player == null:
			player = get_tree().root.find_child("player", true, false) as Node3D

	if StoryManager.has_signal("dialogue_finished"):
		StoryManager.dialogue_finished.connect(_on_story_dialogue_finished)

	if GameManager.unpacking_completed:
		_restore_all_completed()
	elif GameManager.unpacking_rak1_done:
		_restore_rak1_completed()
		_setup_phase(2)
	else:
		_setup_phase(1)

func _on_story_dialogue_finished() -> void:
	if current_phase == 1 and waiting_for_dialog:
		continue_to_next_phase()
		
func _setup_phase(phase: int) -> void:
	current_phase = phase
	current_placed_items = 0
	current_total_items = 0
	phase_completed = false
	waiting_for_dialog = false
	held_item = null

	if rak1_container != null:
		_show_items(rak1_container)
		_set_container_interaction(rak1_container, phase == 1)

	if rak2_container != null:
		if phase == 2:
			_show_items(rak2_container)
			_set_container_interaction(rak2_container, true)
		else:
			_hide_items(rak2_container)
			_set_container_interaction(rak2_container, false)

	var active_container: Node3D = rak1_container if phase == 1 else rak2_container

	if active_container != null:
		var items = active_container.find_children("", "UnpackItem3D", true, false)
		current_total_items = items.size()
		
func _show_items(container: Node3D) -> void:

	if container == null:
		return

	# Container tetap terlihat
	container.visible = true

	# Tampilkan semua item
	for item in container.find_children(
		"",
		"UnpackItem3D",
		true,
		false
	):

		var unpack_item := item as UnpackItem3D

		if unpack_item != null:
			unpack_item.visible = true

func _hide_items(container: Node3D) -> void:

	if container == null:
		return

	# Container tetap aktif secara visual
	container.visible = true

	# Tapi semua barang disembunyikan
	for item in container.find_children(
		"",
		"UnpackItem3D",
		true,
		false
	):

		var unpack_item := item as UnpackItem3D

		if unpack_item != null:
			unpack_item.visible = false

func _set_container_interaction(container: Node3D, is_active: bool) -> void:

	if container == null:
		return

	# Container
	container.process_mode = (
		Node.PROCESS_MODE_INHERIT
		if is_active
		else Node.PROCESS_MODE_DISABLED
	)

	# Item
	for item in container.find_children(
		"",
		"UnpackItem3D",
		true,
		false
	):

		var unpack_item := item as UnpackItem3D

		if unpack_item != null:

			unpack_item.process_mode = (
				Node.PROCESS_MODE_INHERIT
				if is_active
				else Node.PROCESS_MODE_DISABLED
			)

	# Slot
	for slot in container.find_children(
		"",
		"UnpackingSlot3D",
		true,
		false
	):

		var unpack_slot := slot as UnpackingSlot3D

		if unpack_slot != null:

			unpack_slot.process_mode = (
				Node.PROCESS_MODE_INHERIT
				if is_active
				else Node.PROCESS_MODE_DISABLED
			)

func _process(delta: float) -> void:

	if held_item == null:
		return

	if held_item.is_placed:
		return

	if player == null:
		return

	# Posisi item ketika sedang dipegang
	var target_pos: Vector3 = (
		player.global_position
		+ (player.global_transform.basis * hold_offset)
	)

	held_item.global_position = held_item.global_position.lerp(
		target_pos,
		15.0 * delta
	)

	held_item.global_rotation = player.global_rotation

func _input(event: InputEvent) -> void:

	if not event is InputEventKey:
		return

	if not event.pressed:
		return

	if event.echo:
		return

	if event.keycode != KEY_E:
		return


	# Kalau belum memegang item
	if held_item == null:
		_try_interact_pickup()

	# Kalau sedang memegang item
	else:
		_try_interact_place()

func _try_interact_pickup() -> void:

	if player == null:
		return

	var active_container: Node3D = _get_active_container()

	if active_container == null:
		return


	var nearest_item: UnpackItem3D = null
	var min_dist: float = interact_distance


	for item in active_container.find_children(
		"",
		"UnpackItem3D",
		true,
		false
	):

		var unpack_item := item as UnpackItem3D

		if unpack_item == null:
			continue

		# Item sudah ditempatkan → skip
		if unpack_item.is_placed:
			continue

		# Item sedang hidden → skip
		if not unpack_item.visible:
			continue


		var distance: float = player.global_position.distance_to(
			unpack_item.global_position
		)


		if distance < min_dist:

			min_dist = distance
			nearest_item = unpack_item


	if nearest_item == null:
		return


	# Ambil item
	held_item = nearest_item

	# Highlight slot yang cocok
	_highlight_matching_slots(
		nearest_item.item_type,
		true
	)

func _try_interact_place() -> void:
	if player == null:
		return

	if held_item == null:
		return

	var active_container: Node3D = _get_active_container()
	if active_container == null:
		return

	var matching_slot: UnpackingSlot3D = null
	var min_dist: float = interact_distance

	var player_flat := Vector3(player.global_position.x, 0.0, player.global_position.z)

	for slot in active_container.find_children("", "UnpackingSlot3D", true, false):
		var unpack_slot := slot as UnpackingSlot3D
		if unpack_slot == null:
			continue

		if unpack_slot.occupied:
			continue

		if unpack_slot.accepts_item_type != held_item.item_type:
			continue

		var slot_flat := Vector3(
			unpack_slot.global_position.x, 0.0, unpack_slot.global_position.z)

		var distance: float = player_flat.distance_to(slot_flat)

		if distance < min_dist:
			min_dist = distance
			matching_slot = unpack_slot

	if matching_slot == null:
		return

	var item_to_snap: UnpackItem3D = held_item
	held_item = null
	_highlight_matching_slots("",false)

	item_to_snap.is_placed = true

	matching_slot.snap_item(item_to_snap)
	await matching_slot.item_snap_finished
	current_placed_items += 1
	print(
		"Item placed: ",
		current_placed_items,
		"/",
		current_total_items
	)

	_check_phase_finish()

func _highlight_matching_slots(type: String, active: bool) -> void:

	var active_container: Node3D = _get_active_container()
	if active_container == null:
		return


	for slot in active_container.find_children(
		"",
		"UnpackingSlot3D",
		true,
		false
	):

		var unpack_slot := slot as UnpackingSlot3D

		if unpack_slot == null:
			continue

		if unpack_slot.occupied:
			continue


		var should_highlight: bool = (
			active
			and unpack_slot.accepts_item_type == type
		)


		unpack_slot.set_highlight(
			should_highlight
		)

func _get_active_container() -> Node3D:

	if current_phase == 1:
		return rak1_container

	if current_phase == 2:
		return rak2_container

	return null

func _check_phase_finish() -> void:

	# Sudah selesai → jangan jalankan lagi
	if phase_completed:
		return

	# Belum semua item
	if current_total_items <= 0:
		return

	if current_placed_items < current_total_items:
		return

	# PHASE SELESAI

	phase_completed = true


	# Pastikan tidak ada item yang sedang dipegang
	held_item = null

	# Matikan highlight
	_highlight_matching_slots(
		"",
		false
	)

	# RAK 1 SELESAI
	if current_phase == 1:

		# Rak 1 tetap terlihat
		# Tetapi tidak bisa diinteraksi lagi
		_set_container_interaction(
			rak1_container,
			false
		)


		# Tandai sedang menunggu dialog
		waiting_for_dialog = true

		GameManager.unpacking_rak1_done = true

		# Signal
		rak1_completed.emit()

		# TAMPILKAN DIALOG
		StoryManager.start_dialogue(
			[rak1_complete_dialogue],
			speaker_name
		)

	# RAK 2 SELESAI
	elif current_phase == 2:

		_set_container_interaction(
			rak2_container,
			false
		)

		waiting_for_dialog = true

		GameManager.unpacking_completed = true

		all_completed.emit()

		StoryManager.start_dialogue(
			[rak2_complete_dialogue],
			speaker_name
		)

func continue_to_next_phase() -> void:
	if current_phase == 1 and waiting_for_dialog:
		waiting_for_dialog = false
		_setup_phase(2)

func _restore_rak1_completed() -> void:
	if rak1_container:
		_snap_container_items_instantly(rak1_container)
		_set_container_interaction(rak1_container, false)

func _restore_all_completed() -> void:
	phase_completed = true
	if rak1_container:
		_snap_container_items_instantly(rak1_container)
		_set_container_interaction(rak1_container, false)
	if rak2_container:
		_snap_container_items_instantly(rak2_container)
		_set_container_interaction(rak2_container, false)

func _snap_container_items_instantly(container: Node3D) -> void:
	if container == null:
		return
	container.visible = true
	var items = container.find_children("", "UnpackItem3D", true, false)
	var slots = container.find_children("", "UnpackingSlot3D", true, false)

	for slot in slots:
		var unpack_slot := slot as UnpackingSlot3D
		if unpack_slot == null:
			continue
		for item in items:
			var unpack_item := item as UnpackItem3D
			if unpack_item == null or unpack_item.is_placed:
				continue
			if unpack_item.item_type == unpack_slot.accepts_item_type:
				unpack_item.is_placed = true
				unpack_slot.occupied = true
				unpack_item.visible = true
				unpack_item.global_position = unpack_slot.global_position
				unpack_item.global_rotation = unpack_slot.global_rotation
				var col = unpack_item.find_child("CollisionShape3D", true, false) as CollisionShape3D
				if col:
					col.disabled = true
				if unpack_slot.preview_mesh:
					unpack_slot.preview_mesh.visible = false
				break
