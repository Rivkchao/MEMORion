extends Control

@export_group("References")
@export var button_container: Container

@export_group("Scenes")
@export var game_scene: String = "res://LEV1.tscn"

@onready var mulai_game_btn: Button = $MenuContainer/MulaiGameBtn
@onready var muat_game_btn: Button = $MenuContainer/MuatGameBtn
@onready var lanjut_game_btn: Button = $MenuContainer/LanjutGameBtn
@onready var pengaturan_btn: Button = $MenuContainer/PengaturanBtn
@onready var keluar_btn: Button = $MenuContainer/KeluarBtn
@onready var instagram_btn: Button = $InstagramBtn

@onready var logo_rect: TextureRect = $Logo

const HOVER_COLOR: Color = Color(0.77, 0.26, 0.92)
const INSTAGRAM_URL: String = "https://www.instagram.com/memorion.plus"

func _ready() -> void:
	_start_logo_flip_animation()
	
	if Engine.is_editor_hint():
		return
	
	var buttons = [mulai_game_btn, muat_game_btn, lanjut_game_btn, pengaturan_btn, keluar_btn]
	for btn in buttons:
		if btn:
			_setup_button_hover(btn)
	
	mulai_game_btn.pressed.connect(_on_mulai_game)
	muat_game_btn.pressed.connect(_on_muat_game)
	lanjut_game_btn.pressed.connect(_on_lanjut_game)
	pengaturan_btn.pressed.connect(_on_pengaturan)
	keluar_btn.pressed.connect(_on_keluar)
	instagram_btn.pressed.connect(_on_instagram)
	
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8)

func _setup_button_hover(btn: Button) -> void:
	# Ambil warna teks bawaan (font_color) yang sudah diatur di Inspector/Theme
	var default_color: Color = btn.get_theme_color("font_color")
	
	# Simpan warna aslinya ke metadata tombol
	btn.set_meta("default_font_color", default_color)
	
	# Sambungkan signal hover in dan hover out
	btn.mouse_entered.connect(func():
		btn.add_theme_color_override("font_color", HOVER_COLOR)
		btn.add_theme_color_override("font_hover_color", HOVER_COLOR)
	)
	
	btn.mouse_exited.connect(func():
		var original_color = btn.get_meta("default_font_color")
		btn.add_theme_color_override("font_color", original_color)
		btn.add_theme_color_override("font_hover_color", original_color)
	)

func _start_logo_flip_animation() -> void:
	logo_rect.pivot_offset = logo_rect.size / 2.0
	
	var flip_tween = create_tween().set_loops()
	
	flip_tween.tween_interval(3.0)
	flip_tween.tween_property(logo_rect, "scale:x", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flip_tween.tween_property(logo_rect, "scale:x", -1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flip_tween.tween_property(logo_rect, "scale:x", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flip_tween.tween_property(logo_rect, "scale:x", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_mulai_game() -> void:
	LoadingScreen.load_scene(game_scene)

func _on_muat_game() -> void:
	LoadingScreen.load_scene(game_scene)

func _on_lanjut_game() -> void:
	LoadingScreen.load_scene(game_scene)

func _on_pengaturan() -> void:
	pass

func _on_keluar() -> void:
	get_tree().quit()

func _on_instagram() -> void:
	OS.shell_open(INSTAGRAM_URL)
