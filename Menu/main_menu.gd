extends Control

@export_group("References")
@export var button_container: Container

@export_group("Scenes")
@export var game_scene: String = "res://LEV1.tscn"

@onready var new_game_btn: Button = $MenuContainer/NewGameBtn
@onready var load_btn: Button = $MenuContainer/LoadGameBtn
@onready var options_btn: Button = $MenuContainer/OptionsBtn
@onready var exit_btn: Button = $MenuContainer/ExitBtn

@onready var logo_rect: TextureRect = $Logo

const HOVER_COLOR: Color = Color(0.77, 0.26, 0.92)

func _ready() -> void:
	_start_logo_flip_animation()
	
	if Engine.is_editor_hint():
		return
	
	var buttons = [new_game_btn, load_btn, options_btn, exit_btn]
	for btn in buttons:
		if btn:
			_setup_button_hover(btn)
	
	new_game_btn.pressed.connect(_on_new_game)
	load_btn.pressed.connect(_on_load_game)
	options_btn.pressed.connect(_on_options)
	exit_btn.pressed.connect(_on_exit)
	
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

func _on_new_game() -> void:
	LoadingScreen.load_scene(game_scene)

func _on_load_game() -> void:
	LoadingScreen.load_scene(game_scene)

func _on_options() -> void:
	pass

func _on_exit() -> void:
	get_tree().quit()
