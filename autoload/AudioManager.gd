# autoload/AudioManager.gd
extends Node

## Singleton pengelola audio global untuk BGM (Music) dan SFX.
## Mendukung smooth crossfading, pause/resume, history stack, dan trigger 2D/3D SFX.

signal bgm_started(stream: AudioStream)
signal bgm_stopped()

# Dua audio stream player untuk smooth crossfade BGM
var _bgm_player_a: AudioStreamPlayer
var _bgm_player_b: AudioStreamPlayer
var _active_bgm_player: AudioStreamPlayer = null

# Dedicated player untuk Ambience Lingkungan (Wind / Nature loop)
var _ambience_player: AudioStreamPlayer = null
var _ambience_tween: Tween = null

# History stack untuk mengingat BGM sebelumnya saat masuk/keluar zona audio
var _bgm_history: Array[Dictionary] = []

# Pool player SFX 2D instan
var _sfx_pool: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 8

var _crossfade_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_bgm_players()
	_setup_ambience_player()
	_setup_sfx_pool()

func _setup_bgm_players() -> void:
	_bgm_player_a = AudioStreamPlayer.new()
	_bgm_player_a.name = "BGMPlayerA"
	_bgm_player_a.bus = &"Music"
	add_child(_bgm_player_a)

	_bgm_player_b = AudioStreamPlayer.new()
	_bgm_player_b.name = "BGMPlayerB"
	_bgm_player_b.bus = &"Music"
	add_child(_bgm_player_b)

func _setup_ambience_player() -> void:
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "AmbiencePlayer"
	_ambience_player.bus = &"SFX"
	add_child(_ambience_player)

func _setup_sfx_pool() -> void:
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.bus = &"SFX"
		add_child(p)
		_sfx_pool.append(p)

# ----------------------------------------------------
# Ambience Management
# ----------------------------------------------------

func play_ambience(stream: AudioStream, fade_duration: float = 2.0, target_volume_db: float = -8.0) -> void:
	if _ambience_player == null or stream == null:
		return
	if _ambience_player.stream == stream and _ambience_player.playing:
		return

	if _ambience_tween and _ambience_tween.is_valid():
		_ambience_tween.kill()

	_ambience_player.stream = stream
	_ambience_player.volume_db = -80.0
	_ambience_player.play()

	_ambience_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ambience_tween.tween_property(_ambience_player, "volume_db", target_volume_db, maxf(fade_duration, 0.1))

func stop_ambience(fade_duration: float = 2.0) -> void:
	if _ambience_player == null or not _ambience_player.playing:
		return

	if _ambience_tween and _ambience_tween.is_valid():
		_ambience_tween.kill()

	if fade_duration <= 0.1:
		_ambience_player.stop()
		return

	_ambience_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ambience_tween.tween_property(_ambience_player, "volume_db", -80.0, fade_duration)
	_ambience_tween.tween_callback(_ambience_player.stop)

# ----------------------------------------------------
# BGM Management
# ----------------------------------------------------

## Memutar BGM dengan transisi crossfade mulus.
func play_bgm(stream: AudioStream, fade_duration: float = 1.0, target_volume_db: float = 0.0) -> void:
	if stream == null:
		stop_bgm(fade_duration)
		return

	# Jika BGM yang sama sedang diputar, cukup pastikan volume dan playback
	if _active_bgm_player != null and _active_bgm_player.stream == stream and _active_bgm_player.playing:
		return

	# Tentukan player berikutnya (swap A <-> B)
	var next_player: AudioStreamPlayer = _bgm_player_b if _active_bgm_player == _bgm_player_a else _bgm_player_a
	var prev_player: AudioStreamPlayer = _active_bgm_player

	next_player.stream = stream
	next_player.volume_db = -80.0
	next_player.play()

	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	_crossfade_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Fade in player baru
	_crossfade_tween.tween_property(next_player, "volume_db", target_volume_db, maxf(fade_duration, 0.05))

	# Fade out player lama (jika ada)
	if prev_player and prev_player.playing:
		_crossfade_tween.tween_property(prev_player, "volume_db", -80.0, maxf(fade_duration, 0.05))
		_crossfade_tween.chain().tween_callback(prev_player.stop)

	_active_bgm_player = next_player
	bgm_started.emit(stream)

## Menghentikan BGM dengan fade out.
func stop_bgm(fade_duration: float = 1.0) -> void:
	if _active_bgm_player == null or not _active_bgm_player.playing:
		return

	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	if fade_duration <= 0.05:
		_active_bgm_player.stop()
		_active_bgm_player = null
		bgm_stopped.emit()
		return

	_crossfade_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_crossfade_tween.tween_property(_active_bgm_player, "volume_db", -80.0, fade_duration)
	_crossfade_tween.tween_callback(func():
		if _active_bgm_player:
			_active_bgm_player.stop()
			_active_bgm_player = null
			bgm_stopped.emit()
	)

## Menyimpan BGM saat ini ke stack (berguna saat masuk area/zone khusus)
func push_bgm(stream: AudioStream, fade_duration: float = 1.0, target_volume_db: float = 0.0) -> void:
	if _active_bgm_player and _active_bgm_player.stream:
		_bgm_history.append({
			"stream": _active_bgm_player.stream,
			"volume_db": _active_bgm_player.volume_db
		})
	play_bgm(stream, fade_duration, target_volume_db)

## Mengembalikan BGM sebelumnya dari stack (saat keluar area/zone khusus)
func pop_bgm(fade_duration: float = 1.0) -> void:
	if _bgm_history.is_empty():
		stop_bgm(fade_duration)
		return

	var last_entry = _bgm_history.pop_back()
	play_bgm(last_entry.get("stream"), fade_duration, last_entry.get("volume_db", 0.0))

## Mendapatkan stream BGM yang sedang aktif
func get_current_bgm() -> AudioStream:
	if _active_bgm_player and _active_bgm_player.playing:
		return _active_bgm_player.stream
	return null

# ----------------------------------------------------
# 2D SFX Management & Preloaded Sound Effects
# ----------------------------------------------------

# Preload Asset SFX Umum
const SFX_UI_CLICK = preload("res://assets/audio/sfx/SCI-FI_UI_SFX_PACK/Clicks/Click.wav")
const SFX_UI_HOVER = preload("res://assets/audio/sfx/SCI-FI_UI_SFX_PACK/Clicks/Click_Mid.wav")
const SFX_UI_CONFIRM = preload("res://assets/audio/sfx/SCI-FI_UI_SFX_PACK/Click Combos/Click_Combo_2.wav")
const SFX_DIALOGUE_BLIP = preload("res://assets/audio/sfx/SCI-FI_UI_SFX_PACK/Clicks/Click_Pitched_Up.wav")
const SFX_ITEM_PICKUP = preload("res://assets/audio/sfx/SCI-FI_UI_SFX_PACK/Rings/Ring_Pitched_Up.wav")
const SFX_ROCK_IMPACT = preload("res://assets/audio/sfx/SCI-FI_UI_SFX_PACK/Impacts/Impact_1_Low.wav")
const SFX_ROCK_PICKUP = preload("res://assets/audio/sfx/SCI-FI_UI_SFX_PACK/Clicks/Click_Low.wav")
const SFX_PUZZLE_CORRECT = preload("res://assets/audio/sfx/SCI-FI_UI_SFX_PACK/Tone3/Major/Tone3C_MajorThirdUp.wav")
const SFX_PUZZLE_WRONG = preload("res://assets/audio/sfx/SCI-FI_UI_SFX_PACK/Tone3/Minor/Tone3A_MinorTriadDown.wav")
const SFX_PUZZLE_SOLVED = preload("res://assets/audio/sfx/SCI-FI_UI_SFX_PACK/Tone3/Major/Tone3C_MajorTriadUp.wav")
const SFX_GLITCH = preload("res://assets/audio/sfx/SCI-FI_UI_SFX_PACK/Glitches/Glitch_2.wav")
const SFX_JUMP = preload("res://assets/audio/sfx/SCI-FI_UI_SFX_PACK/FX Sounds/Air_FX_Pitched_Up.wav")
const SFX_LAND = preload("res://assets/audio/sfx/SCI-FI_UI_SFX_PACK/Impacts/Impact_1_Low.wav")
const AMBIENCE_WIND = preload("res://assets/audio/sfx/wind.mp3")

const SFX_FOOTSTEPS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/footsteps/step_1.wav"),
	preload("res://assets/audio/sfx/footsteps/step_2.wav"),
	preload("res://assets/audio/sfx/footsteps/step_3.wav"),
	preload("res://assets/audio/sfx/footsteps/step_4.wav"),
	preload("res://assets/audio/sfx/footsteps/step_5.wav")
]

const PUZZLE_TONES: Array[AudioStream] = [
	preload("res://assets/audio/sfx/SCI-FI_UI_SFX_PACK/Tone3/Basic Tones/Tone3A.wav"),
	preload("res://assets/audio/sfx/SCI-FI_UI_SFX_PACK/Tone3/Basic Tones/Tone3B.wav"),
	preload("res://assets/audio/sfx/SCI-FI_UI_SFX_PACK/Tone3/Basic Tones/Tone3C.wav"),
	preload("res://assets/audio/sfx/SCI-FI_UI_SFX_PACK/Tone3/Basic Tones/Tone3D.wav"),
	preload("res://assets/audio/sfx/SCI-FI_UI_SFX_PACK/Tone3/Basic Tones/Tone3E.wav")
]

## Memutar sound effect 2D global non-spatial (UI / Sound efek umum).
func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if stream == null:
		return

	# Cari player di pool yang sedang idle
	for p in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch_scale
			p.play()
			return

	# Jika semua sibuk, gunakan player pertama
	var fallback_player := _sfx_pool[0]
	fallback_player.stream = stream
	fallback_player.volume_db = volume_db
	fallback_player.pitch_scale = pitch_scale
	fallback_player.play()

# ----------------------------------------------------
# Helper Functions Praktis
# ----------------------------------------------------

func play_ui_click(volume_db: float = -4.0, pitch_scale: float = 1.0) -> void:
	play_sfx(SFX_UI_CLICK, volume_db, pitch_scale)

func play_ui_hover(volume_db: float = -12.0, pitch_scale: float = 1.2) -> void:
	play_sfx(SFX_UI_HOVER, volume_db, pitch_scale)

func play_ui_confirm(volume_db: float = -2.0, pitch_scale: float = 1.0) -> void:
	play_sfx(SFX_UI_CONFIRM, volume_db, pitch_scale)

func play_dialogue_blip(volume_db: float = -8.0, pitch_scale: float = 1.1) -> void:
	play_sfx(SFX_DIALOGUE_BLIP, volume_db, pitch_scale)

func play_item_pickup(volume_db: float = -2.0, pitch_scale: float = 1.0) -> void:
	play_sfx(SFX_ITEM_PICKUP, volume_db, pitch_scale)

func play_rock_pickup(volume_db: float = -6.0, pitch_scale: float = 1.0) -> void:
	play_sfx(SFX_ROCK_PICKUP, volume_db, pitch_scale)

func play_rock_impact(volume_db: float = -4.0, pitch_scale: float = 0.9) -> void:
	play_sfx(SFX_ROCK_IMPACT, volume_db, pitch_scale)

func play_footstep(volume_db: float = -6.0) -> void:
	if SFX_FOOTSTEPS.is_empty():
		return
	var step_sound = SFX_FOOTSTEPS.pick_random()
	var pitch = randf_range(0.92, 1.08)
	play_sfx(step_sound, volume_db, pitch)

func play_jump(volume_db: float = -8.0) -> void:
	var pitch = randf_range(0.95, 1.05)
	play_sfx(SFX_JUMP, volume_db, pitch)

func play_land(volume_db: float = -6.0) -> void:
	var pitch = randf_range(0.9, 1.0)
	play_sfx(SFX_LAND, volume_db, pitch)

func play_puzzle_tone(tone_index: int, volume_db: float = 0.0) -> void:
	if PUZZLE_TONES.is_empty():
		return
	var idx = clamp(tone_index, 0, PUZZLE_TONES.size() - 1)
	play_sfx(PUZZLE_TONES[idx], volume_db, 1.0)

func play_puzzle_step_correct(volume_db: float = 0.0) -> void:
	play_sfx(SFX_PUZZLE_CORRECT, volume_db, 1.0)

func play_puzzle_wrong(volume_db: float = -2.0) -> void:
	play_sfx(SFX_PUZZLE_WRONG, volume_db, 1.0)

func play_puzzle_solved(volume_db: float = 2.0) -> void:
	play_sfx(SFX_PUZZLE_SOLVED, volume_db, 1.0)

func play_glitch(volume_db: float = -4.0) -> void:
	play_sfx(SFX_GLITCH, volume_db, 1.0)
