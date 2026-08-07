extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 10.0
@export var jump_force: float = 8.0
@export var gravity: float = 20.0
@export var camera_rig: NodePath

@onready var mesh: Node3D = $RionMesh
@onready var interact_area: Area3D = $InteractArea
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_state: AnimationNodeStateMachinePlayback = anim_tree["parameters/playback"]
@onready var camera_node: Node3D = get_node(camera_rig)

var joystick_input: Vector2 = Vector2.ZERO
var current_interactable: Interactable = null
var current_speed: float = walk_speed

@export var fall_threshold: float = -5.0
var last_safe_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	last_safe_position = global_position

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_movement()
	_handle_jump()
	_handle_rotation(delta)
	_handle_animation()
	_check_interact_prompt()
	_check_fall()
	move_and_slide()

func _check_fall() -> void:
	if global_position.y < fall_threshold:
		global_position = last_safe_position
		velocity = Vector3.ZERO
		return
	
	if is_on_floor():
		last_safe_position = global_position

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5

func _handle_movement() -> void:
	if _is_any_ui_active():
		velocity.x = 0
		velocity.z = 0
		return
	if RockPuzzleManager.is_puzzle_active:
		velocity.x = 0
		velocity.z = 0
		return
	# 1. Tentukan kecepatan aktif (Sprint / Walk)
	if Input.is_action_pressed("sprint"):
		current_speed = sprint_speed
	else:
		current_speed = walk_speed

	var input_dir = Vector2.ZERO

	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_forward", "move_back")

	if joystick_input.length() > 0.1:
		input_dir = joystick_input

	# Jika tidak ada input arah atau UI sedang terbuka, hentikan pergerakan
	if input_dir == Vector2.ZERO or _is_any_ui_active():
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		return

	var cam_basis = camera_node.global_transform.basis
	var forward = -Vector3(cam_basis.z.x, 0, cam_basis.z.z).normalized()
	var right = Vector3(cam_basis.x.x, 0, cam_basis.x.z).normalized()

	var move_dir = (forward * -input_dir.y + right * input_dir.x).normalized()

	# Gunakan current_speed
	velocity.x = move_dir.x * current_speed
	velocity.z = move_dir.z * current_speed
	
func _handle_jump() -> void:
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_force

func _handle_rotation(delta: float) -> void:
	var move_dir = Vector3(velocity.x, 0, velocity.z)
	if move_dir.length() > 0.1:
		var target_angle = atan2(move_dir.x, move_dir.z)
		$RionMesh.rotation.y = lerp_angle(
			$RionMesh.rotation.y,
			target_angle,
			10.0 * delta
		)

func _handle_animation() -> void:
	var is_moving = Vector2(velocity.x, velocity.z).length() > 0.1

	if not is_on_floor():
		anim_state.travel("Jump")
	elif is_moving:
		anim_state.travel("Walk")
	else:
		anim_state.travel("Idle")

func _check_interact_prompt() -> void:
	var bodies = interact_area.get_overlapping_bodies()
	var found: Interactable = null

	for body in bodies:
		if body is Interactable:
			found = body
			break

	if found != current_interactable:
		if current_interactable != null:
			current_interactable.hide_prompt()

		current_interactable = found

		if current_interactable != null:
			current_interactable.show_prompt()

func _try_interact() -> void:
	if current_interactable != null:
		current_interactable.interact()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		# Cek apakah ada UI aktif dulu
		if _is_any_ui_active():
			if StoryManager.dialogue_box != null and StoryManager.dialogue_box.is_active():
				StoryManager.dialogue_box.next()
			return
		_try_interact()

func _is_any_ui_active() -> bool:
	if RockPuzzleManager.is_puzzle_active and RockPuzzleManager.dragging_rock != null:
		return true
	if StoryManager.dialogue_box != null and StoryManager.dialogue_box.is_active():
		return true
	if StoryManager.puzzle_ui != null and StoryManager.puzzle_ui.visible:
		return true
	if StoryManager.matching_puzzle != null and StoryManager.matching_puzzle.visible:
		return true
	if StoryManager.wire_puzzle != null and StoryManager.wire_puzzle.visible:
		return true
	if StoryManager.unpacking_puzzle != null and StoryManager.unpacking_puzzle.visible:
		return true
	return false
