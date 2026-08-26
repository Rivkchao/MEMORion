class_name PlacementSlot3D
extends Interactable

@export var accepts: String = ""
@onready var slot_mesh: MeshInstance3D = $MeshInstance3D

var is_filled: bool = false
var placed_item: Carryable3D = null

# Material
var mat_empty: StandardMaterial3D
var mat_filled: StandardMaterial3D

func _ready() -> void:
	super._ready()
	interact_label = "Taruh"
	
	mat_empty = StandardMaterial3D.new()
	mat_empty.albedo_color = Color(1, 1, 1, 0.3)
	mat_empty.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_empty.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	mat_filled = StandardMaterial3D.new()
	mat_filled.albedo_color = Color(0.2, 0.9, 0.3, 0.5)
	mat_filled.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_filled.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	slot_mesh.material_override = mat_empty

func interact() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("try_place_item_3d"):
		player.try_place_item_3d(self)

func place_item(item: Carryable3D) -> void:
	is_filled = true
	placed_item = item
	item.reparent(self)
	var tween = create_tween()
	tween.tween_property(item, "global_position", global_position, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	item.rotation = Vector3.ZERO
	slot_mesh.material_override = mat_filled
	hide_prompt()

func clear_slot() -> void:
	is_filled = false
	placed_item = null
	slot_mesh.material_override = mat_empty
	interact_label = "Taruh"
	show_prompt()
