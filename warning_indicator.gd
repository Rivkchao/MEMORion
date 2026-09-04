extends Sprite3D

@export var blink_interval: float = 0.5 # Kecepatan kedip
var _blink_tween: Tween

func _ready() -> void:
	# Sambungkan langsung ke sinyal StoryManager yang sudah ada
	if StoryManager.has_signal("wire_puzzle_completed"):
		StoryManager.wire_puzzle_completed.connect(_on_puzzle_completed)
	
	_start_blinking()

func _start_blinking() -> void:
	# Animasi kedip hidup-mati secara looping
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_callback(func(): visible = not visible).set_delay(blink_interval)

func _on_puzzle_completed(is_correct: bool) -> void:
	if is_correct:
		# Hentikan kedip dan sembunyikan sprite selamanya
		if _blink_tween and _blink_tween.is_valid():
			_blink_tween.kill()
		visible = false
