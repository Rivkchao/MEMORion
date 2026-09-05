extends Camera3D

@export var target_path: NodePath = ^"../RionCapsule"
var target_node: Node3D
var is_tracking: bool = false

func _ready() -> void:
	target_node = get_node_or_null(target_path)

func _process(_delta: float) -> void:
	# Hanya lacak saat kamera ini sedang aktif (current)
	if current and is_instance_valid(target_node):
		look_at(target_node.global_position, Vector3.UP)
