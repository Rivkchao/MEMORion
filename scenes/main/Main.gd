extends Node3D

func _ready() -> void:
	# Cari node WirePuzzle & HUD secara dinamis
	var wire_puzzle_node = find_child("WirePuzzle", true, false)
	var dialogue_node = find_child("DialogueBox", true, false)
	if dialogue_node == null:
		dialogue_node = find_child("HUD", true, false)
	
	# Inisialisasi ke StoryManager
	StoryManager.init(dialogue_node, null, wire_puzzle_node)
	
	# Jalankan intro roket HANYA jika scene ini memiliki roket & kamera roket
	if has_node("RocketCamera") and has_node("RionCapsule/AnimationPlayer"):
		_play_rocket_intro()

func _play_rocket_intro() -> void:
	var rocket_cam: Camera3D = get_node_or_null("RocketCamera")
	var anim_player: AnimationPlayer = get_node_or_null("RionCapsule/AnimationPlayer")
	var player = find_child("Player", true, false)
	var camera_rig = find_child("CameraRig", true, false)
	var hud = find_child("HUD", true, false)
	
	# Cari kamera player di dalam CameraRig secara otomatis
	var player_cam: Camera3D = null
	if camera_rig:
		player_cam = camera_rig.find_child("*Camera*", true, false) as Camera3D

	# 1. Nonaktifkan kontrol player & HUD
	if player:
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
	if camera_rig:
		camera_rig.set_process(false)
		camera_rig.set_process_unhandled_input(false)
	if hud:
		hud.visible = false

	# 2. Pindah ke kamera sinematik roket
	if rocket_cam:
		rocket_cam.make_current()

	# 3. Putar animasi dan tunggu hingga tuntas
	if anim_player:
		anim_player.play("Kehancuran")
		await anim_player.animation_finished

	# 4. Kembalikan kamera dan pulihkan kontrol pemain
	if player_cam:
		player_cam.make_current()
	if player:
		player.set_physics_process(true)
		player.set_process_unhandled_input(true)
	if camera_rig:
		camera_rig.set_process(true)
		camera_rig.set_process_unhandled_input(true)
	if hud:
		hud.visible = true
