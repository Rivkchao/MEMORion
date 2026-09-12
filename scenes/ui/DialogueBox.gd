extends CanvasLayer

@onready var name_label: Label = $PanelContainer/MarginContainer/VBoxContainer/NameLabel
@onready var dialogue_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DialogueLabel
@onready var continue_label: Label = $ContinueLabel
@onready var avatar: TextureRect = $TextureRect
@export var avatar_happy: Texture2D
@export var avatar_kagum: Texture2D

const MAX_LINES: int = 4

var lines: Array[String] = []
var current_line: int = 0
var is_typing: bool = false
var speaker_name: String = ""

# Menggunakan tween agar kecepatan ketik stabil
var _type_tween: Tween

@export var char_per_second: float = 35.0 # Kecepatan ketik (35 huruf per detik)

var magic_time: float = 0.0
signal dialogue_finished
signal dialogue_started

func _ready() -> void:
	hide()
	dialogue_label.max_lines_visible = MAX_LINES
	dialogue_label.lines_skipped = 0

func _process(delta: float) -> void:
	if visible:
		magic_time += delta
		var shimmer = (sin(magic_time * 3.0) + 1.0) / 2.0
		var base_color = Color(0.8, 0.6, 1, 1)
		var shimmer_color = Color(1.0, 0.8, 1.0, 1)
		name_label.modulate = base_color.lerp(shimmer_color, shimmer * 0.3)
		
		var glow = (sin(magic_time * 2.0) + 1.0) / 2.0
		dialogue_label.modulate = Color(1.0, 0.95, 1.0, 1.0).lerp(Color(0.9, 0.85, 1.0, 1.0), glow * 0.2)

func start(dialogue_lines: Array[String], npc_name: String = "", avatar_texture: Texture2D = null) -> void:
	lines = dialogue_lines
	speaker_name = npc_name
	current_line = 0
	name_label.text = speaker_name
	if avatar_texture:
		avatar.texture = avatar_texture
	continue_label.hide()
	show()
	_show_line()
	dialogue_started.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		get_viewport().set_input_as_handled()
		next()

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		get_viewport().set_input_as_handled()
		next()

func _show_line() -> void:
	dialogue_label.lines_skipped = 0
	var raw_text: String = lines[current_line].strip_edges()
	var current_speaker: String = speaker_name
	var display_text: String = raw_text

	if raw_text.begins_with("Ona:"):
		current_speaker = "Ona"
		display_text = raw_text.substr(4).strip_edges()
		name_label.modulate = Color(0.85, 0.55, 1.0, 1.0)
		avatar.visible = true
	elif raw_text.begins_with("Rion:"):
		current_speaker = "Rion"
		display_text = raw_text.substr(5).strip_edges()
		name_label.modulate = Color(0.4, 0.85, 1.0, 1.0)
		avatar.visible = true
	elif raw_text.begins_with("Rallux:") or raw_text.begins_with("Rallux (") or raw_text.begins_with("Rallux:"):
		current_speaker = "Rallux"
		var colon_idx = raw_text.find(":")
		if colon_idx != -1:
			display_text = raw_text.substr(colon_idx + 1).strip_edges()
		else:
			display_text = raw_text.substr(6).strip_edges()
		name_label.modulate = Color(1.0, 0.65, 0.2, 1.0) # Orange / warm amber
		avatar.visible = false
	elif raw_text == "TANG! KLATAK!" or raw_text.begins_with("TANG!") or raw_text.begins_with("*Suara"):
		current_speaker = "Efek Suara"
		display_text = raw_text
		name_label.modulate = Color(1.0, 0.8, 0.2, 1.0)
		avatar.visible = false
	elif raw_text.begins_with("[SISTEM ONA]") or raw_text.begins_with("*[SISTEM ONA]*"):
		current_speaker = "[SISTEM ONA]"
		if raw_text.begins_with("[SISTEM ONA]"):
			display_text = raw_text.substr(12).strip_edges()
		else:
			display_text = raw_text.substr(14).strip_edges()
		name_label.modulate = Color(0.2, 1.0, 0.8, 1.0)
		avatar.visible = false
	elif raw_text.begins_with("_(") or raw_text.begins_with("(") or raw_text.begins_with("*"):
		current_speaker = "Catatan"
		display_text = raw_text
		name_label.modulate = Color(0.75, 0.75, 0.85, 1.0)
		avatar.visible = false
	else:
		name_label.modulate = Color(0.85, 0.6, 1.0, 1.0)
		avatar.visible = true

	# Bersihkan tanda kutip pembungkus jika ada
	if display_text.begins_with("\"") and display_text.ends_with("\"") and display_text.length() > 2:
		display_text = display_text.substr(1, display_text.length() - 2)

	name_label.text = current_speaker
	dialogue_label.text = display_text
	_start_typewriter_for_current_view()

func _start_typewriter_for_current_view() -> void:
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()

	is_typing = true
	continue_label.hide()
	dialogue_label.visible_ratio = 0.0

	# Hitung durasi mengetik berdasarkan panjang teks
	var text_len = dialogue_label.text.length()
	var duration = text_len / char_per_second

	_type_tween = create_tween()
	_type_tween.tween_property(dialogue_label, "visible_ratio", 1.0, duration)
	_type_tween.finished.connect(_on_typing_done)

func _on_typing_done() -> void:
	is_typing = false
	dialogue_label.visible_ratio = 1.0
	continue_label.show()

func next() -> void:
	# 1. Jika teks sedang mengetik: instan tuntaskan tampilan
	if is_typing:
		if _type_tween and _type_tween.is_valid():
			_type_tween.kill()
		_on_typing_done()
		return
	
	if AudioManager:
		AudioManager.play_dialogue_blip()

	# 2. Jika masih ada baris sisa di bawahnya:
	var total_lines = dialogue_label.get_line_count()
	if dialogue_label.lines_skipped + MAX_LINES < total_lines:
		dialogue_label.lines_skipped += MAX_LINES
		# Langsung tampilkan penuh halaman sambungan tanpa jeda mengetik ulang
		dialogue_label.visible_ratio = 1.0
		is_typing = false
		continue_label.show()
		return
	
	# 3. Pindah ke dialog/orang berikutnya (efek tik jalan kembali dari awal)
	current_line += 1
	if current_line < lines.size():
		_show_line()
	else:
		hide()
		dialogue_finished.emit()

func set_avatar_by_emotion(emotion_name: String) -> void:
	match emotion_name.to_lower():
		"kagum":
			if avatar_kagum:
				avatar.texture = avatar_kagum
		"happy", "senang":
			if avatar_happy:
				avatar.texture = avatar_happy
		_:
			# Default fallback ke happy
			if avatar_happy:
				avatar.texture = avatar_happy

func is_active() -> bool:
	return visible
