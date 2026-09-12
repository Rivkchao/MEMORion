extends Sprite3D

@export var blink_interval: float = 0.5
var _blink_tween: Tween
var _active: bool = false

func _ready() -> void:
	# Kalau terminal sudah selesai, warning tidak perlu tampil
	if GameManager.terminal_puzzle_done:
		visible = false
		set_process(false)
		return

	if StoryManager.has_signal("wire_puzzle_completed"):
		StoryManager.wire_puzzle_completed.connect(_on_puzzle_completed)

	visible = false
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _ona_lever_done() -> bool:
	return GameManager.solved_levers.get("OnaProgramRoom_Lever", false)

func _refresh() -> void:
	# Warning baru menyala setelah tuas Ona Program 100%
	var should_show: bool = _ona_lever_done() and not GameManager.terminal_puzzle_done
	if should_show and not _active:
		_active = true
		visible = true
		_start_blinking()
	elif not should_show and _active:
		_active = false
		if _blink_tween and _blink_tween.is_valid():
			_blink_tween.kill()
		visible = false

func _start_blinking() -> void:
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_callback(func(): visible = not visible).set_delay(blink_interval)

func _on_puzzle_completed(is_correct: bool) -> void:
	if is_correct:
		_active = false
		if _blink_tween and _blink_tween.is_valid():
			_blink_tween.kill()
		visible = false
