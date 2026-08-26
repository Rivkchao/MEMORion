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
	
	# Hapus penimpaan skala agar ukuran mesh tetap mengikuti ukuran asli di editor
	
	# Material 1: Redup / Tenggelam
	mat_submerged = StandardMaterial3D.new()
	mat_submerged.albedo_color = Color(0.3, 0.4, 0.6, 0.35)
	mat_submerged.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_submerged.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	# Material 2: Nyala Preview (Render priority 1 agar tidak bentrok z-fighting)
	mat_active = StandardMaterial3D.new()
	mat_active.albedo_color = Color(0.2, 0.9, 1.0, 0.9)
	mat_active.emission_enabled = true
	mat_active.emission = Color(0.2, 0.9, 1.0)
	mat_active.emission_energy_multiplier = 2.5
	mat_active.render_priority = 1
	
	# Material 3: Selesai Hijau
	mat_solved = StandardMaterial3D.new()
	mat_solved.albedo_color = Color(0.2, 1.0, 0.4, 0.8)
	mat_solved.emission_enabled = true
	mat_solved.emission = Color(0.2, 1.0, 0.4)
	mat_solved.emission_energy_multiplier = 1.2
	mat_solved.render_priority = 1
	
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
	mat_wrong.emission_enabled = true
	mat_wrong.emission = Color(1.0, 0.1, 0.1)
	mat_wrong.emission_energy_multiplier = 3.0
	mat_wrong.render_priority = 2
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
