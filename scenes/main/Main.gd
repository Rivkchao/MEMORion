extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var camera_rig: Node3D = $CameraRig
@onready var hud = $HUD
@onready var dialogue_box = $HUD/DialogueBox

func _ready() -> void:
	camera_rig.target = player.get_node("CameraTarget")
	StoryManager.init(dialogue_box)
