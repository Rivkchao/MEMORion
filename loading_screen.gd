# autoload/LoadingScreen.gd
extends CanvasLayer

@onready var fade_rect: ColorRect = $FadeRect
@onready var panel: Control = $Panel
@onready var animated_sprite: AnimatedSprite2D = $Panel/AnimatedSprite2D
@onready var loading_label: Label = $Panel/LoadingLabel
@onready var progress_bar: ProgressBar = $Panel/ProgressBar

var target_scene: String = ""

func _ready() -> void:
	layer = 10
	fade_rect.color = Color(0, 0, 0, 0)
	panel.hide()

func load_scene(scene_path: String) -> void:
	target_scene = scene_path
	_fade_out()

func _fade_out() -> void:
	# Fade to black dulu
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.5)
	tween.tween_callback(_start_loading)

func _start_loading() -> void:
	panel.show()
	progress_bar.value = 0
	loading_label.text = "Memuat..."
	animated_sprite.play("default")
	ResourceLoader.load_threaded_request(target_scene)

func _process(_delta: float) -> void:
	if target_scene == "":
		return
	
	var progress = []
	var status = ResourceLoader.load_threaded_get_status(target_scene, progress)
	
	# Update progress
	if progress.size() > 0:
		progress_bar.value = progress[0] * 100
		if progress[0] < 0.3:
			loading_label.text = "Memuat..."
		elif progress[0] < 0.6:
			loading_label.text = "Menyiapkan planet..."
		elif progress[0] < 0.9:
			loading_label.text = "Hampir siap..."
	
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			progress_bar.value = 100
			loading_label.text = "Siap!"
			animated_sprite.stop()
			await get_tree().create_timer(0.3).timeout
			var scene = ResourceLoader.load_threaded_get(target_scene)
			get_tree().change_scene_to_packed(scene)
			target_scene = ""
			panel.hide()
			_fade_in()
		
		ResourceLoader.THREAD_LOAD_FAILED:
			loading_label.text = "Gagal memuat!"
			animated_sprite.stop()
			await get_tree().create_timer(1.0).timeout
			target_scene = ""
			panel.hide()
			_fade_in()

func _fade_in() -> void:
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, 0.5)
