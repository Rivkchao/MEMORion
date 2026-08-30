@tool
extends EditorScript

func _run() -> void:
	var edited_scene_root = EditorInterface.get_edited_scene_root()
	var selected_nodes = EditorInterface.get_selection().get_selected_nodes()
	
	for node in selected_nodes:
		_process_node(node, edited_scene_root)

func _process_node(node: Node, scene_root: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		# Cek apakah sudah ada StaticBody3D agar tidak dobel
		var existing_body = node.get_node_or_null("StaticBody3D")
		if not existing_body:
			var trimesh_shape = node.mesh.create_trimesh_shape()
			if trimesh_shape:
				# 1. Buat StaticBody3D
				var static_body = StaticBody3D.new()
				static_body.name = "StaticBody3D"
				node.add_child(static_body)
				static_body.owner = scene_root
				
				# 2. Buat CollisionShape3D
				var collision_shape = CollisionShape3D.new()
				collision_shape.name = "CollisionShape3D"
				collision_shape.shape = trimesh_shape
				static_body.add_child(collision_shape)
				collision_shape.owner = scene_root
	
	# Rekursif untuk memproses anak-anak nodenya jika yang dipilih adalah parent node
	for child in node.get_children():
		_process_node(child, scene_root)
