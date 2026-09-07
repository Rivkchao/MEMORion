# scenes/ui/hud.gd
extends CanvasLayer

@onready var objective_text: Label = $ObjectivePanel/MarginContainer/VBoxContainer/ObjectiveText
@onready var progress_label: Label = $ObjectivePanel/MarginContainer/VBoxContainer/ProgressLabel
@onready var settings_btn: Button = get_node_or_null("SettingsBtn")

func _ready() -> void:
	GameManager.init(self)
	
	if settings_btn:
		settings_btn.pivot_offset = settings_btn.size / 2.0
		settings_btn.button_down.connect(func():
			var tween = create_tween()
			tween.tween_property(settings_btn, "scale", Vector2(0.9, 0.9), 0.08).set_ease(Tween.EASE_OUT)
		)
		settings_btn.button_up.connect(func():
			var tween = create_tween()
			tween.tween_property(settings_btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		)
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
