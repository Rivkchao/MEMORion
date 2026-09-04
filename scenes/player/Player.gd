extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 10.0
@export var jump_force: float = 8.0
@export var jump_delay: float = 0.45
@export var gravity: float = 20.0
@export var camera_rig: NodePath

@onready var mesh: Node3D = $RionMesh
@onready var interact_area: Area3D = $InteractArea
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var camera_node: Node3D = get_node_or_null(camera_rig)

var joystick_input: Vector2 = Vector2.ZERO
var current_interactable: Interactable = null
var current_speed: float = walk_speed
var is_jumping_prep: bool = false

@export var fall_threshold: float = -5.0
var last_safe_position: Vector3 = Vector3.ZERO

@export var hand_point_path: NodePath
@onready var hand_point: Marker3D = get_node(hand_point_path)

var held_item: Carryable3D = null

func _ready() -> void:
	add_to_group("player")
	var scene_str: String = ""
	if owner and owner.scene_file_path:
		scene_str = owner.scene_file_path
	elif get_tree() and get_tree().current_scene:
		scene_str = get_tree().current_scene.scene_file_path
		if scene_str == "":
			scene_str = get_tree().current_scene.name
	
	if scene_str != "":
		var new_pos = GameManager.consume_spawn_override_for(scene_str)
		if new_pos != Vector3.ZERO:
			global_position = new_pos
	last_safe_position = global_position

func pick_up_item(item: Carryable3D) -> void:
	if held_item != null:
		return
	
	held_item = item
	item.is_held = true
	
	if item.has_node("CollisionShape3D"):
		item.get_node("CollisionShape3D").disabled = true
	
	item.hide_prompt()
	current_interactable = null
	
	item.reparent(hand_point)
	var tween = create_tween()
	tween.tween_property(item, "position", Vector3.ZERO, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func try_place_item_3d(slot: PlacementSlot3D) -> void:
	if held_item == null:
		return
	if slot.is_filled:
		StoryManager.start_dialogue(["Slot ini sudah terisi!"], "Rion")
		return
	if slot.accepts != held_item.item_type:
		StoryManager.start_dialogue(["Hmm, sepertinya ini bukan tempatnya..."], "Rion")
		return
	
	var item = held_item
	held_item = null
	item.is_held = false
	
	if item.has_node("CollisionShape3D"):
		item.get_node("CollisionShape3D").disabled = false
	
	slot.place_item(item)
	
	var puzzle = slot.get_parent().get_parent()
	if puzzle.has_method("check_complete"):
		puzzle.check_complete()

func drop_item() -> void:
	if held_item == null:
		return
	held_item.is_held = false
	if held_item.has_node("CollisionShape3D"):
		held_item.get_node("CollisionShape3D").disabled = false
	held_item.return_to_original()
	held_item = null

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_movement()
	_handle_jump()
	move_and_slide()
	_handle_rotation(delta)
	_handle_animation(delta)
	_check_interact_prompt()
	_check_fall()

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
	elif velocity.y < 0:
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

	if Input.is_action_pressed("sprint"):
		current_speed = sprint_speed
	else:
		current_speed = walk_speed

	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_forward", "move_back")

	if joystick_input.length() > 0.1:
		input_dir = joystick_input

	if input_dir == Vector2.ZERO or _is_any_ui_active():
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		return

	if camera_node == null:
		if not camera_rig.is_empty():
			camera_node = get_node_or_null(camera_rig)
		if camera_node == null:
			camera_node = get_viewport().get_camera_3d()
	if camera_node == null:
		return

	var cam_basis = camera_node.global_transform.basis
	var forward = -Vector3(cam_basis.z.x, 0, cam_basis.z.z).normalized()
	var right = Vector3(cam_basis.x.x, 0, cam_basis.x.z).normalized()

	var move_dir = (forward * -input_dir.y + right * input_dir.x).normalized()

	velocity.x = move_dir.x * current_speed
	velocity.z = move_dir.z * current_speed

func _handle_jump() -> void:
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		# Berikan daya dorong langsung secara instan
		velocity.y = jump_force
		
		# Picu animasi lompat
		anim_tree.set("parameters/JumpShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		
func _handle_rotation(delta: float) -> void:
	var move_dir = Vector3(velocity.x, 0, velocity.z)
	if move_dir.length() > 0.1:
		var target_angle = atan2(move_dir.x, move_dir.z)
		$RionMesh.rotation.y = lerp_angle(
			$RionMesh.rotation.y,
			target_angle,
			10.0 * delta
		)

func _handle_animation(delta: float) -> void:
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	var target_move_blend: float = 0.0

	if horizontal_speed > 0.1:
		if Input.is_action_pressed("sprint"):
			target_move_blend = 1.0  # Run
		else:
			target_move_blend = 0.5  # Walk
	else:
		target_move_blend = 0.0      # Idle

	# Update posisi blend kaki & badan dasar
	var move_path = "parameters/StateMachine/Move/blend_position"
	var current_move: float = anim_tree.get(move_path) if anim_tree.get(move_path) != null else 0.0
	anim_tree.set(move_path, lerpf(current_move, target_move_blend, 8.0 * delta))

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
		if _is_any_ui_active():
			if StoryManager.dialogue_box != null and StoryManager.dialogue_box.is_active():
				StoryManager.dialogue_box.next()
			return
		_try_interact()
	
	if event.is_action_pressed("ui_cancel") and held_item != null:
		drop_item()

func _is_any_ui_active() -> bool:
	if RockPuzzleManager.is_puzzle_active and RockPuzzleManager.dragging_rock != null:
		return true
	if StoryManager.dialogue_box != null and StoryManager.dialogue_box.is_active():
		return true
	if StoryManager.matching_puzzle != null and StoryManager.matching_puzzle.visible:
		return true
	if StoryManager.wire_puzzle != null and StoryManager.wire_puzzle.visible:
		return true
	return false
