# scenes/ui/ReflectionDialog.gd
extends CanvasLayer

signal reflection_submitted(sentiment: String, user_text: String, ai_reply: String)
signal badge_closed

@onready var backdrop: ColorRect = $Backdrop
@onready var reflection_card: Control = $CardContainer/ReflectionCard
@onready var reflection_input: LineEdit = $CardContainer/ReflectionCard/Margin/VBox/InputContainer/ReflectionInput
@onready var hint_label: Label = $CardContainer/ReflectionCard/Margin/VBox/InputContainer/HintLabel
@onready var error_label: Label = $CardContainer/ReflectionCard/Margin/VBox/InputContainer/ErrorLabel
@onready var submit_btn: Button = $CardContainer/ReflectionCard/Margin/VBox/SubmitButton
@onready var badge_card: Control = $CardContainer/BadgeCard
@onready var badge_close_btn: Button = $CardContainer/BadgeCard/Margin/VBox/CloseButton
@onready var card_container: Control = $CardContainer

var is_waiting_input: bool = false
var is_waiting_badge: bool = false
var is_processing: bool = false

# Kata-kata kasar / toxic / hinaan yang dilarang
const PROFANITY_LIST: Array[String] = [
	"bego", "bodoh", "goblok", "tolol", "idiot", "dungu", "anjing", "anjir", "anying",
	"babi", "bangsat", "bajingan", "kontol", "memek", "pantek", "perek", "sialan",
	"tai", "taik", "asu", "kampret", "setan", "iblis", "mampus", "bacot", "bgst", "kntl",
	"jancuk", "jancok", "pantat", "titit", "itil", "pepek", "fuck", "shit", "bitch", "asshole"
]

# Kata-kata singkat / spam / non-refleksi
const NONSENSE_WORDS: Array[String] = [
	"gg", "wp", "ez", "lol", "wkwk", "wkwkwk", "haha", "hahaha", "hehe", "huhu",
	"ok", "oke", "test", "tes", "asdf", "qwerty", "hai", "halo", "yo", "skip", "next"
]

# Kata kunci sentimen bahasa Indonesia untuk offline fallback
const POSITIVE_KEYWORDS: Array[String] = [
	"bisa", "senang", "lega", "seru", "mudah", "gampang", "berhasil", "hebat",
	"percaya", "diri", "keren", "mantap", "semangat", "yakin", "tenang", "sabar",
	"asyik", "bangga", "siap", "sukses", "aman", "paham", "mengerti", "happy",
	"fokus", "puas", "bersyukur", "nikmat", "terbiasa", "terampil"
]

const NEGATIVE_KEYWORDS: Array[String] = [
	"susah", "sulit", "capek", "lelah", "kesal", "marah", "takut", "gagal",
	"bingung", "pusing", "berat", "panik", "cemas", "ribet", "jengkel",
	"putus asa", "kalah", "lemah", "ragu", "bosan", "repot", "tenggelam",
	"kecewa", "gemetar", "keringetan", "nangis"
]

func _ready() -> void:
	add_to_group("reflection_dialog")
	hide()
	reflection_card.hide()
	badge_card.hide()
	backdrop.modulate.a = 0.0
	if error_label:
		error_label.hide()

	reflection_input.text_submitted.connect(_on_input_submitted)
	submit_btn.pressed.connect(_on_submit_pressed)
	badge_close_btn.pressed.connect(_on_badge_close_pressed)

func show_reflection_prompt() -> void:
	show()
	badge_card.hide()
	reflection_card.show()
	reflection_input.text = ""
	reflection_input.editable = true
	submit_btn.disabled = false
	if error_label:
		error_label.hide()
	if hint_label:
		hint_label.text = "(Tekan Enter untuk melanjutkan)"
		hint_label.modulate = Color(1, 1, 1, 0.8)
	is_waiting_input = true
	is_processing = false

	# Fade in animasi
	var tween = create_tween().set_parallel(true)
	tween.tween_property(backdrop, "modulate:a", 1.0, 0.3)
	reflection_card.scale = Vector2(0.85, 0.85)
	reflection_card.modulate.a = 0.0
	tween.tween_property(reflection_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(reflection_card, "modulate:a", 1.0, 0.3)

	await tween.finished
	reflection_input.grab_focus()

func _on_submit_pressed() -> void:
	if not is_waiting_input or is_processing:
		return
	_validate_and_submit(reflection_input.text)

func _on_input_submitted(text: String) -> void:
	if not is_waiting_input or is_processing:
		return
	_validate_and_submit(text)

func _validate_and_submit(raw_text: String) -> void:
	var cleaned = raw_text.strip_edges()
	var lower = cleaned.to_lower()

	# 1. Cek jika kosong
	if cleaned.is_empty():
		_show_validation_error("Silakan ketik apa yang kamu rasakan ya...")
		return

	# 2. Cek kata kasar / profanity
	var words = lower.split(" ", false)
	for w in words:
		var clean_w = ""
		for char in w:
			if char.is_valid_identifier() or char in ["-", "_"]:
				clean_w += char
		if clean_w in PROFANITY_LIST or w in PROFANITY_LIST:
			_show_validation_error("Yuk gunakan kata-kata yang sopan dan ceritakan perasaanmu yang sebenarnya.")
			return

	for bad in PROFANITY_LIST:
		if bad in lower and (lower.begins_with(bad + " ") or lower.ends_with(" " + bad) or (" " + bad + " ") in lower or lower == bad):
			_show_validation_error("Yuk gunakan kata-kata yang sopan dan ceritakan perasaanmu yang sebenarnya.")
			return

	# 3. Cek kata nonsense / spam / terlalu singkat
	if words.size() == 1 and (words[0] in NONSENSE_WORDS or words[0].length() < 3):
		_show_validation_error("Ceritakan sedikit lebih banyak tentang perasaanmu melewati sungai tadi ya!")
		return

	# Cek jika hanya huruf acak berulang tanpa spasi (misal 'asdfghjk', 'aaaaaa')
	if words.size() == 1 and words[0].length() > 6:
		var vowels = 0
		for ch in words[0]:
			if ch in ["a", "i", "u", "e", "o"]:
				vowels += 1
		if vowels == 0:
			_show_validation_error("Tolong ceritakan dengan kalimat yang jelas ya, Rion.")
			return

	# Jika lolos validasi, proses refleksi (AI / Fallback)
	_process_reflection(cleaned)

func _show_validation_error(msg: String) -> void:
	if error_label:
		error_label.text = msg
		error_label.show()
	
	# Efek getar (shake) kartu input
	var original_pos = reflection_card.position
	var shake_tween = create_tween()
	for i in range(4):
		var offset_x = 10.0 if (i % 2 == 0) else -10.0
		shake_tween.tween_property(reflection_card, "position:x", original_pos.x + offset_x, 0.04)
	shake_tween.tween_property(reflection_card, "position:x", original_pos.x, 0.04)
	
	reflection_input.grab_focus()

func _process_reflection(user_text: String) -> void:
	is_processing = true
	reflection_input.editable = false
	submit_btn.disabled = true
	if error_label:
		error_label.hide()
	if hint_label:
		hint_label.text = "✦ Ona sedang menganalisis responmu... ✦"
		hint_label.modulate = Color(0.4, 0.9, 1.0, 1.0)

	var sentiment := "positif"
	var ai_reply := ""

	var ai_mgr = get_node_or_null("/root/AIManager") if is_inside_tree() else null
	if ai_mgr and ai_mgr.get("_api_key") != "" and ai_mgr.get("_api_key") != "ISI_API_KEY_KAMU_DISINI":
		var ai_res = await _request_ai_reflection(user_text, ai_mgr)
		if not ai_res.is_empty():
			sentiment = ai_res.get("sentiment", "positif")
			ai_reply = ai_res.get("reply", "")

	# Jika AI offline / gagal, gunakan respon fallback lokal yang cerdas
	if ai_reply.is_empty():
		sentiment = _local_keyword_sentiment(user_text)
		if sentiment == "positif":
			ai_reply = "Hebat sekali, Rion! Menjaga pikiran tetap tenang dan memperhatikan pola adalah kunci keberhasilanmu tadi."
		else:
			ai_reply = "Perasaan lelah atau tegang itu sangat wajar, Rion. Yang paling membanggakan adalah kamu tidak menyerah dan berhasil sampai di seberang."

	is_waiting_input = false
	is_processing = false

	# Sembunyikan dialog card
	if reflection_card:
		reflection_card.hide()
	if backdrop:
		backdrop.modulate.a = 0.0
	hide()

	# Emit hasil analisis lengkap: sentiment, teks asli pemain, dan balasan personal Ona
	reflection_submitted.emit(sentiment, user_text, ai_reply)

func _request_ai_reflection(text: String, ai_mgr: Node) -> Dictionary:
	var http_request := HTTPRequest.new()
	add_child(http_request)

	var request_headers = [
		"Authorization: Bearer " + str(ai_mgr.get("_api_key")),
		"Content-Type: application/json"
	]

	var system_prompt = """
Kamu adalah Ona, robot asisten AI yang bijak, hangat, ramah, dan empatik untuk anak-anak dalam game petualangan antariksa Memorion+.
Rion (temanmu) baru saja berhasil melompati rintangan sungai batu di planet asing setelah memperhatikan pola kedipan lampu batu.
Ona bertanya: "Bagaimana perasaanmu setelah berhasil melewati rintangan sungai tadi?"
Pemain (Rion) menjawab: "%s"

Tugasmu:
1. Tentukan sentimen emosinya ("positif" jika merasa senang/lega/bangga/percaya diri, atau "negatif" jika merasa lelah/kesal/pusing/sulit/takut).
2. Berikan 1 atau maksimal 2 kalimat balasan LANGSUNG dari Ona yang merespons secara spesifik apa yang dirasakan atau diceritakan Rion dengan penuh empati dan apresiasi.

Aturan Output:
WAJIB balas HANYA format JSON persis seperti ini:
{
	"sentiment": "positif" atau "negatif",
	"reply": "<balasan singkat dan hangat dari Ona>"
}
""" % text

	var payload = {
		"model": "openai/gpt-4o-mini",
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": text}
		],
		"temperature": 0.4,
		"response_format": { "type": "json_object" }
	}

	var err = http_request.request(
		str(ai_mgr.get("API_URL")),
		request_headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

	if err != OK:
		http_request.queue_free()
		return {}

	# Timeout 5 detik agar gameplay tidak macet jika jaringan lambat
	var timer = get_tree().create_timer(5.0)
	var completed = false
	var res_data: Array = []

	http_request.request_completed.connect(func(res, code, hdrs, bdy):
		res_data = [res, code, hdrs, bdy]
		completed = true
	)

	while not completed and timer.time_left > 0:
		await get_tree().process_frame

	if not completed:
		http_request.cancel_request()
		http_request.queue_free()
		print("[ReflectionDialog] AI Request timeout, menggunakan fallback lokal.")
		return {}

	http_request.queue_free()

	if res_data.size() >= 4 and res_data[1] == 200:
		var body: PackedByteArray = res_data[3]
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json.has("choices") and json["choices"].size() > 0:
			var content_str = json["choices"][0]["message"]["content"]
			var parsed = JSON.parse_string(content_str)
			if parsed and parsed.has("sentiment") and parsed.has("reply"):
				var sent = String(parsed["sentiment"]).to_lower().strip_edges()
				var s = "positif"
				if "negatif" in sent or "negative" in sent:
					s = "negatif"
				return {"sentiment": s, "reply": String(parsed["reply"]).strip_edges()}

	return {}

func _local_keyword_sentiment(text: String) -> String:
	var lower = text.to_lower()
	var words = lower.split(" ", false)

	var pos_score := 0
	var neg_score := 0
	var nlp_mgr = get_node_or_null("/root/NLPManager") if is_inside_tree() else null

	for w in words:
		for p in POSITIVE_KEYWORDS:
			if p == w or (nlp_mgr and nlp_mgr.has_method("levenshtein") and nlp_mgr.levenshtein(w, p) <= 1):
				pos_score += 1
				break
		for n in NEGATIVE_KEYWORDS:
			if n == w or (nlp_mgr and nlp_mgr.has_method("levenshtein") and nlp_mgr.levenshtein(w, n) <= 1):
				neg_score += 1
				break

	var is_overcoming = ("akhirnya bisa" in lower or "ternyata bisa" in lower or "tapi bisa" in lower or "bisa melewatinya" in lower)

	# Jika terdapat kata negasi seperti "tidak bisa", "kurang paham"
	if ("tidak bisa" in lower or "gak bisa" in lower or "ngga bisa" in lower or "nggak bisa" in lower
		or "capek" in lower or "lelah" in lower or "kesal" in lower
		or ("susah" in lower and not is_overcoming)):
		neg_score += 2

	if is_overcoming or "senang" in lower or "bangga" in lower or "bisa" in lower:
		pos_score += 3

	print("[ReflectionDialog] Local sentiment score: Pos=%d, Neg=%d for text: '%s'" % [pos_score, neg_score, text])

	# Default ke positif jika seri / optimis
	if neg_score > pos_score:
		return "negatif"
	return "positif"

func show_badge_popup() -> void:
	show()
	reflection_card.hide()
	badge_card.show()
	is_waiting_badge = true

	var tween = create_tween().set_parallel(true)
	tween.tween_property(backdrop, "modulate:a", 1.0, 0.3)
	badge_card.scale = Vector2(0.85, 0.85)
	badge_card.modulate.a = 0.0
	tween.tween_property(badge_card, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(badge_card, "modulate:a", 1.0, 0.35)

	await tween.finished
	badge_close_btn.grab_focus()

func _on_badge_close_pressed() -> void:
	if not is_waiting_badge:
		return
	is_waiting_badge = false

	var tween = create_tween().set_parallel(true)
	tween.tween_property(badge_card, "scale", Vector2(0.85, 0.85), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(badge_card, "modulate:a", 0.0, 0.2)
	tween.tween_property(backdrop, "modulate:a", 0.0, 0.25)
	await tween.finished
	badge_card.hide()
	hide()
	badge_closed.emit()
