@tool
extends Node3D

@export var target_scatter_shape: Node3D:
	set(value):
		target_scatter_shape = value
		if Engine.is_editor_hint() and is_inside_tree():
			generate_boundaries()

@export_group("Wall Settings")
@export var wall_thickness: float = 0.5
@export var wall_height: float = 2.0
@export var rebuild: bool = false:
	set(value):
		if value:
			generate_boundaries()
			# Reset tombol ke false otomatis
			rebuild = false

func _ready() -> void:
	generate_boundaries()

func _find_curve(node: Node) -> Curve3D:
	if not node:
		return null
		
	# 1. Cek properti curve langsung
	if "curve" in node and node.get("curve") is Curve3D:
		return node.get("curve")
		
	# 2. Cek di dalam property shape
	if "shape" in node and node.get("shape") != null:
		var s = node.get("shape")
		if "curve" in s and s.get("curve") is Curve3D:
			return s.get("curve")
			
	# 3. Cek properti internal proton scatter
	if "internal_shape" in node and node.get("internal_shape") != null:
		var ishape = node.get("internal_shape")
		if "curve" in ishape and ishape.get("curve") is Curve3D:
			return ishape.get("curve")
			
	# 4. Cari jika ada child bertipe Path3D atau sejenisnya
	for child in node.get_children():
		if "curve" in child and child.get("curve") is Curve3D:
			return child.get("curve")
			
	return null

func generate_boundaries() -> void:
	if not target_scatter_shape:
		return

	var curve := _find_curve(target_scatter_shape)
	if not curve:
		return

	var raw_points := curve.get_baked_points()
	if raw_points.size() < 2:
		return

	# Bersihkan child lama
	for child in get_children():
		child.queue_free()

	# Subsample titik agar jumlah dinding efisien (interval ~3.0 meter)
	var points: Array[Vector3] = []
	points.append(raw_points[0])
	var accumulated_dist: float = 0.0
	var min_step: float = 3.0

	for i in range(1, raw_points.size()):
		accumulated_dist += raw_points[i].distance_to(raw_points[i - 1])
		if accumulated_dist >= min_step or i == raw_points.size() - 1:
			points.append(raw_points[i])
			accumulated_dist = 0.0

	if points.size() < 2:
		return

	# Generate segmen dinding yang efisien
	for i in range(points.size() - 1):
		var a: Vector3 = target_scatter_shape.to_global(points[i])
		var b: Vector3 = target_scatter_shape.to_global(points[i + 1])
		_create_wall(a, b, i)

	# Tutup loop jika closed path
	var first_point: Vector3 = target_scatter_shape.to_global(points[0])
	var last_point: Vector3 = target_scatter_shape.to_global(points[points.size() - 1])

	if first_point.distance_to(last_point) > 1.0:
		_create_wall(last_point, first_point, points.size())

func _create_wall(a: Vector3, b: Vector3, index: int) -> void:
	var direction := b - a
	var length := direction.length()

	if length < 0.2:
		return

	var center := (a + b) / 2.0

	var body := StaticBody3D.new()
	body.name = "Wall_%d" % index
	add_child(body)

	body.global_position = center

	var look_dir := direction.normalized()
	if abs(look_dir.dot(Vector3.UP)) < 0.99:
		body.look_at(center + look_dir, Vector3.UP)
	else:
		body.look_at(center + look_dir, Vector3.FORWARD)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"

	var shape := BoxShape3D.new()
	shape.size = Vector3(wall_thickness, wall_height, length)
	collision.shape = shape

	body.add_child(collision)
