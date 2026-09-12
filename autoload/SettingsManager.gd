# autoload/SettingsManager.gd
extends Node

signal settings_saved
signal mobile_controls_toggled(active: bool)
signal resolution_changed(index: int)
signal window_mode_changed(index: int)

const CONFIG_PATH: String = "user://settings.cfg"

# Resolusi yang didukung
const RESOLUTIONS = [
	{"name": "Tinggi - 1080p (1920×1080)", "width": 1920, "height": 1080},
	{"name": "Sedang - 720p (1280×720)", "width": 1280, "height": 720},
	{"name": "Rendah - 480p (854×480)", "width": 854, "height": 480}
]

# Mode Tampilan Layar: 0 = Jendela, 1 = Layar Penuh, 2 = Jendela Maksimal
const WINDOW_MODES = [
	"Jendela (Windowed)",
	"Layar Penuh (Fullscreen)",
	"Jendela Maksimal (Maximized)"
]

# Mode kontrol mobile: 0 = Otomatis, 1 = Selalu Aktif, 2 = Nonaktif
enum MobileControlsMode {
	AUTO = 0,
	ALWAYS_ON = 1,
	ALWAYS_OFF = 2
}

# --- State Pengaturan ---
var brightness: float = 1.0 # 0.0 (gelap total) hingga 1.0 (normal/terang penuh)
var volume_general: float = 0.8 # 0.0 - 1.0 (Master)
var volume_bgm: float = 0.8 # 0.0 - 1.0 (Music)
var volume_sfx: float = 0.8 # 0.0 - 1.0 (SFX)
var resolution_index: int = 0 # 0 = 1080p, 1 = 720p, 2 = 480p
var window_mode_index: int = 0 # 0 = Windowed, 1 = Fullscreen, 2 = Maximized
var mobile_controls_mode: int = MobileControlsMode.AUTO

# Overlay Brightness Global
var _brightness_layer: CanvasLayer = null
var _brightness_rect: ColorRect = null

# Cache bus audio
var _bus_master: int = -1
var _bus_bgm: int = -1
var _bus_sfx: int = -1

# Preload Scene SettingsMenu untuk kemudahan pemanggilan modal dari mana saja
var settings_menu_scene: PackedScene = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_buses()
	_setup_brightness_overlay()
	load_settings()
	
	if ResourceLoader.exists("res://scenes/ui/SettingsMenu.tscn"):
		settings_menu_scene = load("res://scenes/ui/SettingsMenu.tscn")

func _setup_audio_buses() -> void:
	_bus_master = AudioServer.get_bus_index("Master")
	
	_bus_bgm = AudioServer.get_bus_index("Music")
	if _bus_bgm == -1:
		_bus_bgm = AudioServer.get_bus_index("BGM")
	
	_bus_sfx = AudioServer.get_bus_index("SFX")

func _setup_brightness_overlay() -> void:
	_brightness_layer = CanvasLayer.new()
	_brightness_layer.name = "GlobalBrightnessLayer"
	_brightness_layer.layer = 125 # Layer tinggi agar di atas UI gameplay
	add_child(_brightness_layer)
	
	_brightness_rect = ColorRect.new()
	_brightness_rect.name = "BrightnessOverlay"
	_brightness_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_brightness_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brightness_rect.color = Color(0, 0, 0, 0)
	_brightness_rect.visible = false
	_brightness_layer.add_child(_brightness_rect)

# ----------------------------------------------------
# Brightness Control
# ----------------------------------------------------
func set_brightness(val: float) -> void:
	brightness = clampf(val, 0.0, 1.0)
	_apply_brightness()

func _apply_brightness() -> void:
	if _brightness_rect == null:
		return

	# 1.0 = terang normal. Menurunkan nilai -> overlay hitam (menggelapkan), bukan memutihkan.
	var dim: float = clampf(1.0 - brightness, 0.0, 1.0)
	if dim > 0.0:
		_brightness_rect.color = Color(0.0, 0.0, 0.0, dim)
		_brightness_rect.visible = true
	else:
		_brightness_rect.color = Color(0.0, 0.0, 0.0, 0.0)
		_brightness_rect.visible = false

# ----------------------------------------------------
# Volume Controls
# ----------------------------------------------------
func set_volume_general(val: float) -> void:
	volume_general = clampf(val, 0.0, 1.0)
	_apply_bus_volume(_bus_master, volume_general)

func set_volume_bgm(val: float) -> void:
	volume_bgm = clampf(val, 0.0, 1.0)
	_apply_bus_volume(_bus_bgm, volume_bgm)

func set_volume_sfx(val: float) -> void:
	volume_sfx = clampf(val, 0.0, 1.0)
	_apply_bus_volume(_bus_sfx, volume_sfx)

func _apply_bus_volume(bus_idx: int, linear_val: float) -> void:
	if bus_idx < 0 or bus_idx >= AudioServer.bus_count:
		return
	
	if linear_val <= 0.001:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_val))

# ----------------------------------------------------
# Resolution & Window Mode Control
# ----------------------------------------------------
func set_resolution(index: int) -> void:
	if index < 0 or index >= RESOLUTIONS.size():
		return
	resolution_index = index
	
	_apply_resolution()
	resolution_changed.emit(resolution_index)

func set_window_mode(index: int) -> void:
	window_mode_index = clamp(index, 0, 2)
	_apply_window_mode()
	window_mode_changed.emit(window_mode_index)

func _apply_resolution() -> void:
	var res = RESOLUTIONS[resolution_index]
	var target_size = Vector2i(res["width"], res["height"])
	
	# 1. Terapkan Resolution Scaling
	var win = get_tree().root
	if win:
		win.content_scale_size = target_size
		# Di renderer GL Compatibility, mode VIEWPORT benar-benar merender 3D di resolusi lebih rendah (720p/540p), memangkas beban GPU 50-75%
		if resolution_index > 0:
			win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		else:
			win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS

		# Juga terapkan scaling_3d untuk backend Vulkan jika aktif
		win.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		match resolution_index:
			0: # Tinggi (1080p / 100%)
				win.scaling_3d_scale = 1.0
				RenderingServer.directional_shadow_atlas_set_size(2048, true)
			1: # Sedang (720p / ~67%)
				win.scaling_3d_scale = 0.67
				RenderingServer.directional_shadow_atlas_set_size(1024, true)
			2: # Rendah (540p / 50%)
				win.scaling_3d_scale = 0.50
				RenderingServer.directional_shadow_atlas_set_size(512, true)
	
	# 2. Sesuaikan ukuran jendela hanya jika dalam mode Jendela (Windowed) pada desktop
	if window_mode_index == 0 and not OS.has_feature("mobile") and not OS.has_feature("web"):
		if win:
			var current_size = DisplayServer.window_get_size()
			if current_size != target_size:
				win.size = target_size
				DisplayServer.window_set_size(target_size)
				_center_window(win, target_size)

func _apply_window_mode() -> void:
	if OS.has_feature("mobile") or OS.has_feature("web"):
		return
	
	var win = get_tree().root
	if win == null:
		return
	
	var current_mode = DisplayServer.window_get_mode()
	var res = RESOLUTIONS[resolution_index]
	var target_size = Vector2i(res["width"], res["height"])
	var current_size = DisplayServer.window_get_size()
	
	match window_mode_index:
		0: # Windowed
			if current_mode != DisplayServer.WINDOW_MODE_WINDOWED or current_size != target_size:
				win.mode = Window.MODE_WINDOWED
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				win.size = target_size
				DisplayServer.window_set_size(target_size)
				_center_window(win, target_size)
		1: # Fullscreen
			if current_mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
				win.mode = Window.MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2: # Maximized
			if current_mode != DisplayServer.WINDOW_MODE_MAXIMIZED:
				win.mode = Window.MODE_MAXIMIZED
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	
	# Pastikan render scale 3D tetap aktif saat window mode berubah
	_apply_resolution()

func _center_window(win: Window, target_size: Vector2i) -> void:
	var screen_id = win.current_screen
	var screen_size = DisplayServer.screen_get_size(screen_id)
	if screen_size.x > 0 and screen_size.y > 0:
		var new_pos = (screen_size - target_size) / 2
		new_pos.x = max(0, new_pos.x)
		new_pos.y = max(0, new_pos.y)
		win.position = new_pos
		DisplayServer.window_set_position(new_pos)

# ----------------------------------------------------
# Mobile Controls Mode
# ----------------------------------------------------
func set_mobile_controls_mode(mode: int) -> void:
	mobile_controls_mode = mode
	mobile_controls_toggled.emit(is_mobile_controls_active())

func is_mobile_controls_active() -> bool:
	match mobile_controls_mode:
		MobileControlsMode.ALWAYS_ON:
			return true
		MobileControlsMode.ALWAYS_OFF:
			return false
		_:
			return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()

# ----------------------------------------------------
# Persistence (user://settings.cfg)
# ----------------------------------------------------
func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("display", "brightness", brightness)
	config.set_value("display", "resolution_index", resolution_index)
	config.set_value("display", "window_mode_index", window_mode_index)
	config.set_value("audio", "volume_general", volume_general)
	config.set_value("audio", "volume_bgm", volume_bgm)
	config.set_value("audio", "volume_sfx", volume_sfx)
	config.set_value("controls", "mobile_controls_mode", mobile_controls_mode)
	
	var err = config.save(CONFIG_PATH)
	if err == OK:
		print("[SettingsManager] Pengaturan berhasil disimpan ke %s" % CONFIG_PATH)
		settings_saved.emit()
	else:
		push_warning("[SettingsManager] Gagal menyimpan pengaturan: %d" % err)

func load_settings(apply_display: bool = true) -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	
	if err == OK:
		brightness = clampf(config.get_value("display", "brightness", 1.0), 0.0, 1.0)
		resolution_index = config.get_value("display", "resolution_index", 0)
		window_mode_index = config.get_value("display", "window_mode_index", 0)
		volume_general = config.get_value("audio", "volume_general", 0.8)
		volume_bgm = config.get_value("audio", "volume_bgm", 0.8)
		volume_sfx = config.get_value("audio", "volume_sfx", 0.8)
		mobile_controls_mode = config.get_value("controls", "mobile_controls_mode", MobileControlsMode.AUTO)
	else:
		brightness = 1.0
		resolution_index = 0
		window_mode_index = 0
		volume_general = 0.8
		volume_bgm = 0.8
		volume_sfx = 0.8
		mobile_controls_mode = MobileControlsMode.AUTO
	
	_apply_brightness()
	_apply_bus_volume(_bus_master, volume_general)
	_apply_bus_volume(_bus_bgm, volume_bgm)
	_apply_bus_volume(_bus_sfx, volume_sfx)
	if apply_display:
		_apply_window_mode()
		_apply_resolution()
	mobile_controls_toggled.emit(is_mobile_controls_active())

func reset_to_defaults() -> void:
	brightness = 1.0
	resolution_index = 0
	window_mode_index = 0
	volume_general = 0.8
	volume_bgm = 0.8
	volume_sfx = 0.8
	mobile_controls_mode = MobileControlsMode.AUTO
	
	_apply_brightness()
	_apply_bus_volume(_bus_master, volume_general)
	_apply_bus_volume(_bus_bgm, volume_bgm)
	_apply_bus_volume(_bus_sfx, volume_sfx)
	_apply_window_mode()
	_apply_resolution()
	mobile_controls_toggled.emit(is_mobile_controls_active())
	save_settings()

# ----------------------------------------------------
# Helper untuk membuka UI Modal Settings dari mana saja
# ----------------------------------------------------
func open_settings_dialog(parent_node: Node = null) -> Control:
	if settings_menu_scene == null:
		if ResourceLoader.exists("res://scenes/ui/SettingsMenu.tscn"):
			settings_menu_scene = load("res://scenes/ui/SettingsMenu.tscn")
		else:
			push_warning("[SettingsManager] SettingsMenu.tscn belum tersedia!")
			return null
	
	var existing = get_tree().root.find_child("SettingsMenu", true, false)
	if existing != null:
		if existing.has_method("open"):
			existing.open()
		return existing
	
	var menu_inst = settings_menu_scene.instantiate()
	if parent_node != null:
		parent_node.add_child(menu_inst)
	else:
		get_tree().root.add_child(menu_inst)
	
	if menu_inst.has_method("open"):
		menu_inst.open()
	
	return menu_inst
