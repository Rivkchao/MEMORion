extends CanvasLayer

@onready var game_area: Control = $PopupPanel/MarginContainer/VBoxContainer/GameArea
@onready var title_label: Label = $PopupPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var hint_label: Label = $PopupPanel/MarginContainer/VBoxContainer/HintLabel

signal puzzle_completed(is_correct: bool)

var slots: Array = []
var items: Array = []
var dragging_item: Control = null
var drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	hide()
	hint_label.text = "Drag item ke slot yang sesuai!"

func start(puzzle_data: Dictionary) -> void:
	title_label.text = puzzle_data.get("title", "Naruh barang ke tempatnya!")
	_clear()
	_setup_slots(puzzle_data["slots"])
	_setup_items(puzzle_data["items"])
	show()

func _clear() -> void:
	for child in game_area.get_children():
		child.queue_free()
	slots.clear()
	items.clear()
	dragging_item = null

func _setup_slots(slot_data: Array) -> void:
	# Auto-layout slot di baris atas, centered
	var total = slot_data.size()
	var slot_size = Vector2(100, 100)
	var padding = 20
	var total_width = total * slot_size.x + (total - 1) * padding
	var start_x = (game_area.size.x - total_width) / 2
	
	for i in range(total):
		var data = slot_data[i]
		var slot = Panel.new()
		slot.position = Vector2(start_x + i * (slot_size.x + padding), 20)
		slot.size = slot_size
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.08)
		style.border_color = Color(1, 1, 1, 0.5)
		style.set_border_width_all(2)
		style.set_corner_radius_all(12)
		slot.add_theme_stylebox_override("panel", style)
		
		var label = Label.new()
		label.text = data["label"]
		label.set_anchors_preset(Control.PRESET_CENTER)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		slot.add_child(label)
		
		slot.set_meta("accepts", data["accepts"])
		slot.set_meta("occupied", false)
		
		game_area.add_child(slot)
		slots.append(slot)

func _setup_items(item_data: Array) -> void:
	# Auto-layout item di baris bawah, centered, diacak
	var shuffled = item_data.duplicate()
	shuffled.shuffle()
	
	var total = shuffled.size()
	var item_size = Vector2(90, 90)
	var padding = 20
	var total_width = total * item_size.x + (total - 1) * padding
	var start_x = (game_area.size.x - total_width) / 2
	var item_y = game_area.size.y - item_size.y - 20
	
	for i in range(total):
		var data = shuffled[i]
		var item = Panel.new()
		var pos = Vector2(start_x + i * (item_size.x + padding), item_y)
		item.position = pos
		item.size = item_size
		item.set_meta("type", data["type"])
		item.set_meta("original_pos", pos)
		item.set_meta("placed", false)
		
		var style = StyleBoxFlat.new()
		style.bg_color = data.get("color", Color(0.4, 0.7, 1.0))
		style.set_corner_radius_all(12)
		item.add_theme_stylebox_override("panel", style)
		
		var label = Label.new()
		label.text = data["label"]
		label.set_anchors_preset(Control.PRESET_CENTER)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		item.add_child(label)
		
		item.gui_input.connect(_on_item_input.bind(item))
		
		game_area.add_child(item)
		items.append(item)

func _on_item_input(event: InputEvent, item: Control) -> void:
	if item.get_meta("placed"):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and dragging_item == null:
			dragging_item = item
			drag_offset = event.position
			item.z_index = 10
		elif not event.pressed and dragging_item == item:
			_drop_item(item)

func _process(_delta: float) -> void:
	if dragging_item != null:
		dragging_item.global_position = get_viewport().get_mouse_position() - drag_offset

func _drop_item(item: Control) -> void:
	item.z_index = 0
	var item_center = item.global_position + item.size / 2
	var snapped = false
	
	for slot in slots:
		if slot.get_meta("occupied"):
			continue
		var slot_rect = Rect2(slot.global_position, slot.size)
		if slot_rect.has_point(item_center):
			if slot.get_meta("accepts") == item.get_meta("type"):
				# Snap ke slot dengan animasi
				var tween = create_tween()
				tween.tween_property(item, "global_position", slot.global_position + Vector2(5, 5), 0.15)
				slot.set_meta("occupied", true)
				item.set_meta("placed", true)
				snapped = true
				_on_correct_placement(item, slot)
				break
			else:
				# Salah slot — shake dan balik
				_shake_and_return(item)
				snapped = true
				break
	
	if not snapped:
		# Tidak kena slot apapun — balik ke posisi asal
		var tween = create_tween()
		tween.tween_property(item, "position", item.get_meta("original_pos"), 0.2)
	
	dragging_item = null
	_check_complete()

func _on_correct_placement(item: Control, _slot: Control) -> void:
	# Flash hijau
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.85, 0.4)
	style.set_corner_radius_all(12)
	item.add_theme_stylebox_override("panel", style)
	
	# Scale pop
	var tween = create_tween()
	tween.tween_property(item, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(item, "scale", Vector2(1.0, 1.0), 0.1)

func _shake_and_return(item: Control) -> void:
	# Shake kiri kanan lalu balik
	var original = item.get_meta("original_pos")
	var tween = create_tween()
	tween.tween_property(item, "position", item.position + Vector2(10, 0), 0.05)
	tween.tween_property(item, "position", item.position - Vector2(10, 0), 0.05)
	tween.tween_property(item, "position", item.position + Vector2(10, 0), 0.05)
	tween.tween_property(item, "position", original, 0.1)

func _check_complete() -> void:
	for item in items:
		if not item.get_meta("placed"):
			return
	
	await get_tree().create_timer(0.5).timeout
	puzzle_completed.emit(true)
	StoryManager.start_dialogue(["Wah rapiiii! Kamu jago banget bebenahin barang!"], "Rion")
	hide()
