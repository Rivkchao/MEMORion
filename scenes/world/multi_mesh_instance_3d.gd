extends MultiMeshInstance3D

@export var count: int = 20
@export var area_size: Vector2 = Vector2(40, 40)

func _ready() -> void:
	multimesh.instance_count = count
	
	for i in count:
		var pos = Vector3(
			randf_range(-area_size.x / 2, area_size.x / 2),
			0,
			randf_range(-area_size.y / 2, area_size.y / 2)
		)
		var transform = Transform3D(Basis(), pos)
		multimesh.set_instance_transform(i, transform)
