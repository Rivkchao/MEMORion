# scenes/interactables/CollectibleFlower.gd
extends Interactable

@export var flower_index: int = 0
@export var flower_color_name: String = "biru kosmik"

@onready var glow_particles: GPUParticles3D = get_node_or_null("GlowParticles")
@onready var flower_mesh_node: Node3D = get_node_or_null("Flower_3_Group2")

var is_collected: bool = false
var _player_ref: Node3D = null
var _locked_notice_shown: bool = false

func _can_collect() -> bool:
	# Bunga baru boleh dipetik setelah alur cerita masuk ke kebun (Scene 5).
	return GameManager != null and GameManager.garden_intro_done

func _show_locked_notice() -> void:
	if _locked_notice_shown:
		return
	_locked_notice_shown = true
	if StoryManager and StoryManager.has_method("start_dialogue"):
		StoryManager.start_dialogue(
			["Rion: Bunga-bunga ini sepertinya belum saatnya kupetik. Aku ingin menikmatinya nanti bersama Ona."],
			"Rion"
		)

func _ready() -> void:
	add_to_group("collectible_flowers")
	interact_label = "Petik Bunga"
	if label_3d == null:
		label_3d = get_node_or_null("Label3D")
	if label_3d:
		label_3d.text = "✦ Petik Bunga (Tekan E)"
		label_3d.hide()

func show_prompt() -> void:
	if is_collected:
		return
	if not _can_collect():
		return
	if label_3d:
		var is_mobile := SettingsManager != null and SettingsManager.is_mobile_controls_active()
		label_3d.text = "✦ Petik Bunga (Tekan Aksi)" if is_mobile else "✦ Petik Bunga (Tekan E)"
		label_3d.show()

func hide_prompt() -> void:
	if label_3d:
		label_3d.hide()

func get_label() -> String:
	return "PETIK BUNGA"

func interact() -> void:
	if is_collected:
		return
	if not _can_collect():
		_show_locked_notice()
		return
	collect()

func _physics_process(_delta: float) -> void:
	if is_collected:
		return
	if _player_ref == null:
		_player_ref = get_tree().get_first_node_in_group("player") as Node3D
	if _player_ref:
		var dist = global_position.distance_to(_player_ref.global_position)
		if dist <= 2.8 and _can_collect():
			show_prompt()
			if Input.is_action_just_pressed("interact") or Input.is_key_pressed(KEY_E):
				collect()
		else:
			if label_3d and label_3d.visible:
				var p = _player_ref as CharacterBody3D
				if p and p.get("current_interactable") != self:
					hide_prompt()

func collect() -> void:
	if is_collected:
		return
	is_collected = true
	hide_prompt()
	
	if AudioManager:
		AudioManager.play_item_pickup()

	if GameManager:
		GameManager.collected_flower_count += 1
		print("[CollectibleFlower] Bunga terkumpul: ", GameManager.collected_flower_count, " / ", GameManager.max_collectible_flowers)
		
		# Update progress HUD di kiri atas
		GameManager.update_flower_hud()
		
		# Update basket tampilan
		var basket = get_tree().get_first_node_in_group("flower_basket")
		if basket and basket.has_method("update_flower_display"):
			basket.update_flower_display(GameManager.collected_flower_count)
			if basket.has_method("play_collect_pop"):
				basket.play_collect_pop()

		# Jika sudah terkumpul 10 bunga, langsung munculkan dialog evaluasi bersama Ona!
		if GameManager.collected_flower_count >= GameManager.max_collectible_flowers:
			var ona_node = get_tree().get_first_node_in_group("ona")
			if ona_node == null:
				ona_node = get_tree().root.find_child("Ona", true, false)
			if ona_node and ona_node.has_method("trigger_flower_memory_evaluation"):
				ona_node.call_deferred("trigger_flower_memory_evaluation")

	# Animasi petik bunga: melayang naik, memudar, lalu hilang
	var tw = create_tween().set_parallel(true)
	tw.tween_property(self, "global_position:y", global_position.y + 1.2, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	queue_free()

