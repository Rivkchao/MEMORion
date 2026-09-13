extends Node

const IDLE_LIMIT: float = 2.0

var _idle_time: float = 0.0
var _hidden: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_process(false)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_show_cursor()

func _process(delta: float) -> void:
	# Jangan ganggu saat kamera sedang dalam mode captured (orbit)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	if _hidden:
		return
	_idle_time += delta
	if _idle_time >= IDLE_LIMIT:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		_hidden = true

func _show_cursor() -> void:
	_idle_time = 0.0
	if _hidden:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_hidden = false
