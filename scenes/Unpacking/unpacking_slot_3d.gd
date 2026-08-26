extends Area3D
class_name UnpackingSlot3D

@export var accepts_item_type: String = "gear"
@export var slot_name: String = "Slot Gear"

var occupied: bool = false
@onready var preview_mesh: MeshInstance3D = $PreviewMesh

func _ready() -> void:
	if preview_mesh:
		preview_mesh.visible = false

func set_highlight(active: bool) -> void:
	if occupied or preview_mesh == null:
		return
	preview_mesh.visible = active

func snap_item(item: Node3D) -> void:
	occupied = true
	if preview_mesh:
		preview_mesh.visible = false
	
	var col = item.find_child("CollisionShape3D", true, false)
	if col:
		col.disabled = true
		
	var tween = create_tween().set_parallel(true)
	tween.tween_property(item, "global_position", global_position, 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "global_rotation", global_rotation, 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
