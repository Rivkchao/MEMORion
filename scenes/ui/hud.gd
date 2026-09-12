# scenes/ui/hud.gd
extends CanvasLayer

@onready var objective_panel: PanelContainer = $ObjectivePanel
@onready var objective_title: Label = $ObjectivePanel/MarginContainer/VBoxContainer/ObjectiveTitle
@onready var objective_text: Label = $ObjectivePanel/MarginContainer/VBoxContainer/ObjectiveText
@onready var progress_label: Label = $ObjectivePanel/MarginContainer/VBoxContainer/ProgressLabel
@onready var settings_btn: Button = get_node_or_null("SettingsBtn")

var _obj_base_pos_x: float = 32.0
var _gameplay_ui_visible: bool = true

func _ready() -> void:
	GameManager.init(self)
	_setup_quest_hud_style()

	# Sembunyikan kontrol sentuh saat dialog, tampilkan lagi setelah selesai
	var db = find_child("DialogueBox", true, false)
	if db:
		if db.has_signal("dialogue_started"):
			db.dialogue_started.connect(_on_dialogue_started)
		if db.has_signal("dialogue_finished"):
			db.dialogue_finished.connect(_on_dialogue_finished)

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

func _setup_quest_hud_style() -> void:
	if not is_instance_valid(objective_panel):
		return

	# Load Fonts Telegraf
	var bold_font = load("res://Fonts/Telegraf-Bold-fix15408087824949790956.30.2aa1f309-cb96-4ad6-a94f-e5147e9.ttf")
	var reg_font = load("res://Fonts/telegraf_regular_fix7340951357143627189..44096e48-3548-42c1-bd8a-c4745e9.ttf")

	# Panel Styling (Genshin Impact / Open-World aesthetic)
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_panel.offset_left = 32.0
	objective_panel.offset_top = 28.0
	objective_panel.offset_right = 380.0
	objective_panel.offset_bottom = 120.0
	objective_panel.custom_minimum_size = Vector2(320, 0)
	_obj_base_pos_x = objective_panel.offset_left

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.14, 0.78) # Dark frosted glass
	panel_style.border_width_left = 4
	panel_style.border_color = Color(1.0, 0.82, 0.35, 0.95) # Radiant amber gold quest strip
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_right = 14
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	panel_style.shadow_size = 10
	panel_style.shadow_offset = Vector2(2, 4)
	panel_style.content_margin_left = 18
	panel_style.content_margin_top = 12
	panel_style.content_margin_right = 18
	panel_style.content_margin_bottom = 12
	objective_panel.add_theme_stylebox_override("panel", panel_style)

	var margin = objective_panel.get_node_or_null("MarginContainer") as MarginContainer
	if margin:
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 4)
		margin.add_theme_constant_override("margin_top", 2)
		margin.add_theme_constant_override("margin_right", 4)
		margin.add_theme_constant_override("margin_bottom", 2)

	var vbox = objective_panel.find_child("VBoxContainer", true, false) as VBoxContainer
	if vbox:
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_theme_constant_override("separation", 6)

	# 1. Header / Kategori Misi
	if objective_title:
		objective_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		objective_title.text = "✦  MISI UTAMA"
		if bold_font:
			objective_title.add_theme_font_override("font", bold_font)
		objective_title.add_theme_font_size_override("font_size", 12)
		objective_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.38, 1.0))
		objective_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		objective_title.add_theme_constant_override("shadow_offset_x", 1)
		objective_title.add_theme_constant_override("shadow_offset_y", 1)

	# 2. Teks Deskripsi Misi
	if objective_text:
		objective_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if reg_font:
			objective_text.add_theme_font_override("font", reg_font)
		objective_text.add_theme_font_size_override("font_size", 15)
		objective_text.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0, 1.0))
		objective_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		objective_text.add_theme_constant_override("shadow_offset_x", 1)
		objective_text.add_theme_constant_override("shadow_offset_y", 1)
		objective_text.add_theme_constant_override("line_spacing", 3)
		objective_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		objective_text.custom_minimum_size = Vector2(290, 0)
		if objective_text.text.is_empty():
			objective_text.text = "Jelajahi sekitar dan ikuti petunjuk Ona."

	# 3. Counter Progress (misal X/10 bunga)
	if progress_label:
		progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if bold_font:
			progress_label.add_theme_font_override("font", bold_font)
		progress_label.add_theme_font_size_override("font_size", 13)
		progress_label.add_theme_color_override("font_color", Color(0.42, 0.92, 1.0, 1.0)) # Starlight Cyan
		progress_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		progress_label.add_theme_constant_override("shadow_offset_x", 1)
		progress_label.add_theme_constant_override("shadow_offset_y", 1)
		# Sembunyikan jika belum ada misi pencarian aktif
		if progress_label.text.is_empty():
			progress_label.visible = false

func set_objective(text: String) -> void:
	if objective_text:
		objective_text.text = text
		_animate_objective_update()

func set_progress(current: int, total: int, item_name: String = "bintang") -> void:
	if progress_label:
		if total <= 0:
			progress_label.text = ""
			progress_label.visible = false
		else:
			progress_label.visible = true
			var icon = "✿" if item_name.contains("bunga") else "✦"
			progress_label.text = "%s  %d / %d %s ditemukan" % [icon, current, total, item_name]
			_animate_progress_pulse()

func _animate_objective_update() -> void:
	if not is_instance_valid(objective_panel):
		return
	var tween = create_tween().set_parallel(true)
	objective_panel.offset_left = _obj_base_pos_x - 12.0
	objective_panel.modulate.a = 0.3
	tween.tween_property(objective_panel, "offset_left", _obj_base_pos_x, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(objective_panel, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _animate_progress_pulse() -> void:
	if not is_instance_valid(progress_label):
		return
	progress_label.pivot_offset = Vector2(0, progress_label.size.y / 2.0)
	var tween = create_tween()
	tween.tween_property(progress_label, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(progress_label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_on_settings_pressed()

func _on_settings_pressed() -> void:
	SettingsManager.open_settings_dialog(self)

func _on_dialogue_started() -> void:
	var mobile = find_child("MobileControls", true, false)
	if mobile:
		mobile.visible = false

func _on_dialogue_finished() -> void:
	if not _gameplay_ui_visible:
		return
	var mobile = find_child("MobileControls", true, false)
	if mobile:
		if SettingsManager and SettingsManager.has_method("is_mobile_controls_active"):
			mobile.visible = SettingsManager.is_mobile_controls_active()
		else:
			mobile.visible = true

func set_gameplay_ui_visible(is_vis: bool) -> void:
	_gameplay_ui_visible = is_vis
	for node_name in ["Prompt", "ObjectivePanel", "SettingsBtn"]:
		var n = find_child(node_name, true, false)
		if n:
			n.visible = is_vis

	var mobile = find_child("MobileControls", true, false)
	if mobile:
		if not is_vis:
			mobile.visible = false
		else:
			if SettingsManager and SettingsManager.has_method("is_mobile_controls_active"):
				mobile.visible = SettingsManager.is_mobile_controls_active()
			else:
				mobile.visible = true
