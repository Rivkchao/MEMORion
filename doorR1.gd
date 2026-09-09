extends Area3D

@export var marker_inside: Marker3D
@export var marker_outside: Marker3D
@export var interact_action: String = "interact"

@export_group("Room Darkness Control")
@export var world_environment: WorldEnvironment
@export var inside_ambient_energy: float = 0.05   # Sangat gelap saat di dalam
@export var outside_ambient_energy: float = 0.55  # Normal saat di luar

# Variabel ini diakses langsung oleh lever.gd tanpa butuh class_name
@export var is_room_unlocked: bool = false

var current_player: Node3D = null


var label_3d: Label3D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	label_3d = Label3D.new()
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.font_size = 48
	label_3d.outline_size = 8
	label_3d.outline_modulate = Color(0, 0, 0, 1)
	label_3d.position = Vector3(0, 2.5, 0)
	add_child(label_3d)
	label_3d.hide()


func is_player_inside() -> bool:
	return current_player != null


func _unhandled_input(event: InputEvent) -> void:
	if current_player:
		if (InputMap.has_action(interact_action) and event.is_action_pressed(interact_action)) or \
		   (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
			teleport_player()


func _on_body_entered(body: Node3D) -> void:
	if body is StaticBody3D:
		return
	if body is CharacterBody3D or body.is_in_group("player") or "player" in body.name.to_lower():
		current_player = body
		if label_3d:
			var is_mobile := SettingsManager != null and SettingsManager.is_mobile_controls_active()
			label_3d.text = "Pindah Ruangan (Tekan Aksi)" if is_mobile else "Pindah Ruangan [E]"
			label_3d.show()


func _on_body_exited(body: Node3D) -> void:
	if body == current_player:
		current_player = null
		if label_3d:
			label_3d.hide()


func teleport_player() -> void:
	if not marker_inside or not marker_outside or not current_player:
		print_rich("[color=red][PINTU][/color] Pastikan kedua marker sudah diisi di Inspector!")
		return

	var dist_to_inside = current_player.global_position.distance_to(marker_inside.global_position)
	var dist_to_outside = current_player.global_position.distance_to(marker_outside.global_position)

	# Tentukan apakah player masuk ke dalam atau keluar
	var is_entering_inside: bool = dist_to_outside < dist_to_inside
	var target_marker = marker_inside if is_entering_inside else marker_outside

	current_player.global_position = target_marker.global_position
	current_player.global_rotation.y = target_marker.global_rotation.y

	_apply_room_lighting(is_entering_inside)


func _apply_room_lighting(is_inside: bool) -> void:
	if not world_environment or not world_environment.environment:
		return

	# Jika ruangan sudah dibuka via tuas, saat masuk jangan digelapkan
	if is_inside and is_room_unlocked:
		return

	var target_energy = inside_ambient_energy if is_inside else outside_ambient_energy
	var tween = create_tween()
	tween.tween_property(world_environment.environment, "ambient_light_energy", target_energy, 0.4)
