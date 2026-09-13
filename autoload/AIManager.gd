# AIManager.gd
# Terhubung langsung ke OpenRouter API dengan kredensial hardcode.
extends Node

# Signal ke UI / Scene Game
signal emotion_analyzed(detected_emotion: String, npc_reply: String)
signal answer_checked(npc_reply: String, emotion: String)

# Kredensial Hardcode
const API_URL: String = "https://openrouter.ai/api/v1/chat/completions"
const API_KEY: String = "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"
const DEFAULT_MODEL: String = "openai/gpt-4o-mini"

# Variabel kompatibilitas scene lama
var _api_key: String = API_KEY

func _ready() -> void:
	print("[AIManager] Siap. Endpoint: %s | Model: %s" % [API_URL, DEFAULT_MODEL])

func is_ai_available() -> bool:
	return not API_KEY.strip_edges().is_empty()

# ---------------------------------------------------------------
# Core HTTP Request
# ---------------------------------------------------------------
func chat(messages: Array, model: String = "", temperature: float = 0.4,
		max_tokens: int = 0, want_json: bool = false) -> Dictionary:
	if not is_ai_available():
		push_error("[AIManager] API Key belum disetel!")
		return {"ok": false, "code": 401, "content": "", "model": ""}

	var http := HTTPRequest.new()
	http.timeout = 45.0
	add_child(http)

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + API_KEY,
		"HTTP-Referer: https://memorion.game",
		"X-Title: Memorion+"
	])

	var selected_model := model if not model.is_empty() else DEFAULT_MODEL
	var body: Dictionary = {
		"model": selected_model,
		"messages": messages,
		"temperature": temperature
	}

	if max_tokens > 0:
		body["max_tokens"] = max_tokens
	if want_json:
		body["response_format"] = {"type": "json_object"}

	var payload := JSON.stringify(body)
	var err := http.request(API_URL, headers, HTTPClient.METHOD_POST, payload)
	if err != OK:
		http.queue_free()
		return {"ok": false, "code": -1, "content": "", "model": selected_model}

	var res: Array = await http.request_completed
	http.queue_free()

	var status_code := int(res[1])
	var raw_str := (res[3] as PackedByteArray).get_string_from_utf8()
	var parsed = JSON.parse_string(raw_str)

	if status_code != 200 or typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[AIManager] Request gagal (%d): %s" % [status_code, raw_str])
		return {"ok": false, "code": status_code, "content": "", "model": selected_model}

	var choices: Array = parsed.get("choices", [])
	var content_text := ""
	if not choices.is_empty():
		var message_node: Dictionary = choices[0].get("message", {})
		content_text = str(message_node.get("content", ""))

	return {
		"ok": true,
		"code": status_code,
		"content": content_text,
		"model": str(parsed.get("model", selected_model))
	}

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
# Fitur Game
# ---------------------------------------------------------------
func analyze_player_emotion(user_input: String, npc_role: String = "Teman yang suportif") -> void:
	var system_prompt := """
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
		{"role": "user", "content": user_input}
	], "", 0.3)

	if parsed.is_empty():
		emotion_analyzed.emit("Unknown", "Maaf, terjadi kendala saat memproses respons.")
		return

	emotion_analyzed.emit(
		str(parsed.get("emotion", "Netral")),
		str(parsed.get("reply", "Aku mendengarkanmu."))
	)

func check_answer(question: String, player_answer: String, is_correct: bool,
		npc_role: String = "Rion, teman alien yang suportif dan lucu") -> void:
	var status_text := "BENAR" if is_correct else "SALAH"

	var system_prompt := """
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
		{"role": "user", "content": player_answer}
	], "", 0.5)

	if parsed.is_empty():
		answer_checked.emit("Maaf, koneksi bermasalah. Tapi kamu sudah berusaha!", "happy")
		return

	answer_checked.emit(
		str(parsed.get("reply", "Kerja bagus!")),
		str(parsed.get("emotion", "happy")).to_lower()
	)
