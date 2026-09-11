# scenes/audio/BGMPlacer.gd
class_name BGMPlacer
extends Node3D

## Komponen untuk menaruh dan mengatur BGM (Background Music) langsung dari Inspector.
## Bisa digunakan sebagai BGM level utama (saat scene dibuka) atau sebagai Zona Audio (Area3D).

@export_group("BGM Settings")
## File audio musik yang ingin diputar (Drag & drop file audio .ogg / .mp3 / .wav ke sini)
@export var bgm_stream: AudioStream

## Volume BGM dalam Decibel (-80 dB s/d +24 dB)
@export_range(-80.0, 24.0, 0.5) var volume_db: float = 0.0

## Durasi transisi fade in / fade out dalam detik
@export_range(0.0, 10.0, 0.1) var fade_duration: float = 1.5

@export_group("Playback Mode")
## Putar BGM otomatis begitu scene / node ini aktif
@export var play_on_ready: bool = true

## Hentikan BGM saat scene / node ini dihapus dari tree
@export var stop_on_exit_tree: bool = false

@export_group("Zone Trigger (Optional)")
## Jika aktif, musik hanya terpicu saat Player masuk ke dalam area / radius zona ini
@export var is_zone: bool = false

## Jika aktif, mengembalikan lagu BGM sebelumnya setelah Player keluar dari zona ini
@export var restore_previous_on_exit: bool = true

## Radius zona pemicu jika is_zone aktif (dalam meter)
@export var zone_radius: float = 8.0

## Layer physics target pemain (Default layer 2 = Player)
@export_flags_3d_physics var player_collision_mask: int = 2

var _area: Area3D = null

func _ready() -> void:
	if is_zone:
		_setup_trigger_zone()
	elif play_on_ready:
		trigger_play()

func _exit_tree() -> void:
	if stop_on_exit_tree and not is_zone:
		trigger_stop()

func _setup_trigger_zone() -> void:
	# Cek apakah sudah ada child Area3D manual
	for child in get_children():
		if child is Area3D:
			_area = child
			break
	
	# Jika belum ada, buatkan Area3D dan CollisionShape3D otomatis
	if _area == null:
		_area = Area3D.new()
		_area.name = "BGMZoneArea"
		_area.collision_layer = 0
		_area.collision_mask = player_collision_mask
		
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = zone_radius
		shape.shape = sphere
		
		_area.add_child(shape)
		add_child(_area)
	else:
		_area.collision_mask = player_collision_mask

	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		if restore_previous_on_exit:
			if AudioManager:
				AudioManager.push_bgm(bgm_stream, fade_duration, volume_db)
		else:
			trigger_play()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		if restore_previous_on_exit:
			if AudioManager:
				AudioManager.pop_bgm(fade_duration)
		else:
			trigger_stop()

## Panggil fungsi ini dari script/signal jika ingin memicu manual
func trigger_play() -> void:
	if bgm_stream == null:
		return
	if AudioManager:
		AudioManager.play_bgm(bgm_stream, fade_duration, volume_db)

## Panggil fungsi ini untuk menghentikan manual
func trigger_stop() -> void:
	if AudioManager:
		AudioManager.stop_bgm(fade_duration)
