extends CanvasLayer

@onready var game_area: Control = $PopupPanel/MarginContainer/VBoxContainer/GameArea
@onready var slots_container: Node2D = $PopupPanel/MarginContainer/VBoxContainer/GameArea/SlotsContainer
@onready var items_container: Node2D = $PopupPanel/MarginContainer/VBoxContainer/GameArea/ItemsContainer
@onready var title_label: Label = $PopupPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var hint_label: Label = $PopupPanel/MarginContainer/VBoxContainer/HintLabel

signal puzzle_completed(is_correct: bool)

@export var puzzle_title: String = "Bantu Rion menata barang-barang ini!"
@export var default_item_color: Color = Color.WHITE
@export var success_color: Color = Color("A7C957")
@export var wrong_color: Color = Color("E63946")

var slots: Array[UnpackSlot] = []
var items: Array[UnpackItem] = []
var dragging_item: UnpackItem = null
var drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	hide()
	hint_label.text = "Rapikan barang ke tempat yang sesuai, ya."
	title_label.text = puzzle_title
	for child in items_container.get_children():
		if child is UnpackItem:
			items.append(child)
			child.picked.connect(_on_item_picked)
			print("connected: ", child.name)
		
	for child in slots_container.get_children():
		if child is UnpackSlot:
			slots.append(child)

	for child in items_container.get_children():
		if child is UnpackItem:
			items.append(child)
			child.picked.connect(_on_item_picked)

func start(puzzle_data: Dictionary = {}) -> void:
	if puzzle_data.has("title"):
		title_label.text = puzzle_data["title"]
	game_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var positions: Array = []
	for item in items:
		positions.append(item.original_pos)
	positions.shuffle()

	for i in range(items.size()):
		items[i].position = positions[i]
		items[i].original_pos = positions[i]
		items[i].placed = false
		items[i].sprite.modulate = default_item_color

	for slot in slots:
		slot.occupied = false

	dragging_item = null
	show()

func _process(_delta: float) -> void:
	if dragging_item != null:
		dragging_item.global_position = get_viewport().get_mouse_position() - drag_offset

func _unhandled_input(event: InputEvent) -> void:
	if dragging_item == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_drop_item(dragging_item)

func _on_item_picked(item: UnpackItem) -> void:
	if item.placed or dragging_item != null:
		return
	dragging_item = item
	drag_offset = get_viewport().get_mouse_position() - item.global_position
	item.z_index = 10

func _drop_item(item: UnpackItem) -> void:
	item.z_index = 0
	var snapped = false

	for slot in slots:
		if slot.occupied:
			continue
		var item_center = item.global_position + item.size / 2
		if slot.get_world_rect().has_point(item_center):
			if slot.accepts == item.item_type:
				var tween = create_tween()
				tween.tween_property(item, "global_position", slot.global_position, 0.15)\
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				slot.occupied = true
				item.placed = true
				item.sprite.modulate = success_color
			else:
				_shake_and_return(item)
			snapped = true
			break

	if not snapped:
		var tween = create_tween()
		tween.tween_property(item, "global_position", item.original_pos, 0.25)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	dragging_item = null
	_check_complete()

func _shake_and_return(item: UnpackItem) -> void:
	item.sprite.modulate = wrong_color
	var tween = create_tween()
	tween.tween_property(item, "position", item.position + Vector2(12, 0), 0.04)
	tween.tween_property(item, "position", item.position - Vector2(12, 0), 0.04)
	tween.tween_property(item, "position", item.position + Vector2(8, 0), 0.04)
	tween.tween_property(item, "position", item.original_pos, 0.15)
	await tween.finished
	if not item.placed:
		item.sprite.modulate = default_item_color

func _check_complete() -> void:
	for item in items:
		if not item.placed:
			return
	await get_tree().create_timer(0.4).timeout
	puzzle_completed.emit(true)
	StoryManager.start_dialogue(["Wah rapiiii! Kamu jago banget bebenahin barang!"], "Rion")
	hide()
