extends Interactable

@onready var omni_light_1: OmniLight3D = $OmniLight3D
@onready var omni_light_2: OmniLight3D = $OmniLight3D2
	
@export var flicker_min_energy: float = 200.0
@export var flicker_max_energy: float = 500.0
@export var flicker_speed: float = 0.2

@export var solved_color: Color = Color(0.2, 1.0, 0.3) # Hijau
@export var solved_energy: float = 100.0

var _flicker_timer: float = 0.0
var _puzzle_solved: bool = false

func _ready() -> void:
	super._ready()
	interact_label = "Gunakan Terminal"
	StoryManager.wire_puzzle_completed.connect(_on_wire_puzzle_completed)
	
	if GameManager.terminal_puzzle_done:
		_puzzle_solved = true
		omni_light_1.light_color = solved_color
		omni_light_1.light_energy = solved_energy
		omni_light_2.light_color = solved_color
		omni_light_2.light_energy = solved_energy
		interact_label = ""
	else:
		_update_power_lights()

func _ona_lever_done() -> bool:
	return GameManager.solved_levers.get("OnaProgramRoom_Lever", false)

func _levers_done() -> bool:
	return GameManager.unpacking_rak1_done \
		and GameManager.solved_levers.get("CrusherRoom_Lever", false) \
		and _ona_lever_done()

func _update_power_lights() -> void:
	if _puzzle_solved:
		return
	# Selama tuas Ona Program belum 100%, lampu merah terminal dimatikan
	var on := _ona_lever_done()
	if omni_light_1:
		omni_light_1.visible = on
	if omni_light_2:
		omni_light_2.visible = on

func _process(delta: float) -> void:
	if _puzzle_solved:
		return
	if not _ona_lever_done():
		_update_power_lights()
		return
	if omni_light_1 and not omni_light_1.visible:
		omni_light_1.visible = true
		omni_light_2.visible = true
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		var energy = randf_range(flicker_min_energy, flicker_max_energy)
		omni_light_1.light_energy = energy
		omni_light_2.light_energy = energy * 0.8
		_flicker_timer = flicker_speed

func interact() -> void:
	if _puzzle_solved:
		return
	if not _levers_done():
		if StoryManager and StoryManager.has_method("start_dialogue"):
			StoryManager.start_dialogue([
				"Rion: \"Terminalnya masih gelap total... sepertinya sumber dayanya belum tersambung.\"",
				"Ona: \"Kita harus menyalakan tuas di Ruang Crusher dan Ona Program dulu sebelum terminal ini bisa hidup.\""
			], "Rion")
		return
	_play_terminal_emergency()

func _play_terminal_emergency() -> void:
	# Efek kedip merah tipis menandakan kegawatan sumber listrik
	var layer := CanvasLayer.new()
	layer.layer = 110
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = Color(1.0, 0.1, 0.1, 0.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	add_child(layer)
	var flash := create_tween().set_loops(5)
	flash.tween_property(rect, "color:a", 0.16, 0.25)
	flash.tween_property(rect, "color:a", 0.0, 0.25)

	var emergency: Array[String] = [
		"Ona: \"Rion, awas! Sensor mendeteksi lonjakan tegangan di ruang energi!\"",
		"Rion: \"Lonjakan tegangan?! Sumber listriknya kenapa, Ona?!\"",
		"Ona: \"Kabel penghubung inti terlepas. Kalau tidak segera dibenerin, seluruh bengkel bisa mati total!\"",
		"Rion: \"Tenang, aku akan sambungkan kembali kabelnya. Bantu aku mengarahkan, Ona!\""
	]
	StoryManager.start_dialogue(emergency, "Ona")
	await StoryManager.dialogue_finished

	if flash:
		flash.kill()
	if is_instance_valid(layer):
		layer.queue_free()
	StoryManager.start_wire_puzzle()

func _on_wire_puzzle_completed(is_correct: bool) -> void:
	if is_correct and not _puzzle_solved:
		_puzzle_solved = true
		omni_light_1.light_color = solved_color
		omni_light_1.light_energy = solved_energy
		omni_light_2.light_color = solved_color
		omni_light_2.light_energy = solved_energy
		interact_label = ""

		# Dramatisasi dialog setelah terminal berhasil dinyalakan (kembali tenang)
		if StoryManager and StoryManager.has_method("start_dialogue"):
			var lines: Array[String] = [
				"Rion: \"Layar terminalnya menyala! Sistem ruang energi mulai membaca ulang data.\"",
				"Ona: \"Sambungan kabelnya sudah tepat. Tegangan stabil kembali, Rion.\"",
				"Ona: \"Lihat... lampu-lampunya tenang lagi. Semua baik-baik saja sekarang. Terima kasih sudah sigap.\""
			]
			StoryManager.start_dialogue(lines, "Rion")
			await StoryManager.dialogue_finished
		# Setelah dialog tenang selesai, baru buka Rak 2
		GameManager.terminal_puzzle_done = true
