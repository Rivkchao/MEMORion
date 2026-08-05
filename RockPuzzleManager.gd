extends Node

signal puzzle_completed

var is_puzzle_active: bool = false
var dragging_rock: Node3D = null
var slots: Array = []
var rocks: Array = []

func register_slot(slot: Node3D) -> void:
	slots.append(slot)

func register_rock(rock: Node3D) -> void:
	rocks.append(rock)

func start_puzzle() -> void:
	is_puzzle_active = true

func check_complete() -> void:
	for slot in slots:
		if not slot.is_occupied():
			return
		if not slot.is_correct():
			return
	
	is_puzzle_active = false
	puzzle_completed.emit()
	StoryManager.start_dialogue(["Yeay! Jembatannya jadi! Ayo nyebrang!"], "Rion")
