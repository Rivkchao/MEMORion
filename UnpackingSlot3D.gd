extends Node3D

@export var memorize_duration: float = 4.0

@onready var slots_container: Node3D = $SlotsContainer
@onready var items_container: Node3D = $ItemsContainer
@onready var countdown_label: Label3D = $CountdownLabel

var slots: Array[PlacementSlot3D] = []
var items: Array[Carryable3D] = []
var puzzle_active: bool = false
var puzzle_done: bool = false

signal puzzle_completed

func _ready() -> void:
	# Kumpulkan semua slot dan item
	for child in slots_container.get_children():
		if child is PlacementSlot3D:
			slots.append(child)
	for child in items_container.get_children():
		if child is Carryable3D:
			items.append(child)
	
	countdown_label.hide()
	
	# Sembunyikan item di awal
	for item in items:
		item.hide()

func start_puzzle() -> void:
	if puzzle_done:
		return
	puzzle_active = true
	_phase_memorize()

func _phase_memorize() -> void:
	# Tampilkan semua item di slot masing-masing
	for i in range(min(items.size(), slots.size())):
		items[i].show()
		items[i].global_position = slots[i].global_position + Vector3(0, 0.1, 0)
	
	# Countdown
	countdown_label.show()
	var time_left = memorize_duration
	
	while time_left > 0:
		countdown_label.text = "Hafalkan! %.0f" % ceil(time_left)
		await get_tree().create_timer(0.1).timeout
		time_left -= 0.1
	
	countdown_label.hide()
	_phase_clear()

func _phase_clear() -> void:
	# Tween semua item ke ItemsContainer (meja)
	for i in range(items.size()):
		var item = items[i]
		var target_pos = items_container.global_position + Vector3(
			(i % 4) * 0.8 - 1.2,
			0,
			int(i / 4) * 0.8
		)
		var tween = create_tween()
		tween.tween_property(item, "global_position", target_pos, 0.4)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		item.original_position = target_pos
	
	await get_tree().create_timer(0.5).timeout
	
	# Aktifkan slot
	for slot in slots:
		slot.clear_slot()
	
	StoryManager.start_dialogue(["Oke! Sekarang kembalikan barang-barang ke tempatnya ya!"], "Rion")

func check_complete() -> void:
	for slot in slots:
		if not slot.is_filled:
			return
	
	puzzle_done = true
	puzzle_active = false
	puzzle_completed.emit()
	StoryManager.start_dialogue(["Wah ingatan kamu keren banget! Semua barang kembali ke tempatnya!"], "Rion")
