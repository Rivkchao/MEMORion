extends Camera3D

@export var target_path: NodePath = ^"../RionCapsule"
var target_node: Node3D
var is_tracking: bool = false

func _ready() -> void:
	target_node = get_node_or_null(target_path)

func _process(_delta: float) -> void:
	# Hanya lacak saat kamera ini sedang aktif (current)
	if current and is_instance_valid(target_node):
		var target_pos = target_node.global_position + Vector3(0, 1.0, 0)
		if global_position.distance_to(target_pos) > 0.2:
			look_at(target_pos, Vector3.UP)

func track_target(node: Node3D) -> void:
	target_node = node
