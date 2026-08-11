extends CanvasLayer

@onready var animated_sprite: AnimatedSprite2D = $Control/AnimatedSprite2D
@onready var loading_label: Label = $Control/LoadingLabel

var target_scene: String = ""
var load_status: int = 0

func _ready() -> void:
	hide()

func load_scene(scene_path: String) -> void:
	target_scene = scene_path
	show()
	loading_label.text = "Memuat..."
	animated_sprite.play("default")  # ganti nama animasi sesuai yang kamu set di SpriteFrames
	ResourceLoader.load_threaded_request(scene_path)

func _process(_delta: float) -> void:
	if target_scene == "":
		return
	
	var progress = []
	load_status = ResourceLoader.load_threaded_get_status(target_scene, progress)
	
	match load_status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			loading_label.text = "Memuat..."
		ResourceLoader.THREAD_LOAD_LOADED:
			loading_label.text = "Siap!"
			animated_sprite.stop()
			await get_tree().create_timer(0.5).timeout
			var scene = ResourceLoader.load_threaded_get(target_scene)
			get_tree().change_scene_to_packed(scene)
			target_scene = ""
			hide()
		ResourceLoader.THREAD_LOAD_FAILED:
			loading_label.text = "Gagal memuat scene!"
			animated_sprite.stop()
