# scenes/audio/PathAudioPlacer3D.gd
class_name PathAudioPlacer3D
extends Path3D

## Komponen audio untuk sungai, rel kereta, garis pantai, atau jalur panjang lainnya.
## Posisi sumber suara 3D akan otomatis meluncur di sepanjang kurva Path3D mengikuti titik terdekat dengan Pemain.

@export_group("Audio Stream")
## File audio aliran air / ambient yang ingin diputar
@export var stream: AudioStream:
	set(val):
		stream = val
		_ensure_stream_loop()
		if _audio_player:
			_audio_player.stream = stream

@export_group("Audio Properties")
## Volume audio dalam Decibel
@export_range(-80.0, 24.0, 0.5) var volume_db: float = 0.0:
	set(val):
		volume_db = val
		if _audio_player:
			_audio_player.volume_db = volume_db

## Pitch dasar audio
@export_range(0.1, 4.0, 0.05) var pitch_scale: float = 1.0:
	set(val):
		pitch_scale = val
		if _audio_player:
			_audio_player.pitch_scale = pitch_scale

## Bus audio output
@export var bus: StringName = &"SFX"

## Putar otomatis saat game dimulai
@export var auto_play: bool = true

## Pastikan audio berputar berulang (looping) secara otomatis
@export var force_loop: bool = true

@export_group("3D Distance & Attenuation")
## Jarak maksimal suara masih terdengar (dalam meter)
@export var max_distance: float = 35.0

## Jarak di mana volume masih 100% penuh (unit size)
@export var unit_size: float = 10.0

## Model pelemahan suara seiring jarak
@export var attenuation_model: AudioStreamPlayer3D.AttenuationModel = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE

@export_group("Path Follow Settings")
## Kecepatan luncur suara mengikuti pemain di sepanjang garis kurva
@export_range(1.0, 50.0, 0.5) var follow_speed: float = 20.0

## Target node khusus (opsional, jika kosong otomatis mencari node di group "player" atau Camera3D)
@export var target_node: Node3D = null

var _audio_player: AudioStreamPlayer3D
var _listener_target: Node3D = null

func _ready() -> void:
	# Jika curve belum digambar atau titiknya kurang dari 2, buatkan 2 titik default dari ukuran parent
	_check_and_init_curve()
	_ensure_stream_loop()
	_setup_player()
	_find_listener_target()

	if auto_play:
		# Panggil deferred agar tree sudah sepenuhnya siap
		call_deferred("play")

func _check_and_init_curve() -> void:
	if curve == null:
		curve = Curve3D.new()
	
	if curve.point_count < 2:
		# Buat 2 titik default membentang di sumbu Z (-10 s/d +10 meter)
		curve.clear_points()
		curve.add_point(Vector3(0, 0, -15))
		curve.add_point(Vector3(0, 0, 15))

func _ensure_stream_loop() -> void:
	if not force_loop or stream == null:
		return
	if stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

func _setup_player() -> void:
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "RiverAudioSource3D"
	_audio_player.bus = bus
	_audio_player.volume_db = volume_db
	_audio_player.pitch_scale = pitch_scale
	_audio_player.max_distance = max_distance
	_audio_player.unit_size = unit_size
	_audio_player.attenuation_model = attenuation_model
	_audio_player.top_level = true
	_audio_player.global_position = global_position # Mulai tepat di posisi node, bukan (0,0,0)
	
	# Safeguard loop: jika stream selesai, otomatis restart jika auto_play / force_loop
	_audio_player.finished.connect(func():
		if auto_play and force_loop and is_inside_tree():
			_audio_player.play()
	)

	add_child(_audio_player)

	if stream:
		_audio_player.stream = stream

func _find_listener_target() -> void:
	if target_node != null and is_instance_valid(target_node):
		_listener_target = target_node
		return
	
	# Cari pemain di group "player"
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_listener_target = players[0] as Node3D
		return

	# Fallback ke Camera3D
	var cam = get_viewport().get_camera_3d()
	if cam:
		_listener_target = cam

func _process(delta: float) -> void:
	if _audio_player == null:
		return

	if _listener_target == null or not is_instance_valid(_listener_target):
		_find_listener_target()
		if _listener_target == null:
			return

	var target_global_pos = _listener_target.global_position
	var closest_global_point = global_position

	if curve != null and curve.point_count >= 2:
		var target_local_pos = to_local(target_global_pos)
		var closest_local_point = curve.get_closest_point(target_local_pos)
		closest_global_point = to_global(closest_local_point)

	# Luncurkan posisi AudioStreamPlayer3D ke titik terdekat secara smooth
	_audio_player.global_position = _audio_player.global_position.lerp(closest_global_point, delta * follow_speed)

## Memutar audio sungai/jalur
func play() -> void:
	if _audio_player == null:
		_setup_player()
		
	if stream != null:
		_ensure_stream_loop()
		_audio_player.stream = stream
		_audio_player.volume_db = volume_db
		_audio_player.pitch_scale = pitch_scale
		_audio_player.play()

## Menghentikan audio
func stop() -> void:
	if _audio_player:
		_audio_player.stop()
