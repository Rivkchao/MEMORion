extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and not RockPuzzleManager.is_puzzle_done:
		var cam_rig = get_tree().current_scene.find_child("CameraRig", true, false)
		RockPuzzleManager.setup_camera(cam_rig, global_position)
		RockPuzzleManager.start_puzzle()
