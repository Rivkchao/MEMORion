extends Control
class_name UnpackItem

signal picked(item: UnpackItem)

@export var item_type: String = ""
@export var item_label: String = ""
@export var item_size: Vector2 = Vector2(100, 100)

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

var placed: bool = false
var original_pos: Vector2

func _ready() -> void:
	original_pos = position
	custom_minimum_size = item_size
	size = item_size
	if label:
		label.text = item_label
	_fit_sprite()

func _fit_sprite() -> void:
	if sprite and sprite.texture:
		var tex_size = sprite.texture.get_size()
		sprite.scale = item_size / tex_size

func _gui_input(event: InputEvent) -> void:
	if placed:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		picked.emit(self)
