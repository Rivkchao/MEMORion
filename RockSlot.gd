extends Node3D

@export var slot_order: int = 0  # 1 = paling kecil, 5 = paling besar
@onready var area: Area3D = $Area3D

var occupied_by: Node3D = null

func _ready() -> void:
	RockPuzzleManager.register_slot(self)

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
	return true

func remove_rock() -> void:
	occupied_by = null
