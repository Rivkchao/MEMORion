extends Node3D

const BGM_LEVEL1_EXPLORATION = preload("res://assets/audio/bgm/meditation_main.mp3")

func _ready() -> void:
	if AudioManager:
		AudioManager.play_bgm(BGM_LEVEL1_EXPLORATION, 2.0, -4.0)
		AudioManager.play_ambience(AudioManager.AMBIENCE_WIND, 2.0, -8.0)

	# Cari node WirePuzzle & HUD secara dinamis
	var wire_puzzle_node = find_child("WirePuzzle", true, false)
	var dialogue_node = find_child("DialogueBox", true, false)
	if dialogue_node == null:
		dialogue_node = find_child("HUD", true, false)
	
	# Inisialisasi ke StoryManager
	StoryManager.init(dialogue_node, null, wire_puzzle_node)
	
	# Jalankan intro roket HANYA jika scene ini memiliki roket & kamera roket DAN belum pernah ke bengkel
	if has_node("RocketCamera") and has_node("RionCapsule/AnimationPlayer") and not GameManager.has_visited_workshop:
		_play_rocket_intro()
	elif has_node("StoryPointing2") and has_node("Rallux") and not GameManager.has_visited_workshop:
		_play_workshop_intro()
	elif has_node("StoryPointing2") and has_node("Rallux") and GameManager.sleep_transition_done and not GameManager.r1_morning_intro_done:
		_play_r1_morning_intro()
	else:
		_setup_gameplay_state()

func _setup_gameplay_state() -> void:
	var player: CharacterBody3D = find_child("Player", true, false) as CharacterBody3D
	var camera_rig = find_child("CameraRig", true, false)
	var hud = find_child("HUD", true, false)

	# Pastikan Player aktif, terlihat, dan collision aktif
	if player:
		player.visible = true
		player.set_physics_process(true)
		player.set_process_unhandled_input(true)
		var col = player.find_child("CollisionShape3D", true, false)
		if col:
			col.set_deferred("disabled", false)
		
		# Ambil override spawn jika ada
		var scene_str = ""
		if owner and owner.scene_file_path:
			scene_str = owner.scene_file_path
		elif get_tree() and get_tree().current_scene:
			scene_str = get_tree().current_scene.scene_file_path
			if scene_str == "":
				scene_str = get_tree().current_scene.name
		if scene_str != "":
			var override_pos = GameManager.consume_spawn_override_for(scene_str)
			if override_pos != Vector3.ZERO:
				player.global_position = override_pos
				if "last_safe_position" in player:
					player.last_safe_position = override_pos

		player.rotation = Vector3.ZERO
		var rion_mesh = player.get_node_or_null("RionMesh")
		if rion_mesh:
			rion_mesh.rotation = Vector3.ZERO

	# Pastikan Kamera Player aktif & snap ke target
	if camera_rig:
		camera_rig.set_physics_process(true)
		camera_rig.set_process(true)
		camera_rig.set_process_unhandled_input(true)
		var player_cam = camera_rig.find_child("*Camera*", true, false) as Camera3D
		if player_cam:
			player_cam.make_current()
		if camera_rig.has_method("snap_to_target"):
			camera_rig.snap_to_target()

	# Pastikan HUD gameplay aktif
	if hud:
		if hud.has_method("set_gameplay_ui_visible"):
			hud.set_gameplay_ui_visible(true)
		else:
			hud.visible = true

	# Khusus LEV1: pastikan kapsul tetap di lokasi mendarat dan api tetap menyala
	if has_node("RocketCamera"):
		var capsule = find_child("RionCapsule", true, false)
		if capsule:
			capsule.visible = true
			capsule.global_position = Vector3(106.118, -0.096, 25.87)
			capsule.rotation = Vector3(0, 0, deg_to_rad(9.5))
			var c_anim: AnimationPlayer = capsule.get_node_or_null("AnimationPlayer")
			if c_anim:
				c_anim.stop()
			var smoke = capsule.find_child("Smoke", true, false)
			if smoke:
				smoke.visible = true
		for fire_name in ["Fire1", "Fire2", "Fire3"]:
			var fire_node = find_child(fire_name, true, false)
			if fire_node:
				fire_node.visible = true

	# Khusus R1: kapsul yang sudah dibersihkan tetap tampil setelah cutscene pagi.
	if has_node("StoryPointing2") and has_node("RionCapsule") and GameManager.r1_morning_intro_done:
		var r1_capsule = find_child("RionCapsule", true, false)
		if r1_capsule:
			r1_capsule.visible = true

	# Hari berikutnya di bengkel (R1): arahkan Rion mengerjakan misi secara berurutan.
	if has_node("StoryPointing2") and has_node("Rallux") and not GameManager.unpacking_completed:
		if not GameManager.unpacking_rak1_done:
			GameManager.set_objective("Kumpulkan perkakas berserakan dan rapikan Rak 1", 0, "")
		elif not _workshop_tasks_done():
			GameManager.set_objective("Tarik Tuas Crusher & Tuas Ona Program, lalu nyalakan Terminal", 0, "")
		else:
			GameManager.set_objective("Rapikan Rak 2 (angkut semua barang ke slot yang benar)", 0, "")

func _workshop_tasks_done() -> bool:
	return GameManager.terminal_puzzle_done \
		and GameManager.solved_levers.get("CrusherRoom_Lever", false) \
		and GameManager.solved_levers.get("OnaProgramRoom_Lever", false)

var _fade_layer: CanvasLayer = null
var _fade_color_rect: ColorRect = null

func _get_or_create_fade_rect() -> ColorRect:
	if _fade_color_rect and is_instance_valid(_fade_color_rect):
		return _fade_color_rect
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 120
	add_child(_fade_layer)
	_fade_color_rect = ColorRect.new()
	_fade_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_color_rect.color = Color.BLACK
	_fade_color_rect.modulate.a = 0.0
	_fade_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_color_rect)
	return _fade_color_rect

func _fade_screen_out(duration: float = 0.5) -> void:
	var rect = _get_or_create_fade_rect()
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween()
	tween.tween_property(rect, "modulate:a", 1.0, duration)
	await tween.finished

func _fade_screen_in(duration: float = 0.5) -> void:
	var rect = _get_or_create_fade_rect()
	var tween = create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, duration)
	await tween.finished
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Redup lalu terang kembali TANPA menghentikan aksi (dipakai saat karakter sedang berjalan).
## Tidak di-await oleh pemanggil supaya jalan & fade berlangsung bersamaan.
func _fade_walk_transition(fade_out_time: float = 0.45, fade_in_time: float = 0.55, hold: float = 0.1, peak_alpha: float = 0.85) -> void:
	var rect = _get_or_create_fade_rect()
	# Biarkan input tetap lewat: ini hanya efek visual, bukan pemblokir
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween = create_tween()
	tween.tween_property(rect, "modulate:a", peak_alpha, fade_out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if hold > 0.0:
		tween.tween_interval(hold)
	tween.tween_property(rect, "modulate:a", 0.0, fade_in_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Memutar node/mesh secara halus ke sudut target Y dengan lerp_angle
func _smooth_rotate_y(node: Node3D, target_angle: float, duration: float = 0.35) -> void:
	if not is_instance_valid(node):
		return
	var start_angle = node.rotation.y
	var diff = abs(wrapf(target_angle - start_angle, -PI, PI))
	if diff < 0.02:
		node.rotation.y = target_angle
		return
	var adj_duration = clampf(duration * (diff / PI), 0.15, duration)
	var tween = create_tween()
	tween.tween_method(func(t: float):
		if is_instance_valid(node):
			node.rotation.y = lerp_angle(start_angle, target_angle, t)
	, 0.0, 1.0, adj_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if is_instance_valid(node):
		node.rotation.y = target_angle

func _walk_character(char: CharacterBody3D, target_pos: Vector3, speed: float = 6.0) -> void:
	var start_pos = char.global_position
	var diff = target_pos - start_pos
	diff.y = 0.0
	var dist = diff.length()
	if dist < 0.1:
		return
	var duration = max(dist / speed, 0.4)
	var move_dir = diff.normalized()

	var is_player = char.is_in_group("player") or char.name == "Player"
	var rion_mesh = char.get_node_or_null("RionMesh")
	var anim_tree: AnimationTree = char.get_node_or_null("AnimationTree")

	# Putar badan secara halus sebelum atau saat mulai melangkah
	if is_player:
		char.rotation = Vector3.ZERO
		if rion_mesh and move_dir.length() > 0.01:
			var target_rot = atan2(move_dir.x, move_dir.z)
			await _smooth_rotate_y(rion_mesh, target_rot, 0.25)
		if anim_tree:
			anim_tree.set("parameters/StateMachine/Move/blend_position", 0.5)
	else:
		if move_dir.length() > 0.01:
			var target_rot = atan2(-move_dir.x, -move_dir.z)
			await _smooth_rotate_y(char, target_rot, 0.25)
		if char.has_method("play_animation"):
			char.play_animation("walk")

	var tween = create_tween()
	tween.tween_property(char, "global_position", target_pos, duration)
	await tween.finished

	if is_player:
		if anim_tree:
			anim_tree.set("parameters/StateMachine/Move/blend_position", 0.0)
	else:
		if char.has_method("play_animation"):
			char.play_animation("idle")

func _walk_pair(ona_char: CharacterBody3D, ona_target: Vector3, player_char: CharacterBody3D, player_target: Vector3, speed: float = 6.0, cam_offset: Vector3 = Vector3.ZERO) -> void:
	var ona_diff = ona_target - ona_char.global_position
	ona_diff.y = 0.0
	var dist = ona_diff.length()
	var duration = max(dist / speed, 0.5)
	var ona_dir = ona_diff.normalized()

	var rion_mesh = player_char.get_node_or_null("RionMesh")
	var anim_tree: AnimationTree = player_char.get_node_or_null("AnimationTree")

	# Putar Ona dan Rion secara halus bersamaan sebelum melangkah maju
	var rot_tween = create_tween().set_parallel(true)
	if ona_dir.length() > 0.01:
		var ona_target_rot = atan2(-ona_dir.x, -ona_dir.z)
		var ona_start_rot = ona_char.rotation.y
		rot_tween.tween_method(func(t: float):
			if is_instance_valid(ona_char):
				ona_char.rotation.y = lerp_angle(ona_start_rot, ona_target_rot, t)
		, 0.0, 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var p_diff = player_target - player_char.global_position
	p_diff.y = 0.0
	var p_dir = p_diff.normalized()
	player_char.rotation = Vector3.ZERO
	if rion_mesh and p_dir.length() > 0.01:
		var p_target_rot = atan2(p_dir.x, p_dir.z)
		var p_start_rot = rion_mesh.rotation.y
		rot_tween.tween_method(func(t: float):
			if is_instance_valid(rion_mesh):
				rion_mesh.rotation.y = lerp_angle(p_start_rot, p_target_rot, t)
		, 0.0, 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await rot_tween.finished

	# Mulai animasi jalan
	if ona_char.has_method("play_animation"):
		ona_char.play_animation("walk")
	if anim_tree:
		anim_tree.set("parameters/StateMachine/Move/blend_position", 0.5)

	var camera_rig = find_child("CameraRig", true, false)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(ona_char, "global_position", ona_target, duration)
	tween.tween_property(player_char, "global_position", player_target, duration)
	if camera_rig and cam_offset != Vector3.ZERO:
		tween.tween_property(camera_rig, "global_position", ona_target + cam_offset, duration)

	await tween.finished

	if ona_char.has_method("play_animation"):
		ona_char.play_animation("idle")
	if anim_tree:
		anim_tree.set("parameters/StateMachine/Move/blend_position", 0.0)

func _play_rocket_intro() -> void:
	var rocket_cam: Camera3D = get_node_or_null("RocketCamera")
	var anim_player: AnimationPlayer = get_node_or_null("RionCapsule/AnimationPlayer")
	var player = find_child("Player", true, false)
	var camera_rig = find_child("CameraRig", true, false)
	var hud = find_child("HUD", true, false)
	var ona = find_child("Ona", true, false)
	
	# Cari kamera player di dalam CameraRig secara otomatis
	var player_cam: Camera3D = null
	if camera_rig:
		player_cam = camera_rig.find_child("*Camera*", true, false) as Camera3D

	# 1. Nonaktifkan kontrol player, sembunyikan Rion sampai Ona selesai ke Point 5
	if player:
		player.visible = false
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
		var col = player.find_child("CollisionShape3D", true, false)
		if col:
			col.set_deferred("disabled", true)

	if camera_rig:
		camera_rig.set_physics_process(false)
		camera_rig.set_process(false)
		camera_rig.set_process_unhandled_input(false)

	if hud:
		if hud.has_method("set_gameplay_ui_visible"):
			hud.set_gameplay_ui_visible(false)
		else:
			hud.visible = false

	# 2. Pindah ke kamera sinematik roket
	if rocket_cam:
		rocket_cam.make_current()

	# 3. Putar animasi roket Kehancuran
	if anim_player:
		anim_player.play("Kehancuran")

	# 4. Saat roket mendarat (5 detik), arahkan kamera ke Ona yang mulai berjalan
	await get_tree().create_timer(5.0).timeout
	var capsule = find_child("RionCapsule", true, false)
	if capsule:
		capsule.visible = true
		capsule.global_position = Vector3(106.118, -0.096, 25.87)
		capsule.rotation = Vector3(0, 0, deg_to_rad(9.5))
		var smoke = capsule.find_child("Smoke", true, false)
		if smoke:
			smoke.visible = true
	for fire_name in ["Fire1", "Fire2", "Fire3"]:
		var fire_node = find_child(fire_name, true, false)
		if fire_node:
			fire_node.visible = true

	if rocket_cam and is_instance_valid(ona):
		if rocket_cam.has_method("track_target"):
			rocket_cam.track_target(ona)
		else:
			rocket_cam.target_node = ona

	# 5. Tunggu sampai Ona selesai sampai di Point 5
	if ona and ona.has_signal("point_5_finished"):
		await ona.point_5_finished

	# 6. Pastikan Rion muncul (unhidden) dan kontrol pemain pulih
	if player:
		player.visible = true
		player.set_physics_process(true)
		player.set_process_unhandled_input(true)
		var col = player.find_child("CollisionShape3D", true, false)
		if col:
			col.set_deferred("disabled", false)

	if camera_rig:
		camera_rig.set_physics_process(true)
		camera_rig.set_process(true)
		camera_rig.set_process_unhandled_input(true)
	if player_cam:
		player_cam.make_current()
	if camera_rig and camera_rig.has_method("snap_to_target"):
		camera_rig.snap_to_target()
	if hud:
		if hud.has_method("set_gameplay_ui_visible"):
			hud.set_gameplay_ui_visible(true)
		else:
			hud.visible = true

func _play_workshop_intro() -> void:
	var player: CharacterBody3D = find_child("Player", true, false) as CharacterBody3D
	var camera_rig = find_child("CameraRig", true, false)
	var hud = find_child("HUD", true, false)
	var ona: CharacterBody3D = find_child("Ona", true, false) as CharacterBody3D
	var rallux: Node3D = find_child("Rallux", true, false) as Node3D
	var storypoints: Node3D = get_node_or_null("StoryPointing2")

	if storypoints == null or ona == null or rallux == null or player == null:
		return

	var p1: Marker3D = storypoints.get_node_or_null("Point1") as Marker3D
	var p2: Marker3D = storypoints.get_node_or_null("Point2") as Marker3D
	var p3: Marker3D = storypoints.get_node_or_null("Point3") as Marker3D
	var p4: Marker3D = storypoints.get_node_or_null("Point4") as Marker3D
	var p5: Marker3D = storypoints.get_node_or_null("Point5") as Marker3D

	if p1 == null or p2 == null or p3 == null or p4 == null:
		return

	var rallux_anim: AnimationPlayer = rallux.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var rion_mesh = player.get_node_or_null("RionMesh")

	# 1. Nonaktifkan kontrol gameplay & UI
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	if camera_rig:
		camera_rig.set_physics_process(false)
		camera_rig.set_process(false)
		camera_rig.set_process_unhandled_input(false)
	if hud:
		if hud.has_method("set_gameplay_ui_visible"):
			hud.set_gameplay_ui_visible(false)
		else:
			hud.visible = false

	# 2. Setup Posisi Awal di pintu masuk (Point 4)
	# Ona dan Rion masuk dari pintu bengkel
	ona.global_position = p4.global_position + Vector3(2.0, 0, 0)
	player.global_position = p4.global_position + Vector3(0.5, 0, -1.2)
	player.rotation = Vector3.ZERO
	if rion_mesh:
		rion_mesh.rotation = Vector3.ZERO

	# Rallux berada di posisi awal yang telah diatur (23.843, 0, 30.673) rotasi (0, -137.3, 0) di balik meja kerja
	var rallux_start_pos := Vector3(23.843, 0.0, 30.673)
	var rallux_start_rot := Vector3(0.0, deg_to_rad(-137.3), 0.0)
	rallux.global_position = rallux_start_pos
	rallux.rotation = rallux_start_rot
	_play_rallux_anim(rallux, "searching")

	# Setup Kamera di belakang-kiri Ona saat baru masuk - tetap di dalam ruangan (bukan menembus dinding selatan)
	var entrance_cam_offset := Vector3(-6.0, 5.0, 2.5)
	if camera_rig:
		camera_rig.global_position = ona.global_position + entrance_cam_offset
		camera_rig.look_at(ona.global_position + Vector3(0.0, 1.4, 3.0), Vector3.UP)
		var cam = camera_rig.find_child("*Camera*", true, false) as Camera3D
		if cam:
			cam.make_current()

	await get_tree().create_timer(0.5).timeout

	# =========================================================================
	# 2. ONA & RION BERJALAN DARI PINTU (P4) KE POINT 1 → DIALOG → LANJUT KE POINT 2
	# =========================================================================
	# Langkah 1: Jalan dari P4 ke Point 1
	var p1_ona_target: Vector3 = p1.global_position
	var p1_player_target: Vector3 = p1.global_position + Vector3(-1.0, 0, 1.0)
	var cam_p1: Vector3 = p1.global_position + Vector3(-6.0, 5.0, 3.0)
	await _walk_pair(ona, p1_ona_target, player, p1_player_target, 6.5, cam_p1 - p1_ona_target)

	# Pastikan di Point 1 menghadap lurus ke lorong (+X / menuju Point 2), tidak serong
	var straight_dir_p1 := Vector3(1.0, 0.0, 0.0)
	var target_rot_ona_p1 := atan2(-straight_dir_p1.x, -straight_dir_p1.z)
	var target_rot_rion_p1 := atan2(straight_dir_p1.x, straight_dir_p1.z)
	var rot_p1 = create_tween().set_parallel(true)
	var ona_s_p1 = ona.rotation.y
	rot_p1.tween_method(func(t: float):
		if is_instance_valid(ona):
			ona.rotation.y = lerp_angle(ona_s_p1, target_rot_ona_p1, t)
	, 0.0, 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if rion_mesh:
		var rion_s_p1 = rion_mesh.rotation.y
		rot_p1.tween_method(func(t: float):
			if is_instance_valid(rion_mesh):
				rion_mesh.rotation.y = lerp_angle(rion_s_p1, target_rot_rion_p1, t)
		, 0.0, 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await rot_p1.finished

	if camera_rig:
		camera_rig.look_at(ona.global_position + Vector3(0, 1.4, 0), Vector3.UP)

	# Dialog di Point 1: Rion bingung mencari Rallux
	var point1_dialog: Array[String] = [
		"Rion: \"Ona... tempatnya luas banget... Tapi... mana Tuan Rallux-nya?\"",
		"Ona: \"Tuan Rallux pasti sedang bekerja di meja kerjanya di sudut ruangan. Ayo kita hampiri, Rion.\""
	]
	StoryManager.start_dialogue(point1_dialog, "Rion")
	await StoryManager.dialogue_finished

	await get_tree().create_timer(0.3).timeout

	# Langkah 2: Lanjut BERJALAN ke Point 2.
	# Fade dijalankan SELAGI mereka berjalan (tanpa teleport) agar cutscene tidak kaku.
	var p2_ona_target: Vector3 = p2.global_position + Vector3(0.0, 0.0, -0.6)
	var p2_player_target: Vector3 = p2.global_position + Vector3(-1.2, 0, 1.0)
	var cam_p2: Vector3 = p2.global_position + Vector3(-7.5, 5.2, 4.0)

	# Redup sebentar lalu terang kembali sambil kaki tetap berjalan
	_fade_walk_transition(0.45, 0.55)
	await _walk_pair(ona, p2_ona_target, player, p2_player_target, 7.5, cam_p2 - p2_ona_target)

	# Di Point 2: Menghadap lurus ke depan (+X)
	var straight_dir_p2 := Vector3(1.0, 0.0, 0.0)
	await _smooth_rotate_y(ona, atan2(-straight_dir_p2.x, -straight_dir_p2.z), 0.3)
	if rion_mesh:
		rion_mesh.rotation.y = atan2(straight_dir_p2.x, straight_dir_p2.z)

	if ona.has_method("play_animation"):
		ona.play_animation("idle")
	var anim_tree: AnimationTree = player.get_node_or_null("AnimationTree")
	if anim_tree:
		anim_tree.set("parameters/StateMachine/Move/blend_position", 0.0)

	if camera_rig:
		camera_rig.look_at(ona.global_position + Vector3(0, 1.4, 0), Vector3.UP)

	await get_tree().create_timer(0.3).timeout

	# Di Point 2 terdengar suara TANG! KLATAK! dari meja kerja Rallux
	var point2_dialog: Array[String] = [
		"TANG! KLATAK!",
	]
	StoryManager.start_dialogue(point2_dialog, "Rion")
	await StoryManager.dialogue_finished

	await get_tree().create_timer(0.4).timeout

	# =========================================================================
	# 3. SHOOT RALLUX DI MEJA KERJA SAAT MENGGERUTU, LALU FADE MENUJU POINT 2 & 3
	# =========================================================================
	# Sorot Rallux dari arah depannya saat mencari baut di meja kerja
	if camera_rig:
		var rallux_cam_pos = rallux.global_position + Vector3(-7.0, 4.5, -7.2)
		camera_rig.global_position = rallux_cam_pos
		camera_rig.look_at(rallux.global_position + Vector3(0, 2.0, 0), Vector3.UP)

	_play_rallux_anim(rallux, "searching")

	# Rallux menggerutu sambil mencari baut di meja kerja (kamera menyorot Rallux)
	var p2_dialog: Array[String] = [
		"Rallux: \"Aduh! Baut gravitasi yang nakal... lari ke mana lagi kamu? Jangan pura-pura jadi hiasan lantai, aku tahu kamu sembunyi di dekat situ!\"",
		"Rallux: \"Fiuh... baut kecil itu lincah sekali kalau menggelinding.\""
	]
	StoryManager.start_dialogue(p2_dialog, "Rallux")
	await StoryManager.dialogue_finished

	# Setelah dialog Rallux selesai: Fade out
	await _fade_screen_out(0.4)

	# Posisikan Rallux di Point 3 menghadap ke arah Ona & Rion di Point 2
	rallux.global_position = p3.global_position
	var dir_rallux_to_ona = (ona.global_position - rallux.global_position).normalized()
	dir_rallux_to_ona.y = 0.0
	if dir_rallux_to_ona.length() > 0.01:
		rallux.rotation.y = atan2(dir_rallux_to_ona.x, dir_rallux_to_ona.z)
	if rallux.has_method("play_animation"):
		rallux.play_animation("idle")
	elif rallux_anim:
		rallux_anim.play("idle")

	# Kamera kembali siap di Point 2 menyorot Ona dan Rion
	if camera_rig:
		camera_rig.global_position = cam_p2
		camera_rig.look_at(ona.global_position + Vector3(0, 1.4, 0), Vector3.UP)

	await get_tree().create_timer(0.2).timeout
	# Fade in: layar kembali terang dengan kamera menyorot Ona & Rion dan Rallux sudah tiba di Point 3
	await _fade_screen_in(0.4)

	# Dialog sambutan Rallux bagian pertama
	var p3_dialog_1: Array[String] = [
		"Rallux: \"Eh? Ona! Kamu sudah kembali dari jalan-jalan di hutan?\"",
		"Rallux: \"Oho! Dan siapa teman baru di sampingmu ini?\"",
		"_(Rion langsung menarik jubah Ona lebih erat, menyembunyikan wajahnya karena masih ragu dan malu pada orang asing)_"
	]
	StoryManager.start_dialogue(p3_dialog_1, "Rallux")
	await StoryManager.dialogue_finished

	# Kamera berpindah menyorot Ona & Rion dari jarak lebih jauh
	if camera_rig:
		camera_rig.global_position = ona.global_position + Vector3(-5.5, 3.2, 6.5)
		camera_rig.look_at(ona.global_position + Vector3(0, 1.2, 0), Vector3.UP)

	# Rion bergerak secara alami ke belakang Ona, tetapi tetap menghadap ke arah Rallux
	var dir_to_rallux = (rallux.global_position - ona.global_position).normalized()
	dir_to_rallux.y = 0.0
	var rion_hide_pos = ona.global_position - dir_to_rallux * 1.5 + Vector3(-0.6, 0, 0)
	await _walk_character(player, rion_hide_pos, 3.5)

	var dir_rion_to_rallux = (rallux.global_position - player.global_position).normalized()
	dir_rion_to_rallux.y = 0.0
	if rion_mesh and dir_rion_to_rallux.length() > 0.01:
		var target_rion_rallux = atan2(dir_rion_to_rallux.x, dir_rion_to_rallux.z)
		await _smooth_rotate_y(rion_mesh, target_rion_rallux, 0.3)
	if ona.has_method("play_animation"):
		ona.play_animation("bashful")

	# Dialog perkenalan Ona & sambutan hangat Rallux
	var p3_dialog_2: Array[String] = [
		"Ona: \"Selamat sore, Tuan Rallux. Kenalkan, ini adalah teman baru kita. Namanya Rion. Dia masih agak malu dan berhati-hati saat bertemu dengan orang baru.\"",
		"Rallux: \"Ah, wajar sekali! Kalau aku jadi Rion dan tiba-tiba melihat orang asing tak dikenal, aku juga pasti memilih sembunyi dulu di balik punggungmu, Ona.\"",
		"Rallux: \"Halo, Rion. Senang sekali bisa menyambutmu di sini. Anggap saja tempat ini seperti ruang bermainmu sendiri ya. Kamu bebas melihat-lihat, duduk di sana, atau sekadar menikmati wangi matcha di bengkel ini.\"",
		"_(Rallux memperhatikan tubuh Rion yang masih tampak kaku dan tegang)_",
		"Rallux: \"Ona, bagaimana kalau kamu ajak Rion jalan-jalan santai dulu di sekitar kebun luar? Supaya Rion bisa menghirup udara segar dan merasa lebih rileks dulu.\"",
		"Ona: \"Ide yang sangat bagus, Tuan Rallux. Udara sore di luar sangat sejuk dan menenangkan.\"",
		"Ona: \"Ayo, Rion... kita jalan-jalan santai di luar sebentar, mau?\"",
		"Rion: \"...\""
	]
	StoryManager.start_dialogue(p3_dialog_2, "Rallux")
	await StoryManager.dialogue_finished

	# =========================================================================
	# 4. ONA & RION INGIN KELUAR BENGKEL: JALAN MENUJU POINT 1 → FADE SAAT JALAN
	# =========================================================================
	# Nonaktifkan tabrakan antara Player dan Ona agar pergerakan mulus tanpa saling dorong
	player.set_collision_mask_value(2, false)
	player.set_collision_mask_value(3, false)
	ona.set_collision_mask_value(2, false)
	ona.set_collision_mask_value(3, false)

	# Posisikan kamera di belakang Ona & Rion menghadap ke arah Point 1
	var dir_to_p1 = (p1.global_position - ona.global_position).normalized()
	dir_to_p1.y = 0.0
	var to_p1_cam_offset = -dir_to_p1 * 7.0 + Vector3(0, 4.0, 0)
	if camera_rig:
		camera_rig.global_position = ona.global_position + to_p1_cam_offset
		camera_rig.look_at(ona.global_position + Vector3(0, 1.4, 0), Vector3.UP)

	# Putar hadap Ona dan Rion ke arah Point 1
	var rot_exit = create_tween().set_parallel(true)
	if dir_to_p1.length() > 0.01:
		var ona_target_rot = atan2(-dir_to_p1.x, -dir_to_p1.z)
		var ona_start_rot = ona.rotation.y
		rot_exit.tween_method(func(t: float):
			if is_instance_valid(ona):
				ona.rotation.y = lerp_angle(ona_start_rot, ona_target_rot, t)
		, 0.0, 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var side_vec_p1 = Vector3(-dir_to_p1.z, 0.0, dir_to_p1.x).normalized()
	var player_p1_exit_target = p1.global_position + side_vec_p1 * 1.8 - dir_to_p1 * 0.8
	var p_diff = player_p1_exit_target - player.global_position
	p_diff.y = 0.0
	var p_dir = p_diff.normalized()
	player.rotation = Vector3.ZERO
	if rion_mesh and p_dir.length() > 0.01:
		var p_target_rot = atan2(p_dir.x, p_dir.z)
		var p_start_rot = rion_mesh.rotation.y
		rot_exit.tween_method(func(t: float):
			if is_instance_valid(rion_mesh):
				rion_mesh.rotation.y = lerp_angle(p_start_rot, p_target_rot, t)
		, 0.0, 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await rot_exit.finished

	# Mulai berjalan menuju Point 1
	if ona.has_method("play_animation"):
		ona.play_animation("walk")
	var ona_anim_player = ona.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ona_anim_player and (ona_anim_player.current_animation != "walk" or not ona_anim_player.is_playing()):
		ona_anim_player.play("walk")
	var anim_tree_exit: AnimationTree = player.get_node_or_null("AnimationTree")
	if anim_tree_exit:
		anim_tree_exit.set("parameters/StateMachine/Move/blend_position", 0.5)

	var walk_exit_tween = create_tween().set_parallel(true)
	walk_exit_tween.tween_property(ona, "global_position", p1.global_position, 6.0)
	walk_exit_tween.tween_property(player, "global_position", player_p1_exit_target, 6.0)
	if camera_rig:
		walk_exit_tween.tween_property(camera_rig, "global_position", p1.global_position + to_p1_cam_offset, 6.0)

	# Biarkan mereka melangkah sejenak (1.2 detik) sehingga terlihat jelas mereka sedang berjalan keluar menuju Point 1
	await get_tree().create_timer(1.2).timeout

	# Kunci pintu bengkel dan tandai telah mengunjungi bengkel
	GameManager.has_visited_workshop = true
	GameManager.workshop_door_locked = true

	# Set posisi spawn Rion di depan Bengkel di LEV1 berdampingan dengan Ona
	GameManager.set_spawn_override(Vector3(-145.8, 0.0, -2.5), "LEV1")

	# Saat sedang berjalan menuju Point 1, transisi fade keluar bengkel menuju LEV1
	if has_node("/root/LoadingScreen"):
		LoadingScreen.load_scene("res://LEV1.tscn")
	else:
		await _fade_screen_out(0.6)
		get_tree().change_scene_to_file("res://LEV1.tscn")

## Kilas balik monokrom di LEV1, tepat di depan kapsul Rion yang jatuh.
## Dipanggil saat transisi tidur sebelum berpindah ke bengkel R1 (pagi berikutnya).
func _play_lev1_flashback() -> void:
	var camera_rig = find_child("CameraRig", true, false)
	var player: CharacterBody3D = find_child("Player", true, false) as CharacterBody3D
	var capsule: Node3D = find_child("RionCapsule", true, false) as Node3D
	var hud = find_child("HUD", true, false)

	if hud and hud.has_method("set_gameplay_ui_visible"):
		hud.set_gameplay_ui_visible(false)
	if player:
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
		player.velocity = Vector3.ZERO
	if camera_rig:
		camera_rig.set_physics_process(false)
		camera_rig.set_process(false)
		camera_rig.set_process_unhandled_input(false)
	if capsule:
		capsule.visible = true

	var cap_pos: Vector3 = capsule.global_position if capsule else Vector3(106.118, 0.0, 25.87)
	cap_pos.y = 0.0

	# Rallux sementara berdiri di depan kapsul untuk kilas balik.
	# Kalau ada Marker3D bernama "FlashbackRalluxPoint" di LEV1, posisinya dipakai.
	var rallux_point: Node3D = find_child("FlashbackRalluxPoint", true, false) as Node3D
	var rallux_scene := load("res://assets/Rallux/rallux.tscn") as PackedScene
	var rally: Node3D = null
	if rallux_scene:
		rally = rallux_scene.instantiate() as Node3D
		add_child(rally)
		rally.global_position = rallux_point.global_position if rallux_point else (cap_pos + Vector3(2.4, 0.0, 2.8))
		var d_r: Vector3 = cap_pos - rally.global_position
		d_r.y = 0.0
		if d_r.length_squared() > 0.01:
			rally.rotation.y = atan2(d_r.x, d_r.z)
		if rally.has_method("play_animation"):
			rally.play_animation("idle")

	var cam: Camera3D = null
	if camera_rig:
		cam = camera_rig.find_child("*Camera*", true, false) as Camera3D
		if cam:
			cam.make_current()
		camera_rig.global_position = cap_pos + Vector3(5.0, 3.2, 7.5)
		camera_rig.look_at(cap_pos + Vector3(0.0, 1.4, 0.0), Vector3.UP)

	var fade_rect = _get_or_create_fade_rect()
	fade_rect.modulate.a = 1.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	_set_monochrome(true)
	_set_flashback_particles(true)
	await _fade_screen_in(0.8)
	var flashback: Array[String] = [
		"Rallux: \"Kapsul penyelamat model gravitasi orbit... Sistem pelindungnya hampir habis terkikis gesekan atmosfer.\"",
		"Rallux: \"Data navigasi terhapus... rekaman memori nol byte. Anak sekecil itu menahan guncangan sebesar ini sendirian di ruang hampa.\"",
		"Rallux: \"Kamu sudah bertahan luar biasa, kapsul kecil. Ayo, kita bawa rumah besimu ini ke tempat yang aman.\""
	]
	StoryManager.start_dialogue(flashback, "Rallux")
	await StoryManager.dialogue_finished
	await _fade_screen_out(0.6)
	_set_flashback_particles(false)
	_set_monochrome(false)
	if is_instance_valid(rally):
		rally.queue_free()

## Cutscene pagi di bengkel R1 (setelah fade "KEESOKAN HARINYA"):
## masa kini di depan barier kapsul, Rion bangun & melangkah ke Point5,
## Rallux pamit keluar, lalu gameplay misi beres-beres dimulai.
func _play_r1_morning_intro() -> void:
	var player: CharacterBody3D = find_child("Player", true, false) as CharacterBody3D
	var camera_rig = find_child("CameraRig", true, false)
	var hud = find_child("HUD", true, false)
	var ona: CharacterBody3D = find_child("Ona", true, false) as CharacterBody3D
	var rallux: Node3D = find_child("Rallux", true, false) as Node3D
	var capsule: Node3D = find_child("RionCapsule", true, false) as Node3D
	var rion_mesh = player.get_node_or_null("RionMesh") if player else null
	var p_anim: AnimationTree = player.get_node_or_null("AnimationTree") if player else null

	# 1. Kunci kontrol gameplay & UI
	if player:
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
		player.velocity = Vector3.ZERO
	if camera_rig:
		camera_rig.set_physics_process(false)
		camera_rig.set_process(false)
		camera_rig.set_process_unhandled_input(false)
	if hud:
		if hud.has_method("set_gameplay_ui_visible"):
			hud.set_gameplay_ui_visible(false)
		else:
			hud.visible = false

	if capsule:
		capsule.visible = true

	# Posisi barier kapsul Rion di R1 (adegan masa kini)
	var barrier: Node3D = capsule.find_child("CapsuleBarier", true, false) as Node3D if capsule else null
	var cap_pos: Vector3 = Vector3(-4.0, 0.0, -39.0)
	if barrier:
		cap_pos = barrier.global_position
	elif capsule:
		cap_pos = capsule.global_position
	cap_pos.y = 0.0

	# Rion menunggu (akan fade in) di Point5
	var storypoints := get_node_or_null("StoryPointing2")
	var p5: Marker3D = storypoints.get_node_or_null("Point5") as Marker3D if storypoints else null
	var rion_target: Vector3 = p5.global_position if p5 else Vector3(38.508793, 0.0, 0.0)

	# 2. Blocking: Ona & Rallux berdampingan di depan barier kapsul
	var ona_pos: Vector3 = cap_pos + Vector3(-2.6, 0.0, 2.8)
	var rallux_pos: Vector3 = cap_pos + Vector3(2.4, 0.0, 2.4)

	if ona:
		ona.global_position = ona_pos
		ona.velocity = Vector3.ZERO
		if ona.has_method("play_animation"):
			ona.play_animation("idle")
	if rallux:
		rallux.global_position = rallux_pos
		if rallux.has_method("play_animation"):
			rallux.play_animation("idle")
	if player:
		player.global_position = rion_target
		player.rotation = Vector3.ZERO
	if rion_mesh:
		rion_mesh.rotation = Vector3.ZERO

	var cam: Camera3D = null
	if camera_rig:
		cam = camera_rig.find_child("*Camera*", true, false) as Camera3D
		if cam:
			cam.make_current()

	# Hadapkan Ona & Rallux ke kapsul
	if ona:
		var d_ona: Vector3 = cap_pos - ona.global_position
		d_ona.y = 0.0
		if d_ona.length_squared() > 0.01:
			ona.rotation.y = atan2(-d_ona.x, -d_ona.z)
	if rallux:
		var d_ral: Vector3 = cap_pos - rallux.global_position
		d_ral.y = 0.0
		if d_ral.length_squared() > 0.01:
			rallux.rotation.y = atan2(d_ral.x, d_ral.z)

	# 3. KEMBALI KE MASA KINI: Ona & Rallux di depan barier kapsul
	if camera_rig:
		camera_rig.global_position = cap_pos + Vector3(0.0, 2.6, 9.0)
		camera_rig.look_at(cap_pos + Vector3(0.0, 1.2, 0.0), Vector3.UP)
	var fade_rect = _get_or_create_fade_rect()
	fade_rect.modulate.a = 1.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_screen_in(0.6)
	var present_1: Array[String] = [
		"Ona: \"Jadi... rekaman log kapsulnya benar-benar tidak bisa dipulihkan sama sekali, Tuan Rallux?\"",
		"Rallux: \"Semua catatan riwayat di sistem kapsul hangus terbakar saat menembus orbit. Rion kehilangan seluruh ingatannya, Ona. Dia tidak tahu dari mana asalnya, siapa keluarganya, atau ke mana arah tujuannya.\"",
		"Ona: \"Pasti sangat membingungkan baginya... terbangun di tempat asing tanpa tahu siapa dirinya sebenarnya.\"",
		"Rallux: \"Benar. Tapi kemarin sore kamu sudah memberinya ruang yang aman. Saat rasa takutnya mereda, mesin pikirannya mulai bernapas lagi dengan tenang. Kita tidak perlu memaksanya mengingat semuanya sekaligus. Hari ini kita temani dia menata energinya lewat kegiatan-kegiatan sederhana di bengkel.\""
	]
	StoryManager.start_dialogue(present_1, "Ona")
	await StoryManager.dialogue_finished

	# 4. RION BANGUN DI POINT5: fade in + shoot dari depan badan
	await _fade_screen_out(0.5)
	var dir_to_capsule: Vector3 = cap_pos - rion_target
	dir_to_capsule.y = 0.0
	if dir_to_capsule.length_squared() > 0.0001:
		dir_to_capsule = dir_to_capsule.normalized()
	else:
		dir_to_capsule = Vector3(0.0, 0.0, -1.0)
	if player:
		player.global_position = rion_target
	if rion_mesh:
		rion_mesh.rotation.y = atan2(dir_to_capsule.x, dir_to_capsule.z)
	if camera_rig:
		camera_rig.global_position = rion_target + dir_to_capsule * 8.5 + Vector3(0.0, 2.7, 0.0)
		camera_rig.look_at(rion_target + Vector3(0.0, 1.25, 0.0), Vector3.UP)
	await _fade_screen_in(0.6)

	var rion_wake: Array[String] = [
		"Rion: \"Hoaaam... Ona...? Tuan Rallux...? Kalian di mana?\""
	]
	StoryManager.start_dialogue(rion_wake, "Rion")
	await StoryManager.dialogue_finished

	# 5. KAMERA PINDAH KE BELAKANG RION, MENGARAH KE KAPSUL RION
	if camera_rig:
		var perp: Vector3 = Vector3(-dir_to_capsule.z, 0.0, dir_to_capsule.x)
		camera_rig.global_position = rion_target - dir_to_capsule * 9.0 + perp * 1.0 + Vector3(0.0, 3.7, 0.0)
		camera_rig.look_at(cap_pos + Vector3(0.0, 1.35, 0.0), Vector3.UP)

	# Ona & Rallux serentak menghadap ke arah Rion
	if ona and player:
		var d1: Vector3 = player.global_position - ona.global_position
		d1.y = 0.0
		if d1.length_squared() > 0.01:
			ona.rotation.y = atan2(-d1.x, -d1.z)
	if rallux and player:
		var d2: Vector3 = player.global_position - rallux.global_position
		d2.y = 0.0
		if d2.length_squared() > 0.01:
			rallux.rotation.y = atan2(d2.x, d2.z)

	var greeting: Array[String] = [
		"Ona: \"Selamat pagi, Rion! Nyenyak tidurnya semalam?\"",
		"Rion: \"Selamat pagi! Tidurku nyenyak banget... Kasurnya empuk dan gak dingin sama sekali!\"",
		"Rion: \"Lho?! Itu kan... kapsul besi yang aku naiki kemarin! Kok bisa sudah ada di sini dan bersih banget?!\"",
		"Rallux: \"Haha! Semalam selagi kalian tidur, aku meminjam derek gravitasi sebentar untuk menjemputnya dari hutan jamur. Kapsul hebat ini terlalu berharga kalau dibiarkan di luar.\"",
		"Rion: \"Wah... terima kasih banyak ya, Tuan Rallux!\"",
		"Rallux: \"Sama-sama, Rion! Nah, karena cacing di perut kita pasti sudah mulai bernyanyi, aku mau meracik sarapan roti panggang madu dan teh matcha hangat dulu di dapur. Kalian tunggu sebentar ya!\""
	]
	StoryManager.start_dialogue(greeting, "Rion")
	await StoryManager.dialogue_finished

	# 6. Rallux berjalan keluar sendiri (kamera TIDAK mengikuti)
	if rallux:
		var route: Array[Vector3] = [rallux.global_position]
		if storypoints:
			for pname in ["Point3", "Point2", "Point1"]:
				var m: Node3D = storypoints.get_node_or_null(pname) as Node3D
				if m:
					route.append(m.global_position)
		var door_node: Node3D = find_child("quitdoor", true, false) as Node3D
		if door_node:
			route.append(door_node.global_position)
		_run_rallux_leave(rallux, route, 8.0)

	# Rion menghampiri Ona dengan menempati posisi awal Rallux
	if player and ona:
		await _walk_with_follow_camera(player, rallux_pos, camera_rig, 6.0)
		# Kamera kembali ke posisi yang sama seperti dialog Ona & Rallux
		if camera_rig:
			camera_rig.global_position = cap_pos + Vector3(0.0, 2.6, 9.0)
			camera_rig.look_at(cap_pos + Vector3(0.0, 1.2, 0.0), Vector3.UP)

	# 7. INISIATIF RION
	var initiative: Array[String] = [
		"Rion: \"Ona... mumpung Tuan Rallux lagi keluar sebentar, boleh gak kalau kita rapikan lantai bengkel ini?\"",
		"Ona: \"Kamu mau merapikannya, Rion?\"",
		"Rion: \"Iya! Tuan Rallux sudah baik banget merawat kapsulku dan ngasih tempat istirahat yang hangat. Aku mau kumpulkan baut-baut yang melayang ini dan susun alat-alatnya ke rak dinding. Jadi pas Tuan Rallux balik nanti, lantainya sudah bersih dan gak bikin tersandung lagi!\"",
		"Ona: \"Wah, inisiatif yang sangat hebat dan penuh perhatian, Rion! Tuan Rallux pasti akan sangat senang melihat bengkelnya tertata rapi. Aku akan bantu memproyeksikan panduan slot wadahnya untukmu.\""
	]
	StoryManager.start_dialogue(initiative, "Rion")
	await StoryManager.dialogue_finished

	# 8. Aktifkan gameplay misi beres-beres
	GameManager.r1_morning_intro_done = true
	GameManager.set_objective("Kumpulkan perkakas yang berserakan di lantai dan selaraskan ke rak penyimpanan", 0, "")
	if hud:
		if hud.has_method("set_gameplay_ui_visible"):
			hud.set_gameplay_ui_visible(true)
		else:
			hud.visible = true
	if player:
		player.set_physics_process(true)
		player.set_process_unhandled_input(true)
	if camera_rig:
		camera_rig.set_physics_process(true)
		camera_rig.set_process(true)
		camera_rig.set_process_unhandled_input(true)
		if camera_rig.has_method("snap_to_target"):
			camera_rig.snap_to_target()
	if cam:
		cam.make_current()

var _mono_we: WorldEnvironment = null
var _mono_prev_enabled: bool = false
var _mono_prev_sat: float = 1.0
var _flashback_layer: CanvasLayer = null

func _set_monochrome(on: bool) -> void:
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null or we.environment == null:
		return
	if on:
		_mono_we = we
		_mono_prev_enabled = we.environment.adjustment_enabled
		_mono_prev_sat = we.environment.adjustment_saturation
		we.environment.adjustment_enabled = true
		we.environment.adjustment_saturation = 0.0
	else:
		if _mono_we and _mono_we.environment:
			_mono_we.environment.adjustment_enabled = _mono_prev_enabled
			_mono_we.environment.adjustment_saturation = _mono_prev_sat

func _set_flashback_particles(on: bool) -> void:
	if not on:
		if _flashback_layer:
			_flashback_layer.visible = false
		return
	if _flashback_layer == null:
		_flashback_layer = CanvasLayer.new()
		_flashback_layer.name = "FlashbackLayer"
		_flashback_layer.layer = 0
		add_child(_flashback_layer)
		var p := GPUParticles2D.new()
		p.name = "FlashbackParticles"
		p.amount = 70
		p.lifetime = 6.0
		p.preprocess = 6.0
		p.emitting = true
		var grad := Gradient.new()
		grad.set_color(0, Color(1.0, 1.0, 1.0, 0.45))
		grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.width = 16
		tex.height = 16
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		p.texture = tex
		var mat := ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = Vector3(1100.0, 650.0, 0.0)
		mat.direction = Vector3(0.0, -1.0, 0.0)
		mat.spread = 180.0
		mat.initial_velocity_min = 3.0
		mat.initial_velocity_max = 10.0
		mat.gravity = Vector3.ZERO
		mat.scale_min = 0.4
		mat.scale_max = 1.3
		p.process_material = mat
		p.position = Vector2(960.0, 540.0)
		_flashback_layer.add_child(p)
	_flashback_layer.visible = true

## Paksa animasi Rallux (searching/idle/run) lewat state machine + pastikan loop.
func _play_rallux_anim(rallux: Node3D, anim_name: String) -> void:
	var at := rallux.get_node_or_null("AnimationTree") as AnimationTree
	if at == null:
		at = rallux.find_child("AnimationTree", true, false) as AnimationTree
	if at:
		at.active = true
		var pb = at.get("parameters/playback")
		if pb:
			pb.travel(anim_name)
	var ap := rallux.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap == null:
		ap = rallux.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		var a := ap.get_animation(anim_name)
		if a:
			a.loop_mode = Animation.LOOP_LINEAR
		if at == null and ap.current_animation != anim_name:
			ap.play(anim_name)

## Rallux berjalan keluar bengkel TANPA diiringi kamera. Animasi "run" dipaksa aktif.
func _run_rallux_leave(rallux: Node3D, route: Array, speed: float = 8.0) -> void:
	# State machine kadang tidak pindah, jadi paksa lewat AnimationPlayer langsung.
	var at := rallux.get_node_or_null("AnimationTree") as AnimationTree
	if at:
		at.active = false
	var ap := rallux.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap:
		var run_anim := ap.get_animation("run")
		if run_anim:
			run_anim.loop_mode = Animation.LOOP_LINEAR
		ap.play("run")

	var prev := Time.get_ticks_msec()
	for i in range(1, route.size()):
		var to: Vector3 = route[i]
		var dist2d: float = Vector2(to.x - rallux.global_position.x, to.z - rallux.global_position.z).length()
		var time_limit := Time.get_ticks_msec() + int((dist2d / speed) * 1000.0) + 2000
		while rallux.global_position.distance_to(to) > 0.3:
			if Time.get_ticks_msec() > time_limit:
				break
			var now := Time.get_ticks_msec()
			var dt := clampf((now - prev) / 1000.0, 0.0, 0.1)
			prev = now
			var dir: Vector3 = to - rallux.global_position
			dir.y = 0.0
			if dir.length_squared() > 0.01:
				rallux.rotation.y = lerp_angle(rallux.rotation.y, atan2(dir.x, dir.z), 12.0 * dt)
			rallux.global_position = rallux.global_position.move_toward(to, speed * dt)
			await get_tree().physics_frame
		prev = Time.get_ticks_msec()
	rallux.global_position = route[route.size() - 1]

	# Kembalikan state machine ke idle sebelum disembunyikan
	if ap:
		ap.stop()
	if at:
		at.active = true
		var playback = at.get("parameters/playback")
		if playback:
			playback.start("idle")
	rallux.visible = false

## Rion berjalan ke target dengan kamera mengikuti dari belakang badannya.
func _walk_with_follow_camera(char: CharacterBody3D, target: Vector3, camera_rig: Node3D, speed: float = 6.0) -> void:
	var mesh := char.get_node_or_null("RionMesh")
	var anim := char.get_node_or_null("AnimationTree") as AnimationTree
	if anim:
		anim.set("parameters/StateMachine/Move/blend_position", 0.5)

	var start: Vector3 = char.global_position
	var walk_dir: Vector3 = target - start
	walk_dir.y = 0.0
	if walk_dir.length_squared() > 0.0001:
		walk_dir = walk_dir.normalized()
	else:
		walk_dir = Vector3(0.0, 0.0, -1.0)
	# Offset tetap (tidak berubah mengikuti rotasi) supaya kamera tidak getar
	var cam_offset: Vector3 = -walk_dir * 9.0 + Vector3(0.0, 2.8, 0.0)
	if camera_rig:
		camera_rig.global_position = char.global_position + cam_offset
		camera_rig.look_at(char.global_position + Vector3(0.0, 1.3, 0.0), Vector3.UP)

	var prev := Time.get_ticks_msec()
	while char.global_position.distance_to(target) > 0.3:
		var now := Time.get_ticks_msec()
		var dt := clampf((now - prev) / 1000.0, 0.0, 0.1)
		prev = now
		var dir: Vector3 = target - char.global_position
		dir.y = 0.0
		if dir.length_squared() > 0.0001:
			dir = dir.normalized()
			char.global_position = char.global_position.move_toward(target, speed * dt)
			if mesh:
				mesh.rotation.y = lerp_angle(mesh.rotation.y, atan2(dir.x, dir.z), 8.0 * dt)
			if camera_rig:
				var desired: Vector3 = char.global_position + cam_offset
				var a: float = 1.0 - exp(-10.0 * dt)
				camera_rig.global_position = camera_rig.global_position.lerp(desired, a)
				camera_rig.look_at(char.global_position + Vector3(0.0, 1.3, 0.0), Vector3.UP)
		await get_tree().physics_frame
	if anim:
		anim.set("parameters/StateMachine/Move/blend_position", 0.0)

## Rallux berlari menyusuri titik-titik rute dengan gerak tetap (move_toward per frame,
## bukan tween) sehingga dijamin sampai ke tujuan. Kamera mengikuti mulus setiap frame.
func _run_rallux_route(rallux: Node3D, route: Array, rallux_anim: AnimationPlayer, camera_rig: Node3D, speed: float = 9.0, end_idle: bool = true) -> void:
	if rallux.has_method("play_animation"):
		rallux.play_animation("run")
	elif rallux_anim:
		rallux_anim.play("run")

	var cam_offset: Vector3 = Vector3(-6.5, 4.2, 6.5)

	# Posisikan kamera dulu di belakang Rallux sebelum ia mulai berlari
	if camera_rig:
		var behind: Vector3 = rallux.global_position + cam_offset
		var cam_set: Tween = create_tween()
		cam_set.tween_property(camera_rig, "global_position", behind, 0.5)
		await cam_set.finished
		camera_rig.look_at(rallux.global_position + Vector3(0, 1.6, 0), Vector3.UP)

	var prev_time := Time.get_ticks_msec()

	for i in range(1, route.size()):
		var to: Vector3 = route[i]
		var dist2d: float = Vector2(
			to.x - rallux.global_position.x,
			to.z - rallux.global_position.z
		).length()
		var time_limit := Time.get_ticks_msec() + int((dist2d / speed) * 1000.0) + 1500

		while rallux.global_position.distance_to(to) > 0.2:
			if Time.get_ticks_msec() > time_limit:
				break
			var now := Time.get_ticks_msec()
			var dt := clampf((now - prev_time) / 1000.0, 0.0, 0.1)
			prev_time = now

			# Putar hadap Rallux secara mulus (lerp_angle) mengikuti arah gerak saat ini
			var dir: Vector3 = to - rallux.global_position
			dir.y = 0.0
			if dir.length() > 0.01:
				var target_rot = atan2(dir.x, dir.z)
				rallux.rotation.y = lerp_angle(rallux.rotation.y, target_rot, 12.0 * dt)

			var next_pos: Vector3 = rallux.global_position.move_toward(to, speed * dt)
			next_pos.y = to.y
			rallux.global_position = next_pos

			if camera_rig:
				var desired: Vector3 = rallux.global_position + cam_offset
				camera_rig.global_position = camera_rig.global_position.lerp(desired, 0.08)
				camera_rig.look_at(rallux.global_position + Vector3(0, 1.6, 0), Vector3.UP)
			await get_tree().physics_frame

		prev_time = Time.get_ticks_msec()

	rallux.global_position = route[route.size() - 1]
	if camera_rig:
		camera_rig.global_position = rallux.global_position + cam_offset
		camera_rig.look_at(rallux.global_position + Vector3(0, 1.6, 0), Vector3.UP)
	if end_idle:
		if rallux.has_method("play_animation"):
			rallux.play_animation("idle")
		elif rallux_anim:
			rallux_anim.play("idle")
