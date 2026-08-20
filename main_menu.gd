extends Control

@export_group("References")
@export var button_container: Container

@export_group("Scenes")
@export var game_scene: String = "res://scenes/main/Main.tscn"

@onready var new_game_btn: Button = $MenuContainer/NewGameBtn
@onready var load_btn: Button = $MenuContainer/LoadGameBtn
@onready var options_btn: Button = $MenuContainer/OptionsBtn
@onready var exit_btn: Button = $MenuContainer/ExitBtn

@onready var logo_rect: TextureRect = $Logo

func _ready() -> void:
	_start_logo_flip_animation()
	
	if Engine.is_editor_hint():
		return
	
	# Connect signal tombol klik
	new_game_btn.pressed.connect(_on_new_game)
	load_btn.pressed.connect(_on_load_game)
	options_btn.pressed.connect(_on_options)
	exit_btn.pressed.connect(_on_exit)
	
	# Animasi fade in menu awal
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8)

func _start_logo_flip_animation() -> void:
	logo_rect.pivot_offset = logo_rect.size / 2.0
	
	var flip_tween = create_tween().set_loops()
	
	# Jeda diam 3 detik
	flip_tween.tween_interval(3.0)
	
	# Putar 360 derajat (Flip horizontal)
	flip_tween.tween_property(logo_rect, "scale:x", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flip_tween.tween_property(logo_rect, "scale:x", -1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flip_tween.tween_property(logo_rect, "scale:x", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flip_tween.tween_property(logo_rect, "scale:x", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_new_game() -> void:
	LoadingScreen.load_scene(game_scene)

func _on_load_game() -> void:
	# TODO: M9 Save/Load
	LoadingScreen.load_scene(game_scene)

func _on_options() -> void:
	# TODO: Settings panel
	pass

func _on_exit() -> void:
	get_tree().quit()
