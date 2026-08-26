extends CanvasLayer

@onready var fade_rect: ColorRect = $FadeRect
@onready var panel: Control = $Panel
@onready var animated_sprite: AnimatedSprite2D = $Panel/AnimatedSprite2D
@onready var loading_label: Label = $Panel/LoadingLabel
@onready var progress_bar: ProgressBar = $Panel/ProgressBar
@onready var logo_rect: TextureRect = $Panel/Logo

var target_scene: String = ""
var is_loading_finished: bool = false

func _ready() -> void:
	_start_logo_flip_animation()
	layer = 10
	fade_rect.color = Color(0, 0, 0, 0)
	panel.hide()

func load_scene(scene_path: String) -> void:
	target_scene = scene_path
	is_loading_finished = false
	_fade_out()

func _fade_out() -> void:
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.5)
	tween.tween_callback(_start_loading)

func _start_logo_flip_animation() -> void:
	if not is_instance_valid(logo_rect):
		return
	logo_rect.pivot_offset = logo_rect.size / 2.0
	
	var flip_tween = create_tween().set_loops()
	flip_tween.tween_interval(3.0)
	flip_tween.tween_property(logo_rect, "scale:x", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flip_tween.tween_property(logo_rect, "scale:x", -1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flip_tween.tween_property(logo_rect, "scale:x", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flip_tween.tween_property(logo_rect, "scale:x", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _start_loading() -> void:
	panel.show()
	progress_bar.value = 0
	loading_label.text = "Memuat..."
	animated_sprite.play("default")
	ResourceLoader.load_threaded_request(target_scene)

func _process(_delta: float) -> void:
	if target_scene == "" or is_loading_finished:
		return
	
	var progress = []
	var status = ResourceLoader.load_threaded_get_status(target_scene, progress)
	
	if progress.size() > 0:
		var p: float = progress[0]
		progress_bar.value = p * 100
		
		if p < 0.3:
			loading_label.text = "Memuat..."
		elif p < 0.7:
			loading_label.text = "Menyiapkan planet..."
		elif p < 1.0:
			loading_label.text = "Hampir selesai..."
	
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			is_loading_finished = true
			_on_load_success()
		
		ResourceLoader.THREAD_LOAD_FAILED:
			is_loading_finished = true
			loading_label.text = "Gagal memuat!"
			animated_sprite.stop()
			await get_tree().create_timer(1.0).timeout
			target_scene = ""
			panel.hide()
			_fade_in()

func _on_load_success() -> void:
	progress_bar.value = 100
	loading_label.text = "Siap dimainkan!"
	animated_sprite.stop()
	
	await get_tree().create_timer(1.0).timeout
	
	var scene = ResourceLoader.load_threaded_get(target_scene)
	get_tree().change_scene_to_packed(scene)
	target_scene = ""
	
	await get_tree().process_frame
	panel.hide()
	_fade_in()

func _fade_in() -> void:
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, 0.5)
