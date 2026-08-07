extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var camera_rig: Node3D = $CameraRig
@onready var hud = $HUD
@onready var dialogue_box = $HUD/DialogueBox

func _ready() -> void:
	camera_rig.target = player.get_node("CameraTarget")
	StoryManager.init($HUD/DialogueBox, $HUD/PuzzleUI, $HUD/MatchingPuzzle, $HUD/WirePuzzle, $HUD/UnpackingPuzzle)
	GameManager.init($HUD)
	GameManager.set_objective("Cari bintang tersembunyi!", 3, "bintang")
	RockPuzzleManager.setup_camera(camera_rig, Vector3(-25, 0, 0))
	# Test unpacking
	await get_tree().create_timer(1.0).timeout
	StoryManager.start_unpacking({
		"title": "Naruh barang ke tempatnya!",
		"slots": [
			{"position": Vector2(100, 100), "size": Vector2(90, 90), "label": "Buku", "accepts": "buku"},
			{"position": Vector2(250, 100), "size": Vector2(90, 90), "label": "Alat", "accepts": "alat"},
			{"position": Vector2(400, 100), "size": Vector2(90, 90), "label": "Mainan", "accepts": "mainan"},
		],
		"items": [
			{"position": Vector2(100, 300), "size": Vector2(80, 80), "label": "Buku Cerita", "type": "buku", "color": Color(0.3, 0.6, 1.0)},
			{"position": Vector2(250, 300), "size": Vector2(80, 80), "label": "Obeng", "type": "alat", "color": Color(1.0, 0.6, 0.2)},
			{"position": Vector2(400, 300), "size": Vector2(80, 80), "label": "Lego", "type": "mainan", "color": Color(0.9, 0.3, 0.3)},
		]
	})
