extends DirectionalLight3D

@export_group("Cycle Settings")
@export var cycle_duration: float = 100.0

@export_group("Water Glow")
@export var water_mesh: MeshInstance3D
@export var max_water_glow: float = 0.5 

@export_group("Terrain Glow")
@export var terrain_node: Node3D
@export var max_path_glow: float = 2.5
@export var max_grass_glow: float = 1.8

var elapsed: float = 0.0
var _water_material: ShaderMaterial = null
var _terrain_material: Resource = null

func _ready() -> void:
	# Ambil material air
	if water_mesh != null:
		_water_material = water_mesh.get_active_material(0) as ShaderMaterial

	# Ambil material Terrain3D
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

	# Energi Cahaya Matahari / Bulan
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
		energy = 0.55
	else:
		energy = lerpf(0.55, 0.3, (t - 0.95) / 0.05)

	light_energy = energy
	
	# Update Glow
	_update_water_glow(t)
	_update_terrain_glow(t)

func _update_water_glow(t: float) -> void:
	if _water_material == null:
		return

	var glow: float = 0.0
	if t >= 0.25 and t < 0.50:
		glow = lerpf(0.0, max_water_glow, (t - 0.25) / 0.25)
	elif t >= 0.50 and t < 0.95:
		glow = max_water_glow
	elif t >= 0.95:
		glow = lerpf(max_water_glow, 0.0, (t - 0.95) / 0.05)
	else:
		glow = 0.0

	_water_material.set_shader_parameter("night_glow_strength", glow)

func _update_terrain_glow(t: float) -> void:
	if _terrain_material == null:
		return

	var path_glow: float = 0.0
	var grass_glow: float = 0.0

	# Transisi halus dari sore (0.25) ke malam (0.50 - 0.95)
	if t >= 0.25 and t < 0.50:
		var factor: float = (t - 0.25) / 0.25
		path_glow = lerpf(0.0, max_path_glow, factor)
		grass_glow = lerpf(0.0, max_grass_glow, factor)
	elif t >= 0.50 and t < 0.95:
		path_glow = max_path_glow
		grass_glow = max_grass_glow
	elif t >= 0.95:
		var factor: float = (t - 0.95) / 0.05
		path_glow = lerpf(max_path_glow, 0.0, factor)
		grass_glow = lerpf(max_grass_glow, 0.0, factor)
	else:
		path_glow = 0.0
		grass_glow = 0.0

	if _terrain_material.has_method("set_shader_param"):
		_terrain_material.set_shader_param("path_glow_intensity", path_glow)
		_terrain_material.set_shader_param("grass_glow_intensity", grass_glow)
	elif _terrain_material is ShaderMaterial:
		_terrain_material.set_shader_parameter("path_glow_intensity", path_glow)
		_terrain_material.set_shader_parameter("grass_glow_intensity", grass_glow)
