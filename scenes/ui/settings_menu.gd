# scenes/ui/settings_menu.gd
extends Control
class_name SettingsMenu

signal closed

# Display References
@onready var brightness_slider: HSlider = %BrightnessSlider
@onready var brightness_label: Label = %BrightnessValue
@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var resolution_option: OptionButton = %ResolutionOption

# Audio References
@onready var vol_general_slider: HSlider = %VolGeneralSlider
@onready var vol_general_label: Label = %VolGeneralValue
@onready var vol_bgm_slider: HSlider = %VolBgmSlider
@onready var vol_bgm_label: Label = %VolBgmValue
@onready var vol_sfx_slider: HSlider = %VolSfxSlider
@onready var vol_sfx_label: Label = %VolSfxValue

# Controls References
@onready var mobile_mode_option: OptionButton = %MobileModeOption

# Action Buttons
@onready var save_btn: Button = %SaveBtn
@onready var reset_btn: Button = %ResetBtn
@onready var close_btn: Button = %CloseBtn
@onready var panel_container: PanelContainer = %PanelContainer

var _was_paused_before_open: bool = false
var _initial_brightness: float = 1.0
var _initial_volume_general: float = 0.8
var _initial_volume_bgm: float = 0.8
var _initial_volume_sfx: float = 0.8
var _initial_window_mode: int = 0
var _initial_resolution: int = 0
var _initial_mobile_mode: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	_populate_options()
	_connect_signals()
	_sync_from_manager()

func _populate_options() -> void:
	# Populate Mode Layar
	if window_mode_option:
		window_mode_option.clear()
		for m in SettingsManager.WINDOW_MODES:
			window_mode_option.add_item(m)
	
	# Populate Resolusi
	if resolution_option:
		resolution_option.clear()
		for res in SettingsManager.RESOLUTIONS:
			resolution_option.add_item(res["name"])
	
	# Populate Kontrol Mobile
	if mobile_mode_option:
		mobile_mode_option.clear()
		mobile_mode_option.add_item("Otomatis (Layar Sentuh)")
		mobile_mode_option.add_item("Selalu Aktif (Paksa Tampil)")
		mobile_mode_option.add_item("Nonaktif (Keyboard/Mouse)")

func _connect_signals() -> void:
	brightness_slider.value_changed.connect(_on_brightness_changed)
	
	if window_mode_option:
		window_mode_option.item_selected.connect(_on_window_mode_selected)
	
	if resolution_option:
		resolution_option.item_selected.connect(_on_resolution_selected)
	
	vol_general_slider.value_changed.connect(_on_vol_general_changed)
	vol_bgm_slider.value_changed.connect(_on_vol_bgm_changed)
	vol_sfx_slider.value_changed.connect(_on_vol_sfx_changed)
	
	if mobile_mode_option:
		mobile_mode_option.item_selected.connect(_on_mobile_mode_selected)
	
	save_btn.pressed.connect(_on_save_pressed)
	reset_btn.pressed.connect(_on_reset_pressed)
	close_btn.pressed.connect(_on_close_pressed)

	for btn in [save_btn, reset_btn, close_btn]:
		if btn:
			btn.pivot_offset = btn.size / 2.0
			btn.button_down.connect(func():
				var tween = create_tween()
				tween.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.08).set_ease(Tween.EASE_OUT)
			)
			btn.button_up.connect(func():
				var tween = create_tween()
				tween.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			)

	var dim = get_node_or_null("DimOverlay")
	if dim:
		dim.gui_input.connect(func(event):
			if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
				_on_close_pressed()
		)
	
	if SettingsManager:
		SettingsManager.window_mode_changed.connect(_on_settings_window_mode_changed)
		SettingsManager.resolution_changed.connect(_on_settings_resolution_changed)

func _sync_from_manager() -> void:
	if SettingsManager == null:
		return
	
	# Brightness
	brightness_slider.value = SettingsManager.brightness
	_update_brightness_label(SettingsManager.brightness)
	
	# Window Mode & Resolution
	if window_mode_option:
		window_mode_option.selected = clamp(SettingsManager.window_mode_index, 0, SettingsManager.WINDOW_MODES.size() - 1)
	if resolution_option:
		resolution_option.selected = clamp(SettingsManager.resolution_index, 0, SettingsManager.RESOLUTIONS.size() - 1)
	
	# Audio
	vol_general_slider.value = SettingsManager.volume_general
	_update_vol_label(vol_general_label, SettingsManager.volume_general)
	
	vol_bgm_slider.value = SettingsManager.volume_bgm
	_update_vol_label(vol_bgm_label, SettingsManager.volume_bgm)
	
	vol_sfx_slider.value = SettingsManager.volume_sfx
	_update_vol_label(vol_sfx_label, SettingsManager.volume_sfx)
	
	# Mobile Controls Mode
	if mobile_mode_option:
		mobile_mode_option.selected = clamp(SettingsManager.mobile_controls_mode, 0, 2)

# ----------------------------------------------------
# Event Handlers: Live Tweaks
# ----------------------------------------------------
func _on_brightness_changed(val: float) -> void:
	SettingsManager.set_brightness(val)
	_update_brightness_label(val)

func _update_brightness_label(val: float) -> void:
	brightness_label.text = "%d%%" % int(val * 100.0)

func _on_window_mode_selected(index: int) -> void:
	SettingsManager.set_window_mode(index)

func _on_resolution_selected(index: int) -> void:
	SettingsManager.set_resolution(index)

func _on_settings_window_mode_changed(index: int) -> void:
	if window_mode_option:
		window_mode_option.selected = index

func _on_settings_resolution_changed(index: int) -> void:
	if resolution_option:
		resolution_option.selected = index

func _on_vol_general_changed(val: float) -> void:
	SettingsManager.set_volume_general(val)
	_update_vol_label(vol_general_label, val)

func _on_vol_bgm_changed(val: float) -> void:
	SettingsManager.set_volume_bgm(val)
	_update_vol_label(vol_bgm_label, val)

func _on_vol_sfx_changed(val: float) -> void:
	SettingsManager.set_volume_sfx(val)
	_update_vol_label(vol_sfx_label, val)

func _update_vol_label(lbl: Label, val: float) -> void:
	lbl.text = "%d%%" % int(val * 100.0)

func _on_mobile_mode_selected(index: int) -> void:
	SettingsManager.set_mobile_controls_mode(index)

func _on_save_pressed() -> void:
	SettingsManager.save_settings()
	close()

func _on_reset_pressed() -> void:
	SettingsManager.reset_to_defaults()
	_sync_from_manager()

func _on_close_pressed() -> void:
	if SettingsManager:
		# Kembalikan pengaturan ke snapshot awal sebelum modal dibuka
		var display_changed: bool = (SettingsManager.window_mode_index != _initial_window_mode) or (SettingsManager.resolution_index != _initial_resolution)
		
		SettingsManager.brightness = _initial_brightness
		SettingsManager.volume_general = _initial_volume_general
		SettingsManager.volume_bgm = _initial_volume_bgm
		SettingsManager.volume_sfx = _initial_volume_sfx
		SettingsManager.window_mode_index = _initial_window_mode
		SettingsManager.resolution_index = _initial_resolution
		SettingsManager.mobile_controls_mode = _initial_mobile_mode
		
		SettingsManager._apply_brightness()
		SettingsManager._apply_bus_volume(SettingsManager._bus_master, _initial_volume_general)
		SettingsManager._apply_bus_volume(SettingsManager._bus_bgm, _initial_volume_bgm)
		SettingsManager._apply_bus_volume(SettingsManager._bus_sfx, _initial_volume_sfx)
		SettingsManager.mobile_controls_toggled.emit(SettingsManager.is_mobile_controls_active())
		
		# Hanya terapkan ulang display jika user sempat mengubahnya saat di menu
		if display_changed:
			SettingsManager._apply_window_mode()
	close()

# ----------------------------------------------------
# Modal Open & Close Animations
# ----------------------------------------------------
func open() -> void:
	_was_paused_before_open = get_tree().paused
	
	if SettingsManager:
		_initial_brightness = SettingsManager.brightness
		_initial_volume_general = SettingsManager.volume_general
		_initial_volume_bgm = SettingsManager.volume_bgm
		_initial_volume_sfx = SettingsManager.volume_sfx
		_initial_window_mode = SettingsManager.window_mode_index
		_initial_resolution = SettingsManager.resolution_index
		_initial_mobile_mode = SettingsManager.mobile_controls_mode
	
	var current_scene = get_tree().current_scene
	if current_scene != null and current_scene.name != "MainMenu":
		get_tree().paused = true
	
	_sync_from_manager()
	visible = true
	modulate.a = 0.0
	panel_container.scale = Vector2(0.9, 0.9)
	panel_container.pivot_offset = panel_container.size / 2.0
	
	var tween = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_container, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close() -> void:
	var tween = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(panel_container, "scale", Vector2(0.9, 0.9), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	
	visible = false
	if not _was_paused_before_open:
		get_tree().paused = false
	
	closed.emit()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close_pressed()
