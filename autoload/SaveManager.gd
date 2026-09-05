extends Node

const SAVE_DIR = "user://saves/"
const MAX_SLOTS = 3

var current_uid: String = ""
var current_username: String = ""

signal login_success
signal login_failed(reason: String)
signal register_success
signal register_failed(reason: String)
signal save_success
signal load_success(data: Dictionary)

func _ready() -> void:
	DirAccess.make_dir_absolute(SAVE_DIR)
	print(OS.get_user_data_dir())

# ─── REGISTER (bikin akun baru, simpan lokal) ─────────
func register(username: String, password: String) -> void:
	# Cek username sudah ada
	var path = SAVE_DIR + username + ".json"
	if FileAccess.file_exists(path):
		register_failed.emit("Username sudah dipakai, coba yang lain!")
		return
	
	# Generate UID
	var uid = _generate_uid()
	
	# Buat file akun
	var account = {
		"uid": uid,
		"username": username,
		"password": password,
		"created_at": Time.get_datetime_string_from_system(),
		"save_data": {}
	}
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		register_failed.emit("Gagal membuat akun!")
		return
	
	file.store_string(JSON.stringify(account))
	file.close()
	
	current_uid = uid
	current_username = username
	register_success.emit()

# ─── LOGIN ────────────────────────────────────────────
func login(username: String, password: String) -> void:
	var path = SAVE_DIR + username + ".json"
	
	if not FileAccess.file_exists(path):
		login_failed.emit("Username tidak ditemukan!")
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		login_failed.emit("Gagal membaca data!")
		return
	
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if data == null:
		login_failed.emit("Data rusak!")
		return
	
	if data["password"] != password:
		login_failed.emit("Password salah!")
		return
	
	current_uid = data["uid"]
	current_username = data["username"]
	login_success.emit()
	load_success.emit(data.get("save_data", {}))

# ─── SAVE ─────────────────────────────────────────────
func save() -> void:
	if current_username == "":
		return
	
	var path = SAVE_DIR + current_username + ".json"
	
	if not FileAccess.file_exists(path):
		return
	
	# Baca data lama dulu
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if data == null:
		return
	
	# Update save_data
	data["save_data"] = {
		"player_position": {
			"x": GameManager.spawn_point_override.x,
			"y": GameManager.spawn_point_override.y,
			"z": GameManager.spawn_point_override.z
		},
		"scene": get_tree().current_scene.scene_file_path,
		"objective": {
			"text": GameManager.objective_text,
			"current": GameManager.objective_current,
			"total": GameManager.objective_total,
			"item_name": GameManager.objective_item
		},
		"completed_puzzles": GameManager.completed_puzzles,
		"inventory": GameManager.inventory,
		"dialogue_history": GameManager.dialogue_history,
		"last_saved": Time.get_datetime_string_from_system()
	}
	
	# Tulis ulang
	var write_file = FileAccess.open(path, FileAccess.WRITE)
	if write_file == null:
		return
	write_file.store_string(JSON.stringify(data))
	write_file.close()
	
	save_success.emit()
	print("Save berhasil!")

# ─── RESTORE ──────────────────────────────────────────
func restore(save_data: Dictionary) -> void:
	if save_data.is_empty():
		return
	
	var pos = save_data.get("player_position", {})
	if not pos.is_empty():
		GameManager.set_spawn_override(Vector3(pos["x"], pos["y"], pos["z"]))
	
	var obj = save_data.get("objective", {})
	if not obj.is_empty():
		GameManager.objective_text = obj.get("text", "")
		GameManager.objective_current = obj.get("current", 0)
		GameManager.objective_total = obj.get("total", 0)
		GameManager.objective_item = obj.get("item_name", "bintang")
	
	GameManager.completed_puzzles = save_data.get("completed_puzzles", [])
	GameManager.inventory = save_data.get("inventory", [])
	GameManager.dialogue_history = save_data.get("dialogue_history", [])
	
	var scene = save_data.get("scene", "res://scenes/main/Main.tscn")
	LoadingScreen.load_scene(scene)

func has_any_save() -> bool:
	var dir = DirAccess.open(SAVE_DIR)
	if dir == null:
		return false
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file.ends_with(".json"):
			return true
		file = dir.get_next()
	return false

# ─── UTILITY ──────────────────────────────────────────
func _generate_uid() -> String:
	var time = Time.get_ticks_msec()
	var random = randi()
	return "%x-%x" % [time, random]
