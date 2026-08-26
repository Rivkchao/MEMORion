extends Area3D
class_name UnpackItem3D

@export var item_type: String = "gear"
@export var item_name: String = "Gear Roda Gigi"

var is_placed: bool = false
var original_transform: Transform3D

func _ready() -> void:
	original_transform = global_transform

func return_to_origin() -> void:
	var tween = create_tween()
	tween.tween_property(self, "global_transform", original_transform, 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
