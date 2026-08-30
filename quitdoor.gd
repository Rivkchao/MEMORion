extends Area3D
class_name DoorExit

@export_file("*.tscn") var target_scene: String = "res://LEV1.tscn"
@export var interact_distance: float = 6.0
@export var door_label: String = "Press E to Exit"

var player: Node3D = null
var _player_near: bool = false
var _transition_started: bool = false

@onready var label_3d: Label3D = get_node_or_null("Label3D")

func _ready() -> void:
	if label_3d == null:
		label_3d = Label3D.new()
		label_3d.name = "Label3D"
		label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_3d.font_size = 72
		label_3d.outline_size = 12
		label_3d.outline_modulate = Color(0, 0, 0, 1)
		add_child(label_3d)
	label_3d.top_level = true
	label_3d.global_position = global_position + Vector3(0, 22, 0)
	label_3d.text = door_label
	label_3d.hide()
	_find_player()

func _process(_delta: float) -> void:
	if label_3d == null:
		return
	_find_player()
	if player == null:
		return
	var near := global_position.distance_to(player.global_position) <= interact_distance
	if near != _player_near:
		_player_near = near
		label_3d.visible = near

func _input(event: InputEvent) -> void:
	if _player_near and event.is_action_pressed("interact"):
		_try_interact()

func _find_player() -> void:
	if player != null:
		return
	player = get_tree().root.find_child("Player", true, false) as Node3D
	if player == null:
		player = get_tree().root.find_child("player", true, false) as Node3D
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D

func _try_interact() -> void:
	if _transition_started:
		return
	_find_player()
	if player == null:
		return
	if global_position.distance_to(player.global_position) > interact_distance:
		return
	_transition_started = true
	print("[DoorExit] Pindah scene ke: ", target_scene)
	if has_node("/root/LoadingScreen"):
		LoadingScreen.load_scene(target_scene)
	else:
		get_tree().change_scene_to_file(target_scene)
