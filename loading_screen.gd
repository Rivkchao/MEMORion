extends Control

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var loading_anim: AnimatedSprite2D = $CenterContainer/AnimationLoading
@onready var loading_label: Label = $LoadingLabel  # optional, hapus kalau gapake

var min_time: float = 1.5  # durasi minimum loading screen tampil (detik)
var elapsed: float = 0.0
var scene_loaded: bool = false
var current_progress: float = 0.0


func _ready() -> void:
	# Validasi: pastiin ada scene tujuan
	if SceneLoader.next_scene_path == "":
		push_error("LoadingScreen: next_scene_path kosong!")
		return

	# Mulai request load scene di background thread
	var err = ResourceLoader.load_threaded_request(SceneLoader.next_scene_path)
	if err != OK:
		push_error("Gagal mulai load: " + SceneLoader.next_scene_path)
		return

	# Mainin animasi loading (looping)
	loading_anim.play("default")

	progress_bar.value = 0
	progress_bar.max_value = 100


func _process(delta: float) -> void:
	elapsed += delta

	if scene_loaded:
		return

	var status = ResourceLoader.load_threaded_get_status(
		SceneLoader.next_scene_path, SceneLoader.loading_progress
	)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# loading_progress[0] nilainya 0.0 - 1.0
			var target_progress = SceneLoader.loading_progress[0] * 100
			# smoothing biar bar-nya gak nyentak-nyentak
			current_progress = lerp(current_progress, target_progress, 0.1)
			progress_bar.value = current_progress
			_update_label(int(current_progress))

		ResourceLoader.THREAD_LOAD_LOADED:
			current_progress = 100
			progress_bar.value = 100
			_update_label(100)

			# Tunggu sampai minimum time terpenuhi, biar loading screen
			# nggak cuma kedip sekejap kalau scene-nya kecil
			if elapsed >= min_time:
				_change_to_loaded_scene()

		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Gagal load scene: " + SceneLoader.next_scene_path)
			scene_loaded = true  # stop loop biar gak spam error

		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Resource invalid: " + SceneLoader.next_scene_path)
			scene_loaded = true


func _change_to_loaded_scene() -> void:
	scene_loaded = true
	var packed_scene: PackedScene = ResourceLoader.load_threaded_get(SceneLoader.next_scene_path)
	get_tree().change_scene_to_packed(packed_scene)


func _update_label(percent: int) -> void:
	if loading_label:
		loading_label.text = "Loading... %d%%" % percent
