extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	var is_player = body.is_in_group("player") or body.name.to_lower() == "player"
	if is_player and not GameManager.rock_puzzle_done:
		input_ray_pickable = false
		monitoring = false
		monitorable = false
		var col = find_child("CollisionShape3D", true, false)
		if col:
			col.set_deferred("disabled", true)
		var cam_rig = get_tree().current_scene.find_child("CameraRig", true, false)
		RockPuzzleManager.setup_camera(cam_rig, global_position)
		RockPuzzleManager.start_puzzle()
