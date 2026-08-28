extends Node3D

@export var path_way: Node3D

@export_category("Boundary")
@export var wall_height: float = 2.5
@export var wall_thickness: float = 0.4

@export_category("Generation")
@export var generate_on_ready := true


func _ready() -> void:
	if generate_on_ready:
		generate_boundaries()


func generate_boundaries() -> void:
	if path_way == null:
		push_error("RoadBoundary: PathWay belum di-assign.")
		return

	# Ambil ProtonScatterPath dari PathWay
	var scatter_path = path_way.shape

	if scatter_path == null:
		push_error("RoadBoundary: PathWay tidak memiliki Shape.")
		return

	var curve: Curve3D = scatter_path.curve

	if curve == null:
		push_error("RoadBoundary: PathWay tidak memiliki Curve3D.")
		return

	var points := curve.get_baked_points()

	if points.size() < 2:
		push_error("RoadBoundary: Curve tidak punya cukup point.")
		return

	# Bersihkan collision lama
	for child in get_children():
		child.queue_free()

	# Buat collision setiap segmen
	for i in range(points.size() - 1):
		var a: Vector3 = path_way.to_global(points[i])
		var b: Vector3 = path_way.to_global(points[i + 1])

		_create_wall(a, b, i)

	# Karena PathWay = CLOSED,
	# sambungkan titik terakhir ke titik pertama
	var first_point: Vector3 = path_way.to_global(points[0])
	var last_point: Vector3 = path_way.to_global(points[points.size() - 1])

	if first_point.distance_to(last_point) > 0.05:
		_create_wall(last_point, first_point, points.size())


func _create_wall(a: Vector3, b: Vector3, index: int) -> void:

	var direction := b - a
	var length := direction.length()

	if length < 0.05:
		return

	var center := (a + b) / 2.0

	var body := StaticBody3D.new()
	body.name = "RoadBoundary_%d" % index

	add_child(body)

	body.global_position = center

	# Arahkan Z mengikuti garis
	body.look_at(
		center + direction.normalized(),
		Vector3.UP
	)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"

	var shape := BoxShape3D.new()

	shape.size = Vector3(
		wall_thickness,
		wall_height,
		length
	)

	collision.shape = shape

	body.add_child(collision)
