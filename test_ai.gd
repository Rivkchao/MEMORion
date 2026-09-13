# test_ai.gd
# Tes koneksi AIManager -> Laravel -> Sumopod, tanpa harus main game.
# Jalankan dari terminal:
#   godot --headless --path "<folder project ini>" --script res://test_ai.gd
extends SceneTree

const CONFIG_PATH := "res://api_config.cfg"
const TEST_MESSAGE := "Aku senang bisa melewati sungai batu tadi"

func _init() -> void:
	var ai = load("res://autoload/AIManager.gd").new()
	ai.name = "AIManager"
	root.add_child(ai)
	await process_frame

	var user := "demoplayer"
	var passwd := "password"
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		user = str(cfg.get_value("dev", "username", user))
		passwd = str(cfg.get_value("dev", "password", passwd))

	print("[TEST] base_url=", ai._base_url)

	var ok: bool = await ai.login(user, passwd)
	print("[TEST] login=", ok, " ai_available=", ai.is_ai_available())

	var models: Dictionary = await ai._http_json("/api/v1/ai/models", HTTPClient.METHOD_GET, {})
	print("[TEST] GET /ai/models -> code=", models.get("code"), " body=", models.get("data"))

	if ai.is_ai_available():
		var parsed: Dictionary = await ai.request_json([
			{"role": "system", "content": "Kamu NLP. Balas HANYA JSON: {\"emotion\":\"<emosi>\",\"reply\":\"<balasan>\"}"},
			{"role": "user", "content": TEST_MESSAGE},
		], "", 0.3)
		print("[TEST] parsed=", parsed)

	var logout_ok := ai.is_ai_available()
	if logout_ok:
		await ai.logout()
	print("[TEST] selesai")

	quit()
