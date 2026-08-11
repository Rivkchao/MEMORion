extends Control

@onready var new_game_btn: Button = $ButtonContainer/NewGameButton
@onready var load_game_btn: Button = $ButtonContainer/LoadGameButton
@onready var settings_btn: Button = $ButtonContainer/SettingsButton
@onready var quit_btn: Button = $ButtonContainer/QuitButton

const GAME_SCENE = "res://scenes/main/Main.tscn"

func _ready() -> void:
	new_game_btn.pressed.connect(_on_new_game)
	load_game_btn.pressed.connect(_on_load_game)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	
	# Animasi masuk
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 1.0)

func _on_new_game() -> void:
	_transition_to(GAME_SCENE)

func _on_load_game() -> void:
	# TODO: M9 Save/Load
	pass

func _on_settings() -> void:
	# TODO: Settings panel
	pass

func _on_quit() -> void:
	get_tree().quit()

func _transition_to(scene_path: String) -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): get_tree().change_scene_to_file(scene_path))
