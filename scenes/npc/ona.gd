extends CharacterBody3D

signal point_5_finished

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var fade_rect: ColorRect = get_parent().get_node_or_null("FadeLayer/FadeRect")

@export var speed := 10.0
@export var waypoints: Array[Node3D]
var current_waypoint := 0
var is_moving := false
var is_dialogue := false

func _ready():
	if fade_rect:
		fade_rect.modulate.a = 0.0
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var storypoints = get_parent().get_node_or_null("Storypoints")
	if storypoints:
		for point in storypoints.get_children():
			if point is Node3D:
				waypoints.append(point)

	print("Jumlah waypoint Ona: ", waypoints.size())

	await get_tree().create_timer(5.0).timeout
	go_to_next_waypoint()
	
func _physics_process(_delta):
	# Gravitasi agar Ona menapak tanah
	if not is_on_floor():
		velocity.y -= 18.0 * _delta
	else:
		velocity.y = 0.0

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
		look_at(global_position + Vector3(direction.x, 0, direction.z), Vector3.UP)
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
	# POINT 6 → SAMPAI DI POINT 6 (TEPI SUNGAI)
	# ==========================================
	if current_waypoint == 5:
		is_moving = false
		velocity = Vector3.ZERO
		play_animation("idle")
		print("Ona dan Rion telah sampai di Point 6 (Tepi Sungai)!")
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

	# 2. Hentikan animasi roket jika masih aktif agar tidak merebut kamera
	var anim_player: AnimationPlayer = get_parent().get_node_or_null("RionCapsule/AnimationPlayer")
	if anim_player and anim_player.is_playing():
		anim_player.stop()

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
	if animation_player and animation_player.current_animation != animation_name:
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
