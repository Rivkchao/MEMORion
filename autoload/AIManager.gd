# AIManager.gd
extends Node

const API_URL: String = "https://openrouter.ai/api/v1/chat/completions"
const CONFIG_PATH: String = "res://api_config.cfg"

# Dimuat dari api_config.cfg saat _ready() — JANGAN hardcode di sini!
var _api_key: String = ""

# Signal untuk mengirim hasil (Emosi & Balasan NPC) ke UI/Game
signal emotion_analyzed(detected_emotion: String, npc_reply: String)

# Signal untuk hasil pengecekan jawaban puzzle
signal answer_checked(npc_reply: String)

func _ready() -> void:
	_load_api_key()

func _load_api_key() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err == OK:
		_api_key = config.get_value("api", "openrouter_key", "")
		if _api_key.is_empty():
			push_error("[AIManager] api_config.cfg ditemukan tapi 'openrouter_key' kosong!")
	else:
		push_error("[AIManager] File api_config.cfg tidak ditemukan! Salin api_config.cfg.example dan isi key-nya.")

func analyze_player_emotion(user_input: String, npc_role: String = "Teman yang suportif") -> void:
	var http_request := HTTPRequest.new()
	add_child(http_request)
	
	http_request.request_completed.connect(
		func(result, response_code, headers, body):
			_on_request_completed(result, response_code, headers, body, http_request)
	)

	var request_headers = [
		"Authorization: Bearer " + _api_key,
		"Content-Type: application/json"
	]

	# --- SYSTEM PROMPT UNTUK NLP EMOTION DETECTION ---
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

	var payload = {
		"model": "openai/gpt-4o-mini",
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": user_input}
		],
		"temperature": 0.3, # Temperature rendah agar analisis konsisten
		"response_format": { "type": "json_object" } # Memaksa output JSON
	}

	http_request.request(
	API_URL,
	request_headers,
	HTTPClient.METHOD_POST,
	JSON.stringify(payload)
)

func _on_request_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	http_node: HTTPRequest
) -> void:
	http_node.queue_free()
	
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		var content_str = json["choices"][0]["message"]["content"]
		var parsed_response = JSON.parse_string(content_str)
		
		var emotion = parsed_response.get("emotion", "Netral")
		var reply = parsed_response.get("reply", "Aku mendengarkanmu.")
		
		# Pancarkan signal hasil analisis
		emotion_analyzed.emit(emotion, reply)
	else:
		emotion_analyzed.emit("Unknown", "Maaf, terjadi kesalahan koneksi.")

# -------------------------------------------------------
# Fungsi khusus puzzle: AI merespons dengan konteks soal
# -------------------------------------------------------
func check_answer(question: String, player_answer: String, is_correct: bool, npc_role: String = "Rion, teman alien yang suportif dan lucu") -> void:
	var http_request := HTTPRequest.new()
	add_child(http_request)

	http_request.request_completed.connect(
		func(result, response_code, headers, body):
			_on_check_answer_completed(result, response_code, headers, body, http_request)
	)

	var request_headers = [
		"Authorization: Bearer " + _api_key,
		"Content-Type: application/json"
	]

	var status_text = "BENAR" if is_correct else "SALAH"

	var system_prompt = """
Kamu adalah %s dalam game edukasi Memorion+.
Seorang pemain baru saja menjawab pertanyaan di dalam game.

Konteks:
- Pertanyaan yang diajukan: "%s"
- Jawaban pemain: "%s"
- Status jawaban (dari sistem): %s

Tugasmu:
- Jika jawaban BENAR: Berikan pujian singkat yang antusias dan menyemangati (1-2 kalimat).
- Jika jawaban SALAH: Berikan dorongan positif dan petunjuk halus mengenai jawaban yang benar, tanpa langsung menyebutkan jawabannya (1-2 kalimat).

Gunakan bahasa Indonesia yang santai dan ramah. Jangan sebut kata 'BENAR' atau 'SALAH' secara eksplisit.
Balas HANYA dengan kalimat percakapan Rion saja, tanpa format JSON, tanpa label apapun.
""" % [npc_role, question, player_answer, status_text]

	var payload = {
		"model": "openai/gpt-4o-mini",
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": player_answer}
		],
		"temperature": 0.7,
		"max_tokens": 100
	}

	http_request.request(
		API_URL,
		request_headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

func _on_check_answer_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	http_node: HTTPRequest
) -> void:
	http_node.queue_free()

	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		var reply = json["choices"][0]["message"]["content"].strip_edges()
		answer_checked.emit(reply)
	else:
		answer_checked.emit("Maaf, koneksi bermasalah. Tapi kamu sudah berusaha!")
