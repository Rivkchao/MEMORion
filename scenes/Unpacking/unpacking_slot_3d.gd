extends Area3D
class_name UnpackingSlot3D

@export var accepts_item_type: String = "gear"
@export var slot_name: String = "Slot Gear"
var occupied: bool = false
@onready var preview_mesh: MeshInstance3D = $PreviewMesh
signal item_snap_finished

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

	var col: CollisionShape3D = item.find_child("CollisionShape3D",true,false) as CollisionShape3D

	if col:
		col.disabled = true

	var original_scale: Vector3 = item.scale
	var tween: Tween = create_tween().set_parallel(true)

	tween.tween_property(
		item,"global_position",global_position,0.35).set_trans(Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)

	tween.tween_property(item,"global_rotation",global_rotation,0.35).set_trans(Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)

	tween.tween_property(item,"scale",original_scale,0.35)

	await tween.finished

	item.global_position = global_position
	item.global_rotation = global_rotation
	item.scale = original_scale

	item_snap_finished.emit()
