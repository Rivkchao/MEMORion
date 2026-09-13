# scenes/ui/ToBeContinueOverlay.gd
# Layar penutup "To Be Continue..." setelah semua misi R1 selesai.
# Dibuat murni dari kode agar tidak perlu mengubah file .tscn.
extends CanvasLayer

signal finished

@export var title_text: String = "To Be Continue..."
@export var fade_to_black_time: float = 1.2
@export var text_fade_time: float = 1.6
@export var hold_time: float = 4.0
@export var pause_game: bool = true
## Scene tujuan setelah layar penutup. Kosongkan untuk berhenti di layar ini saja.
@export_file("*.tscn") var next_scene: String = "res://Menu/main_menu.tscn"

var _black: ColorRect
var _label: Label
var _playing: bool = false

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _build_ui() -> void:
	_black = ColorRect.new()
	_black.name = "Black"
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.color = Color.BLACK
	_black.modulate.a = 0.0
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_black)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_label = Label.new()
	_label.name = "Title"
	_label.text = title_text
	_label.modulate.a = 0.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 72)
	_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_label.add_theme_constant_override("outline_size", 12)
	center.add_child(_label)

## Jalankan animasi penutup: fade ke hitam, lalu teks muncul.
func play() -> void:
	if _playing:
		return
	_playing = true

	if pause_game and get_tree() != null:
		get_tree().paused = true

	var fade_to_black := create_tween()
	fade_to_black.tween_property(_black, "modulate:a", 1.0, fade_to_black_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_to_black.finished

	var reveal := create_tween()
	reveal.tween_property(_label, "modulate:a", 1.0, text_fade_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await reveal.finished

	if get_tree() != null:
		# process_always = true supaya timer tetap jalan walau tree di-pause.
		await get_tree().create_timer(hold_time, true).timeout

	finished.emit()

	# Setelah layar penutup selesai, lanjut ke scene berikutnya (default: main menu).
	if not next_scene.is_empty():
		await _go_to_next_scene()

## Pindah ke next_scene memakai LoadingScreen bila tersedia.
func _go_to_next_scene() -> void:
	var tree := get_tree()
	if tree == null:
		queue_free()
		return

	# Wajib unpause dulu agar LoadingScreen (PAUSABLE) bisa menjalankan tween-nya.
	if pause_game:
		tree.paused = false

	var loading := tree.root.get_node_or_null("LoadingScreen")
	if loading != null and loading.has_method("load_scene"):
		loading.load_scene(next_scene)
		# Biarkan fade LoadingScreen menutupi layar sebelum overlay dilepas.
		await tree.create_timer(0.6).timeout
		queue_free()
	else:
		tree.change_scene_to_file(next_scene)
		queue_free()

## Sembunyikan layar penutup dan lanjutkan game (dipakai bila perlu lanjut bermain).
func dismiss() -> void:
	var tween := create_tween()
	tween.tween_property(_black, "modulate:a", 0.0, 0.6)
	await tween.finished
	if pause_game and get_tree() != null:
		get_tree().paused = false
	queue_free()
