# scenes/audio/SFXPlacer2D.gd
class_name SFXPlacer2D
extends Node

## Komponen untuk Sound Effect 2D / Global (UI Button, Dialogue chime, puzzle solve, dsb).
## Cukup tempelkan ke node UI atau objek manapun dan tarik file audio ke Inspector.

enum TriggerMode {
	ON_PARENT_BUTTON_PRESS = 0,
	ON_READY = 1,
	MANUAL_ONLY = 2
}

@export_group("SFX Stream")
## File audio utama yang ingin diputar
@export var stream: AudioStream

## Variasi audio acak (opsional)
@export var variations: Array[AudioStream] = []

@export_group("Trigger Mode")
## Kapan suara ini diputar otomatis
@export var trigger_mode: TriggerMode = TriggerMode.ON_PARENT_BUTTON_PRESS

@export_group("Sound Settings")
## Volume dalam Decibel
@export_range(-80.0, 24.0, 0.5) var volume_db: float = 0.0

## Pitch dasar
@export_range(0.1, 4.0, 0.05) var pitch_scale: float = 1.0

## Variasi pitch acak (+/-) agar suara tidak monoton saat diklik berulang
@export_range(0.0, 1.0, 0.05) var random_pitch_variance: float = 0.05

func _ready() -> void:
	match trigger_mode:
		TriggerMode.ON_READY:
			play()
		TriggerMode.ON_PARENT_BUTTON_PRESS:
			var parent = get_parent()
			if parent is BaseButton:
				parent.pressed.connect(play)

## Memutar SFX 2D melalui AudioManager
func play() -> void:
	var chosen_stream = _get_chosen_stream()
	if chosen_stream == null:
		return
		
	var final_pitch = pitch_scale
	if random_pitch_variance > 0.0:
		final_pitch += randf_range(-random_pitch_variance, random_pitch_variance)
	final_pitch = maxf(0.05, final_pitch)
	
	if AudioManager:
		AudioManager.play_sfx(chosen_stream, volume_db, final_pitch)

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
