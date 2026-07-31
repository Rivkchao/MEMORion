extends Interactable

func _ready() -> void:
	super._ready()
	interact_label = "Gunakan Terminal"

func interact() -> void:
	StoryManager.start_wire_puzzle()
