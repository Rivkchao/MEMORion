# scenes/audio/SFXPlacer3D.gd
class_name SFXPlacer3D
extends Node3D

## Komponen penempatan Sound Effect 3D di dunia permainan.
## Cukup drag audio ke inspector dan atur mode trigger (Looping Ambient, Saat Player Masuk, Interaksi, atau Manual).

enum TriggerMode {
	LOOPING_AMBIENT = 0,
	ON_PLAYER_ENTER_AREA = 1,
	ON_INTERACT_EVENT = 2,
	MANUAL_ONLY = 3
}

@export_group("SFX Stream")
## File audio utama yang ingin diputar
@export var stream: AudioStream

## Variasi audio acak (opsional, jika diisi akan memilih acak antara stream utama & variasi ini)
@export var variations: Array[AudioStream] = []

@export_group("Trigger Mode")
## Mode pemicu suara
@export var trigger_mode: TriggerMode = TriggerMode.LOOPING_AMBIENT

@export_group("Audio Properties")
## Volume audio dalam Decibel
@export_range(-80.0, 24.0, 0.5) var volume_db: float = 0.0

## Pitch dasar
@export_range(0.1, 4.0, 0.05) var pitch_scale: float = 1.0

## Variasi pitch acak (+/- nilai ini) agar suara tidak monoton saat dipicu berulang
@export_range(0.0, 1.0, 0.05) var random_pitch_variance: float = 0.0

## Bus audio output
@export var bus: StringName = &"SFX"

@export_group("3D Attenuation & Distance")
## Jarak maksimal suara masih terdengar (dalam meter)
@export var max_distance: float = 25.0

## Jarak di mana volume masih 100% penuh (unit size)
@export var unit_size: float = 10.0

## Model pelemahan volume seiring jarak
@export var attenuation_model: AudioStreamPlayer3D.AttenuationModel = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE

@export_group("Area Trigger Settings (Jika Mode: ON_PLAYER_ENTER_AREA)")
## Radius area pemicu (dalam meter)
@export var trigger_radius: float = 3.0

## Jika aktif, suara hanya berbunyi 1x saat pertama kali player masuk area
@export var one_shot_area: bool = false

## Layer physics target pemain (Default layer 2 = Player)
@export_flags_3d_physics var player_collision_mask: int = 2

var _player_3d: AudioStreamPlayer3D
var _area: Area3D
var _has_triggered: bool = false

func _ready() -> void:
	_setup_audio_player()
	
	match trigger_mode:
		TriggerMode.LOOPING_AMBIENT:
			play()
		TriggerMode.ON_PLAYER_ENTER_AREA:
			_setup_area_trigger()

func _setup_audio_player() -> void:
	_player_3d = AudioStreamPlayer3D.new()
	_player_3d.name = "Player3D"
	_player_3d.bus = bus
	_player_3d.volume_db = volume_db
	_player_3d.pitch_scale = pitch_scale
	_player_3d.max_distance = max_distance
	_player_3d.unit_size = unit_size
	_player_3d.attenuation_model = attenuation_model
	add_child(_player_3d)

func _setup_area_trigger() -> void:
	for child in get_children():
		if child is Area3D:
			_area = child
			break
			
	if _area == null:
		_area = Area3D.new()
		_area.name = "SFXTriggerArea"
		_area.collision_layer = 0
		_area.collision_mask = player_collision_mask
		
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = trigger_radius
		shape.shape = sphere
		
		_area.add_child(shape)
		add_child(_area)
	else:
		_area.collision_mask = player_collision_mask

	_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if one_shot_area and _has_triggered:
		return
	if body.is_in_group("player") or body.name == "Player":
		_has_triggered = true
		play()

## Memutar SFX
func play() -> void:
	var chosen_stream = _get_chosen_stream()
	if chosen_stream == null:
		return
	
	_player_3d.stream = chosen_stream
	_player_3d.volume_db = volume_db
	
	var final_pitch = pitch_scale
	if random_pitch_variance > 0.0:
		final_pitch += randf_range(-random_pitch_variance, random_pitch_variance)
	_player_3d.pitch_scale = maxf(0.05, final_pitch)
	
	_player_3d.play()

## Menghentikan SFX
func stop() -> void:
	if _player_3d:
		_player_3d.stop()

func _get_chosen_stream() -> AudioStream:
	if variations.is_empty():
		return stream
	
	var all_streams: Array[AudioStream] = []
	if stream != null:
		all_streams.append(stream)
	all_streams.append_array(variations)
	
	if all_streams.is_empty():
		return null
	return all_streams.pick_random()
