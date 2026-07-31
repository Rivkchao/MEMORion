extends Node

var hud: CanvasLayer = null
var objective_current: int = 0
var objective_total: int = 0
var objective_item: String = "bintang"

func init(hud_node: CanvasLayer) -> void:
	hud = hud_node

func set_objective(text: String, total: int, item_name: String = "bintang") -> void:
	objective_total = total
	objective_current = 0
	objective_item = item_name
	if hud:
		hud.set_objective(text)
		hud.set_progress(0, total, item_name)

func add_progress() -> void:
	objective_current = min(objective_current + 1, objective_total)
	if hud:
		hud.set_progress(objective_current, objective_total, objective_item)
	
	if objective_current >= objective_total:
		_on_objective_complete()

func _on_objective_complete() -> void:
	print("Objective complete!")
	StoryManager.start_dialogue(["Hebat! Kamu berhasil mengumpulkan semua bintang!"], "Rion")
