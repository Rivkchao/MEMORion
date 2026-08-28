extends Area3D
class_name DoorExit

@export_file("*.tscn") var target_scene: String = "res://LEV1.tscn"
@export var interact_distance: float = 3.0

var player: Node3D = null

func _ready() -> void:
	player = get_tree().root.find_child("Player", true, false) as Node3D
	if player == null:
		player = get_tree().root.find_child("player", true, false) as Node3D

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_try_interact()

func _try_interact() -> void:
	if player == null:
		player = get_tree().root.find_child("Player", true, false) as Node3D
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
	
	if player == null:
		return
		
	var d: float = player.global_position.distance_to(global_position)
	if d <= interact_distance:
		print("[DoorExit] Pindah scene ke: ", target_scene)
		if has_node("/root/LoadingScreen"):
			LoadingScreen.load_scene(target_scene)
		else:
			get_tree().change_scene_to_file(target_scene)
