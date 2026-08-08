extends Node2D
class_name UnpackSlot

@export var accepts: String = ""
@export var slot_label: String = ""
@export var slot_size: Vector2 = Vector2(110, 110)

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

var occupied: bool = false

func _ready() -> void:
	if label:
		label.text = slot_label
	_fit_sprite()

func _fit_sprite() -> void:
	if sprite and sprite.texture:
		var tex_size = sprite.texture.get_size()
		sprite.scale = slot_size / tex_size

func get_world_rect() -> Rect2:
	return Rect2(global_position - slot_size / 2.0, slot_size)
