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

func _ready():
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
		is_following_player = true
		# Posisikan Ona di dekat pintu bengkel / Point 9
		if waypoints.size() >= 9:
			global_position = waypoints[8].global_position + Vector3(2.0, 0, 0)
		else:
			global_position = Vector3(-145.0, 0.0, -0.86)
		play_animation("idle")
		print("Ona menyambut Rion di kebun luar dan siap mengikuti ke mana pun Rion pergi!")
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
	# ONA SEDANG DIALOG
	# ==========================================
	if is_dialogue:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		play_animation("idle")
		return

	# ==========================================
	# ONA MENGIKUTI RION DI SEKITAR POINT 9
	# ==========================================
	if is_following_player:
		_process_follow_player(_delta)
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
	if reflection_dialog and reflection_dialog.has_method("show_reflection_prompt"):
		reflection_dialog.show_reflection_prompt()
		detected_sentiment = await reflection_dialog.reflection_submitted

	print("[Ona] Hasil sentimen refleksi Rion: ", detected_sentiment)

	# 3. Percabangan Berdasarkan Sentimen
	if detected_sentiment == "positif":
		var branch_a: Array[String] = [
			"Rion: Awalnya kelihatan susah, tapi ternyata pas aku coba... aku bisa melewatinya!",
			"Ona: Analisis emosi terdeteksi: Percaya diri meningkat! Rasa itu wajar kamu rasakan, Rion. Kamu berhasil karena mau memberi kesempatan pada dirimu sendiri untuk memperhatikan polanya.",
			"Rion: Iya ya! Waktu aku sabar nonton preview kedipan lampunya sampai selesai, menyusun batunya jadi terasa jauh lebih gampang. Gak seseram yang aku bayangin di awal!",
			"Ona: Tepat sekali. Otakmu merespons instruksi visual dengan sangat baik saat kamu tidak terburu-buru."
		]
		StoryManager.start_dialogue(branch_a, "Rion")
		await StoryManager.dialogue_finished
	else:
		var branch_b: Array[String] = [
			"Rion: Capek... dan agak kesel. Tadi aku sempat salah dan batunya langsung tenggelam lagi ke air. Rasanya pengen nyerah aja.",
			"Ona: Analisis emosi terdeteksi: Kelelahan dan frustrasi. Emosi itu sepenuhnya valid, Rion. Beradaptasi dengan hal yang baru memang membutuhkan energi mental yang sangat besar.",
			"Rion: Aku ngerasa bersalah tiap kali batunya reset... Kayak aku gak bisa apa-apa.",
			"Ona: Reset sistem bukan berarti kamu gagal, Rion. Itu adalah fitur pengaman sungai agar kita bisa mencoba lagi dengan aman.",
			"Ona: Yang terpenting, kamu tidak berhenti saat batunya tenggelam. Kamu menarik napas, mencoba lagi, dan buktinya... sekarang kakimu sudah menapak di tanah seberang ini.",
			"Rion: (Tersenyum tipis) Makasih, Ona. Mendengarnya bikin dadaku terasa lebih lega."
		]
		StoryManager.start_dialogue(branch_b, "Rion")
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
