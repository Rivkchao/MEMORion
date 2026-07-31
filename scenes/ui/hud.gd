extends CanvasLayer

@onready var objective_text: Label = $ObjectivePanel/MarginContainer/VBoxContainer/ObjectiveText
@onready var progress_label: Label = $ObjectivePanel/MarginContainer/VBoxContainer/ProgressLabel

func set_objective(text: String) -> void:
	objective_text.text = text

func set_progress(current: int, total: int, item_name: String = "bintang") -> void:
	progress_label.text = "%d/%d %s ditemukan" % [current, total, item_name]
