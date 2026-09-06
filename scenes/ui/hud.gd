# scenes/ui/hud.gd
extends CanvasLayer

@onready var objective_text: Label = $ObjectivePanel/MarginContainer/VBoxContainer/ObjectiveText
@onready var progress_label: Label = $ObjectivePanel/MarginContainer/VBoxContainer/ProgressLabel
@onready var settings_btn: Button = get_node_or_null("SettingsBtn")

func _ready() -> void:
	GameManager.init(self)
	
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)

func set_objective(text: String) -> void:
	if objective_text:
		objective_text.text = text

func set_progress(current: int, total: int, item_name: String = "bintang") -> void:
	if progress_label:
		progress_label.text = "%d/%d %s ditemukan" % [current, total, item_name]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_on_settings_pressed()

func _on_settings_pressed() -> void:
	SettingsManager.open_settings_dialog(self)
