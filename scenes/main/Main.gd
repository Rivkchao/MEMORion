extends Node3D

func _ready() -> void:
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

	if is_player:
		char.rotation = Vector3.ZERO
		if rion_mesh and move_dir.length() > 0.01:
			rion_mesh.rotation.y = atan2(move_dir.x, move_dir.z)
		if anim_tree:
			anim_tree.set("parameters/StateMachine/Move/blend_position", 0.5)
	else:
		if move_dir.length() > 0.01:
			char.look_at(char.global_position + move_dir, Vector3.UP)
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

	if ona_dir.length() > 0.01:
		ona_char.look_at(ona_char.global_position + ona_dir, Vector3.UP)
	if ona_char.has_method("play_animation"):
		ona_char.play_animation("walk")

	var p_diff = player_target - player_char.global_position
	p_diff.y = 0.0
	var p_dir = p_diff.normalized()
	player_char.rotation = Vector3.ZERO
	if rion_mesh and p_dir.length() > 0.01:
		rion_mesh.rotation.y = atan2(p_dir.x, p_dir.z)
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

	# Rallux berada di Point 2 (balik meja kerja), memutar animasi searching
	rallux.global_position = p2.global_position
	if rallux_anim:
		rallux_anim.play("searching")

	# Setup Kamera di belakang Ona & Rion saat baru masuk
	if camera_rig:
		camera_rig.global_position = ona.global_position + Vector3(0.0, 2.5, -4.5)
		camera_rig.look_at(ona.global_position + Vector3(0.0, 1.4, 2.0), Vector3.UP)
		var cam = camera_rig.find_child("*Camera*", true, false) as Camera3D
		if cam:
			cam.make_current()

	await get_tree().create_timer(0.5).timeout

	# ==========================================
	# ONA & RION BERJALAN DARI PINTU KE POINT 1
	# ==========================================
	await _walk_pair(ona, p1.global_position, player, p1.global_position + Vector3(-1.0, 0, -1.0), 6.5, Vector3(0.0, 2.5, -4.5))

	# Di Point 1: Ona & Rion berbalik menatap ke arah dalam bengkel / Point 2
	var dir_to_p2 = (p2.global_position - p1.global_position).normalized()
	dir_to_p2.y = 0.0
	ona.look_at(ona.global_position + dir_to_p2, Vector3.UP)
	if rion_mesh:
		rion_mesh.rotation.y = atan2(dir_to_p2.x, dir_to_p2.z)

	if camera_rig:
		camera_rig.look_at(ona.global_position + Vector3(0, 1.4, 0), Vector3.UP)

	await get_tree().create_timer(0.4).timeout

	# ==========================================
	# POINT 1: DIALOG RION BERBISIK DI BALIK PUNGGUNG ONA
	# ==========================================
	var p1_dialog: Array[String] = [
		"Rion: \"Ona... tempatnya luas banget... Tapi... mana Tuan Rallux-nya?\""
	]
	StoryManager.start_dialogue(p1_dialog, "Rion")
	await StoryManager.dialogue_finished

	await get_tree().create_timer(0.4).timeout

	# ==========================================
	# POINT 2: KEJADIAN DARI BALIK MEJA KERJA
	# ==========================================
	# Sorot Rallux secara jelas di balik meja kerja
	if camera_rig:
		var rallux_cam_pos = p2.global_position + Vector3(-4.0, 2.8, 5.0)
		var cam_tween = create_tween()
		cam_tween.tween_property(camera_rig, "global_position", rallux_cam_pos, 1.2)
		await cam_tween.finished
		camera_rig.look_at(rallux.global_position + Vector3(0, 1.8, 0), Vector3.UP)

	if rallux_anim:
		rallux_anim.play("searching")

	var p2_dialog: Array[String] = [
		"_(Tiba-tiba, dari balik meja kerja besar di sudut ruangan, terdengar suara kencang:)",
		"TANG! KLATAK!",
		"*Suara dari Balik Meja*",
		"Rallux: \"Aduh! Baut gravitasi yang nakal... lari ke mana lagi kamu? Jangan pura-pura jadi hiasan lantai, aku tahu kamu sembunyi di dekat situ!\"",
		"Rallux: \"Fiuh... baut kecil itu lincah sekali kalau menggelinding.\""
	]
	StoryManager.start_dialogue(p2_dialog, "Rallux")
	await StoryManager.dialogue_finished

	# ==========================================
	# POINT 3: RALLUX LARI KE POINT 3
	# ==========================================
	# Rallux berbalik dan berlari ke Point 3
	var dir_to_p3 = (p3.global_position - rallux.global_position).normalized()
	dir_to_p3.y = 0.0
	rallux.look_at(rallux.global_position + dir_to_p3, Vector3.UP)
	if rallux_anim:
		rallux_anim.play("run")

	var run_duration = max(rallux.global_position.distance_to(p3.global_position) / 8.0, 1.5)
	var rallux_tween = create_tween().set_parallel(true)
	rallux_tween.tween_property(rallux, "global_position", p3.global_position, run_duration)
	if camera_rig:
		rallux_tween.tween_property(camera_rig, "global_position", p3.global_position + Vector3(-4.5, 2.5, 4.5), run_duration)
	await rallux_tween.finished

	# Rallux sampai di Point 3, tatap Ona & Rion, ganti animasi idle
	var dir_rallux_face = (ona.global_position - rallux.global_position).normalized()
	dir_rallux_face.y = 0.0
	rallux.look_at(rallux.global_position + dir_rallux_face, Vector3.UP)
	if rallux_anim:
		rallux_anim.play("idle")
	if camera_rig:
		camera_rig.look_at(rallux.global_position + Vector3(0, 1.8, 0), Vector3.UP)

	# Dialog sambutan Rallux bagian pertama
	var p3_dialog_1: Array[String] = [
		"Rallux: \"Eh? Ona! Kamu sudah kembali dari jalan-jalan di hutan?\"",
		"Rallux: \"Oho! Dan siapa teman baru di sampingmu ini?\"",
		"_(Rion langsung menarik jubah Ona lebih erat, menyembunyikan wajahnya karena masih ragu dan malu pada orang asing)_"
	]
	StoryManager.start_dialogue(p3_dialog_1, "Rallux")
	await StoryManager.dialogue_finished

	# Kamera berpindah menyorot Ona & Rion
	if camera_rig:
		camera_rig.global_position = ona.global_position + Vector3(-3.0, 2.0, 4.0)
		camera_rig.look_at(ona.global_position + Vector3(0, 1.2, 0), Vector3.UP)

	# Rion bergerak secara alami ke belakang Ona, tetapi tetap menghadap ke arah Rallux
	var rion_hide_pos = ona.global_position - dir_to_p2 * 1.5 + Vector3(-0.6, 0, 0)
	await _walk_character(player, rion_hide_pos, 3.5)

	var dir_rion_to_rallux = (rallux.global_position - player.global_position).normalized()
	dir_rion_to_rallux.y = 0.0
	if rion_mesh:
		rion_mesh.rotation.y = atan2(dir_rion_to_rallux.x, dir_rion_to_rallux.z)
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
		"Rion: \"...\"",
		"_(Rion masih terdiam dan tidak bicara, tapi perlahan ia mengangguk pelan lalu melangkah mengikuti Ona keluar)_"
	]
	StoryManager.start_dialogue(p3_dialog_2, "Rallux")
	await StoryManager.dialogue_finished

	# ==========================================
	# POINT 4: ONA & RION MELANGKAH KE PINTU KELUAR (POINT 4)
	# ==========================================
	var dir_to_p4 = (p4.global_position - ona.global_position).normalized()
	dir_to_p4.y = 0.0
	if camera_rig:
		camera_rig.global_position = ona.global_position - dir_to_p4 * 4.0 + Vector3(0, 3.0, 0)
		camera_rig.look_at(ona.global_position + Vector3(0, 1.4, 0), Vector3.UP)

	await _walk_pair(ona, p4.global_position, player, p4.global_position + Vector3(1.2, 0, 1.2), 6.0, -dir_to_p4 * 4.0 + Vector3(0, 3.0, 0))

	# Kunci pintu bengkel dan tandai telah mengunjungi bengkel
	GameManager.has_visited_workshop = true
	GameManager.workshop_door_locked = true

	# Set posisi spawn Rion di depan Bengkel di LEV1
	GameManager.set_spawn_override(Vector3(-147.0, 0.0, -0.86), "LEV1")

	# Pindah scene kembali ke LEV1
	if has_node("/root/LoadingScreen"):
		LoadingScreen.load_scene("res://LEV1.tscn")
	else:
		get_tree().change_scene_to_file("res://LEV1.tscn")
