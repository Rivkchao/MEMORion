# AIManager.gd
# Gateway AI ke backend Laravel (proxy). API key AI tidak pernah disimpan di game.
# Lokal: base_url http://memorion.auto  |  Produksi: ganti base_url di api_config.cfg.
extends Node

const CONFIG_PATH_RES: String = "res://api_config.cfg"
const AUTH_PATH_USER: String = "user://memorion_auth.cfg"
const ENC_PASS: String = "memorion-local-obfuscation"
const API_PREFIX: String = "/api/v1"
const DEFAULT_BASE_URL: String = "http://memorion.auto"

# Signal untuk mengirim hasil (Emosi & Balasan NPC) ke UI/Game
signal emotion_analyzed(detected_emotion: String, npc_reply: String)
signal answer_checked(npc_reply: String, emotion: String)
signal auth_changed(logged_in: bool, message: String)
signal auth_required(message: String)

# Kompatibilitas scene lama yang masih mengecek _api_key / API_URL
var _api_key: String = ""   # berisi token sesi (Bearer)
var API_URL: String = ""    # base_url + /api/v1/ai/chat

var _base_url: String = DEFAULT_BASE_URL
var _token: String = ""
var _expires_at: int = 0
var _username: String = ""
var _auto_register: bool = true
var is_logging_in: bool = false

func _ready() -> void:
	_base_url = _resolve_base_url()
	API_URL = _base_url + API_PREFIX + "/ai/chat"
	_load_auth()
	print("[AIManager] base_url=%s ai_available=%s" % [_base_url, is_ai_available()])
	if not is_ai_available():
		await _try_dev_autologin()

# ---------------------------------------------------------------
# Konfigurasi (res:// hanya berisi hal non-rahasia)
# ---------------------------------------------------------------
func _resolve_base_url() -> String:
	var override := OS.get_environment("MEMORION_API_URL")
	if not override.is_empty():
		return override.rstrip("/")

	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH_RES) == OK:
		return str(cfg.get_value("api", "base_url", DEFAULT_BASE_URL)).rstrip("/")

	return DEFAULT_BASE_URL

func _try_dev_autologin() -> void:
	if not OS.has_feature("editor"):
		return

	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH_RES) != OK:
		return

	var user := str(cfg.get_value("dev", "username", ""))
	var passwd := str(cfg.get_value("dev", "password", ""))
	if user.is_empty() or passwd.is_empty():
		return

	var ok := await login(user, passwd)
	if not ok and _auto_register:
		await register(user, passwd)

func _relogin() -> bool:
	if OS.has_feature("editor"):
		await _try_dev_autologin()
	return is_ai_available()

# ---------------------------------------------------------------
# Auth tersimpan di user:// (terenkripsi)
# ---------------------------------------------------------------
func _load_auth() -> void:
	if not FileAccess.file_exists(AUTH_PATH_USER):
		return

	var f := FileAccess.open_encrypted_with_pass(AUTH_PATH_USER, FileAccess.READ, ENC_PASS)
	if f == null:
		return

	var cfg := ConfigFile.new()
	if cfg.parse(f.get_as_text()) != OK:
		return

	_username = str(cfg.get_value("api", "username", ""))
	_token = str(cfg.get_value("api", "token", ""))
	_expires_at = int(cfg.get_value("api", "expires_at", 0))
	_api_key = _token

func _save_auth() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("api", "username", _username)
	cfg.set_value("api", "token", _token)
	cfg.set_value("api", "expires_at", _expires_at)

	var f := FileAccess.open_encrypted_with_pass(AUTH_PATH_USER, FileAccess.WRITE, ENC_PASS)
	if f == null:
		push_warning("[AIManager] Gagal menulis auth ke %s" % AUTH_PATH_USER)
		return
	f.store_string(cfg.encode_to_text())
	f.close()

func _clear_auth() -> void:
	_token = ""
	_expires_at = 0
	_api_key = ""
	_save_auth()

func is_ai_available() -> bool:
	if _token.is_empty():
		return false
	if _expires_at > 0 and Time.get_unix_time_from_system() >= float(_expires_at):
		_clear_auth()
		return false
	return true

func get_username() -> String:
	return _username

# ---------------------------------------------------------------
# Login / register / logout
# ---------------------------------------------------------------
func login(username: String, password: String) -> bool:
	var res := await _http_json(API_PREFIX + "/player/login", HTTPClient.METHOD_POST,
		{"username": username, "password": password}, false)

	if int(res.get("code", 0)) != 200:
		push_warning("[AIManager] Login gagal (HTTP %s)" % res.get("code", -1))
		return false

	_apply_session(username, res.get("data", {}))
	auth_changed.emit(true, "Login berhasil")
	print("[AIManager] Login berhasil sebagai %s" % username)
	return true

func register(username: String, password: String) -> bool:
	var res := await _http_json(API_PREFIX + "/player/register", HTTPClient.METHOD_POST,
		{"username": username, "password": password}, false)

	if int(res.get("code", 0)) != 201:
		push_warning("[AIManager] Register gagal (HTTP %s)" % res.get("code", -1))
		return false

	_apply_session(username, res.get("data", {}))
	auth_changed.emit(true, "Registrasi berhasil")
	return true

func _apply_session(username: String, data: Dictionary) -> void:
	_username = username
	_token = str(data.get("token", ""))
	_expires_at = _parse_expiry(str(data.get("expires_at", "")))
	_api_key = _token
	_save_auth()

func logout() -> void:
	if is_ai_available():
		await _http_json(API_PREFIX + "/player/logout", HTTPClient.METHOD_POST, {})
	_clear_auth()
	auth_changed.emit(false, "Logout")

func _parse_expiry(iso: String) -> int:
	if iso.length() < 19:
		return 0
	var ts := Time.get_unix_time_from_datetime_string(iso.substr(0, 19))
	return int(ts) if ts > 0.0 else 0

# ---------------------------------------------------------------
# HTTP inti
# ---------------------------------------------------------------
func _http_json(path: String, method: int, body: Dictionary, with_auth: bool = true) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 45.0
	add_child(http)

	var env_url := OS.get_environment("MEMORION_API_URL")
	if not env_url.is_empty():
		_base_url = env_url.rstrip("/")

	var headers := PackedStringArray(["Content-Type: application/json"])
	if with_auth and not _token.is_empty():
		headers.append("Authorization: Bearer " + _token)

	var payload := "" if body.is_empty() else JSON.stringify(body)
	var err := http.request(_base_url + path, headers, method, payload)
	if err != OK:
		http.queue_free()
		return {"code": -1, "data": {}}

	var res: Array = await http.request_completed
	http.queue_free()

	var code := int(res[1])
	var parsed = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		parsed = {}

	return {"code": code, "data": parsed}

## Kirim chat ke Laravel. Mengembalikan {ok, code, content, model}.
func chat(messages: Array, model: String = "", temperature: float = 0.4,
		max_tokens: int = 0, want_json: bool = false, _retry: bool = true) -> Dictionary:
	if not is_ai_available():
		if not await _relogin():
			auth_required.emit("Silakan login untuk memakai fitur AI.")
			return {"ok": false, "code": 401, "content": "", "model": ""}

	var body := {"messages": messages, "temperature": temperature}
	if not model.is_empty():
		body["model"] = model
	if max_tokens > 0:
		body["max_tokens"] = max_tokens
	if want_json:
		body["response_format"] = {"type": "json_object"}

	var res := await _http_json(API_PREFIX + "/ai/chat", HTTPClient.METHOD_POST, body)

	# Token kedaluwarsa / dicabut -> coba login ulang sekali
	if int(res.get("code", 0)) == 401 and _retry:
		if await _relogin():
			return await chat(messages, model, temperature, max_tokens, want_json, false)
		auth_required.emit("Sesi berakhir. Silakan login ulang.")

	var root: Dictionary = res.get("data", {})
	var payload: Dictionary = root.get("data", {})

	return {
		"ok": int(res.get("code", 0)) == 200,
		"code": int(res.get("code", 0)),
		"content": str(payload.get("content", "")),
		"model": str(payload.get("model", "")),
	}

## Kirim chat dan langsung kembalikan Dictionary hasil parse JSON.
func request_json(messages: Array, model: String = "", temperature: float = 0.3) -> Dictionary:
	var res := await chat(messages, model, temperature, 0, true)
	if not res.get("ok", false):
		return {}
	return _extract_json(str(res.get("content", "")))

func _extract_json(text: String) -> Dictionary:
	var clean := text.strip_edges()
	if clean.begins_with("```"):
		clean = clean.trim_prefix("```json").trim_prefix("```").strip_edges()
		clean = clean.trim_suffix("```").strip_edges()

	var start := clean.find("{")
	var end := clean.rfind("}")
	if start == -1 or end == -1 or end <= start:
		return {}

	var parsed = JSON.parse_string(clean.substr(start, end - start + 1))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

# ---------------------------------------------------------------
# API publik lama (konsumen tidak perlu diubah)
# ---------------------------------------------------------------
func analyze_player_emotion(user_input: String, npc_role: String = "Teman yang suportif") -> void:
	var system_prompt = """
	Kamu adalah AI NLP Expert yang bertugas menganalisis suasana hati (mood/emosi) dari kalimat yang diketik oleh pengguna.

	Tugas Utama:
	1. Analisis teks pengguna dan tentukan emosi utamanya. Kategori emosi yang valid: ["Cemas", "Takut", "Overthinking", "Sedih", "Marah", "Senang", "Netral"].
	2. Berikan respon balik dari sudut pandang peran berikut: %s.

	Aturan Output:
	Kamu WAJIB merespon HANYA dalam format JSON dengan struktur persis seperti ini:
	{
		"emotion": "<nama_emosi>",
		"reply": "<kalimat_balasan_npc>"
	}
	""" % npc_role

	var parsed := await request_json([
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": user_input},
	], "", 0.3)

	if parsed.is_empty():
		emotion_analyzed.emit("Unknown", "Maaf, terjadi kesalahan koneksi.")
		return

	emotion_analyzed.emit(
		str(parsed.get("emotion", "Netral")),
		str(parsed.get("reply", "Aku mendengarkanmu."))
	)

func check_answer(question: String, player_answer: String, is_correct: bool,
		npc_role: String = "Rion, teman alien yang suportif dan lucu") -> void:
	var status_text := "BENAR" if is_correct else "SALAH"

	var system_prompt = """
Kamu adalah %s dalam game edukasi Memorion+.
Seorang pemain baru saja menjawab pertanyaan di dalam game.

Konteks:
- Pertanyaan: "%s"
- Jawaban pemain: "%s"
- Status: %s

Tugasmu:
1. Jika BENAR: Berikan pujian hangat/antusias (1-2 kalimat).
2. Jika SALAH: Berikan dorongan dan petunjuk halus tanpa membocorkan jawaban (1-2 kalimat).
3. Tentukan mood ekspresi avatar:
   - Pilih "kagum" jika jawaban luar biasa, unik, benar sempurna, atau sangat mengejutkan.
   - Pilih "happy" untuk situasi senang, ramah, atau menyemangati secara umum.

Aturan Output:
Balas HANYA format JSON valid:
{
	"reply": "<kalimat percakapan>",
	"emotion": "happy" atau "kagum"
}
""" % [npc_role, question, player_answer, status_text]

	var parsed := await request_json([
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": player_answer},
	], "", 0.5)

	if parsed.is_empty():
		answer_checked.emit("Maaf, koneksi bermasalah. Tapi kamu sudah berusaha!", "happy")
		return

	answer_checked.emit(
		str(parsed.get("reply", "Kerja bagus!")),
		str(parsed.get("emotion", "happy")).to_lower()
	)
