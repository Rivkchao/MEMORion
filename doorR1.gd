extends Area3D

@export var marker_inside: Marker3D
@export var marker_outside: Marker3D
@export var interact_action: String = "interact"

var current_player: Node3D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if current_player:
		if (InputMap.has_action(interact_action) and event.is_action_pressed(interact_action)) or \
		   (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
			teleport_player()

func _on_body_entered(body: Node3D) -> void:
	if body is StaticBody3D:
		return
	if body is CharacterBody3D or body.is_in_group("player") or "Player" in body.name:
		current_player = body

func _on_body_exited(body: Node3D) -> void:
	if body == current_player:
		current_player = null

func teleport_player() -> void:
	if not marker_inside or not marker_outside or not current_player:
		print_rich("[color=red][PINTU][/color] Pastikan kedua marker sudah diisi di Inspector!")
		return

	# Hitung jarak player ke kedua marker
	var dist_to_inside = current_player.global_position.distance_to(marker_inside.global_position)
	var dist_to_outside = current_player.global_position.distance_to(marker_outside.global_position)

	# Pilih target marker yang posisinya paling jauh dari posisi player saat ini
	var target_marker = marker_outside if dist_to_inside < dist_to_outside else marker_inside

	# Pindahkan posisi dan samakan rotasi hadap player
	current_player.global_position = target_marker.global_position
	current_player.global_rotation.y = target_marker.global_rotation.y
