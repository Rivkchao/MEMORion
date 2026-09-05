extends CanvasLayer

@onready var tab_container: TabContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer
@onready var loading_indicator: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LoadingIndicator

# Login nodes
@onready var login_username: LineEdit = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/LoginTab/UsernameField
@onready var login_password: LineEdit = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/LoginTab/PasswordField
@onready var login_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/LoginTab/LoginBtn
@onready var login_feedback: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/LoginTab/FeedbackLabel

# Register nodes
@onready var reg_username: LineEdit = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/RegisterTab/UsernameField
@onready var reg_password: LineEdit = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/RegisterTab/PasswordField
@onready var reg_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/RegisterTab/RegisterBtn
@onready var reg_feedback: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer/RegisterTab/FeedbackLabel

func _ready() -> void:
	# Setup field
	login_password.secret = true
	reg_password.secret = true
	
	login_feedback.text = ""
	reg_feedback.text = ""
	loading_indicator.hide()
	
	# Placeholder text
	login_username.placeholder_text = "Nama panggilanmu..."
	login_password.placeholder_text = "Password..."
	reg_username.placeholder_text = "Pilih nama unikmu..."
	reg_password.placeholder_text = "Buat password..."
	
	# Connect tombol
	login_btn.pressed.connect(_on_login)
	reg_btn.pressed.connect(_on_register)
	
	# Connect SaveManager signals
	SaveManager.login_success.connect(_on_login_success)
	SaveManager.login_failed.connect(_on_login_failed)
	SaveManager.register_success.connect(_on_register_success)
	SaveManager.register_failed.connect(_on_register_failed)
	SaveManager.load_success.connect(_on_load_success)
	
	# Animasi fade in di CenterContainer
	$CenterContainer.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property($CenterContainer, "modulate:a", 1.0, 0.8)

func _on_login() -> void:
	var username = login_username.text.strip_edges()
	var password = login_password.text.strip_edges()
	
	if username.is_empty() or password.is_empty():
		login_feedback.text = "Username dan password tidak boleh kosong!"
		login_feedback.modulate = Color.RED
		return
	
	_set_loading(true)
	SaveManager.login(username, password)

func _on_register() -> void:
	var username = reg_username.text.strip_edges()
	var password = reg_password.text.strip_edges()
	
	if username.is_empty() or password.is_empty():
		reg_feedback.text = "Username dan password tidak boleh kosong!"
		reg_feedback.modulate = Color.RED
		return
	
	if username.length() < 3:
		reg_feedback.text = "Username minimal 3 karakter!"
		reg_feedback.modulate = Color.RED
		return
	
	if password.length() < 6:
		reg_feedback.text = "Password minimal 6 karakter!"
		reg_feedback.modulate = Color.RED
		return
	
	_set_loading(true)
	SaveManager.register(username, password)

func _on_login_success() -> void:
	_set_loading(false)
	login_feedback.text = "Berhasil masuk! Memuat data..."
	login_feedback.modulate = Color.GREEN

func _on_login_failed(reason: String) -> void:
	_set_loading(false)
	login_feedback.text = reason
	login_feedback.modulate = Color.RED

func _on_register_success() -> void:
	_set_loading(false)
	reg_feedback.text = "Akun berhasil dibuat! Selamat datang!"
	reg_feedback.modulate = Color.GREEN
	# Langsung masuk game
	await get_tree().create_timer(1.0).timeout
	LoadingScreen.load_scene("res://scenes/main/Main.tscn")

func _on_register_failed(reason: String) -> void:
	_set_loading(false)
	reg_feedback.text = reason
	reg_feedback.modulate = Color.RED

func _on_load_success(save_data: Dictionary) -> void:
	SaveManager.restore(save_data)

func _set_loading(is_loading: bool) -> void:
	login_btn.disabled = is_loading
	reg_btn.disabled = is_loading
	if is_loading:
		loading_indicator.text = "Menghubungkan ke server..."
		loading_indicator.show()
	else:
		loading_indicator.hide()
