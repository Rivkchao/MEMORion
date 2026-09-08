# scenes/ui/mobile_controls.gd
extends CanvasLayer
class_name MobileControls

@export var max_joystick_radius: float = 80.0
@export var deadzone: float = 0.12

# Node References
@onready var joystick_area: Control = $JoystickZone
@onready var joystick_base: Control = $JoystickZone/Base
@onready var joystick_knob: Control = $JoystickZone/Base/Knob

@onready var action_buttons_container: Control = $ActionButtons
@onready var btn_jump: Button = $ActionButtons/JumpBtn
@onready var btn_sprint: Button = $ActionButtons/SprintBtn
@onready var btn_interact: Button = $ActionButtons/InteractBtn
@onready var btn_drop: Button = $ActionButtons/DropBtn

@onready var touch_camera_area: Control = $TouchCameraArea

# State Joystick
var _joystick_touch_id: int = -1
var _joystick_center: Vector2 = Vector2.ZERO
var _joystick_input: Vector2 = Vector2.ZERO
var _base_default_pos: Vector2 = Vector2.ZERO
var _is_mouse_joystick: bool = false

# State Kamera
var _camera_touches: Dictionary = {} # touch_id -> Vector2 pos
var _prev_pinch_dist: float = 0.0

# State Tombol & Player
var is_sprint_toggled: bool = false
var _player: Node3D = null
var _camera_rig: Node3D = null
var _pulse_time: float = 0.0

func _ready() -> void:
	layer = 20 # Di bawah dialog box dan popup settings
	
	# Hubungkan sinyal dari SettingsManager
	if SettingsManager:
		SettingsManager.mobile_controls_toggled.connect(_on_mobile_controls_toggled)
		visible = SettingsManager.is_mobile_controls_active()
	
	_base_default_pos = joystick_base.position
	_joystick_center = joystick_base.size / 2.0
	joystick_knob.position = _joystick_center - (joystick_knob.size / 2.0)
	
	# Setup Tombol Action
	btn_jump.button_down.connect(_on_jump_down)
	btn_jump.button_up.connect(_on_jump_up)
	
	btn_sprint.pressed.connect(_on_sprint_pressed)
	
	btn_interact.button_down.connect(_on_interact_down)
	btn_interact.button_up.connect(_on_interact_up)
	
	btn_drop.pressed.connect(_on_drop_pressed)
	btn_drop.visible = false
	
	# Setup press animation feedback untuk setiap tombol
	_setup_button_feedback(btn_jump)
	_setup_button_feedback(btn_sprint)
	_setup_button_feedback(btn_interact)
	_setup_button_feedback(btn_drop)
	
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()

func _setup_button_feedback(btn: Button) -> void:
	if btn == null:
		return
	btn.pivot_offset = btn.size / 2.0
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.button_down.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.08).set_ease(Tween.EASE_OUT)
	)
	btn.button_up.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)

func _apply_responsive_layout() -> void:
	if not is_inside_tree():
		return
	var safe_area = DisplayServer.get_display_safe_area()
	var screen_size = DisplayServer.screen_get_size()
	
	if screen_size.x > 0 and screen_size.y > 0 and safe_area.size != Vector2i.ZERO:
		var left_margin = max(0.0, float(safe_area.position.x))
		var right_margin = max(0.0, float(screen_size.x - safe_area.end.x))
		if left_margin > 10.0 and joystick_area:
			joystick_area.offset_left = 40.0 + left_margin
		if right_margin > 10.0 and action_buttons_container:
			action_buttons_container.offset_right = -right_margin

func _on_mobile_controls_toggled(active: bool) -> void:
	visible = active

func _process(delta: float) -> void:
	if not visible:
		return
	
	_find_player_and_camera()
	_update_ui_state(delta)
	
	# Terapkan input sprint terus-menerus jika sedang aktif
	if is_sprint_toggled:
		Input.action_press("sprint")

func _find_player_and_camera() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			_player = get_tree().root.find_child("Player", true, false)
	
	if _camera_rig == null or not is_instance_valid(_camera_rig):
		_camera_rig = get_tree().current_scene.find_child("CameraRig", true, false)
		if _camera_rig == null:
			_camera_rig = get_tree().root.find_child("CameraRig", true, false)

func _update_ui_state(delta: float) -> void:
	var ui_blocking = _is_ui_blocking()
	var target_alpha: float = 0.25 if ui_blocking else 1.0
	if joystick_area:
		joystick_area.modulate.a = lerpf(joystick_area.modulate.a, target_alpha, 10.0 * delta)
	if action_buttons_container:
		action_buttons_container.modulate.a = lerpf(action_buttons_container.modulate.a, target_alpha, 10.0 * delta)
	
	if _player != null:
		# Update tombol lepas benda
		if "held_item" in _player and _player.held_item != null:
			if not btn_drop.visible:
				btn_drop.visible = true
				btn_drop.scale = Vector2(0.5, 0.5)
				var tween = create_tween()
				tween.tween_property(btn_drop, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			btn_drop.visible = false
		
		# Efek visual tombol interaksi jika ada objek interaktif di dekatnya
		if "current_interactable" in _player and _player.current_interactable != null:
			_pulse_time += delta * 4.0
			var pulse_scale = 1.0 + sin(_pulse_time) * 0.05
			btn_interact.scale = Vector2(pulse_scale, pulse_scale)
			btn_interact.modulate = Color(0.4, 1.0, 0.7, 1.0)
			
			if _player.current_interactable.has_method("get_label"):
				var lbl: String = _player.current_interactable.get_label()
				btn_interact.text = "✦\n" + (lbl if lbl.length() <= 8 else "AKSI")
		else:
			btn_interact.scale = Vector2.ONE
			btn_interact.modulate = Color(1.0, 1.0, 1.0, 0.92)
			btn_interact.text = "✦\nAKSI"

func _is_ui_blocking() -> bool:
	if StoryManager != null:
		if StoryManager.dialogue_box != null and StoryManager.dialogue_box.has_method("is_active") and StoryManager.dialogue_box.is_active():
			return true
		if StoryManager.wire_puzzle != null and StoryManager.wire_puzzle.visible:
			return true
	if RockPuzzleManager != null and RockPuzzleManager.is_puzzle_active and RockPuzzleManager.dragging_rock != null:
		return true
	return false

# ----------------------------------------------------
# Multi-touch & Mouse Input Handler
# ----------------------------------------------------
func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	var viewport_rect = get_viewport().get_visible_rect()
	var half_width = viewport_rect.size.x * 0.48
	
	# 1. SCREEN TOUCH
	if event is InputEventScreenTouch:
		if event.pressed:
			# Touch di area kiri layar (Floating Joystick)
			if event.position.x < half_width and event.position.y > viewport_rect.size.y * 0.2:
				if _joystick_touch_id == -1:
					_start_joystick(event.index, event.position)
			else:
				# Touch di area kanan (Kamera Swipe / Pinch)
				if not _is_touching_action_buttons(event.position):
					_camera_touches[event.index] = event.position
					if _camera_touches.size() == 2:
						var keys = _camera_touches.keys()
						_prev_pinch_dist = _camera_touches[keys[0]].distance_to(_camera_touches[keys[1]])
		else:
			# Touch release
			if event.index == _joystick_touch_id:
				_release_joystick()
			if _camera_touches.has(event.index):
				_camera_touches.erase(event.index)
				_prev_pinch_dist = 0.0
	
	# 2. SCREEN DRAG
	elif event is InputEventScreenDrag:
		if event.index == _joystick_touch_id:
			_update_joystick(event.position)
		elif _camera_touches.has(event.index):
			_camera_touches[event.index] = event.position
			
			if _camera_touches.size() == 1:
				if _camera_rig and _camera_rig.has_method("rotate_camera"):
					_camera_rig.rotate_camera(event.relative)
			elif _camera_touches.size() == 2:
				var keys = _camera_touches.keys()
				var new_dist = _camera_touches[keys[0]].distance_to(_camera_touches[keys[1]])
				if _prev_pinch_dist > 0.0:
					var pinch_delta = (_prev_pinch_dist - new_dist) * 0.025
					if _camera_rig and _camera_rig.has_method("zoom_camera"):
						_camera_rig.zoom_camera(pinch_delta)
				_prev_pinch_dist = new_dist
	
	# 3. MOUSE SUPPORT (Untuk kenyamanan testing di PC)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.position.x < half_width and event.position.y > viewport_rect.size.y * 0.2:
					_is_mouse_joystick = true
					_start_joystick(999, event.position)
			else:
				if _is_mouse_joystick:
					_is_mouse_joystick = false
					_release_joystick()
	elif event is InputEventMouseMotion:
		if _is_mouse_joystick:
			_update_joystick(event.position)

func _is_touching_action_buttons(touch_pos: Vector2) -> bool:
	var buttons = [btn_jump, btn_sprint, btn_interact, btn_drop]
	for btn in buttons:
		if btn and btn.is_visible_in_tree() and btn.get_global_rect().has_point(touch_pos):
			return true
	return false

# ----------------------------------------------------
# Logika Virtual Joystick Dinamis
# ----------------------------------------------------
func _start_joystick(touch_id: int, touch_pos: Vector2) -> void:
	_joystick_touch_id = touch_id
	
	# Pindahkan joystick base tepat ke bawah jari jempol
	var local_pos = (touch_pos - joystick_area.global_position) - _joystick_center
	
	# Batasi agar base tidak keluar dari batas area joystick zone
	local_pos.x = clampf(local_pos.x, 0.0, maxf(0.0, joystick_area.size.x - joystick_base.size.x))
	local_pos.y = clampf(local_pos.y, 0.0, maxf(0.0, joystick_area.size.y - joystick_base.size.y))
	
	joystick_base.position = local_pos
	_update_joystick(touch_pos)

func _update_joystick(touch_pos: Vector2) -> void:
	var base_center_global = joystick_base.global_position + _joystick_center
	var drag_offset = touch_pos - base_center_global
	var dist = drag_offset.length()
	
	if dist > max_joystick_radius:
		drag_offset = drag_offset.normalized() * max_joystick_radius
	
	# Geser knob secara presisi
	joystick_knob.position = (_joystick_center + drag_offset) - (joystick_knob.size / 2.0)
	
	# Normalisasi vektor input (-1.0 s/d 1.0)
	var raw_vec = drag_offset / max_joystick_radius
	if raw_vec.length() < deadzone:
		_joystick_input = Vector2.ZERO
	else:
		_joystick_input = raw_vec
	
	_feed_input_to_player(_joystick_input)

func _release_joystick() -> void:
	_joystick_touch_id = -1
	_joystick_input = Vector2.ZERO
	_feed_input_to_player(Vector2.ZERO)
	
	# Animasi halus kembalikan base dan knob ke posisi asal
	var tween = create_tween().set_parallel(true)
	tween.tween_property(joystick_base, "position", _base_default_pos, 0.25)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(joystick_knob, "position", _joystick_center - (joystick_knob.size / 2.0), 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _feed_input_to_player(vec: Vector2) -> void:
	if _player and "joystick_input" in _player:
		_player.joystick_input = vec
	
	# Simulasikan juga aksi tombol keyboard bawaan jika diperlukan
	if vec.x < -0.3:
		Input.action_press("move_left", -vec.x)
	else:
		Input.action_release("move_left")
		
	if vec.x > 0.3:
		Input.action_press("move_right", vec.x)
	else:
		Input.action_release("move_right")
		
	if vec.y < -0.3:
		Input.action_press("move_forward", -vec.y)
	else:
		Input.action_release("move_forward")
		
	if vec.y > 0.3:
		Input.action_press("move_back", vec.y)
	else:
		Input.action_release("move_back")

# ----------------------------------------------------
# Aksi Tombol
# ----------------------------------------------------
func _on_jump_down() -> void:
	Input.action_press("jump")

func _on_jump_up() -> void:
	Input.action_release("jump")

func _on_sprint_pressed() -> void:
	is_sprint_toggled = not is_sprint_toggled
	if is_sprint_toggled:
		btn_sprint.text = "⚡\nLARI ON"
		btn_sprint.modulate = Color(1.0, 0.9, 0.3, 1.0)
		Input.action_press("sprint")
	else:
		btn_sprint.text = "⚡\nLARI"
		btn_sprint.modulate = Color(1.0, 1.0, 1.0, 0.9)
		Input.action_release("sprint")

func _on_interact_down() -> void:
	Input.action_press("interact")

func _on_interact_up() -> void:
	Input.action_release("interact")

func _on_drop_pressed() -> void:
	if _player and _player.has_method("drop_item"):
		_player.drop_item()
	else:
		Input.action_press("ui_cancel")
		Input.action_release("ui_cancel")
