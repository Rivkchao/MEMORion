extends Node

var hud: CanvasLayer = null
var objective_current: int = 0
var objective_total: int = 0
var objective_item: String = "bintang"

var spawn_override_position: Vector3 = Vector3.ZERO
var spawn_override_scene: String = "LEV1"
var has_spawn_override: bool = false

func set_spawn_override(pos: Vector3, for_scene_name: String = "LEV1") -> void:
	spawn_override_position = pos
	spawn_override_scene = for_scene_name
	has_spawn_override = true

func consume_spawn_override_for(current_scene_str: String) -> Vector3:
	if has_spawn_override:
		if spawn_override_scene == "" or current_scene_str.contains(spawn_override_scene) or spawn_override_scene.contains(current_scene_str):
			has_spawn_override = false
			return spawn_override_position
	return Vector3.ZERO

func save_state(player_node: Node3D, target_scene_for_override: String = "LEV1") -> void:
	if player_node:
		set_spawn_override(player_node.global_position, target_scene_for_override)

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