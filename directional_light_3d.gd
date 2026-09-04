extends DirectionalLight3D

@export_group("Cycle Settings")
@export var cycle_duration: float = 70.0

@export_group("Environment Fill")
@export var world_environment: WorldEnvironment
@export var min_ambient_energy: float = 0.55  # Batas kegelapan malam agar tidak siluet
@export var max_ambient_energy: float = 0.65

@export_group("Water Glow")
@export var water_mesh: MeshInstance3D
@export var max_water_glow: float = 0.5 

@export_group("Terrain Glow")
@export var terrain_node: Node3D
@export var max_path_glow: float = 1.5
@export var max_grass_glow: float = 1.1

@export_group("Rock Glow")
@export var max_rock_glow: float = 0.4

@export_group("Player Night Light")
@export var player_light: OmniLight3D
@export var max_player_light_energy: float = 0.8

var elapsed: float = 0.0
var _water_material: ShaderMaterial = null
var _terrain_material: Resource = null
var _rock_materials: Array[ShaderMaterial] = []

func _ready() -> void:
	if water_mesh != null:
		_water_material = water_mesh.get_active_material(0) as ShaderMaterial

	if terrain_node != null:
		_terrain_material = terrain_node.get("material")

	var rocks = get_tree().get_nodes_in_group("glowing_rock")
	for r in rocks:
		if r is MeshInstance3D:
			var mat = r.get_active_material(0) as ShaderMaterial
			if mat:
				_rock_materials.append(mat)

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
	
	_update_ambient_light(t)
	_update_water_glow(t)
	_update_terrain_glow(t)
	_update_rock_glow(t)
	_update_player_light(t)

func _update_ambient_light(t: float) -> void:
	if world_environment == null or world_environment.environment == null:
		return
	
	var amb_energy: float = max_ambient_energy
	if t >= 0.45 and t < 0.55:
		amb_energy = lerpf(max_ambient_energy, min_ambient_energy, (t - 0.45) / 0.10)
	elif t >= 0.55 and t < 0.90:
		amb_energy = min_ambient_energy
	elif t >= 0.90:
		amb_energy = lerpf(min_ambient_energy, max_ambient_energy, (t - 0.90) / 0.10)
		
	world_environment.environment.ambient_light_energy = amb_energy

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

func _update_rock_glow(t: float) -> void:
	if _rock_materials.is_empty():
		return

	var glow: float = 0.0
	if t >= 0.25 and t < 0.50:
		glow = lerpf(0.0, max_rock_glow, (t - 0.25) / 0.25)
	elif t >= 0.50 and t < 0.95:
		glow = max_rock_glow
	elif t >= 0.95:
		glow = lerpf(max_rock_glow, 0.0, (t - 0.95) / 0.05)
	else:
		glow = 0.0

	for mat in _rock_materials:
		mat.set_shader_parameter("night_glow_strength", glow)

func _update_player_light(t: float) -> void:
	if player_light == null:
		return

	var target_energy: float = 0.0

	# Sore mulai redup ke malam (t: 0.25 - 0.50) -> lampu perlahan menyala
	if t >= 0.25 and t < 0.50:
		var factor: float = (t - 0.25) / 0.25
		target_energy = lerpf(0.0, max_player_light_energy, factor)
	# Malam penuh (t: 0.50 - 0.95) -> lampu menyala stabil
	elif t >= 0.50 and t < 0.95:
		target_energy = max_player_light_energy
	# Fajar menjelang pagi (t: 0.95 - 1.0) -> lampu perlahan mati
	elif t >= 0.95:
		var factor: float = (t - 0.95) / 0.05
		target_energy = lerpf(max_player_light_energy, 0.0, factor)
	else:
		target_energy = 0.0

	player_light.light_energy = target_energy
	player_light.visible = target_energy > 0.01
