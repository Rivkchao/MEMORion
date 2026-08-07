extends Node

signal puzzle_completed

var is_puzzle_active: bool = false
var is_puzzle_done: bool = false  # ← flag permanen
var dragging_rock: Node3D = null
var slots: Array = []
var rocks: Array = []
var camera_rig: Node3D = null
var original_camera_target: Node3D = null
var puzzle_camera_position: Vector3 = Vector3.ZERO

func register_slot(slot: Node3D) -> void:
	slots.append(slot)

func register_rock(rock: Node3D) -> void:
	rocks.append(rock)

func setup_camera(cam_rig: Node3D, puzzle_pos: Vector3) -> void:
	camera_rig = cam_rig
	puzzle_camera_position = puzzle_pos

func start_puzzle() -> void:
	if is_puzzle_active or is_puzzle_done:  # ← skip kalau sudah selesai
		return
	is_puzzle_active = true
	_move_camera_to_puzzle()

func _move_camera_to_puzzle() -> void:
	if camera_rig == null:
		return
	original_camera_target = camera_rig.target
	camera_rig.target = null
	
	var target_pos = puzzle_camera_position + Vector3(0, 10, 0)
	var tween = create_tween()
	tween.tween_property(camera_rig, "global_position", target_pos, 0.8)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_CUBIC)
	
	await tween.finished
	camera_rig.look_at(puzzle_camera_position, Vector3.FORWARD)

func end_puzzle() -> void:
	is_puzzle_active = false
	is_puzzle_done = true  # ← lock permanen
	_restore_camera()
	_hide_all_slots()

func _hide_all_slots() -> void:
	for slot in slots:
		slot.hide_slot()

func _restore_camera() -> void:
	if camera_rig == null or original_camera_target == null:
		return
	camera_rig.target = original_camera_target

func check_complete() -> void:
	for slot in slots:
		if not slot.is_occupied():
			return
		if not slot.is_correct():
			return
	
	end_puzzle()
	puzzle_completed.emit()
	StoryManager.start_dialogue(["Yeay! Jembatannya jadi! Ayo nyebrang!"], "Rion")
