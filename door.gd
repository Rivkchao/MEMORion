extends Interactable

@export var target_scene: String = ""
@export var door_label: String = "Masuk"
@export var spawn_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	super._ready()
	interact_label = door_label

func interact() -> void:
	if target_scene == "":
		return
	var player = get_tree().get_first_node_in_group("player")
	if player:
		GameManager.save_state(player)
	if spawn_position != Vector3.ZERO:
		GameManager.set_spawn_override(spawn_position)
	LoadingScreen.load_scene(target_scene)
