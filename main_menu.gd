@tool
extends Control

@export_group("Menu Theme")
@export var font_size: int = 24:
	set(value):
		font_size = value
		_apply_styling()
@export var default_color: Color = Color.WHITE:
	set(value):
		default_color = value
		_apply_styling()
@export var highlight_color: Color = Color("4aa3df"):
	set(value):
		highlight_color = value
		_apply_styling()
@export var custom_font: Font:
	set(value):
		custom_font = value
		_apply_styling()

@export_group("References")
@export var button_container: Container

@export_group("Scenes")
@export var game_scene: String = "res://scenes/main/Main.tscn"

@onready var new_game_btn: Button = $MenuContainer/NewGameBtn
@onready var load_btn: Button = $MenuContainer/LoadGameBtn
@onready var options_btn: Button = $MenuContainer/OptionsBtn
@onready var exit_btn: Button = $MenuContainer/ExitBtn

func _ready() -> void:
	_apply_styling()
	
	if Engine.is_editor_hint():
		return
	
	# Connect tombol
	new_game_btn.pressed.connect(_on_new_game)
	load_btn.pressed.connect(_on_load_game)
	options_btn.pressed.connect(_on_options)
	exit_btn.pressed.connect(_on_exit)
	
	# Animasi fade in
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8)

func _on_new_game() -> void:
	LoadingScreen.load_scene(game_scene)

func _on_load_game() -> void:
	# TODO: M9 Save/Load
	# Sementara langsung load game scene
	LoadingScreen.load_scene(game_scene)

func _on_options() -> void:
	# TODO: Settings panel
	pass

func _on_exit() -> void:
	get_tree().quit()

func _apply_styling() -> void:
	if not button_container:
		return
	
	var style_empty = StyleBoxEmpty.new()
	var style_focus = StyleBoxFlat.new()
	style_focus.bg_color = Color(highlight_color.r, highlight_color.g, highlight_color.b, 0.15)
	style_focus.border_color = highlight_color
	style_focus.border_width_left = 4
	style_focus.content_margin_left = 12
	style_focus.content_margin_top = 4
	style_focus.content_margin_bottom = 4
	
	for child in button_container.get_children():
		if child is Button:
			child.add_theme_stylebox_override("normal", style_empty)
			child.add_theme_stylebox_override("hover", style_focus)
			child.add_theme_stylebox_override("focus", style_focus)
			child.add_theme_stylebox_override("pressed", style_focus)
			child.add_theme_color_override("font_color", default_color)
			child.add_theme_color_override("font_hover_color", highlight_color)
			child.add_theme_color_override("font_focus_color", highlight_color)
			child.add_theme_color_override("font_outline_color", Color.BLACK)
			child.add_theme_constant_override("outline_size", 4)
			child.add_theme_font_size_override("font_size", font_size)
			if custom_font:
				child.add_theme_font_override("font", custom_font)
			child.alignment = HORIZONTAL_ALIGNMENT_LEFT
