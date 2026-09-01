extends CanvasLayer

var label: Label
var panel: Panel

func _ready() -> void:
	layer = 10
	visible = false
	
	panel = Panel.new()
	panel.custom_minimum_size = Vector2(300, 100)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2((get_viewport().get_visible_rect().size.x - 300) * 0.5, 60)
	# Jangan blokir klik mouse ke batu 3D di belakangnya
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = ""
	
	panel.add_child(label)
	add_child(panel)

func show_distraction() -> void:
	visible = true
	# Generate soal angka cepat acak
	var a = randi_range(3, 15)
	var b = randi_range(2, 9)
	label.text = "⚠️ DISTRAKSI CEPAT!\nHitung: %d + %d = ?" % [a, b]
	
	# Muncul dengan animasi pop
	panel.scale = Vector2.ZERO
	panel.pivot_offset = panel.size * 0.5
	var tween = create_tween()
	tween.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Hilang otomatis setelah 2.2 detik
	await get_tree().create_timer(2.2).timeout
	var tween_out = create_tween()
	tween_out.tween_property(panel, "scale", Vector2.ZERO, 0.2)
	await tween_out.finished
	visible = false
