extends DirectionalLight3D

@export var cycle_duration: float = 100.0
@export var water_mesh: MeshInstance3D
@export var max_water_glow: float = 4.0
var elapsed: float = 0.0
var _water_material: ShaderMaterial = null

@export var terrain_node: Node3D
@export var max_path_glow: float = 2.5
var _terrain_material: Resource = null

func _ready() -> void:
	# 1. Cari Mesh Air
	if water_mesh == null:
		water_mesh = get_tree().root.find_child("River", true, false) as MeshInstance3D
		if water_mesh == null:
			water_mesh = get_tree().root.find_child("WaterMesh", true, false) as MeshInstance3D

	if water_mesh != null:
		_water_material = water_mesh.get_active_material(0) as ShaderMaterial

	# 2. Cari Node Terrain3D jika belum diassign
	if terrain_node == null:
		terrain_node = get_tree().root.find_child("Terrain3D", true, false)

	if terrain_node != null:
		_terrain_material = terrain_node.get("material")

func _process(delta: float) -> void:
	elapsed += delta
	var t: float = fmod(elapsed, cycle_duration) / cycle_duration

	rotation_degrees.x = t * 360.0 - 90.0

	var col: Color
	if t < 0.05:
		col = Color(1.0, 0.6, 0.35).lerp(Color(1.0, 0.92, 0.82), t / 0.05)
	elif t < 0.25:
		col = Color(1.0, 0.92, 0.82).lerp(Color(1.0, 1.0, 0.98), (t - 0.05) / 0.20)
	elif t < 0.35:
		col = Color(1.0, 1.0, 0.98).lerp(Color(1.0, 0.85, 0.55), (t - 0.25) / 0.10)
	elif t < 0.5:
		col = Color(1.0, 0.85, 0.55).lerp(Color(1.0, 0.45, 0.15), (t - 0.35) / 0.15)
	elif t < 0.55:
		col = Color(1.0, 0.45, 0.15).lerp(Color(0.15, 0.18, 0.35), (t - 0.5) / 0.05)
	elif t < 0.95:
		col = Color(0.15, 0.18, 0.35).lerp(Color(0.18, 0.2, 0.38), (t - 0.55) / 0.40)
	else:
		col = Color(0.18, 0.2, 0.38).lerp(Color(1.0, 0.6, 0.35), (t - 0.95) / 0.05)

	light_color = col

	# ------- Energi Cahaya Matahari / Bulan -------
	var energy: float
	if t < 0.05:
		energy = lerpf(0.3, 0.8, t / 0.05)
	elif t < 0.10:
		energy = lerpf(0.8, 1.2, (t - 0.05) / 0.05)
	elif t < 0.40:
		energy = 1.2
	elif t < 0.50:
		energy = lerpf(1.2, 0.6, (t - 0.40) / 0.10)
	elif t < 0.55:
		energy = lerpf(0.6, 0.15, (t - 0.50) / 0.05)
	elif t < 0.95:
		energy = 0.15
	else:
		energy = lerpf(0.15, 0.3, (t - 0.95) / 0.05)

	light_energy = energy

	# ------- Update Pendaran Malam (Air & Jalan) -------
	_update_water_glow(t)
	_update_terrain_glow(t) # <--- Ini tadi belum dipanggil

func _update_water_glow(t: float) -> void:
	if _water_material == null:
		return

	var glow: float = 0.0
	
	if t >= 0.35 and t < 0.60:
		glow = lerpf(0.0, max_water_glow, (t - 0.35) / 0.25)
	elif t >= 0.60 and t < 0.95:
		glow = max_water_glow
	elif t >= 0.95:
		glow = lerpf(max_water_glow, 0.0, (t - 0.95) / 0.05)
	else:
		glow = 0.0

	_water_material.set_shader_parameter("glow_intensity", glow)

func _update_terrain_glow(t: float) -> void:
	if _terrain_material == null:
		if terrain_node != null:
			_terrain_material = terrain_node.get("material")
		else:
			# Coba cari lagi jika null
			terrain_node = get_tree().root.find_child("Terrain3D", true, false)
			if terrain_node != null:
				_terrain_material = terrain_node.get("material")
		return

	var glow: float = 0.0
	if t >= 0.35 and t < 0.60:
		glow = lerpf(0.0, max_path_glow, (t - 0.35) / 0.25)
	elif t >= 0.60 and t < 0.95:
		glow = max_path_glow
	elif t >= 0.95:
		glow = lerpf(max_path_glow, 0.0, (t - 0.95) / 0.05)

	if _terrain_material.has_method("set_shader_param"):
		_terrain_material.call("set_shader_param", "path_glow_intensity", glow)
	elif _terrain_material is ShaderMaterial:
		_terrain_material.set_shader_parameter("path_glow_intensity", glow)
