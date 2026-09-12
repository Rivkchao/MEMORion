extends Area3D

@export var marker_inside: Marker3D
@export var marker_outside: Marker3D
@export var interact_action: String = "interact"

@export_group("Room Darkness Control")
@export var world_environment: WorldEnvironment
@export var inside_ambient_energy: float = 0.05   # Sangat gelap saat di dalam
@export var outside_ambient_energy: float = 0.55  # Normal saat di luar

# Variabel ini diakses langsung oleh lever.gd tanpa butuh class_name
@export var is_room_unlocked: bool = false

var current_player: Node3D = null


var label_3d: Label3D = null

func _ready() -> void:
	add_to_group("doors")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	label_3d = Label3D.new()
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.font_size = 48
	label_3d.outline_size = 8
	label_3d.outline_modulate = Color(0, 0, 0, 1)
	label_3d.position = Vector3(0, 2.5, 0)
	add_child(label_3d)
	label_3d.hide()


func is_player_inside() -> bool:
	return current_player != null


func _unhandled_input(event: InputEvent) -> void:
	# Jangan proses input pintu saat dialog sedang berjalan
	if StoryManager != null and StoryManager.dialogue_box != null and StoryManager.dialogue_box.visible:
		return
	if current_player:
		if (InputMap.has_action(interact_action) and event.is_action_pressed(interact_action)) or \
		   (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
			teleport_player()


func _on_body_entered(body: Node3D) -> void:
	if body is StaticBody3D:
		return
	if body is CharacterBody3D or body.is_in_group("player") or "player" in body.name.to_lower():
		current_player = body
		if label_3d:
			var is_mobile := SettingsManager != null and SettingsManager.is_mobile_controls_active()
			label_3d.text = "Pindah Ruangan (Tekan Aksi)" if is_mobile else "Pindah Ruangan [E]"
			label_3d.show()


func _on_body_exited(body: Node3D) -> void:
	if body == current_player:
		current_player = null
		if label_3d:
			label_3d.hide()


func teleport_player() -> void:
	if not marker_inside or not marker_outside or not current_player:
		print_rich("[color=red][PINTU][/color] Pastikan kedua marker sudah diisi di Inspector!")
		return

	# Urutan misi: setiap pintu ruangan terkunci sampai tugas sebelumnya selesai
	if not _door_gate_ok():
		_show_locked_notice()
		return

	var dist_to_inside = current_player.global_position.distance_to(marker_inside.global_position)
	var dist_to_outside = current_player.global_position.distance_to(marker_outside.global_position)

	# Tentukan apakah player masuk ke dalam atau keluar
	var is_entering_inside: bool = dist_to_outside < dist_to_inside
	var target_marker = marker_inside if is_entering_inside else marker_outside

	current_player.global_position = target_marker.global_position
	current_player.global_rotation.y = target_marker.global_rotation.y

	# Bawa Ona ikut berpindah ruangan (kalau ada di scene R1)
	var scene := get_tree().current_scene
	if scene:
		var ona := scene.find_child("Ona", true, false) as Node3D
		if ona and ona != current_player:
			ona.global_position = target_marker.global_position + Vector3(1.6, 0.0, 0.8)
			ona.global_rotation.y = target_marker.global_rotation.y

	_apply_room_lighting(is_entering_inside)

	# Ona ditahan diam di depan pintu selama berada di dalam ruangan misi
	var entering_room: bool = (target_marker == _inside_marker())
	GameManager.ona_hold_position = entering_room
	_play_room_intro(target_marker, entering_room)

func _inside_marker() -> Node3D:
	# Untuk GlassRoom, sisi "dalam" (Energy Core) ada di marker_outside
	if _room_key().contains("glass"):
		return marker_outside
	return marker_inside

func _play_room_intro(marker: Node3D, entering_room: bool) -> void:
	if not entering_room:
		return
	var room := _room_key()
	var already: bool = GameManager.room_intro_seen.get(room, false)
	GameManager.room_intro_seen[room] = true

	# Ona selalu diposisikan diam di depan pintu (dan tidak melayang)
	_position_ona_at_door(marker)

	if already:
		return
	if room.contains("crusher"):
		StoryManager.start_dialogue([
			"Rion: \"Ruangan ini... kok dipenuhi mesin penghancur raksasa?\"",
			"Ona: \"Betul, Rion. Ini Ruang Crusher — tempat kami menghancurkan barang yang sudah tidak terpakai atau rusak, lalu materialnya didaur ulang.\"",
			"Rion: \"Jadi ini tempat pembuangan sekaligus daur ulang... Serem tapi keren juga. Ayo nyalakan tuasnya!\""
		], "Rion")
	elif room.contains("onaprogram"):
		StoryManager.start_dialogue([
			"Rion: \"Ona... ruangan ini diberi nama Ona Program Room. Khusus untukmu ya?\"",
			"Ona: \"Iya, Rion. Di sinilah Tuan Rallux membuat dan memprogram diriku. Setiap log dan memori awalku lahir dari ruangan ini.\"",
			"Rion: \"Jadi ini rumah pertamamu... Terima kasih sudah menemaniku, Ona. Ayo kita hidupkan tuasnya.\""
		], "Rion")
	elif room.contains("glass"):
		StoryManager.start_dialogue([
			"Rion: \"Ruangan ini... banyak sekali kabel dan panel energinya.\"",
			"Ona: \"Ini Ruang Energy Core, sumber daya utama bengkel. Berhati-hatilah, Rion.\"",
			"Rion: \"Baik. Akan kuperiksa terminalnya.\""
		], "Rion")

func _position_ona_at_door(marker: Node3D) -> void:
	# Arah masuk ruangan = dari sisi luar ke sisi dalam pintu
	var inside := _inside_marker()
	var outside: Node3D = marker_inside if inside == marker_outside else marker_outside
	if outside == null:
		outside = marker
	var dir: Vector3 = inside.global_position - outside.global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = -marker.global_transform.basis.z
		dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = Vector3(0.0, 0.0, -1.0)
	dir = dir.normalized()
	var perp: Vector3 = Vector3(-dir.z, 0.0, dir.x)

	# Geser sedikit ke samping + masuk ke dalam ruangan supaya pintu tidak terhalang
	if current_player:
		current_player.global_position = marker.global_position + dir * 2.2
		_snap_to_ground(current_player)

	var scene := get_tree().current_scene
	var ona: Node3D = scene.find_child("Ona", true, false) if scene else null
	if ona and current_player:
		ona.global_position = current_player.global_position + perp * 2.0
		ona.rotation.y = atan2(-dir.x, -dir.z)
		_snap_to_ground(ona)
		if ona.has_method("play_animation"):
			ona.play_animation("idle")
	var rion_mesh = current_player.get_node_or_null("RionMesh") if current_player else null
	if rion_mesh:
		rion_mesh.rotation.y = atan2(dir.x, dir.z)

func _snap_to_ground(node: Node3D) -> void:
	# Cari permukaan lantai supaya Ona tidak melayang
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var from_pos: Vector3 = node.global_position + Vector3(0.0, 4.0, 0.0)
	var to_pos: Vector3 = node.global_position - Vector3(0.0, 8.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collision_mask = 1
	query.collide_with_areas = false
	var result: Dictionary = space.intersect_ray(query)
	if not result.is_empty():
		var p: Vector3 = node.global_position
		p.y = result["position"].y
		node.global_position = p

func _room_key() -> String:
	if name == "GlassRoom":
		return "glassroom"
	return get_parent().name.to_lower()

func _door_gate_ok() -> bool:
	var room := _room_key()
	if room.contains("crusher"):
		# Ruang Crusher: boleh masuk setelah Rak 1 selesai
		return GameManager.unpacking_rak1_done
	if room.contains("onaprogram"):
		# Ruang Ona Program: setelah Tuas Crusher selesai
		return GameManager.solved_levers.get("CrusherRoom_Lever", false)
	if room.contains("glass"):
		# Ruang Energy Core / Terminal: setelah Rak 1 + kedua tuas selesai
		return GameManager.unpacking_rak1_done \
			and GameManager.solved_levers.get("CrusherRoom_Lever", false) \
			and GameManager.solved_levers.get("OnaProgramRoom_Lever", false)
	return true

func _show_locked_notice() -> void:
	if label_3d:
		label_3d.text = "Terkunci"
		label_3d.show()
	if StoryManager == null or StoryManager.dialogue_box == null:
		return
	var room := _room_key()
	var lines: Array[String]
	if room.contains("crusher"):
		lines = [
			"Rion: \"Pintu Ruang Crusher masih terkunci. Sepertinya aku harus beresin Rak 1 dulu.\"",
			"Ona: \"Betul. Selesaikan dulu barang-barang yang berserakan sebelum masuk ke sini.\""
		]
	elif room.contains("onaprogram"):
		lines = [
			"Rion: \"Pintu Ona Program Room terkunci. Aku harus menyalakan Tuas di Ruang Crusher dulu ya?\"",
			"Ona: \"Iya, urutannya begitu. Daya ruanganku baru terbuka setelah Crusher menyala.\""
		]
	elif room.contains("glass"):
		lines = [
			"Rion: \"Pintu menuju Energy Core masih terkunci. Aku harus menyalakan tuas di Ruang Crusher dan Ona Program dulu.\"",
			"Ona: \"Betul. Ruang Energy Core baru bisa dibuka setelah sistem tuasnya aktif.\""
		]
	else:
		lines = ["Rion: \"Pintu ini masih terkunci.\""]
	StoryManager.start_dialogue(lines, "Rion")


func _apply_room_lighting(is_inside: bool) -> void:
	if not world_environment or not world_environment.environment:
		return

	# Jika ruangan sudah dibuka via tuas, saat masuk jangan digelapkan
	if is_inside and is_room_unlocked:
		return

	var target_energy = inside_ambient_energy if is_inside else outside_ambient_energy
	var tween = create_tween()
	tween.tween_property(world_environment.environment, "ambient_light_energy", target_energy, 0.4)
