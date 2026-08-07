extends Node3D

@export var slot_order: int = 0
@onready var area: Area3D = $Area3D
@onready var mesh: MeshInstance3D = $MeshInstance3D

var occupied_by: Node3D = null

# Material
var mat_default: StandardMaterial3D
var mat_correct: StandardMaterial3D

func _ready() -> void:
	RockPuzzleManager.register_slot(self)
	
	# Material default (putih semi transparan)
	mat_default = StandardMaterial3D.new()
	mat_default.albedo_color = Color(1, 1, 1, 0.5)
	mat_default.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_default.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	# Material correct (hijau)
	mat_correct = StandardMaterial3D.new()
	mat_correct.albedo_color = Color(0.2, 0.9, 0.3, 0.7)
	mat_correct.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_correct.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	mesh.material_override = mat_default

func is_occupied() -> bool:
	return occupied_by != null

func is_correct() -> bool:
	if occupied_by == null:
		return false
	return occupied_by.rock_size == slot_order

func try_place(rock: Node3D) -> bool:
	if occupied_by != null:
		return false
	occupied_by = rock
	
	if is_correct():
		mesh.material_override = mat_correct
	else:
		# Salah — kembalikan batu ke posisi asal
		await get_tree().create_timer(0.3).timeout
		rock.return_to_original()
		occupied_by = null
		mesh.material_override = mat_default
	
	return true

func remove_rock() -> void:
	occupied_by = null
	mesh.material_override = mat_default

func hide_slot() -> void:
	mesh.hide()
