extends CharacterBody3D

signal point_5_finished

@onready var navigation_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D")
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var animation_tree: AnimationTree = get_node_or_null("AnimationTree")
@onready var fade_rect: ColorRect = get_parent().get_node_or_null("FadeLayer/FadeRect")

@export var speed := 10.0
@export var waypoints: Array[Node3D]
var current_waypoint := 0
var is_moving := false
var is_dialogue := false
var is_following_player := false
var reflection_dialog: CanvasLayer = null
var _playback: AnimationNodeStateMachinePlayback = null
var _teleport_cooldown: float = 0.0
## Saat true, Ona digerakkan oleh tween cutscene: jangan override animasi/posisi dari _physics_process
var _cutscene_walking: bool = false

func _ready():
	add_to_group("ona")
	_setup_animation_tree()

	if fade_rect:
		fade_rect.modulate.a = 0.0
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Inisialisasi ReflectionDialog UI jika belum ada
	var existing_dialog = get_parent().find_child("ReflectionDialog", true, false)
	if existing_dialog:
		reflection_dialog = existing_dialog
	else:
		var dialog_scene = load("res://scenes/ui/ReflectionDialog.tscn")
		if dialog_scene:
			reflection_dialog = dialog_scene.instantiate()
			get_parent().add_child.call_deferred(reflection_dialog)

	# Jika Ona berada di dalam Bengkel (R1), serahkan kendali penuh cutscene ke Main.gd
	if get_parent().has_node("StoryPointing2") or (get_tree().current_scene and get_tree().current_scene.name == "R1"):
		is_moving = false
		is_dialogue = false
		is_following_player = false
		set_physics_process(false)
		return

	var storypoints = get_parent().get_node_or_null("Storypoints")
	if storypoints:
		for point in storypoints.get_children():
			if point is Node3D:
				waypoints.append(point)

	print("Jumlah waypoint Ona: ", waypoints.size())

	# Jika pemain baru saja kembali dari Bengkel (R1) dan pintu terkunci:
	var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	if gm and gm.get("workshop_door_locked"):
		is_moving = false
		is_following_player = false
		# Ona berdiri berdampingan dekat Rion (selisih 0.9 meter, tidak berjauhan & tidak menabrak bengkel)
		global_position = Vector3(-144.9, 0.0, -2.5)
		play_animation("idle")
		print("Ona menyambut Rion di kebun luar bengkel!")

		# Orientasikan Ona menghadap ke arah kebun (Point 10)
		var p10 = waypoints[9] if waypoints.size() > 9 else get_parent().find_child("Point10", true, false)
		if p10:
			var dir_init = (p10.global_position - global_position).normalized()
			dir_init.y = 0
			if dir_init.length_squared() > 0.01:
				rotation.y = atan2(-dir_init.x, -dir_init.z)

		if not gm.garden_intro_done:
			call_deferred("_start_scene_5_garden_sequence")
		else:
			is_following_player = true
		return

	await get_tree().create_timer(5.0).timeout
	go_to_next_waypoint()
	
func _physics_process(_delta):
	# Gravitasi agar Ona menapak tanah
	if not is_on_floor():
		velocity.y -= 18.0 * _delta
	else:
		velocity.y = 0.0

	# Penyelamatan darurat jika Ona tercebur ke dalam air sungai di sembarang waktu
	if global_position.y < -0.8 and global_position.x > -37.5 and global_position.x < -18.0:
		var player_node = get_parent().find_child("Player", true, false)
		var rescue_x = -17.8
		if player_node and player_node.global_position.x < -28.0:
			rescue_x = -39.0
		var rescue_z = player_node.global_position.z if player_node else global_position.z
		_execute_teleport(Vector3(rescue_x, 0.2, rescue_z), "Penyelamatan darurat dari air sungai")

	# ==========================================
	# ONA DIGERAKKAN TWEEN CUTSCENE (jangan sentuh posisi & animasinya)
	# ==========================================
	if _cutscene_walking:
		velocity = Vector3.ZERO
		return

	# ==========================================
	# ONA SEDANG DIALOG
	# ==========================================
	if is_dialogue:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		play_animation("idle")
		return

	# ==========================================
	# ONA MENGIKUTI RION DI SEKITAR POINT 9 / KEBUN
	# ==========================================
	if is_following_player:
		_process_follow_player(_delta)
		
		# Cek jika Rion kembali ke Point 9 (depan bengkel) setelah memetik bunga di kebun:
		if GameManager and GameManager.garden_intro_done and not GameManager.sleep_transition_done and not _is_evaluating_memory:
			_check_garden_return_to_point9()
		return

	# ==========================================
	# ONA TIDAK BERGERAK
	# ==========================================
	if not is_moving:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		play_animation("idle")
		return

	# ==========================================
	# SAMPAI DI WAYPOINT
	# ==========================================
	var reached = false
	if current_waypoint < waypoints.size() and waypoints[current_waypoint]:
		var target_point = waypoints[current_waypoint]
		var dist_h = Vector2(global_position.x - target_point.global_position.x, global_position.z - target_point.global_position.z).length()
		if dist_h <= 1.5 or navigation_agent.is_navigation_finished():
			reached = true
	elif navigation_agent.is_navigation_finished():
		reached = true

	if reached:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		play_animation("idle")
		is_moving = false
		await waypoint_reached()
		return

	# ==========================================
	# GERAK MENUJU WAYPOINT
	# ==========================================
	var next_position = navigation_agent.get_next_path_position()
	var direction = global_position.direction_to(next_position)
	direction.y = 0

	# Fallback jika path belum terhitung
	if direction.length() <= 0.01 and current_waypoint < waypoints.size() and waypoints[current_waypoint]:
		direction = global_position.direction_to(waypoints[current_waypoint].global_position)
		direction.y = 0

	if direction.length() > 0.01:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		_rotate_towards(direction, _delta)
		play_animation("run" if current_waypoint == 5 else "walk")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		play_animation("idle")

	move_and_slide()

func go_to_next_waypoint():

	if current_waypoint >= waypoints.size():
		is_moving = false
		play_animation("idle")
		print("Semua waypoint selesai!")
		return

	var target_point = waypoints[current_waypoint]

	navigation_agent.target_position = target_point.global_position

	is_moving = true

	print("Menuju Point ", current_waypoint + 1)

func waypoint_reached():
	print("Sampai Point ", current_waypoint + 1)

	# ==========================================
	# POINT 2 → DIALOG & TELEPORT KE POINT 3
	# ==========================================
	if current_waypoint == 1:
		await point_2_dialog()
		await teleport_to_point_3()
		current_waypoint += 1
		go_to_next_waypoint()
		return

	# ==========================================
	# POINT 5 → ONA SELESAI SAMPAI DI POINT 5
	# ==========================================
	if current_waypoint == 4:
		await point_5_reached()
		return

	# ==========================================
	# POINT 6 → DIALOG SUNGAI DERAS & RUTE
	# ==========================================
	if current_waypoint == 5:
		await point_6_reached()
		return

	# ==========================================
	# POINT 7 → DEPAN SUNGAI / KONSOL BATU
	# ==========================================
	if current_waypoint == 6:
		is_moving = false
		velocity = Vector3.ZERO
		play_animation("idle")
		print("Ona telah sampai di Point 7 (Depan Konsol Batu)!")
		_rotate_towards(Vector3(-1, 0, 0), 1.0, 50.0)
		var rock_area = get_parent().find_child("RockArea", true, false)
		if rock_area and rock_area.has_method("check_trigger"):
			rock_area.check_trigger()
		return

	# ==========================================
	# POINT 9 → DEPAN BENGKEL LABORATORIUM
	# ==========================================
	if current_waypoint == 8:
		await point_9_reached()
		return

	# ==========================================
	# LANJUT KE POINT BERIKUTNYA
	# ==========================================
	current_waypoint += 1
	go_to_next_waypoint()

func point_2_dialog():
	is_dialogue = true
	velocity.x = 0.0
	velocity.z = 0.0
	play_animation("idle")

	# Dialog Ona
	if StoryManager.dialogue_box and StoryManager.dialogue_box.has_method("set_avatar_by_emotion"):
		StoryManager.dialogue_box.set_avatar_by_emotion("idle")

	var p2_lines: Array[String] = [
		"Ona: Sniff... sniff... Bau logam terbakar dan debu bintang antariksa. Aku harus periksa ke sana!"
	]
	StoryManager.start_dialogue(p2_lines, "Ona")

	# Tunggu sampai player menyelesaikan dialog
	await StoryManager.dialogue_finished

	is_dialogue = false

func teleport_to_point_3():
	if waypoints.size() <= 2:
		return
	await fade_out()

	# 1. Teleport Ona ke Point 3
	global_position = waypoints[2].global_position
	print("Teleport ke Point 3")

	# 2. Hentikan animasi roket jika masih aktif dan pastikan kapsul tetap di tanah
	var anim_player: AnimationPlayer = get_parent().get_node_or_null("RionCapsule/AnimationPlayer")
	if anim_player and anim_player.is_playing():
		anim_player.stop()
	var capsule = get_parent().find_child("RionCapsule", true, false)
	if capsule:
		capsule.visible = true
		capsule.global_position = Vector3(106.118, -0.096, 25.87)
		capsule.rotation = Vector3(0, 0, deg_to_rad(9.5))
		var smoke = capsule.find_child("Smoke", true, false)
		if smoke:
			smoke.visible = true

	# 3. Posisikan kamera di depan kapsulrion dan shoot dari depan Ona
	var rocket_cam = get_parent().get_node_or_null("RocketCamera")
	if rocket_cam:
		# Posisi kamera di depan kapsulrion (kapsul di z ~25.87, Ona datang dari z ~0 menuju z ~18.36)
		rocket_cam.global_position = Vector3(104.5, 1.8, 22.5)
		if rocket_cam.has_method("track_target"):
			rocket_cam.track_target(self)
		else:
			rocket_cam.target_node = self
		rocket_cam.look_at(global_position + Vector3(0, 1.0, 0), Vector3.UP)

	# 4. Pastikan Ona langsung menghadap ke arah Point 4
	if waypoints.size() > 3 and waypoints[3]:
		var dir_to_p4 = waypoints[3].global_position - global_position
		dir_to_p4.y = 0
		if dir_to_p4.length() > 0.1:
			look_at(global_position + dir_to_p4, Vector3.UP)

	# 5. Set current_waypoint ke 2 sehingga berikutnya adalah Point 4 (index 3)
	current_waypoint = 2

	await fade_in()

func point_5_reached():
	is_moving = false
	velocity.x = 0.0
	velocity.z = 0.0
	play_animation("idle")
	print("Ona telah sampai di Point 5!")

	var player = get_parent().find_child("Player", true, false)
	if player:
		# Hadapkan Ona ke arah Rion
		var dir_to_rion = player.global_position - global_position
		dir_to_rion.y = 0
		if dir_to_rion.length() > 0.1:
			look_at(global_position + dir_to_rion, Vector3.UP)

		# Munculkan Rion (unhidden) & aktifkan kembali collision
		player.visible = true
		var col = player.find_child("CollisionShape3D", true, false)
		if col:
			col.set_deferred("disabled", false)

	# Posisikan kamera di belakang Rion (Over-The-Shoulder menghadap ke Ona)
	var rocket_cam = get_parent().get_node_or_null("RocketCamera")
	if rocket_cam:
		# Rion berada di (103.44, 0.2, 20.74). Kamera di belakang bahu kanan Rion:
		rocket_cam.global_position = Vector3(103.9, 1.45, 22.2)
		if rocket_cam.has_method("track_target"):
			rocket_cam.track_target(self)
		else:
			rocket_cam.target_node = self
		rocket_cam.look_at(Vector3(global_position.x, 1.0, global_position.z), Vector3.UP)

	# Putar dialog percakapan lengkap Scene 1 di Point 5
	await point_5_dialog()

	# Selesai dialog: Ona lari ke Point 6
	point_5_finished.emit()
	print("Ona mulai berlari ke Point 6...")

	# Kembalikan kamera ke player dan tampilkan UI gameplay
	var camera_rig = get_parent().find_child("CameraRig", true, false)
	var player_cam: Camera3D = null
	if camera_rig:
		player_cam = camera_rig.find_child("*Camera*", true, false) as Camera3D
		camera_rig.set_process(true)
		camera_rig.set_process_unhandled_input(true)

	if player_cam:
		player_cam.make_current()

	var hud = get_parent().find_child("HUD", true, false)
	if hud:
		if hud.has_method("set_gameplay_ui_visible"):
			hud.set_gameplay_ui_visible(true)
		else:
			hud.visible = true
		if hud.has_method("set_objective"):
			hud.set_objective("Ikuti Ona ke seberang sungai menuju Bengkel Laboratorium")

	# Aktifkan kontrol Rion agar pemain dapat menggerakkannya sendiri mengikuti Ona
	if player:
		player.set_physics_process(true)
		player.set_process_unhandled_input(true)
		if "is_auto_moving" in player:
			player.is_auto_moving = false

	# Ona berlari menuju Point 6
	if waypoints.size() > 5 and waypoints[5]:
		speed = 10.0
		current_waypoint = 5
		go_to_next_waypoint()

func point_5_dialog() -> void:
	is_dialogue = true
	velocity.x = 0.0
	velocity.z = 0.0
	play_animation("idle")

	var dialogue_lines: Array[String] = [
		"Ona: Baunya aneh... bukan dari planet ini. Asing. Aneh.",
		"Rion: (Membuka mata kaget, langsung mundur dan terduduk)\nHAAAH?! WAAAA!",
		"Rion: Ka-Ka...-Ka-Kamu siapa?! Kenapa ngendus-ngendus mukaku?!",
		"[SISTEM ONA] MEMINDAI ENTITAS ASING... DETAK JANTUNG: TINGGI. POLA EMOSI: KEBINGUNGAN TOTAL.",
		"Ona: Pertanyaanmu tidak logis.",
		"Ona: Kamulah entitas asing yang tiba-tiba jatuh dari langit ke wilayah ini.",
		"Ona: Seharusnya aku yang bertanya...",
		"Ona: Siapa kamu? Dan apa tujuanmu mendarat di planet ini?",
		"Rion: Aku... tujuanku? Aku gak tahu! Semuanya gelap... Aku bahkan gak ingat siapa diriku, atau kenapa aku bisa ada di benda besi itu!",
		"Rion: Tolong... jangan sakiti aku. Aku beneran gak tahu apa-apa...",
		"[SISTEM ONA] ANALISIS DATA MEMORI TARGET: KORUPSI TOTAL (0 BYTE RETRIEVABLE). TINGKAT ANCAMAN FISIK: 0%. STATUS: TIDAK BERBAHAYA.",
		"Ona: Pemindaian selesai. Detak jantungmu murni karena kaget, dan tidak ditemukan indikasi niat jahat. Statusmu dikonfirmasi Aman.",
		"Ona: Protokol resmi diaktifkan. Namaku Ona, asisten bengkel laboratorium di planet ini.",
		"Ona: Apa kamu ingat siapa nama kamu?",
		"Rion: Aku... Aku tidak ingat siapa namaku",
		"Ona: Aku tadi sempat memeriksa badan kapsul penyelamatmu.",
		"Ona: Di badan kapsulmu tertulis... R-I-O-N. Kita sebut saja nama kamu Rion, ya?",
		"Rion: Rion?",
		"Ona: Betul. Sepertinya sistem ingatanmu sedang mengalami eror fatal akibat guncangan pendaratan tadi.",
		"Ona: Jangan panik. Tuan Rallux ada di bengkel laboratorium di seberang sungai. Beliau adalah ilmuwan paling pintar di planet ini, pasti bisa menganalisis dan membantumu mencari tahu siapa dirimu sebenarnya.",
		"Rion: Tuan Rallux...? Baiklah... tolong antarkan aku ke sana.",
		"Ona: Rute terverifikasi. Ikuti aku, Rion."
	]

	StoryManager.start_dialogue(dialogue_lines, "Ona")
	await StoryManager.dialogue_finished
	is_dialogue = false

func play_animation(animation_name: String):
	if _playback:
		_playback.travel(animation_name)
		if _playback.get_current_node() != animation_name:
			_playback.start(animation_name)
	elif animation_player and animation_player.current_animation != animation_name:
		animation_player.play(animation_name)

func fade_out():
	if fade_rect:
		fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		var tween = create_tween()
		tween.tween_property(fade_rect, "modulate:a", 1.0, 0.5)
		await tween.finished

func fade_in():
	if fade_rect:
		var tween = create_tween()
		tween.tween_property(fade_rect, "modulate:a", 0.0, 0.5)
		await tween.finished
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func point_6_reached():
	is_moving = false
	velocity = Vector3.ZERO
	play_animation("idle")
	print("Ona telah sampai di Point 6, menunggu Rion mendekat...")

	var player = get_parent().find_child("Player", true, false)
	while is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		var dir_to_rion = player.global_position - global_position
		dir_to_rion.y = 0.0
		if dir_to_rion.length_squared() > 0.01:
			_rotate_towards(dir_to_rion, 0.05, 5.0)
		if dist <= 4.5:
			break
		await get_tree().create_timer(0.05).timeout

	await point_6_dialog()

	var hud = get_parent().find_child("HUD", true, false)
	if hud and hud.has_method("set_objective"):
		hud.set_objective("Maju bersama Ona mendekati konsol batu di tepi sungai")

	# Lanjut maju ke Point 7 di depan konsol batu sungai
	if waypoints.size() > 6 and waypoints[6]:
		speed = 6.0
		current_waypoint = 6
		go_to_next_waypoint()

func point_6_dialog() -> void:
	is_dialogue = true
	velocity.x = 0.0
	velocity.z = 0.0
	play_animation("idle")

	var dialogue_lines: Array[String] = [
		"Rion: Wah, arusnya deras banget! Tapi... tunggu dulu. Ona, mana jalannya? Gak ada jembatan sama sekali di sini!",
		"Ona: Jembatannya tidak hilang, Rion. Ini adalah Batu Pijakan Resonansi. Sistem di planet ini menyembunyikannya di bawah air. Batunya baru akan muncul ke permukaan kalau kita mengaktifkan urutan batunya dengan tepat.",
		"Rion: Mengaktifkan urutan batu? Gimana caranya?",
		"Ona: Perhatikan baik-baik. Ayo kita maju lagi kedepan. Konsol pemancar akan segera menampilkan kuncinya."
	]

	StoryManager.start_dialogue(dialogue_lines, "Rion")
	await StoryManager.dialogue_finished
	is_dialogue = false

func teleport_to_point_8():
	if waypoints.size() <= 7 or waypoints[7] == null:
		return
	await fade_out()
	global_position = waypoints[7].global_position
	_rotate_towards(Vector3(-1, 0, 0), 1.0, 50.0)
	print("Ona telah diteleportasikan ke Point 8 (Seberang Sungai)!")
	await fade_in()

	# Jalankan rangkaian peristiwa Point 8
	await point_8_sequence()

func point_8_sequence() -> void:
	is_dialogue = true
	velocity = Vector3.ZERO
	play_animation("idle")

	var player = get_parent().find_child("Player", true, false)
	if player:
		player.velocity = Vector3.ZERO
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
		var anim_tree = player.get_node_or_null("AnimationTree")
		if anim_tree:
			anim_tree.set("parameters/StateMachine/Move/blend_position", 0.0)
		var dir_to_rion = player.global_position - global_position
		dir_to_rion.y = 0
		if dir_to_rion.length() > 0.1:
			_rotate_towards(dir_to_rion, 0.2, 10.0)

	# 1. Ona menanyakan perasaan Rion
	var initial_dialogue: Array[String] = [
		"Ona: Kita sudah sampai di seberang dengan selamat, Rion. Bagaimana perasaanmu setelah berhasil melewati rintangan sungai tadi?"
	]
	StoryManager.start_dialogue(initial_dialogue, "Ona")
	await StoryManager.dialogue_finished

	# 2. Kotak Input Refleksi Diri
	if reflection_dialog == null:
		var existing_dialog = get_parent().find_child("ReflectionDialog", true, false)
		if existing_dialog:
			reflection_dialog = existing_dialog
		else:
			var dialog_scene = load("res://scenes/ui/ReflectionDialog.tscn")
			if dialog_scene:
				reflection_dialog = dialog_scene.instantiate()
				get_parent().add_child(reflection_dialog)

	var detected_sentiment := "positif"
	var user_written_text := ""
	var ai_response_reply := ""

	if reflection_dialog and reflection_dialog.has_method("show_reflection_prompt"):
		reflection_dialog.show_reflection_prompt()
		# Ambil hasil langsung dari sinyal (lambda GDScript capture by value → tidak bisa menulis balik)
		var res_ref: Array = await reflection_dialog.reflection_submitted
		if res_ref.size() >= 3:
			detected_sentiment = str(res_ref[0])
			user_written_text = str(res_ref[1])
			ai_response_reply = str(res_ref[2])

	print("[Ona] Hasil sentimen refleksi Rion: ", detected_sentiment, " | Teks: ", user_written_text)

	# 3. Percakapan Refleksi (Rion mengutarakan ketikannya, Ona membalas langsung)
	var dynamic_dialogue: Array[String] = []

	# Kalimat 1: Rion menyampaikan apa yang baru saja diketiknya
	if not user_written_text.is_empty():
		dynamic_dialogue.append("Rion: \"" + user_written_text + "\"")
	elif detected_sentiment == "positif":
		dynamic_dialogue.append("Rion: Awalnya kelihatan susah, tapi ternyata pas aku coba... aku bisa melewatinya!")
	else:
		dynamic_dialogue.append("Rion: Capek... dan agak kesel. Tadi aku sempat salah dan batunya langsung tenggelam lagi ke air.")

	# Kalimat 2: Ona menanggapi secara personal ucapan Rion
	if not ai_response_reply.is_empty():
		dynamic_dialogue.append("Ona: " + ai_response_reply)

	# Kalimat 3 & seterusnya: Konteks penguatan mental / feedback emosi
	if detected_sentiment == "positif":
		dynamic_dialogue.append("Ona: Analisis emosi terdeteksi: Percaya diri meningkat! Kamu berhasil karena mau memberi kesempatan pada dirimu sendiri untuk memperhatikan polanya.")
		dynamic_dialogue.append("Rion: Iya ya! Waktu aku sabar nonton preview kedipan lampunya sampai selesai, menyusun batunya jadi terasa jauh lebih gampang.")
		dynamic_dialogue.append("Ona: Tepat sekali. Otakmu merespons instruksi visual dengan sangat baik saat kamu tidak terburu-buru.")
	else:
		dynamic_dialogue.append("Ona: Analisis emosi terdeteksi: Kelelahan dan frustrasi. Emosi itu sepenuhnya wajar, Rion. Beradaptasi dengan hal yang baru memang membutuhkan energi mental yang besar.")
		dynamic_dialogue.append("Ona: Reset sistem bukan berarti kamu gagal. Yang terpenting, kamu menarik napas, mencoba lagi, dan buktinya... sekarang kakimu sudah menapak di tanah seberang ini.")
		dynamic_dialogue.append("Rion: (Tersenyum tipis) Makasih, Ona. Mendengarnya bikin dadaku terasa lebih lega.")

	StoryManager.start_dialogue(dynamic_dialogue, "Rion")
	await StoryManager.dialogue_finished

	# 4. Pop-up Keterampilan Tercatat (Badge)
	if reflection_dialog and reflection_dialog.has_method("show_badge_popup"):
		reflection_dialog.show_badge_popup()
		await reflection_dialog.badge_closed

	# 5. Dialog Ajakan Melanjutkan Perjalanan
	var proceed_dialogue: Array[String] = [
		"Ona: Yuk Rion kita lanjutkan perjalanannya, sedikit lagi kita sampai."
	]
	StoryManager.start_dialogue(proceed_dialogue, "Ona")
	await StoryManager.dialogue_finished

	is_dialogue = false

	# Kembalikan kontrol gerak ke pemain
	if player:
		player.set_physics_process(true)
		player.set_process_unhandled_input(true)

	# 6. Update HUD dan Ona Berjalan ke Point 9
	var hud = get_parent().find_child("HUD", true, false)
	if hud and hud.has_method("set_objective"):
		hud.set_objective("Ikuti Ona menuju Bengkel Laboratorium Antariksa")

	if waypoints.size() > 8 and waypoints[8]:
		speed = 8.0
		current_waypoint = 8
		go_to_next_waypoint()

func point_9_reached() -> void:
	is_moving = false
	velocity = Vector3.ZERO
	play_animation("idle")
	print("Ona telah sampai di Point 9 (Depan Bengkel Laboratorium)!")

	# Tunggu Rion mendekat jika masih jauh
	var player = get_parent().find_child("Player", true, false)
	while player and global_position.distance_to(player.global_position) > 8.0:
		await get_tree().create_timer(0.5).timeout

	if player:
		var dir_to_rion = player.global_position - global_position
		dir_to_rion.y = 0
		if dir_to_rion.length() > 0.1:
			_rotate_towards(dir_to_rion, 0.5, 10.0)

	# Mainkan percakapan 19-line di Point 9
	await point_9_dialog()

	# Set objective pintu bengkel
	var hud = get_parent().find_child("HUD", true, false)
	if hud and hud.has_method("set_objective"):
		hud.set_objective("Masuk ke dalam Bengkel Laboratorium Antariksa (Tekan E di Pintu)")

	# Aktifkan Ona mengikuti Rion di sekitar Point 9
	is_following_player = true
	print("Ona sekarang dalam mode mengikuti Rion di sekitar Point 9.")

func point_9_dialog() -> void:
	is_dialogue = true
	velocity = Vector3.ZERO
	play_animation("idle")

	var dialogue_lines: Array[String] = [
		"Ona: Kita sudah sampai di depan Bengkel Laboratorium Antariksa. Tuan Rallux ada di dalam.",
		"Rion: (Langkah kakinya melambat, lalu berhenti sepenuhnya. Matanya menatap pintu bengkel yang besar dengan cemas) Ona... tunggu.",
		"Ona: Ada apa, Rion? Sensor motormu mendeteksi penurunan kecepatan secara drastis.",
		"Rion: Aku... aku takut.",
		"Ona: Takut? Pemindaian lingkungan: Bebas bahaya. Tidak ada radiasi liar atau monster antariksa di sekitar sini.",
		"Rion: Bukan monster, Ona! Tapi... Tuan Rallux. Aku gak kenal beliau. Gimana kalau orangnya galak? Gimana kalau beliau marah karena kapsulku jatuh di planet ini? Atau... gimana kalau beliau malah mengusirku karena aku ngerepotin?",
		"Ona: Analisis biometrik: Telapak tanganmu dingin dan ritme napasmu tidak beraturan. Pola emosi: Cemas menghadapi orang asing (Sosial-Anxiety).",
		"Rion: Rasanya tenggorokanku kering, Ona... Kakiku mendadak berat banget buat melangkah ke pintu itu.",
		"Ona: Rion, dengarkan aku. Merasa cemas saat akan bertemu orang baru adalah respons yang sangat wajar bagi otak organik.",
		"Ona: Tapi perlu kamu ketahui: Database Bengkel mencatat bahwa Tuan Rallux adalah orang yang merancang protokol pertolonganku.",
		"Ona: Beliau sangat menyukai penjelajah antariksa dan sudah terbiasa memperbaiki hal-hal yang rusak—termasuk membantu memulihkan memorimu.",
		"Rion: Tapi... kalau nanti aku gak bisa jawab pertanyaannya gimana? Kalau aku kelihatan aneh atau bodoh di depan beliau?",
		"Ona: Kamu tidak harus langsung bercerita banyak hal, Rion.",
		"Ona: Kita bisa masuk pelan-pelan. Aku akan terus berdiri tepat di sampingmu. Kalau suasananya terasa terlalu ramai atau membuatmu kewalahan, kamu boleh memberitahuku kapan saja, dan kita bisa melangkah mundur untuk istirahat sejenak di luar.",
		"Rion: Jadi... aku gak harus memaksakan diri kalau merasa gak nyaman?",
		"Ona: Tentu saja tidak. Kamu selalu punya kendali atas langkahmu sendiri. Tapi kamu tidak akan sendirian. Aku bersamamu.",
		"Rion: (Menghela napas panjang, meremas jemarinya perlahan lalu menatap Ona) Oke... Berdiri di sampingku terus ya, Ona? Jangan tinggalin aku.",
		"Ona: Dipahami. Protokol Pendampingan Penuh aktif. Aku tidak akan ke mana-mana.",
		"Ona: Saat kamu sudah merasa siap, ayo kita buka pintunya dan melangkah masuk bersama-sama."
	]

	StoryManager.start_dialogue(dialogue_lines, "Ona")
	await StoryManager.dialogue_finished
	is_dialogue = false
	GameManager.point_9_dialog_done = true

func _process_follow_player(_delta: float) -> void:
	var player = get_parent().find_child("Player", true, false)
	if player == null or not is_instance_valid(player):
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		play_animation("idle")
		return

	# Cek apakah perlu teleportasi melintasi sungai menyusul Rion
	if _check_river_teleport(_delta, player):
		move_and_slide()
		return

	# Jika Player sedang berada di atas batu sungai:
	# Ona tidak boleh masuk ke air, tunggu aman di tepi sungai
	if player.global_position.x >= -36.5 and player.global_position.x <= -19.0:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		play_animation("idle")
		var dir_to_p = player.global_position - global_position
		dir_to_p.y = 0.0
		_rotate_towards(dir_to_p, _delta)
		return

	var dist = global_position.distance_to(player.global_position)
	# Jarak target follow sekitar 2.2 - 2.8 meter
	if dist > 2.8:
		navigation_agent.target_position = player.global_position
		var next_pos = navigation_agent.get_next_path_position()
		var dir = global_position.direction_to(next_pos)
		dir.y = 0.0

		if dir.length() <= 0.01:
			dir = global_position.direction_to(player.global_position)
			dir.y = 0.0

		if dir.length() > 0.01:
			dir = dir.normalized()
			var follow_speed = clamp(dist * 2.0, 3.5, 7.5)
			velocity.x = dir.x * follow_speed
			velocity.z = dir.z * follow_speed
			_rotate_towards(dir, _delta)
			play_animation("walk" if follow_speed < 5.5 else "run")
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			play_animation("idle")
	else:
		# Dekat dengan player: berhenti dan tatap player
		velocity.x = 0.0
		velocity.z = 0.0
		play_animation("idle")
		var dir_to_player = player.global_position - global_position
		dir_to_player.y = 0.0
		if dir_to_player.length() > 0.2:
			_rotate_towards(dir_to_player, _delta)

	move_and_slide()

func _check_river_teleport(delta: float, player: Node3D) -> bool:
	if _teleport_cooldown > 0.0:
		_teleport_cooldown -= delta

	var ona_x = global_position.x
	var ona_y = global_position.y

	# 1. Penyelamatan darurat jika Ona tercebur ke dalam air sungai
	if ona_y < -0.8 and ona_x > -37.5 and ona_x < -18.0:
		var target_x = -17.8 if player.global_position.x > -28.0 else -39.0
		var rescue_pos = Vector3(target_x, 0.2, player.global_position.z)
		_execute_teleport(rescue_pos, "Penyelamatan darurat dari air sungai")
		return true

	if _teleport_cooldown > 0.0:
		return false

	var player_x = player.global_position.x

	# 2. Player sudah di Tepi Kapsul (X > -19.0), sedangkan Ona masih di Tepi Bengkel / Sungai (X < -26.0)
	if player_x > -19.0 and ona_x < -26.0:
		var target_pos = Vector3(-17.8, 0.1, player.global_position.z)
		if waypoints.size() > 6 and waypoints[6]:
			target_pos = waypoints[6].global_position + Vector3(0.5, 0.1, 0.0)
		_execute_teleport(target_pos, "Menyusul Rion ke tepi sungai daerah kapsul")
		return true

	# 3. Player sudah di Tepi Bengkel (X < -36.5), sedangkan Ona masih di Tepi Kapsul / Sungai (X > -29.0)
	if player_x < -36.5 and ona_x > -29.0:
		var target_pos = Vector3(-39.5, 0.1, player.global_position.z)
		if waypoints.size() > 7 and waypoints[7]:
			target_pos = waypoints[7].global_position + Vector3(-0.5, 0.1, 0.0)
		_execute_teleport(target_pos, "Menyusul Rion ke tepi sungai daerah bengkel")
		return true

	return false

func _execute_teleport(target_pos: Vector3, reason: String) -> void:
	_teleport_cooldown = 1.0
	velocity = Vector3.ZERO
	global_position = target_pos
	play_animation("idle")
	var player = get_parent().find_child("Player", true, false)
	if player:
		var dir_to_p = player.global_position - global_position
		dir_to_p.y = 0.0
		if dir_to_p.length_squared() > 0.01:
			rotation.y = atan2(-dir_to_p.x, -dir_to_p.z)
	print("[Ona Teleport] %s -> Posisi: %s" % [reason, str(target_pos)])

func _rotate_towards(target_dir: Vector3, delta: float, turn_speed: float = 10.0) -> void:
	if target_dir.length_squared() < 0.001:
		return
	var target_angle = atan2(-target_dir.x, -target_dir.z)
	var weight = clampf(turn_speed * delta, 0.0, 1.0)
	rotation.y = lerp_angle(rotation.y, target_angle, weight)

func _setup_animation_tree() -> void:
	if animation_tree == null:
		animation_tree = get_node_or_null("AnimationTree")

	if animation_tree == null and animation_player != null:
		animation_tree = AnimationTree.new()
		animation_tree.name = "AnimationTree"
		add_child(animation_tree)
		animation_tree.anim_player = animation_tree.get_path_to(animation_player)

		var sm = AnimationNodeStateMachine.new()

		var anim_idle = AnimationNodeAnimation.new()
		anim_idle.animation = &"idle"
		sm.add_node("idle", anim_idle, Vector2(200, 100))

		var anim_walk = AnimationNodeAnimation.new()
		anim_walk.animation = &"walk"
		sm.add_node("walk", anim_walk, Vector2(400, 50))

		var anim_run = AnimationNodeAnimation.new()
		anim_run.animation = &"run"
		sm.add_node("run", anim_run, Vector2(400, 150))

		var anim_bashful = AnimationNodeAnimation.new()
		anim_bashful.animation = &"bashful"
		sm.add_node("bashful", anim_bashful, Vector2(200, 220))

		var start_trans = AnimationNodeStateMachineTransition.new()
		start_trans.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
		sm.add_transition("Start", "idle", start_trans)

		var add_trans = func(from: String, to: String, xfade: float):
			var t1 = AnimationNodeStateMachineTransition.new()
			t1.xfade_time = xfade
			sm.add_transition(from, to, t1)
			var t2 = AnimationNodeStateMachineTransition.new()
			t2.xfade_time = xfade
			sm.add_transition(to, from, t2)

		add_trans.call("idle", "walk", 0.25)
		add_trans.call("idle", "run", 0.25)
		add_trans.call("walk", "run", 0.2)
		add_trans.call("idle", "bashful", 0.3)
		add_trans.call("walk", "bashful", 0.3)
		add_trans.call("run", "bashful", 0.3)

		animation_tree.tree_root = sm

	if animation_tree:
		animation_tree.active = true
		_playback = animation_tree.get("parameters/playback")
		if _playback:
			_playback.start("idle")

# =============================================================================
# SCENE 5: KEBUN KOSMIK, REFLEKSI KEMARAHAN, MEMORI BUNGA, & TRANSISI TIDUR
# =============================================================================

var _is_evaluating_memory: bool = false
var _zero_flower_reminded: bool = false

func _check_garden_return_to_point9() -> void:
	var p9_marker = waypoints[8] if waypoints.size() > 8 else get_parent().find_child("Point9", true, false)
	var p9_pos = p9_marker.global_position if p9_marker else Vector3(-147.0, 0.0, -0.86)
	var player = get_parent().find_child("Player", true, false)
	if player == null:
		return
	
	var dist_p9 = player.global_position.distance_to(p9_pos)
	if dist_p9 <= 4.0:
		if GameManager.collected_flower_count > 0:
			trigger_flower_memory_evaluation()
		else:
			# Belum memetik bunga: jangan trigger evaluasi!
			if not _zero_flower_reminded and not is_dialogue:
				_zero_flower_reminded = true
				var reminder: Array[String] = [
					"Ona: Rion, keranjang kita masih kosong. Ayo kita petik beberapa tangkai bunga mekar yang bercahaya di kebun dulu ya!"
				]
				StoryManager.start_dialogue(reminder, "Ona")
	else:
		if dist_p9 > 7.0:
			_zero_flower_reminded = false

func _start_scene_5_garden_sequence() -> void:
	var player = get_parent().find_child("Player", true, false)
	if player:
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
		player.velocity = Vector3.ZERO
		var anim_tree = player.get_node_or_null("AnimationTree")
		if anim_tree:
			anim_tree.set("parameters/StateMachine/Move/blend_position", 0.0)

		# Pasangkan basket bunga di RionMesh
		_attach_basket_to_player(player)

	is_dialogue = true
	velocity = Vector3.ZERO
	play_animation("idle")

	# Langkah 1: Ona dan Rion berjalan berdampingan dari depan bengkel ke Point 10
	var p10_marker = null
	if waypoints.size() > 9 and waypoints[9]:
		p10_marker = waypoints[9]
	else:
		p10_marker = get_parent().find_child("Point10", true, false)

	var target_p10 = p10_marker.global_position if p10_marker else Vector3(-146.5, 0.0, -9.8)

	# Berjalan pelan berdampingan di jalur jalan aman (jarak rapat 0.9m)
	var t_walk = create_tween().set_parallel(true)
	var ona_start = global_position
	var ona_dest = target_p10 + Vector3(0.45, 0, 0)
	var dir_walk = (ona_dest - ona_start).normalized()
	dir_walk.y = 0
	if dir_walk.length_squared() > 0.01:
		rotation.y = atan2(-dir_walk.x, -dir_walk.z)

	_cutscene_walking = true
	play_animation("walk")
	t_walk.tween_property(self, "global_position", ona_dest, 3.5).set_trans(Tween.TRANS_SINE)

	if player:
		var p_start = player.global_position
		var p_dest = target_p10 + Vector3(-0.45, 0, 0)
		var p_dir = (p_dest - p_start).normalized()
		p_dir.y = 0
		var rion_mesh = player.get_node_or_null("RionMesh")
		if rion_mesh and p_dir.length_squared() > 0.01:
			rion_mesh.rotation.y = atan2(p_dir.x, p_dir.z)

		t_walk.tween_property(player, "global_position", p_dest, 3.5).set_trans(Tween.TRANS_SINE)
		var p_anim = player.get_node_or_null("AnimationTree")
		if p_anim:
			p_anim.set("parameters/StateMachine/Move/blend_position", 0.5)

	await t_walk.finished
	_cutscene_walking = false
	play_animation("idle")
	if player:
		var p_anim = player.get_node_or_null("AnimationTree")
		if p_anim:
			p_anim.set("parameters/StateMachine/Move/blend_position", 0.0)

	# Ona menoleh ke arah Rion untuk dialog
	if player:
		var dir_to_p = (player.global_position - global_position).normalized()
		dir_to_p.y = 0
		if dir_to_p.length_squared() > 0.01:
			rotation.y = atan2(-dir_to_p.x, -dir_to_p.z)

		# Rion menghadap ke arah Point 11 (Taman Bunga), bukan menghadap ke Ona
		var rion_mesh = player.get_node_or_null("RionMesh")
		if rion_mesh:
			var p11_marker = null
			if waypoints.size() > 10 and waypoints[10]:
				p11_marker = waypoints[10]
			else:
				p11_marker = get_parent().find_child("Point11", true, false)
			
			var target_pos_p11 = p11_marker.global_position if p11_marker else Vector3(-154.86, 0.0, -12.25)
			var dir_to_garden = (target_pos_p11 - player.global_position).normalized()
			dir_to_garden.y = 0
			if dir_to_garden.length_squared() > 0.01:
				rion_mesh.rotation.y = atan2(dir_to_garden.x, dir_to_garden.z)

	# Langkah 2: Dialog Pembuka Kebun Bunga
	var garden_dialog_part1: Array[String] = [
		"Ona: Wah, lihat deh, Rion! Bunga-bunga kosmik di sini sedang mekar semua. Ayo kita kumpulkan beberapa tangkai bunga untuk hiasan meja di dalam bengkel.",
		"Rion: Waaah... bunganya beneran nyala kayak lampu kecil! Boleh aku petik, Ona?",
		"Ona: Tentu saja boleh! Petik bunga yang sudah mekar besar saja ya, Rion...",
		"Ona: Karena nektar bunganya sudah matang dan layak untuk kita petik.",
		"Rion: Pluk. Hangat dan lembut banget pas dipegang... Rasanya telapak tanganku jadi kesemutan geli. Ternyata tanaman di planet ini unik-unik banget ya.",
		"Ona: Sensor optikku mencatatnya sebagai pendaran cahaya yang stabil, dan aromanya menenangkan sistem sirkulasi energiku.",
		"Ona: (Ona terdiam sejenak, memandangi bunga di tangannya dengan pandangan reflektif)",
		"Ona: Rion... sebagai seonggok mesin yang terbuat dari logam dan kabel, terkadang aku merasa sangat penasaran... Seperti apa sebenarnya rasanya memiliki emosi di dalam hati?",
		"Rion: Eh? Rasa emosi?",
		"Ona: Iya. Sistemku hanya punya kalkulasi angka dan logika data. Tapi makhluk hidup sepertimu bisa merasakan banyak hal. Misalnya... hal apa sih yang biasanya paling bikin kamu merasa marah atau kesal?"
	]

	StoryManager.start_dialogue(garden_dialog_part1, "Ona")
	await StoryManager.dialogue_finished

	# Langkah 3: Kotak Input Refleksi NLP Kemarahan
	if reflection_dialog == null:
		var ex = get_parent().find_child("ReflectionDialog", true, false)
		if ex:
			reflection_dialog = ex
		else:
			var dlg_scene = load("res://scenes/ui/ReflectionDialog.tscn")
			if dlg_scene:
				reflection_dialog = dlg_scene.instantiate()
				get_parent().add_child(reflection_dialog)

	var user_written_anger := ""
	var ona_anger_reply := ""

	if reflection_dialog and reflection_dialog.has_method("show_anger_reflection_prompt"):
		reflection_dialog.show_anger_reflection_prompt()
		# Ambil hasil langsung dari sinyal (lambda GDScript capture by value → tidak bisa menulis balik)
		var res_anger: Array = await reflection_dialog.anger_reflection_submitted
		if res_anger.size() >= 2:
			user_written_anger = str(res_anger[0])
			ona_anger_reply = str(res_anger[1])

	# Langkah 4: Respon Ona & Kisah Tuan Rallux Menjaga Emosi
	var garden_dialog_part2: Array[String] = [
		"Ona: Jadi hal seperti itu yang memicu luapan energi kemarahan di dalam pikiran ya... Menarik sekali.",
		"Ona: Bagi mesin, eror biasanya membuat sistem berhenti bekerja.",
		"Ona: Tapi pada makhluk hidup, rasa marah dan kesal ternyata adalah sinyal bahwa ada hal penting yang sedang terganggu.",
		"Rion: Iya... rasanya kayak ada uap panas yang mau meledak keluar dari kepala kalau lagi kesal.",
		"Ona: Itulah kenapa Tuan Rallux sangat hebat dalam menjaga emosi. Dulu, waktu aku baru pertama kali dirakit dan sistem kendaliku sering eror, aku pernah tanpa sengaja menjatuhkan setumpuk tabung kristal penelitian sampai pecah berantakan.",
		"Rion: Hah?! Terus Tuan Rallux ngapain? Marah besar gak?!",
		"Ona: (Menggeleng pelan) Sama sekali tidak. Beliau tidak pernah membiarkan kemarahan merusak keadaan. Beliau langsung memeriksa tanganku dan bertanya, 'Ona, kamu kaget ya?'",
		"Ona: Beliau selalu bilang, barang yang rusak selalu bisa diperbaiki atau diganti, tapi perasaan kita jauh lebih berharga. Beliau sangat suka teka-teki, suka meracik ube matcha, dan paling senang menyambut teman baru.",
		"Rion: (Tersenyum lega) Wah... ternyata Tuan Rallux memang sebaik dan sehangat itu ya... Aku jadi ngerasa tenang banget sekarang.",
		"Ona: Tentu saja! Makanya, yuk tarik napas dalam-dalam... Nikmati segarnya angin dan pemandangan kebun yang tenang ini.",
		"Rion: (Menarik napas panjang lalu mengembuskannya) Sejuk banget. Badanku rasanya jauh lebih ringan sekarang."
	]

	StoryManager.start_dialogue(garden_dialog_part2, "Ona")
	await StoryManager.dialogue_finished

	# Langkah 5: Aktifkan Gameplay Bebas & Pergantian Skybox Malam
	is_dialogue = false
	GameManager.garden_intro_done = true

	if player:
		player.set_physics_process(true)
		player.set_process_unhandled_input(true)

	if GameManager:
		GameManager.update_flower_hud()

	# Mulai transisi langit malam secara halus (18 detik agar dinikmati)
	var sun = get_parent().find_child("DirectionalLight3D", true, false)
	if sun and sun.has_method("transition_to_night"):
		sun.transition_to_night(18.0)

	# Ona sekarang menemani Rion memetik bunga di sekitar kebun
	is_following_player = true
	print("[Ona] Menemani Rion memetik bunga di kebun.")

func _attach_basket_to_player(player: Node3D) -> void:
	if player.find_child("FlowerBasket", true, false) != null:
		return
	var basket_scene = load("res://scenes/props/FlowerBasket.tscn")
	if basket_scene:
		var basket = basket_scene.instantiate()
		basket.name = "FlowerBasket"
		
		# Pasang tepat pada tulang tangan kanan Rion (mixamorig_RightHand)
		var skeleton = player.find_child("Skeleton3D", true, false) as Skeleton3D
		if skeleton:
			var bone_attach = skeleton.get_node_or_null("RightHandAttachment") as BoneAttachment3D
			if bone_attach == null:
				bone_attach = BoneAttachment3D.new()
				bone_attach.name = "RightHandAttachment"
				bone_attach.bone_name = "mixamorig_RightHand"
				var b_idx = skeleton.find_bone("mixamorig_RightHand")
				if b_idx != -1:
					bone_attach.bone_idx = b_idx
				skeleton.add_child(bone_attach)
			bone_attach.add_child(basket)
			# Posisi dan orientasi tepat pas digenggam tegak di tangan kanan Rion (skala lebih kecil proporsional)
			basket.position = Vector3(-0.05, 0.14, 0.03)
			basket.rotation_degrees = Vector3(-26.0, 121.0, -176.0)
			if basket.has_method("set_base_scale"):
				basket.set_base_scale(Vector3(0.32, 0.32, 0.32))
			else:
				basket.scale = Vector3(0.32, 0.32, 0.32)
			print("[Ona] Keranjang bunga terpasang tepat pada tangan kanan Rion (mixamorig_RightHand)!")
		else:
			var rion_mesh = player.get_node_or_null("RionMesh")
			if rion_mesh:
				rion_mesh.add_child(basket)
				basket.position = Vector3(0.24, 0.40, 0.18)
				basket.rotation = Vector3.ZERO
			else:
				player.add_child(basket)
				basket.position = Vector3(0.35, 0.45, 0.2)
			if basket.has_method("set_base_scale"):
				basket.set_base_scale(Vector3(0.35, 0.35, 0.35))
			else:
				basket.scale = Vector3(0.35, 0.35, 0.35)
			print("[Ona] Keranjang bunga terpasang pada RionMesh!")

## Pemicu Evaluasi Memori Saat Bunga Terkumpul atau Rion Kembali ke Depan Bengkel
func trigger_flower_memory_evaluation() -> void:
	if _is_evaluating_memory:
		return
	# Jika tidak ada bunga yang diambil, jangan trigger evaluasi!
	if GameManager and GameManager.collected_flower_count == 0:
		print("[Ona] Belum ada bunga yang dipetik, evaluasi dibatalkan.")
		return

	_is_evaluating_memory = true
	is_following_player = false
	is_moving = false
	is_dialogue = true
	velocity = Vector3.ZERO
	play_animation("idle")

	var player = get_parent().find_child("Player", true, false)
	if player:
		player.velocity = Vector3.ZERO
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
		var p_anim = player.get_node_or_null("AnimationTree")
		if p_anim:
			p_anim.set("parameters/StateMachine/Move/blend_position", 0.0)

		# Ona dan Rion saling berhadapan untuk percakapan evaluasi
		var dir_to_p = (player.global_position - global_position).normalized()
		dir_to_p.y = 0
		if dir_to_p.length_squared() > 0.01:
			rotation.y = atan2(-dir_to_p.x, -dir_to_p.z)

		var rion_mesh = player.get_node_or_null("RionMesh")
		if rion_mesh:
			var dir_to_ona = (global_position - player.global_position).normalized()
			dir_to_ona.y = 0
			if dir_to_ona.length_squared() > 0.01:
				rion_mesh.rotation.y = atan2(dir_to_ona.x, dir_to_ona.z)

	# Ona menyambut Rion
	var eval_intro: Array[String] = [
		"Ona: (Menyambut Rion dengan senyum ramah) Kerja bagus, Rion! Kamu sudah menjelajahi kebun dengan teliti. Nah, sebelum kita bawa keranjang ini masuk ke dalam, coba kita ingat-ingat sebentar apa yang sudah kita kumpulkan.",
		"Rion: Boleh! Ingat-ingat tentang apa, Ona?",
		"Ona: Saat berkeliling tadi, kamu memetik berapa banyak tangkai bunga untuk dimasukkan ke dalam keranjang?"
	]
	StoryManager.start_dialogue(eval_intro, "Ona")
	await StoryManager.dialogue_finished

	# Input Evaluasi 2: Jumlah Bunga
	var count_exact := false
	var count_comment := ""
	var total_bunga := GameManager.collected_flower_count if GameManager else 0

	if reflection_dialog and reflection_dialog.has_method("show_count_evaluation_prompt"):
		reflection_dialog.show_count_evaluation_prompt()
		# CATATAN: lambda GDScript meng-capture variabel lokal BY VALUE, sehingga menulis
		# ke variabel luar dari dalam lambda tidak berpengaruh. Hasil harus diambil
		# langsung dari sinyal, kalau tidak jawaban benar akan selalu dianggap salah.
		var res_count: Array = await reflection_dialog.count_evaluation_submitted
		if res_count.size() >= 4:
			count_exact = bool(res_count[1])
			count_comment = str(res_count[2])
			total_bunga = int(res_count[3])

	# Respon Ona atas tebakan jumlah bunga
	var count_response_lines: Array[String] = []
	if count_exact:
		count_response_lines = [
			"Ona: Tepat sekali! Ada %d tangkai bunga di keranjangmu. Memorimu bekerja dengan sangat jeli, Rion." % total_bunga,
			"Rion: (Tersenyum bangga) Hehe, aku beneran hitung satu per satu tadi pas memetiknya!"
		]
	else:
		count_response_lines = [
			"Ona: %s! Wajar banget kok kalau angkanya meleset. Di kebun yang luas dan indah seperti ini, perhatian kita memang gampang teralihkan ke mana-mana. Kalau kita hitung bersama di keranjang, totalnya ada %d tangkai." % [count_comment, total_bunga],
			"Rion: Wah, iya ya... tadi aku terlalu asyik lihat kelopaknya yang bersinar.",
			"Ona: Rasa penasaranmu itu hal yang keren, Rion. Tidak perlu buru-buru, yang penting kamu menikmatinya."
		]

	StoryManager.start_dialogue(count_response_lines, "Ona")
	await StoryManager.dialogue_finished

	# Pertanyaan Lanjutan: Warna Bunga
	var color_intro: Array[String] = [
		"Ona: Nah, satu tebakan lagi biar semakin seru. Kira-kira kamu masih ingat tidak, bunga-bunga yang kamu petik tadi warnanya apa?"
	]
	StoryManager.start_dialogue(color_intro, "Ona")
	await StoryManager.dialogue_finished

	# Input Evaluasi 3: Warna Bunga
	var color_correct := false
	if reflection_dialog and reflection_dialog.has_method("show_color_evaluation_prompt"):
		reflection_dialog.show_color_evaluation_prompt()
		# Sama seperti evaluasi jumlah: ambil hasil langsung dari sinyal (bukan lambda)
		var res_color: Array = await reflection_dialog.color_evaluation_submitted
		if res_color.size() >= 2:
			color_correct = bool(res_color[1])

	# Respon Warna Bunga (Target: Biru / Kosmik)
	var color_response_lines: Array[String] = []
	if color_correct:
		color_response_lines = [
			"Ona: (Tersenyum bangga dan bertepuk tangan pelan) Tepat sekali, Rion! Bunganya berwarna biru kosmik yang berkilau lembut.",
			"Ona: Daya ingat dan pengamatan visualmu sangat hebat! Kamu memperhatikan detail warnanya dengan jeli meski kita tadi asyik berkeliling.",
			"Rion: (Tersenyum lebar) Hehe, iya! Pendaran warna birunya kelihatan cantik banget kayak bintang malam di langit.",
			"Ona: Warna biru yang menenangkan ini pasti akan membuat meja kerja di dalam bengkel terasa lebih hidup dan nyaman."
		]
	else:
		color_response_lines = [
			"Ona: Warna yang kamu sebutkan tadi terdengar sangat menarik kalau dibayangkan ada di kebun ini!",
			"Ona: Tapi coba kita perhatikan keranjang bunga ini bersama-sama. Bunga-bunga kosmik yang kita petik tadi sebenarnya berwarna biru yang bersinar lembut.",
			"Rion: Wah, iya ya! Karena pendaran cahayanya terang banget, aku sempat mengira warnanya agak berbeda.",
			"Ona: Tidak apa-apa, Rion! Yang paling penting, kamu sudah berhasil mengumpulkan bunga-bunga mekar yang indah ini untuk kita bawa masuk."
		]

	StoryManager.start_dialogue(color_response_lines, "Ona")
	await StoryManager.dialogue_finished

	# Penutup Scene 5 & Transisi Tidur
	await _run_sleep_transition(player)

## Sekuens Layar Redup, Tidur di Bengkel, & Teks Keesokan Harinya
func _run_sleep_transition(player: Node3D) -> void:
	var closing_dialogue: Array[String] = [
		"Ona: Lihat, langit malam sudah tiba. Udara di kebun mulai dingin. Yuk, kita bawa keranjang bunga ini masuk ke dalam. Kamu bisa beristirahat di sofa yang empuk.",
		"Rion: Iya, Ona... Kakiku udah mulai pegal dan mataku mulai berat. Ayo kita masuk!"
	]
	StoryManager.start_dialogue(closing_dialogue, "Ona")
	await StoryManager.dialogue_finished

	# Fade to Black pekat
	if fade_rect == null:
		fade_rect = get_parent().find_child("FadeRect", true, false)

	if fade_rect:
		fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		var fade_tw = create_tween()
		fade_tw.tween_property(fade_rect, "modulate:a", 1.0, 1.8)
		await fade_tw.finished

	# Dialog Rion mengantuk
	var sleepy_dialog: Array[String] = [
		"Rion: Tempat ini... aman banget... Hoaaam..."
	]
	StoryManager.start_dialogue(sleepy_dialog, "Rion")
	await StoryManager.dialogue_finished

	# Buat UI Narasi Layar Hitam
	var overlay = CanvasLayer.new()
	overlay.layer = 130
	var panel = ColorRect.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.color = Color.BLACK
	overlay.add_child(panel)

	var center_box = CenterContainer.new()
	center_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center_box)

	var label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(800, 200)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1.0))
	label.text = "\"Dikelilingi kehangatan bengkel dan aroma kayu manis yang menenangkan, Rion tertidur pulas tanpa rasa takut lagi...\""
	center_box.add_child(label)

	get_parent().add_child(overlay)

	# Tampilkan teks narasi tidur selama 3.5 detik
	await get_tree().create_timer(3.5).timeout

	# JEDA HENING 2 DETIK
	label.modulate.a = 0.0
	await get_tree().create_timer(2.0).timeout

	# TEKS MUNCUL DI TENGAH LAYAR: KEESOKAN HARINYA... Selama 3 detik
	label.text = "☀️ KEESOKAN HARINYA..."
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
	var tw_txt = create_tween()
	tw_txt.tween_property(label, "modulate:a", 1.0, 0.8)
	await get_tree().create_timer(3.0).timeout

	# Selesai transisi tidur
	GameManager.sleep_transition_done = true
	print("[Ona] Transisi tidur Scene 5 selesai.")

	# Pagi berikutnya: Rion bangun di bengkel (R1) dan bebas mengerjakan misi bengkel.
	GameManager.set_spawn_override(Vector3(-68.10683, 0.114290714, -43.697), "R1")
	if has_node("/root/LoadingScreen"):
		LoadingScreen.load_scene("res://R1.tscn")
	else:
		get_tree().change_scene_to_file("res://R1.tscn")
