extends Interactable

@export_file("*.tscn") var target_scene: String = "res://LEV1.tscn"
@export var door_label: String = "Press E to Enter"
@export var spawn_position: Vector3 = Vector3.ZERO

@onready var area_3d: Area3D = get_node_or_null("Area3D")

var player_inside: bool = false

func _ready() -> void:
	super._ready()
	interact_label = door_label
	
	if area_3d:
		area_3d.body_entered.connect(_on_body_entered)
		area_3d.body_exited.connect(_on_body_exited)
	
	hide_prompt()

func _input(event: InputEvent) -> void:
	if player_inside and event.is_action_pressed("interact"):
		interact()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name.to_lower() == "player":
		player_inside = true
		show_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name.to_lower() == "player":
		player_inside = false
		hide_prompt()

func interact() -> void:
	if target_scene == "":
		if StoryManager and StoryManager.has_method("start_dialogue"):
			StoryManager.start_dialogue(["Pintu ini terkunci."], "Rion")
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		player = get_tree().root.find_child("Player", true, false)
	
	if player and GameManager.has_method("save_state"):
		GameManager.save_state(player, "LEV1")
	
	if has_node("/root/LoadingScreen"):
		LoadingScreen.load_scene(target_scene)
	else:
		get_tree().change_scene_to_file(target_scene)
