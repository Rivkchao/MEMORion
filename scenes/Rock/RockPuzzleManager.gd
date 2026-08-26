extends Node

signal puzzle_completed

var is_puzzle_active: bool = false
var is_puzzle_done: bool = false
var is_previewing: bool = false
var has_triggered_distraction: bool = false
var dragging_rock: Node3D = null

var slots: Array = []
var rocks: Array = []
var correct_sequence: Array = []
var current_step: int = 0

var camera_rig: Node3D = null
var original_camera_target: Node3D = null
var puzzle_camera_position: Vector3 = Vector3.ZERO

func register_slot(slot: Node3D) -> void:
	if not slots.has(slot):
		slots.append(slot)

func register_rock(rock: Node3D) -> void:
	if not rocks.has(rock):
		rocks.append(rock)

func setup_camera(cam_rig: Node3D, puzzle_pos: Vector3) -> void:
	camera_rig = cam_rig
	puzzle_camera_position = puzzle_pos

func start_puzzle() -> void:
	if is_puzzle_active or is_puzzle_done:
		return
	is_puzzle_active = true
	has_triggered_distraction = false
	current_step = 0
	
	_generate_sequence()
	await _move_camera_to_puzzle()
	await _play_sequence_preview()

func _generate_sequence() -> void:
	correct_sequence.clear()
	var indices = range(slots.size())
	indices.shuffle()
	correct_sequence = indices

func _move_camera_to_puzzle() -> void:
	if camera_rig == null:
		print("[RockPuzzleManager] ERROR: camera_rig belum di-setup (masih null)!")
		return
	
	original_camera_target = camera_rig.get("target")
	
	# Matikan physics process rig agar tween tidak ditabrak oleh skrip orbit
	camera_rig.set_physics_process(false)
	camera_rig.set_process_unhandled_input(false)
	
	# Posisi di atas puzzle (tinggi Y = 10)
	var target_pos = puzzle_camera_position + Vector3(-7.5, 9.5, 2.5)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(camera_rig, "global_position", target_pos, 1.0)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_CUBIC)
	
	# Rotasikan kamera menghadap ke bawah (-90 derajat di sumbu X)
	tween.tween_property(camera_rig, "rotation_degrees", Vector3(-85.0, 0.0, 0.0), 1.0)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_CUBIC)
	
	await tween.finished

func _play_sequence_preview() -> void:
	is_previewing = true
	for slot in slots:
		slot.set_highlight(false)
	
	await get_tree().create_timer(0.6).timeout
	
	for step_idx in range(correct_sequence.size()):
		var slot_idx = correct_sequence[step_idx]
		var target_slot = slots[slot_idx]
		
		target_slot.set_highlight(true, step_idx + 1)
		await get_tree().create_timer(0.7).timeout
		target_slot.set_highlight(false)
		await get_tree().create_timer(0.2).timeout
	
	is_previewing = false

func on_rock_placed(placed_slot: Node3D, rock: Node3D) -> void:
	if is_previewing or is_puzzle_done:
		return
	
	var expected_slot_idx = correct_sequence[current_step]
	var actual_slot_idx = slots.find(placed_slot)
	
	if actual_slot_idx == expected_slot_idx:
		current_step += 1
		placed_slot.set_permanent_solved()
		
		if current_step == 1 and not has_triggered_distraction:
			has_triggered_distraction = true
			_trigger_distraction()
		
		if current_step >= correct_sequence.size():
			_on_complete()
	else:
		_on_wrong_step(placed_slot, rock)

func _trigger_distraction() -> void:
	if has_node("/root/RockDistractionOverlay"):
		get_node("/root/RockDistractionOverlay").show_distraction()

func _on_wrong_step(slot: Node3D, rock: Node3D) -> void:
	slot.flash_wrong()
	await get_tree().create_timer(0.4).timeout
	rock.return_to_original()
	slot.occupied_by = null
	
	current_step = 0
	for s in slots:
		s.reset_slot()
	for r in rocks:
		r.return_to_original()
	
	StoryManager.start_dialogue(["Urutannya salah! Ingat-ingat lagi pola jalurnya ya!"], "Rion")
	await get_tree().create_timer(1.0).timeout
	_play_sequence_preview()

func _on_complete() -> void:
	is_puzzle_active = false
	is_puzzle_done = true
	puzzle_completed.emit()
	
	# Sembunyikan semua slot agar warna hijau indikator hilang permanen
	for slot in slots:
		slot.hide_slot()
		
	StoryManager.start_dialogue(["Bagus sekali! Batunya sudah tersusun dengan aman!"], "Rion")
	_restore_camera()
	
func _restore_camera() -> void:
	if camera_rig == null:
		return
	
	# Hidupkan kembali kendali normal kamera rig
	camera_rig.set_physics_process(true)
	camera_rig.set_process_unhandled_input(true)
	if original_camera_target != null:
		camera_rig.set("target", original_camera_target)
