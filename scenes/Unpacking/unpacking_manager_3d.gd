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
var waiting_for_tasks: bool = false
var _last_missing_log: String = ""

signal rak1_completed
signal all_completed

func _ready() -> void:
	add_to_group("unpacking_manager")
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
		if player == null and get_tree().current_scene:
			player = get_tree().current_scene.get_node_or_null("Player") as Node3D

	if StoryManager.has_signal("dialogue_finished"):
		StoryManager.dialogue_finished.connect(_on_story_dialogue_finished)

	if GameManager.unpacking_completed:
		_restore_all_completed()
	elif GameManager.unpacking_rak1_done:
		_restore_rak1_completed()
		if _are_prerequisite_tasks_done():
			_setup_phase(2)
		else:
			phase_completed = true
			waiting_for_tasks = true
			_set_container_interaction(rak1_container, false)
			if rak2_container:
				_hide_items(rak2_container)
				_set_container_interaction(rak2_container, false)
	else:
		_setup_phase(1)

func _on_story_dialogue_finished() -> void:
	if current_phase == 1 and waiting_for_dialog:
		waiting_for_dialog = false
		if not GameManager.collected_fragments.get("unpacking_rak1", false):
			await FragmentBox.show_fragment("unpacking_rak1")
		_begin_waiting_for_tasks()
	elif current_phase == 2 and waiting_for_dialog:
		waiting_for_dialog = false
		if not GameManager.collected_fragments.get("unpacking_rak2", false):
			await FragmentBox.show_fragment("unpacking_rak2")
		
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

	if waiting_for_tasks:
		if _are_prerequisite_tasks_done():
			var dlg_open: bool = StoryManager.dialogue_box != null and StoryManager.dialogue_box.visible
			if not dlg_open:
				_begin_phase_2()
		else:
			var missing := _missing_prerequisites()
			if missing != _last_missing_log:
				_last_missing_log = missing
				print("[Unpacking] Rak 2 terkunci. Sisa syarat: ", missing)

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
	if phase_completed or waiting_for_dialog:
		return

	# Deteksi tombol aksi (Interact) dari keyboard E atau Virtual Button Mobile
	var is_interact := false
	if event.is_action_pressed("interact"):
		is_interact = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		is_interact = true

	if is_interact:
		# Kalau belum memegang item
		if held_item == null:
			_try_interact_pickup()
		# Kalau sedang memegang item
		else:
			_try_interact_place()
		return

	# Deteksi tombol drop / lepas item
	if event.is_action_pressed("ui_cancel") and held_item != null:
		drop_held_item()
		return

	# Sentuhan langsung pada item / slot di layar mobile
	if event is InputEventScreenTouch and event.pressed:
		_try_touch_interact(event.position)

func drop_held_item() -> void:
	if held_item == null:
		return
	held_item.return_to_origin()
	held_item = null
	_highlight_matching_slots("", false)

func has_held_item() -> bool:
	return held_item != null

func get_nearest_item_distance() -> float:
	if player == null:
		return 999.0
	var active_container = _get_active_container()
	if active_container == null:
		return 999.0
	var min_d := 999.0
	for item in active_container.find_children("", "UnpackItem3D", true, false):
		var unpack_item := item as UnpackItem3D
		if unpack_item and not unpack_item.is_placed and unpack_item.visible:
			var d = player.global_position.distance_to(unpack_item.global_position)
			if d < min_d:
				min_d = d
	return min_d

func get_nearest_slot_distance() -> float:
	if player == null:
		return 999.0
	var active_container = _get_active_container()
	if active_container == null:
		return 999.0
	var min_d := 999.0
	for slot in active_container.find_children("", "UnpackingSlot3D", true, false):
		var unpack_slot := slot as UnpackingSlot3D
		if unpack_slot and not unpack_slot.occupied:
			var d = player.global_position.distance_to(unpack_slot.global_position)
			if d < min_d:
				min_d = d
	return min_d

func _try_touch_interact(screen_pos: Vector2) -> bool:
	var camera = get_viewport().get_camera_3d()
	if camera == null or player == null:
		return false

	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_dir = camera.project_ray_normal(screen_pos)
	var active_container = _get_active_container()
	if active_container == null:
		return false

	if held_item != null:
		for slot in active_container.find_children("", "UnpackingSlot3D", true, false):
			var unpack_slot := slot as UnpackingSlot3D
			if unpack_slot == null or unpack_slot.occupied or unpack_slot.accepts_item_type != held_item.item_type:
				continue
			var to_slot = unpack_slot.global_position - ray_origin
			var proj = to_slot.dot(ray_dir)
			if proj > 0.0:
				var closest = ray_origin + ray_dir * proj
				if closest.distance_to(unpack_slot.global_position) < 2.0:
					if player.global_position.distance_to(unpack_slot.global_position) <= interact_distance + 2.0:
						_try_interact_place()
						return true
	else:
		for item in active_container.find_children("", "UnpackItem3D", true, false):
			var unpack_item := item as UnpackItem3D
			if unpack_item == null or unpack_item.is_placed or not unpack_item.visible:
				continue
			var to_item = unpack_item.global_position - ray_origin
			var proj = to_item.dot(ray_dir)
			if proj > 0.0:
				var closest = ray_origin + ray_dir * proj
				if closest.distance_to(unpack_item.global_position) < 2.0:
					if player.global_position.distance_to(unpack_item.global_position) <= interact_distance + 2.0:
						held_item = unpack_item
						_highlight_matching_slots(unpack_item.item_type, true)
						return true
	return false

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
	if AudioManager:
		AudioManager.play_rock_pickup()

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
	if AudioManager:
		AudioManager.play_puzzle_step_correct()
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
	if AudioManager:
		AudioManager.play_puzzle_solved()


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
		await StoryManager.dialogue_finished
		GameManager.ona_hold_position = false
		# Tampilkan checklist semua misi yang sudah selesai
		if GameManager.hud and GameManager.hud.has_method("show_mission_complete_checklist"):
			GameManager.hud.show_mission_complete_checklist()

func continue_to_next_phase() -> void:
	if current_phase == 1:
		waiting_for_dialog = false
		_setup_phase(2)

func _are_prerequisite_tasks_done() -> bool:
	# Urutan misi: Rak 1 -> Tuas Crusher -> Tuas Ona Program -> Terminal -> Rak 2
	return GameManager.terminal_puzzle_done \
		and GameManager.solved_levers.get("CrusherRoom_Lever", false) \
		and GameManager.solved_levers.get("OnaProgramRoom_Lever", false)

func _missing_prerequisites() -> String:
	var missing: Array[String] = []
	if not GameManager.solved_levers.get("CrusherRoom_Lever", false):
		missing.append("Tuas Crusher")
	if not GameManager.solved_levers.get("OnaProgramRoom_Lever", false):
		missing.append("Tuas Ona Program")
	if not GameManager.terminal_puzzle_done:
		missing.append("Terminal")
	return ", ".join(missing)

func _begin_waiting_for_tasks() -> void:
	phase_completed = true
	if _are_prerequisite_tasks_done():
		_begin_phase_2()
		return

	waiting_for_tasks = true
	_set_container_interaction(rak1_container, false)
	if rak2_container:
		_hide_items(rak2_container)
		_set_container_interaction(rak2_container, false)

	print("[Unpacking] Rak 1 selesai. Menunggu tuas Crusher, Tuas Ona Program, & terminal sebelum Rak 2.")
	if GameManager:
		GameManager.set_objective(
			"Tarik Tuas di Ruang Crusher",
			0,
			""
		)

func _begin_phase_2() -> void:
	if current_phase == 2:
		return
	waiting_for_tasks = false
	_setup_phase(2)
	if GameManager:
		GameManager.set_objective(
			"Rapikan Rak 2 (angkut semua barang ke slot yang benar)",
			0,
			""
		)

	# Ona kembali ke Point2 dengan fade, lalu bantu proyeksikan panduan slot (seperti Rak 1)
	await _move_ona_to_point2_with_fade()

	if StoryManager and StoryManager.has_method("start_dialogue"):
		StoryManager.start_dialogue([
			"Ona: \"Ini rak terakhir. Aku bantu proyeksikan panduan slot wadahnya lagi ya, Rion!\"",
			"Rion: \"Makasih, Ona! Ayo kita susun semuanya sampai rapi!\""
		], "Rion")

func _move_ona_to_point2_with_fade() -> void:
	GameManager.ona_hold_position = true
	var scene := get_tree().current_scene
	if scene == null:
		return
	var can_fade: bool = scene.has_method("_fade_screen_out") and scene.has_method("_fade_screen_in")
	if can_fade:
		await scene._fade_screen_out(0.3)

	var ona: Node3D = scene.find_child("Ona", true, false) as Node3D
	if ona == null:
		ona = get_tree().root.find_child("Ona", true, false) as Node3D
	var p2: Node3D = scene.find_child("Point2", true, false) as Node3D
	if p2 == null:
		p2 = get_tree().root.find_child("Point2", true, false) as Node3D

	if ona and p2:
		ona.global_position = p2.global_position
		ona.rotation.y = atan2(-1.0, 0.0)
		if ona.has_method("play_animation"):
			ona.play_animation("idle")

	if can_fade:
		await scene._fade_screen_in(0.35)

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
