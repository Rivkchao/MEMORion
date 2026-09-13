extends Control

@export_group("References")
@export var button_container: Container

@export_group("Scenes")
@export var game_scene: String = "res://LEV1.tscn"
@export var auth_scene: String = "res://Menu/AuthScreen.tscn"

@onready var mulai_game_btn: Button = $MenuContainer/MulaiGameBtn
@onready var muat_game_btn: Button = $MenuContainer/MuatGameBtn
@onready var lanjut_game_btn: Button = $MenuContainer/LanjutGameBtn
@onready var pengaturan_btn: Button = $MenuContainer/PengaturanBtn
@onready var keluar_btn: Button = $MenuContainer/KeluarBtn
@onready var instagram_btn: Button = $InstagramBtn

@onready var logo_rect: TextureRect = $Logo
@onready var frame_menu: TextureRect = $FrameMenu
@onready var bg_btn: TextureRect = $BgBtn
@onready var planet: Sprite2D = $Planet
@onready var sprite_bar: Sprite2D = $SpriteBar
@onready var logo2: TextureRect = $Logo2
@onready var greeting_label: Label = $Label
@onready var menu_container: Control = $MenuContainer

const HOVER_COLOR: Color = Color(0.77, 0.26, 0.92)
const INSTAGRAM_URL: String = "https://www.instagram.com/memorion.plus"
const MENU_BGM = preload("res://assets/audio/bgm/meditation_main.mp3")

func _ready() -> void:
	# Pastikan game tidak dalam kondisi pause saat kembali ke menu.
	get_tree().paused = false
	if get_viewport():
		get_viewport().size_changed.connect(_apply_responsive_layout)
	_start_logo_flip_animation()
	_apply_responsive_layout()
	
	if AudioManager:
		AudioManager.play_bgm(MENU_BGM, 1.5, -4.0)

	if Engine.is_editor_hint():
		return
	
	var buttons = [mulai_game_btn, muat_game_btn, lanjut_game_btn, pengaturan_btn, keluar_btn, instagram_btn]
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_layout()

func _apply_responsive_layout() -> void:
	var vp_size = get_viewport_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return
	
	# 1. Responsif FrameMenu (Texture portrait diputar -90 deg agar menutup seluruh layar di segala rasio)
	if frame_menu:
		frame_menu.rotation = -PI / 2.0
		frame_menu.position = Vector2(0, vp_size.y)
		frame_menu.size = Vector2(vp_size.y, vp_size.x)
	
	# 2. Responsif Planet & Hiasan Kanan
	if planet:
		planet.position = Vector2(vp_size.x - 240.0, vp_size.y * 0.44)
	if sprite_bar:
		sprite_bar.position = Vector2(vp_size.x - 171.0, vp_size.y - 123.0)
	
	# 3. Responsif Menu Card (BgBtn) dan Tombol Menu
	# Menghitung posisi proporsional di kiri layar agar cocok di rasio 16:9, 18:9, 19.5:9, 20:9, 21:9, maupun 4:3
	if bg_btn:
		var card_left = clampf(vp_size.x * 0.11, 80.0, 320.0)
		bg_btn.position.x = card_left
		bg_btn.position.y = clampf((vp_size.y - bg_btn.size.y) * 0.5 + 15.0, 100.0, 300.0)
		if menu_container:
			menu_container.position.x = card_left + 232.0
			menu_container.position.y = bg_btn.position.y + 46.0

func _setup_button_hover(btn: Button) -> void:
	# Ambil warna teks bawaan (font_color) yang sudah diatur di Inspector/Theme
	var default_color: Color = btn.get_theme_color("font_color")
	btn.set_meta("default_font_color", default_color)
	btn.pivot_offset = btn.size / 2.0
	
	# Sambungkan signal hover in dan hover out
	btn.mouse_entered.connect(func():
		btn.add_theme_color_override("font_color", HOVER_COLOR)
		btn.add_theme_color_override("font_hover_color", HOVER_COLOR)
		if AudioManager:
			AudioManager.play_ui_hover()
	)
	
	btn.mouse_exited.connect(func():
		var original_color = btn.get_meta("default_font_color")
		btn.add_theme_color_override("font_color", original_color)
		btn.add_theme_color_override("font_hover_color", original_color)
	)

	# Sentuhan responsif pada mobile & klik mouse
	btn.button_down.connect(func():
		btn.add_theme_color_override("font_color", HOVER_COLOR)
		if AudioManager:
			AudioManager.play_ui_click()
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.08).set_ease(Tween.EASE_OUT)
	)
	
	btn.button_up.connect(func():
		var original_color = btn.get_meta("default_font_color")
		btn.add_theme_color_override("font_color", original_color)
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
	if AudioManager:
		AudioManager.play_ui_confirm()
	_open_auth()

func _on_muat_game() -> void:
	if AudioManager:
		AudioManager.play_ui_confirm()
	_open_auth()

func _on_lanjut_game() -> void:
	if AudioManager:
		AudioManager.play_ui_confirm()
	_open_auth()

## Semua tombol mulai masuk lewat layar login/registrasi dulu (main menu -> auth -> LEV1).
func _open_auth() -> void:
	LoadingScreen.load_scene(auth_scene)

func _on_pengaturan() -> void:
	SettingsManager.open_settings_dialog(self)

func _on_keluar() -> void:
	get_tree().quit()

func _on_instagram() -> void:
	OS.shell_open(INSTAGRAM_URL)

