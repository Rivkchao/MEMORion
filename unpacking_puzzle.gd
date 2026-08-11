extends CanvasLayer

@onready var popup_panel = $PopupPanel
@onready var box_control = $PopupPanel/MarginContainer/VBoxContainer/GameArea/BoxArea/VBoxContainer/BoxControl
@onready var shelf_control = $PopupPanel/MarginContainer/VBoxContainer/GameArea/ShelfArea/VBoxContainer/ShelfControl
@onready var title_label = $PopupPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var hint_label = $PopupPanel/MarginContainer/VBoxContainer/HintLabel
@onready var progress_label = $PopupPanel/MarginContainer/VBoxContainer/ProgressLabel

signal puzzle_completed(is_correct: bool)

@export var puzzle_title: String = "Bantu Rion menata barang-barang ini!"

var slots: Array[UnpackSlot] = []
var items: Array[UnpackItem] = []
var dragging_item: UnpackItem = null
var drag_offset: Vector2 = Vector2.ZERO
var total_items: int = 0
var placed_items: int = 0

func _ready() -> void:
	hide()
	hint_label.text = "Rapikan barang ke tempat yang sesuai, ya."
	title_label.text = puzzle_title
	progress_label.text = "Progress: 0 / 0"

func start(puzzle_data: Dictionary = {}) -> void:
	if puzzle_data.has("title"):
		title_label.text = puzzle_data["title"]
		
	_clear_existing()
	
	total_items = puzzle_data.get("items", []).size()
	placed_items = 0
	_update_progress()
	
	# Spawn Slots
	if puzzle_data.has("slots"):
		for slot_data in puzzle_data["slots"]:
			var slot = UnpackSlot.new()
			slot.accepts = slot_data.get("accepts", "")
			slot.slot_label = slot_data.get("label", "")
			slot.slot_size = slot_data.get("size", Vector2(110, 110))
			slot.position = slot_data.get("position", Vector2.ZERO)
			
			shelf_control.add_child(slot)
			slots.append(slot)
			
	# Spawn Items
	if puzzle_data.has("items"):
		for item_data in puzzle_data["items"]:
			var item = UnpackItem.new()
			item.item_type = item_data.get("type", "")
			item.item_label = item_data.get("label", "")
			item.item_size = item_data.get("size", Vector2(100, 100))
			item.item_color = item_data.get("color", Color(0.3, 0.6, 1.0))
			item.position = item_data.get("position", Vector2.ZERO)
			
			box_control.add_child(item)
			items.append(item)
			item.picked.connect(_on_item_picked)

	dragging_item = null
	show()

func _clear_existing() -> void:
	for slot in slots:
		slot.queue_free()
	slots.clear()
	
	for item in items:
		item.queue_free()
	items.clear()

func _process(_delta: float) -> void:
	if dragging_item != null:
		var new_pos = get_viewport().get_mouse_position() - drag_offset
		dragging_item.global_position = new_pos
		
		# Check hover on slots
		for slot in slots:
			if slot.occupied:
				continue
			var item_center = dragging_item.global_position + dragging_item.size / 2
			if slot.get_world_rect().has_point(item_center):
				slot.set_highlight(true)
			else:
				slot.set_highlight(false)

func _input(event: InputEvent) -> void:
	if dragging_item == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_drop_item(dragging_item)

func _on_item_picked(item: UnpackItem) -> void:
	if item.placed or dragging_item != null:
		return
	dragging_item = item
	drag_offset = get_viewport().get_mouse_position() - item.global_position
	item.set_dragged(true)

func _drop_item(item: UnpackItem) -> void:
	item.set_dragged(false)
	var is_snapped = false

	for slot in slots:
		slot.set_highlight(false)
		if slot.occupied:
			continue
			
		var item_center = item.global_position + item.size / 2
		if slot.get_world_rect().has_point(item_center):
			if slot.accepts == item.item_type:
				# Correct placement
				var tween = create_tween()
				tween.tween_property(item, "global_position", slot.global_position + (slot.size - item.size) / 2.0, 0.15)\
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				slot.occupied = true
				item.set_placed(true)
				
				# Reparent to shelf so it stays relative to it
				var orig_global = item.global_position
				item.get_parent().remove_child(item)
				shelf_control.add_child(item)
				item.global_position = orig_global
				
				placed_items += 1
				_update_progress()
			else:
				# Wrong placement
				_shake_and_return(item)
			is_snapped = true
			break

	if not is_snapped:
		var tween = create_tween()
		tween.tween_property(item, "global_position", box_control.global_position + item.original_pos, 0.25)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	dragging_item = null
	_check_complete()

func _update_progress() -> void:
	progress_label.text = "Progress: %d / %d" % [placed_items, total_items]

func _shake_and_return(item: UnpackItem) -> void:
	var tween = create_tween()
	var start_pos = item.global_position
	tween.tween_property(item, "global_position", start_pos + Vector2(12, 0), 0.04)
	tween.tween_property(item, "global_position", start_pos - Vector2(12, 0), 0.04)
	tween.tween_property(item, "global_position", start_pos + Vector2(8, 0), 0.04)
	tween.tween_property(item, "global_position", box_control.global_position + item.original_pos, 0.15)
	
func _check_complete() -> void:
	if placed_items >= total_items and total_items > 0:
		await get_tree().create_timer(0.4).timeout
		puzzle_completed.emit(true)
		StoryManager.start_dialogue(["Wah rapiiii! Kamu jago banget bebenahin barang!"], "Rion")
		hide()
