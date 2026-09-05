extends Node3D

@export var hold_time := 3.0
@export var lever_light: OmniLight3D
@export var world_environment: WorldEnvironment
@export var door_node: Area3D
@export var interact_distance := 6.0
@export var bright_ambient_energy := 0.7

@export_group("Lever Animation")
@export var lever_handle: Node3D
@export var target_down_angle: float = -120.0

@onready var progress_label: Label3D = $ProgressLabel

var holding := false
var progress := 0.0
var completed := false
var initial_rot_z: float = 0.0
var player_node: Node3D = null

# Timer interval agar Output tidak spam setiap frame
var debug_timer: float = 0.0


func _ready() -> void:
	print_rich("[color=cyan]=== INITIALIZING LEVER (%s) ===[/color]" % name)

	if progress_label:
		progress_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		progress_label.no_depth_test = true
		progress_label.visible = false
	else:
		print_rich("[color=red][LEVER ERROR][/color] Child node 'ProgressLabel' tidak ditemukan!")

	if lever_light:
		lever_light.visible = true

	if lever_handle:
		initial_rot_z = lever_handle.rotation_degrees.z
		print("[LEVER] Handle terpasang di: ", lever_handle.name)
	else:
		print_rich("[color=yellow][LEVER WARNING][/color] 'lever_handle' belum dimasukkan di Inspector!")

	if not door_node:
		print_rich("[color=yellow][LEVER WARNING][/color] 'door_node' belum dimasukkan di Inspector!")

	var lever_id := get_parent().name + "_" + name
	if GameManager.solved_levers.get(lever_id, false):
		completed = true
		progress = 1.0
		if lever_handle:
			lever_handle.rotation_degrees.z = initial_rot_z + target_down_angle
		if lever_light:
			lever_light.visible = false
		if progress_label:
			progress_label.visible = false
		if door_node and "is_room_unlocked" in door_node:
			door_node.is_room_unlocked = true


func _process(delta: float) -> void:
	# Cek apakah ruangan sudah terbuka
	var is_unlocked: bool = false
	if door_node and "is_room_unlocked" in door_node:
		is_unlocked = door_node.is_room_unlocked

	if completed or is_unlocked:
		if lever_handle:
			lever_handle.rotation_degrees.z = initial_rot_z + target_down_angle
		if lever_light:
			lever_light.visible = false
		if progress_label:
			progress_label.visible = false
		return

	# Cari player jika belum ada
	if player_node == null:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_node = players[0]
			print_rich("[color=green][LEVER][/color] Player ditemukan via Group 'player': ", player_node.name)
		else:
			player_node = get_tree().root.find_child("Player", true, false)
			if player_node:
				print_rich("[color=yellow][LEVER][/color] Player ditemukan via nama node fallback: ", player_node.name)

	# Jika player tetap tidak ditemukan sama sekali
	if player_node == null:
		debug_timer += delta
		if debug_timer >= 2.0:
			print_rich("[color=red][LEVER GAGAL][/color] Player tidak terdeteksi! Pastikan Player ada di scene dan masuk group 'player'.")
			debug_timer = 0.0
		return

	# Ambil koordinat titik fisik tuas
	var switch_pos: Vector3 = lever_handle.global_position if lever_handle else global_position
	var player_pos: Vector3 = player_node.global_position
	var dist: float = switch_pos.distance_to(player_pos)
	var is_near: bool = dist <= interact_distance

	# Cek input tombol E / action
	var e_pressed = Input.is_key_pressed(KEY_E)
	var action_pressed = Input.is_action_pressed("interact") if InputMap.has_action("interact") else false
	var key_active = e_pressed or action_pressed

	# Log debug saat tombol ditekan
	if key_active:
		debug_timer += delta
		if debug_timer >= 0.5:
			print_rich("[color=white][DEBUG INPUT][/color] Tombol E DITEKAN | Tuas: %s | Jarak ke Player: [b]%.2f meter[/b] (Batas: %.2f) | Dekat? [b]%s[/b]" % [name, dist, interact_distance, str(is_near)])
			debug_timer = 0.0

	# Tampilan teks saat player mendekat
	if is_near and not holding and progress == 0.0:
		if progress_label:
			progress_label.text = "[E] TAHAN"
			progress_label.visible = true
	elif not is_near and not holding:
		if progress_label and progress == 0.0:
			progress_label.visible = false

	# Logika menahan tuas
	if is_near and key_active:
		if not holding:
			print_rich("[color=green][LEVER][/color] Mulai menarik tuas...")
		holding = true
		progress += delta / hold_time
		progress = clamp(progress, 0.0, 1.0)

		if progress_label:
			progress_label.visible = true
			progress_label.text = str(int(progress * 100.0)) + "%"

		if lever_handle:
			lever_handle.rotation_degrees.z = lerp(initial_rot_z, initial_rot_z + target_down_angle, progress)

		if progress >= 1.0:
			complete_lever()
	else:
		if holding:
			print_rich("[color=orange][LEVER][/color] Tombol dilepas sebelum 100%, kembali turun.")
		holding = false
		if progress > 0.0:
			progress = move_toward(progress, 0.0, delta * 2.0)
			if lever_handle:
				lever_handle.rotation_degrees.z = lerp(initial_rot_z, initial_rot_z + target_down_angle, progress)
			if progress_label:
				progress_label.text = str(int(progress * 100.0)) + "%"
				if progress <= 0.0:
					progress_label.text = "[E] TAHAN"


func complete_lever() -> void:
	completed = true
	holding = false
	progress = 1.0
	var lever_id := get_parent().name + "_" + name
	GameManager.solved_levers[lever_id] = true
	print_rich("[color=green][LEVER SELESAI][/color] 100%% tercapai! Menyalakan lampu...")

	if progress_label:
		progress_label.text = "100%"

	if lever_handle:
		lever_handle.rotation_degrees.z = initial_rot_z + target_down_angle

	if door_node and "is_room_unlocked" in door_node:
		door_node.is_room_unlocked = true

	if world_environment and world_environment.environment:
		var tween := create_tween()
		tween.tween_property(world_environment.environment, "ambient_light_energy", bright_ambient_energy, 1.2)

	var light_tween := create_tween()
	light_tween.tween_interval(1.0)
	light_tween.tween_callback(func():
		if lever_light:
			lever_light.visible = false
		if progress_label:
			progress_label.visible = false
	)
	
	var is_crusher := "crusher" in get_parent().name.to_lower()
	var frag_key := "lever_crusher" if is_crusher else "lever_onaprogram"
	var dialogue_text := "Daya Ruang Crusher aktif kembali! Mesin-mesin mulai menyala!" if is_crusher else "Ruang Program Ona telah aktif! Sistem komputer mulai membaca data!"

	if StoryManager.dialogue_box != null:
		StoryManager.dialogue_box.set_avatar_by_emotion("kagum")
		StoryManager.start_dialogue([dialogue_text], "Rion")
		await StoryManager.dialogue_finished
		if not GameManager.collected_fragments.get(frag_key, false):
			await FragmentBox.show_fragment(frag_key)
