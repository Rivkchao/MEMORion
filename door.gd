extends Interactable

@export_file("*.tscn") var target_scene: String = ""
@export var door_label: String = "Press E to Enter"
@export var spawn_position: Vector3 = Vector3.ZERO
@export var spawn_point: NodePath = NodePath("")
@export var detection_size: Vector3 = Vector3(8, 8, 8)
@export var locked_dialogue: Array[String] = ["Pintu ini terkunci."]
@export var locked_speaker: String = "Rion"

var player_inside: bool = false

func _ready() -> void:
	if get_node_or_null("Label3D") == null:
		var lbl := Label3D.new()
		lbl.name = "Label3D"
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.font_size = 48
		lbl.outline_size = 8
		lbl.outline_modulate = Color(0, 0, 0, 1)
		lbl.position = to_local(_compute_anchor_global()) + Vector3(0, 3.5, 0)
		add_child(lbl)
	label_3d = get_node_or_null("Label3D")

	super._ready()
	interact_label = door_label

	var area := get_node_or_null("Area3D") as Area3D
	if area == null and (collision_layer & 4) == 0:
		area = _build_detection_area()
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

	hide_prompt()

func show_prompt() -> void:
	if label_3d:
		var is_mobile := SettingsManager != null and SettingsManager.is_mobile_controls_active()
		label_3d.text = "Masuk (Tekan Aksi)" if is_mobile else door_label
		label_3d.show()

func get_label() -> String:
	return "MASUK"

func _input(event: InputEvent) -> void:
	if player_inside and event.is_action_pressed("interact"):
		if _is_ui_blocking():
			return
		interact()

func _build_detection_area() -> Area3D:
	var area := Area3D.new()
	area.name = "Area3D"
	area.top_level = true
	area.collision_layer = 0
	area.collision_mask = 2

	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = detection_size
	shape.shape = box
	area.add_child(shape)

	add_child(area)
	var anchor := _compute_anchor_global()
	anchor.y = global_position.y + detection_size.y * 0.5
	area.global_position = anchor
	return area

func _compute_anchor_global() -> Vector3:
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		return mi.global_transform * mi.get_aabb().get_center()
	return global_position

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name.to_lower() == "player":
		player_inside = true
		show_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name.to_lower() == "player":
		player_inside = false
		hide_prompt()

func interact() -> void:
	# Cek apakah pemain mencoba masuk sebelum Ona sampai dan menyelesaikan dialog di Point 9
	if target_scene.contains("R1") and not GameManager.point_9_dialog_done and not GameManager.has_visited_workshop:
		var wait_ona_msg: Array[String] = [
			"Rion: (Menatap pintu bengkel dengan ragu) Aku harus menunggu Ona sampai di sini dulu... Aku tidak berani masuk sendirian."
		]
		if StoryManager and StoryManager.has_method("start_dialogue"):
			StoryManager.start_dialogue(wait_ona_msg, "Rion")
		return

	# Cek apakah pintu bengkel sedang terkunci dari cerita (Scene 5)
	if target_scene.contains("R1") and GameManager.workshop_door_locked:
		var ona_node = get_tree().get_first_node_in_group("ona")
		if ona_node == null:
			ona_node = get_parent().find_child("Ona", true, false)
		
		# Jika pemain sudah menikmati kebun / bunga dan kembali ke pintu bengkel:
		if GameManager.garden_intro_done and not GameManager.sleep_transition_done:
			if GameManager.collected_flower_count == 0:
				var empty_msg: Array[String] = [
					"Ona: Rion, keranjang kita masih kosong. Ayo petik beberapa tangkai bunga kosmik di sepanjang jalan kebun dulu sebelum kita kembali ke bengkel ya!"
				]
				if StoryManager and StoryManager.has_method("start_dialogue"):
					StoryManager.start_dialogue(empty_msg, "Ona")
				return

			if ona_node and ona_node.has_method("trigger_flower_memory_evaluation"):
				ona_node.trigger_flower_memory_evaluation()
				return

		var locked_msg: Array[String] = [
			"Ona: Ayo kita jalan-jalan santai di sekitar kebun luar dulu, Rion. Supaya kamu bisa menghirup udara segar dan merasa lebih rileks."
		]
		if StoryManager and StoryManager.has_method("start_dialogue"):
			StoryManager.start_dialogue(locked_msg, "Ona")
		return

	if not spawn_point.is_empty() or spawn_position != Vector3.ZERO:
		if _teleport_player():
			return
	if target_scene != "":
		_change_scene()
		return
	if _teleport_player():
		return
	_show_locked()

func _teleport_player() -> bool:
	var player := _get_player()
	if player == null:
		return false

	var target_pos := Vector3.ZERO

	if not spawn_point.is_empty():
		var marker := get_node_or_null(spawn_point) as Node3D
		if marker:
			target_pos = marker.global_position

	if target_pos == Vector3.ZERO:
		var parent_room = get_parent()
		if parent_room:
			for child in parent_room.get_children():
				if child is Marker3D:
					target_pos = child.global_position
					break

	if target_pos == Vector3.ZERO and spawn_position != Vector3.ZERO:
		target_pos = spawn_position

	if target_pos != Vector3.ZERO:
		player.global_position = target_pos
		if "velocity" in player:
			player.set("velocity", Vector3.ZERO)
		if "last_safe_position" in player:
			player.set("last_safe_position", target_pos)
		return true

	return false

func _get_player() -> Node3D:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		player = get_tree().root.find_child("Player", true, false) as Node3D
	return player

func _show_locked() -> void:
	if StoryManager and StoryManager.has_method("start_dialogue"):
		StoryManager.start_dialogue(locked_dialogue, locked_speaker)

func _change_scene() -> void:
	var player = _get_player()
	if player and GameManager.has_method("save_state"):
		GameManager.save_state(player, target_scene)

	if has_node("/root/LoadingScreen"):
		LoadingScreen.load_scene(target_scene)
	else:
		get_tree().change_scene_to_file(target_scene)

func _is_ui_blocking() -> bool:
	if StoryManager == null:
		return false
	if StoryManager.dialogue_box != null and StoryManager.dialogue_box.is_active():
		return true
	if StoryManager.matching_puzzle != null and StoryManager.matching_puzzle.visible:
		return true
	if StoryManager.wire_puzzle != null and StoryManager.wire_puzzle.visible:
		return true
	return false
