# RockPuzzleManager.gd
extends Node

signal puzzle_completed

var is_puzzle_active: bool = false
var is_puzzle_done: bool = false
var is_previewing: bool = false
var is_resetting: bool = false
var has_triggered_distraction: bool = false
var dragging_rock: Node3D = null

var is_crossing_active: bool = false
var has_said_near_end: bool = false
var has_crossed_river: bool = false
var safe_crossing_pos: Vector3 = Vector3(-17.8, 0.2, 0.0)

var slots: Array = []
var rocks: Array = []
var correct_sequence: Array = []
var current_step: int = 0

var camera_rig: Node3D = null
var original_camera_target: Node3D = null
var puzzle_camera_position: Vector3 = Vector3.ZERO

func register_slot(slot: Node3D) -> void:
	slots = slots.filter(func(s): return is_instance_valid(s))
	if not slots.has(slot):
		slots.append(slot)
	_check_and_restore_if_done()

func register_rock(rock: Node3D) -> void:
	rocks = rocks.filter(func(r): return is_instance_valid(r))
	if not rocks.has(rock):
		rocks.append(rock)
	_check_and_restore_if_done()

func _check_and_restore_if_done() -> void:
	if not GameManager.rock_puzzle_done:
		return
	# Jika semua slot dan batu baru sudah terdaftar
	if slots.size() >= 5 and rocks.size() >= 5:
		call_deferred("_restore_solved_state")

func _restore_solved_state() -> void:
	is_puzzle_done = true
	is_puzzle_active = false
	
	for rock in rocks:
		if not is_instance_valid(rock):
			continue
		rock.is_solved = true
		rock.input_ray_pickable = false
		
		# Cocokkan ukuran batu dengan ukuran slot
		var r_size = rock.get("rock_size")
		var target_slot: Node3D = null
		for slot in slots:
			if is_instance_valid(slot) and slot.get("required_rock_size") == r_size:
				target_slot = slot
				break
		
		if target_slot != null:
			rock.global_position = target_slot.global_position + Vector3(0, 0.1, 0)
			rock.global_rotation = target_slot.global_rotation
			rock.original_position = rock.global_position
			rock.original_rotation = rock.global_rotation
			if "current_slot" in rock:
				rock.current_slot = target_slot
			if "occupied_by" in target_slot:
				target_slot.occupied_by = rock
	
	for slot in slots:
		if is_instance_valid(slot) and slot.has_method("hide_slot"):
			slot.hide_slot()

func setup_camera(cam_rig: Node3D, puzzle_pos: Vector3) -> void:
	camera_rig = cam_rig
	puzzle_camera_position = puzzle_pos

func _set_gameplay_ui_visible(is_vis: bool) -> void:
	var root = get_tree().current_scene
	if root == null:
		root = get_tree().root
	if root:
		var hud = root.find_child("HUD", true, false)
		if hud:
			if hud.has_method("set_gameplay_ui_visible"):
				hud.set_gameplay_ui_visible(is_vis)
			else:
				hud.visible = is_vis
		var mobile_controls = root.find_child("MobileControls", true, false)
		if mobile_controls:
			if not is_vis:
				mobile_controls.visible = false
			else:
				if SettingsManager and SettingsManager.has_method("is_mobile_controls_active"):
					mobile_controls.visible = SettingsManager.is_mobile_controls_active()
				else:
					mobile_controls.visible = true

func start_puzzle() -> void:
	if is_puzzle_active or GameManager.rock_puzzle_done:
		return
	is_puzzle_active = true
	has_triggered_distraction = false
	current_step = 0
	is_resetting = false

	_set_gameplay_ui_visible(false)
	_generate_sequence()
	_hide_dialogue_ui()
	await _move_camera_to_puzzle()

	# Fase 1: Panduan Misi
	var hud = get_tree().current_scene.find_child("HUD", true, false)
	if hud and hud.has_method("set_objective"):
		hud.set_objective("Ingat urutan kilauannya! Pasangkan batu sesuai urutan menyala dan jenis batu.")

	await _play_sequence_preview()

	# Fase 2: Dialog Rion saat mulai pasang
	StoryManager.start_dialogue([
		"Rion: Wah, gampang banget kayaknya! Pokoknya pasangnya sesuai urutan dan sesuai jenis batu ya..."
	], "Rion")
	await StoryManager.dialogue_finished

func _hide_dialogue_ui() -> void:
	if StoryManager and StoryManager.dialogue_box and StoryManager.dialogue_box is CanvasItem:
		StoryManager.dialogue_box.hide()

func _generate_sequence() -> void:
	correct_sequence.clear()
	var indices = range(slots.size())
	indices.shuffle()
	correct_sequence = indices

func _move_camera_to_puzzle() -> void:
	if camera_rig == null:
		return

	original_camera_target = camera_rig.get("target")
	camera_rig.set_physics_process(false)
	camera_rig.set_process_unhandled_input(false)

	var target_pos = puzzle_camera_position + Vector3(-7.5, 9.5, 2.5)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(camera_rig, "global_position", target_pos, 1.0)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(camera_rig, "rotation_degrees", Vector3(-85.0, 0.0, 0.0), 1.0)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	await tween.finished

	var cam = camera_rig.find_child("*Camera*", true, false) as Camera3D
	if cam:
		cam.make_current()

func _unhandled_input(event: InputEvent) -> void:
	if not is_puzzle_active or is_previewing or is_resetting or is_puzzle_done:
		return

	var camera = get_tree().root.get_viewport().get_camera_3d()
	if camera == null:
		return

	# 1. Deteksi Tekan (Klik Kiri / Touch Down)
	var is_press := false
	var press_pos := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_press = true
		press_pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		is_press = true
		press_pos = event.position

	if is_press and dragging_rock == null:
		var best_rock: Node3D = null
		var min_dist := 1.8
		var ray_origin = camera.project_ray_origin(press_pos)
		var ray_dir = camera.project_ray_normal(press_pos)
		for r in rocks:
			if not is_instance_valid(r) or r.get("is_solved"):
				continue
			var to_center = r.global_position - ray_origin
			var proj = to_center.dot(ray_dir)
			if proj > 0.0:
				var closest_pt = ray_origin + ray_dir * proj
				var d = closest_pt.distance_to(r.global_position)
				if d < min_dist:
					min_dist = d
					best_rock = r

		if best_rock != null:
			if "last_cursor_pos" in best_rock:
				best_rock.last_cursor_pos = press_pos
			if best_rock.has_method("pick_up"):
				best_rock.pick_up()
			elif best_rock.has_method("_pick_up"):
				best_rock._pick_up()
			get_viewport().set_input_as_handled()
			return

	# 2. Deteksi Lepas (Klik Dilepas / Touch Up)
	var is_release := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		is_release = true
	elif event is InputEventScreenTouch and not event.pressed:
		is_release = true

	if is_release and dragging_rock != null:
		if dragging_rock.has_method("drop"):
			dragging_rock.drop()
		elif dragging_rock.has_method("_drop"):
			dragging_rock._drop()
		get_viewport().set_input_as_handled()
		return

func _play_sequence_preview() -> void:
	is_previewing = true
	for slot in slots:
		slot.set_highlight(false)

	await get_tree().create_timer(0.4).timeout

	for step_idx in range(correct_sequence.size()):
		var slot_idx = correct_sequence[step_idx]
		var target_slot = slots[slot_idx]

		target_slot.set_highlight(true, step_idx + 1)
		await get_tree().create_timer(0.7).timeout
		target_slot.set_highlight(false)
		await get_tree().create_timer(0.2).timeout

	is_previewing = false
	is_resetting = false

func on_rock_placed(placed_slot: Node3D, rock: Node3D) -> void:
	if is_previewing or is_puzzle_done or is_resetting:
		return

	var expected_slot_idx = correct_sequence[current_step]
	var actual_slot_idx = slots.find(placed_slot)

	# Cek ukuran batu cocok dengan slot yang dipilih (0 = batu apa saja boleh)
	var required := 0
	if placed_slot.get("required_rock_size") != null:
		required = int(placed_slot.get("required_rock_size"))
	var rock_size := 0
	if rock.get("rock_size") != null:
		rock_size = int(rock.get("rock_size"))
	var size_ok: bool = required == 0 or rock_size == required

	if actual_slot_idx == expected_slot_idx and size_ok:
		current_step += 1
		placed_slot.set_permanent_solved()
		if rock.has_method("set_solved"):
			rock.set_solved()

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
	if is_resetting:
		return
	is_resetting = true
	is_previewing = true
	dragging_rock = null

	# Hentikan semua drag yang sedang berlangsung
	for r in rocks:
		if r.has_method("stop_drag"):
			r.stop_drag()

	slot.flash_wrong()
	await get_tree().create_timer(0.4).timeout
	rock.return_to_original()
	slot.occupied_by = null

	current_step = 0
	for s in slots:
		s.reset_slot()
	for r in rocks:
		r.return_to_original()

	# Skenario jika pemain salah memasukkan urutan
	StoryManager.start_dialogue(["Ona: Tidak apa-apa Rion. Yuk, kita lihat lagi polanya dari awal bersama-sama."], "Ona")
	await StoryManager.dialogue_finished

	# Preview kembali urutan yang benar
	await get_tree().create_timer(0.5).timeout
	await _play_sequence_preview()
	is_resetting = false

func _on_complete() -> void:
	is_puzzle_active = false
	is_puzzle_done = true
	GameManager.rock_puzzle_done = true
	puzzle_completed.emit()

	for slot in slots:
		slot.hide_slot()

	_restore_camera()

	# Skenario saat pemain memasukkan urutan yang benar
	await get_tree().create_timer(0.6).timeout
	var win_dialogue: Array[String] = [
		"Rion: Yeeay! Berhasil! Batunya muncul semua ke atas air!",
		"Ona: Wah kamu hebat Rion. Jalur penyeberangan telah terbuka. Sekarang ayo kita melompat keatas batunya."
	]
	StoryManager.start_dialogue(win_dialogue, "Rion")
	await StoryManager.dialogue_finished

	if not GameManager.collected_fragments.get("batu", false):
		await FragmentBox.show_fragment("batu")

	# Fase 3: Instruksi Penyeberangan / Melompat
	var jump_dialogue: Array[String] = [
		"Ona: Lompat saja saat kamu sudah merasa siap. Kamu pasti bisa melewatinya."
	]
	StoryManager.start_dialogue(jump_dialogue, "Ona")
	await StoryManager.dialogue_finished

	_set_gameplay_ui_visible(true)
	var hud = get_tree().current_scene.find_child("HUD", true, false)
	if hud and hud.has_method("set_objective"):
		hud.set_objective("Lompat melewati batu-batu sungai ke seberang")

	start_river_crossing_phase()

func start_river_crossing_phase() -> void:
	is_crossing_active = true
	has_said_near_end = false
	has_crossed_river = false

	var ona = get_tree().current_scene.find_child("Ona", true, false)
	if ona and "waypoints" in ona and ona.waypoints.size() > 6 and ona.waypoints[6]:
		safe_crossing_pos = ona.waypoints[6].global_position + Vector3(0.5, 0.2, 0.0)
	elif ona:
		safe_crossing_pos = ona.global_position + Vector3(0.5, 0.2, 0.0)

func _process(_delta: float) -> void:
	if not is_crossing_active or has_crossed_river:
		return

	var player = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return

	var px = player.global_position.x
	var py = player.global_position.y

	# 1. Deteksi Jatuh ke Air (Y di bawah air sungai pada rentang sungai)
	if py < -1.2 and px < -20.0 and px > -37.0:
		on_player_fell_in_river()
		return

	# 2. Deteksi Sisa Satu Batu (Rion di dekat batu terakhir X <= -32.0 dan X > -36.0)
	if not has_said_near_end and px <= -32.0 and px > -36.0 and py > -1.0:
		has_said_near_end = true
		StoryManager.start_dialogue(["Ona: Lompatan yang bagus Rion. Tinggal sedikit lagi kamu berhasil."], "Ona")

	# 3. Deteksi Selesai Menyeberang (Rion mendarat di seberang sungai X <= -36.5)
	if not has_crossed_river and px <= -36.5 and py > -1.0:
		has_crossed_river = true
		is_crossing_active = false
		_on_river_crossed_successfully()

func on_player_fell_in_river() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.global_position = safe_crossing_pos
		player.velocity = Vector3.ZERO
	if StoryManager and not is_dialogue_playing():
		StoryManager.start_dialogue(["Ona: Tidak apa-apa Rion, aku akan selalu menyelamatkanmu. Kamu aman bersamaku"], "Ona")

func is_dialogue_playing() -> bool:
	if StoryManager and StoryManager.dialogue_box:
		if StoryManager.dialogue_box.has_method("is_active"):
			return StoryManager.dialogue_box.is_active()
	return false

func _on_river_crossed_successfully() -> void:
	print("Rion berhasil menyeberangi sungai!")
	var hud = get_tree().current_scene.find_child("HUD", true, false)
	if hud and hud.has_method("set_objective"):
		hud.set_objective("Temui Tuan Rallux di dalam Bengkel Laboratorium")

	var ona = get_tree().current_scene.find_child("Ona", true, false)
	if ona and ona.has_method("teleport_to_point_8"):
		await ona.teleport_to_point_8()

func _restore_camera() -> void:
	if camera_rig == null:
		return

	camera_rig.set_physics_process(true)
	camera_rig.set_process_unhandled_input(true)
	if original_camera_target != null:
		camera_rig.set("target", original_camera_target)
