extends CharacterBody3D

@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var animation_tree: AnimationTree = get_node_or_null("AnimationTree")

var _playback: AnimationNodeStateMachinePlayback = null

func _ready() -> void:
	_setup_animation_tree()

func _setup_animation_tree() -> void:
	if animation_tree == null:
		animation_tree = get_node_or_null("AnimationTree")

	if animation_tree:
		animation_tree.active = true
		_playback = animation_tree.get("parameters/playback")
		if _playback:
			_playback.start("idle")

func play_animation(animation_name: String) -> void:
	if _playback:
		_playback.travel(animation_name)
	elif animation_player and animation_player.current_animation != animation_name:
		animation_player.play(animation_name)

