extends Node3D

@onready var mesh: MeshInstance3D = $MeshInstance3D
var occupied_by: Node3D = null

var mat_submerged: StandardMaterial3D
var mat_active: StandardMaterial3D
var mat_solved: StandardMaterial3D

var original_y: float

func _ready() -> void:
	RockPuzzleManager.register_slot(self)
	original_y = position.y
	
	# Helper setup agar konfigurasi rendering seragam dan bebas Z-Fighting
	var setup_mat = func(mat: StandardMaterial3D, col: Color, is_unshaded: bool = false, emission_pwr: float = 0.0) -> void:
		mat.albedo_color = col
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED           # Mencegah sisi dalam tembus hitam
		mat.no_depth_test = true                               # Mencegah tabrakan poligon dengan batu asli
		mat.render_priority = 2                                # Prioritas di atas mesh biasa
		if is_unshaded:
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if emission_pwr > 0.0:
			mat.emission_enabled = true
			mat.emission = Color(col.r, col.g, col.b)
			mat.emission_energy_multiplier = emission_pwr

	# Material 1: Redup / Tenggelam
	mat_submerged = StandardMaterial3D.new()
	setup_mat.call(mat_submerged, Color(0.3, 0.4, 0.6, 0.35), true, 0.0)
	
	# Material 2: Nyala Preview (Biru Muda Glow)
	mat_active = StandardMaterial3D.new()
	setup_mat.call(mat_active, Color(0.2, 0.9, 1.0, 0.9), false, 2.5)
	
	# Material 3: Selesai Hijau
	mat_solved = StandardMaterial3D.new()
	setup_mat.call(mat_solved, Color(0.2, 1.0, 0.4, 0.85), false, 1.5)
	
	mesh.material_override = mat_submerged
	mesh.visible = false

func is_occupied() -> bool:
	return occupied_by != null

func show_slot() -> void:
	mesh.visible = true

func hide_slot() -> void:
	mesh.visible = false

func set_highlight(is_lit: bool, _step_number: int = 0) -> void:
	mesh.visible = true
	var tween = create_tween()
	if is_lit:
		mesh.material_override = mat_active
		tween.tween_property(self, "position:y", original_y + 0.15, 0.2)
	else:
		mesh.material_override = mat_submerged
		tween.tween_property(self, "position:y", original_y, 0.25)

func set_permanent_solved() -> void:
	mesh.material_override = mat_solved
	var tween = create_tween()
	tween.tween_property(self, "position:y", original_y + 0.1, 0.2)

func flash_wrong() -> void:
	mesh.visible = true
	var mat_wrong = StandardMaterial3D.new()
	mat_wrong.albedo_color = Color(1.0, 0.2, 0.2, 0.9)
	mat_wrong.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_wrong.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_wrong.no_depth_test = true
	mat_wrong.render_priority = 3
	mat_wrong.emission_enabled = true
	mat_wrong.emission = Color(1.0, 0.1, 0.1)
	mat_wrong.emission_energy_multiplier = 3.0
	mesh.material_override = mat_wrong

func reset_slot() -> void:
	occupied_by = null
	mesh.material_override = mat_submerged
	position.y = original_y
	mesh.visible = false

func try_place(rock: Node3D) -> bool:
	if occupied_by != null:
		return false
	occupied_by = rock
	RockPuzzleManager.on_rock_placed(self, rock)
	return true
