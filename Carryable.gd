class_name Carryable3D
extends Interactable

@export var item_type: String = ""
var is_held: bool = false
var original_position: Vector3
var original_parent: Node3D

func _ready() -> void:
	super._ready()
	interact_label = "Ambil"
	original_position = global_position
	original_parent = get_parent()

func interact() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("pick_up_item"):
		player.pick_up_item(self)

func return_to_original() -> void:
	reparent(original_parent)
	var tween = create_tween()
	tween.tween_property(self, "global_position", original_position, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
