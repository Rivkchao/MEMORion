extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var camera_rig: Node3D = $CameraRig
@onready var hud = $HUD
@onready var dialogue_box = $HUD/DialogueBox

func _ready() -> void:
	camera_rig.target = player.get_node("CameraTarget")
	StoryManager.init($HUD/DialogueBox, $HUD/PuzzleUI, null, $HUD/WirePuzzle)
	GameManager.init($HUD)
	GameManager.set_objective("Cari bintang tersembunyi!", 3, "bintang")
