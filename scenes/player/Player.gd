extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_force: float = 8.0
@export var gravity: float = 20.0

@onready var mesh: Node3D = $RionMesh
@onready var interact_area: Area3D = $InteractArea
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_state: AnimationNodeStateMachinePlayback = anim_tree["parameters/playback"]

var joystick_input: Vector2 = Vector2.ZERO
var camera_rig: Node3D
var current_interactable: Interactable = null

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_movement()
	_handle_jump()
	_handle_rotation(delta)
	_handle_animation()
	_check_interact_prompt()
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

func _handle_movement() -> void:
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_forward", "move_back")
	
	if joystick_input.length() > 0.1:
		input_dir = joystick_input
	
	var move_dir = Vector3(input_dir.x, 0, input_dir.y).normalized()
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed

func _handle_jump() -> void:
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_force

func _handle_rotation(delta: float) -> void:
	var move_dir = Vector3(velocity.x, 0, velocity.z)
	if move_dir.length() > 0.1:
		var target_angle = atan2(move_dir.x, move_dir.z)
		target_angle += deg_to_rad(0)
		$RionMesh.rotation.y = lerp_angle($RionMesh.rotation.y, target_angle, 10.0 * delta)

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
		if StoryManager.dialogue_box != null and StoryManager.dialogue_box.is_active():
			StoryManager.dialogue_box.next()
		else:
			_try_interact()
