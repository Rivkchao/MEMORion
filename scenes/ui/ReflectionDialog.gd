# scenes/ui/ReflectionDialog.gd
extends CanvasLayer

signal reflection_submitted(sentiment: String, user_text: String, ai_reply: String)
signal anger_reflection_submitted(user_text: String, ai_reply: String)
signal count_evaluation_submitted(user_text: String, is_exact: bool, comment: String, counted_number: int)
signal color_evaluation_submitted(user_text: String, is_correct: bool)
signal badge_closed

@onready var backdrop: ColorRect = $Backdrop
@onready var reflection_card: Control = $CardContainer/ReflectionCard
@onready var header_label: Label = $CardContainer/ReflectionCard/Margin/VBox/HeaderLabel
@onready var question_label: Label = $CardContainer/ReflectionCard/Margin/VBox/QuestionLabel
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
var current_dialog_mode: String = "general_reflection"

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

# Kata kunci relevansi: jawaban harus berhubungan dengan pertanyaan Ona
const RELEVANT_GENERAL: Array[String] = [
	"senang", "lega", "takut", "susah", "sulit", "capek", "lelah", "bangga", "tegang",
	"panik", "cemas", "berhasil", "bisa", "gagal", "mudah", "gampang", "seru", "jengkel",
	"kesal", "marah", "sedih", "tenang", "debar", "grogi", "gugup", "nyaman", "aman",
	"kaget", "keringat", "napas", "nafas", "biasa", "santai", "deg", "rasa",
	"sungai", "air", "batu", "lampu", "kedip", "pola", "lompat", "melompat", "nyebrang",
	"menyeberang", "seberang", "rintangan", "planet", "hutan", "jalan", "perasaan"
]

const RELEVANT_ANGER: Array[String] = [
	"marah", "kesal", "jengkel", "emosi", "geram", "benci", "dongkol", "kecewa",
	"frustasi", "frustrasi", "dendam", "tersinggung", "dihina", "diejek", "direndahkan",
	"dihargai", "dikhianati", "dibohongi", "diprovokasi", "diganggu", "dilanggar",
	"orang", "seseorang", "teman", "keluarga", "ketika", "saat", "kalau", "jika",
	"bila", "karena", "gara", "perilaku", "sikap", "ucapan", "kata"
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
	current_dialog_mode = "general_reflection"
	if header_label:
		header_label.text = "✦ REFLEKSI DIRI BERSAMA ONA ✦"
	if question_label:
		question_label.text = "Bagaimana perasaanmu setelah berhasil melewati rintangan sungai tadi?"
	if reflection_input:
		reflection_input.placeholder_text = "Ketik apa yang sedang kamu rasakan di sini..."
	_open_prompt_card()

## Kotak Refleksi Kemarahan di Kebun Bunga (Scene 5)
func show_anger_reflection_prompt() -> void:
	current_dialog_mode = "anger_reflection"
	if header_label:
		header_label.text = "✦ KOTAK INPUT REFLEKSI DIRI ✦"
	if question_label:
		question_label.text = "Menurutmu, hal apa yang biasanya membuat seseorang merasa marah?"
	if reflection_input:
		reflection_input.placeholder_text = "Ceritakan hal apa yang biasanya membuat marah..."
	_open_prompt_card()

## Evaluasi Memori Jumlah Bunga yang Dipetik (Scene 5)
func show_count_evaluation_prompt() -> void:
	current_dialog_mode = "flower_count"
	if header_label:
		header_label.text = "✦ EVALUASI JUMLAH BUNGA ✦"
	if question_label:
		question_label.text = "Berapa banyak bunga yang telah kamu kumpulkan di kebun tadi?"
	if reflection_input:
		reflection_input.placeholder_text = "Ketik angka atau sebutan jumlahnya (misal: 3 / tiga)..."
	_open_prompt_card()

## Evaluasi Memori Warna Bunga (Scene 5)
func show_color_evaluation_prompt() -> void:
	current_dialog_mode = "flower_color"
	if header_label:
		header_label.text = "✦ EVALUASI WARNA BUNGA ✦"
	if question_label:
		question_label.text = "Bunga-bunga yang kamu kumpulkan tadi warnanya apa saja?"
	if reflection_input:
		reflection_input.placeholder_text = "Ketik warna bunga yang kamu ingat..."
	_open_prompt_card()

func _open_prompt_card() -> void:
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

func _has_relevant_keyword(lower: String, words: PackedStringArray, keys: Array[String]) -> bool:
	var nlp_mgr = get_node_or_null("/root/NLPManager") if is_inside_tree() else null
	for k in keys:
		if k.find(" ") != -1:
			if k in lower:
				return true
		else:
			for w in words:
				if w == k:
					return true
				if nlp_mgr and nlp_mgr.has_method("levenshtein") and w.length() >= 4 and nlp_mgr.levenshtein(w, k) <= 1:
					return true
	return false

func _validate_and_submit(raw_text: String) -> void:
	var cleaned = raw_text.strip_edges()
	var lower = cleaned.to_lower()

	# 1. Cek jika kosong
	if cleaned.is_empty():
		_show_validation_error("Silakan ketik jawabanmu terlebih dahulu ya...")
		return

	# 2. Cek kata kasar / profanity
	var words = lower.split(" ", false)
	for w in words:
		var clean_w = ""
		for char in w:
			if char.is_valid_identifier() or char in ["-", "_"]:
				clean_w += char
		if clean_w in PROFANITY_LIST or w in PROFANITY_LIST:
			_show_validation_error("Yuk gunakan kata-kata yang sopan dan baik.")
			return

	for bad in PROFANITY_LIST:
		if bad in lower and (lower.begins_with(bad + " ") or lower.ends_with(" " + bad) or (" " + bad + " ") in lower or lower == bad):
			_show_validation_error("Yuk gunakan kata-kata yang sopan dan baik.")
			return

	# Cabang validasi sesuai mode
	if current_dialog_mode == "general_reflection":
		if words.size() < 3 or not _has_relevant_keyword(lower, words, RELEVANT_GENERAL):
			_show_validation_error("Jawab sesuai pertanyaan Ona ya: ceritakan perasaanmu saat melewati sungai tadi.")
			return
		_process_reflection(cleaned)

	elif current_dialog_mode == "anger_reflection":
		if words.size() < 3 or not _has_relevant_keyword(lower, words, RELEVANT_ANGER):
			_show_validation_error("Jawab yang berhubungan ya: hal apa yang biasanya membuat seseorang marah?")
			return
		_process_anger_reflection(cleaned)

	elif current_dialog_mode == "flower_count":
		_process_flower_count_eval(cleaned)

	elif current_dialog_mode == "flower_color":
		_process_flower_color_eval(cleaned)

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

	_close_and_emit(func(): reflection_submitted.emit(sentiment, user_text, ai_reply))

## Pemrosesan Refleksi Kemarahan (Scene 5)
func _process_anger_reflection(user_text: String) -> void:
	is_processing = true
	reflection_input.editable = false
	submit_btn.disabled = true
	if error_label:
		error_label.hide()
	if hint_label:
		hint_label.text = "✦ Ona sedang memahami sudut pandangmu... ✦"
		hint_label.modulate = Color(0.4, 0.9, 1.0, 1.0)

	var ai_reply := ""
	var ai_mgr = get_node_or_null("/root/AIManager") if is_inside_tree() else null
	if ai_mgr and ai_mgr.get("_api_key") != "" and ai_mgr.get("_api_key") != "ISI_API_KEY_KAMU_DISINI":
		var ai_res = await _request_ai_anger(user_text, ai_mgr)
		if not ai_res.is_empty():
			ai_reply = String(ai_res.get("reply", "")).strip_edges()

	# Fallback lokal: regulasi positif (validasi perasaan + ambil sisi positifnya)
	if ai_reply.is_empty():
		ai_reply = _build_positive_regulation(user_text)

	_close_and_emit(func(): anger_reflection_submitted.emit(user_text, ai_reply))

## Regulasi positif offline: validasi perasaan, lalu ubah kekurangan/kegagalan menjadi sisi positif.
func _build_positive_regulation(text: String) -> String:
	var lower := text.to_lower()
	var parts: Array[String] = []
	parts.append("Perasaan itu wajar banget dan kamu tidak salah merasakannya.")

	if "gagal" in lower or "salah" in lower or "gak bisa" in lower or "tidak bisa" in lower or "nggak bisa" in lower:
		parts.append("Coba lihat dari sisi lain: itu bukan tanda kamu gagal atau lemah, justru tanda kamu kuat karena masih mau terus mencoba.")
	elif "dihina" in lower or "diejek" in lower or "direndahkan" in lower or "diprovokasi" in lower:
		parts.append("Ucapan orang lain tidak menentukan nilai dirimu. Justru karena kamu tahu mana yang tidak pantas, kamu sedang menjaga harga dirimu.")
	elif "dikhianati" in lower or "dibohongi" in lower or "kecewa" in lower:
		parts.append("Kamu berani percaya, dan itu kekuatan, bukan kelemahan. Rasa kecewa justru menunjukkan kamu orang yang peduli.")
	elif "sakit hati" in lower or "tersinggung" in lower or "dilanggar" in lower:
		parts.append("Rasa sakit hati berarti ada hal berharga di dalam dirimu yang ingin dijaga. Itu tanda kamu punya nilai dan batas yang sehat.")
	elif "lelah" in lower or "capek" in lower or "putus asa" in lower:
		parts.append("Lelah itu tanda kamu sudah berusaha keras. Beristirahat bukan menyerah, tapi cara merawat dirimu supaya bisa lanjut.")
	else:
		parts.append("Di balik rasa itu ada sesuatu yang peduli dan berharga dalam dirimu.")

	parts.append("Jadi bukan kelemahan ya, ini kesempatanmu memilih respons yang baik dan menjaga dirimu.")
	return " ".join(parts)

## Evaluasi Jumlah Bunga yang Dipetik (Scene 5)
func _process_flower_count_eval(user_text: String) -> void:
	is_processing = true
	reflection_input.editable = false
	submit_btn.disabled = true

	var actual_count: int = GameManager.collected_flower_count if GameManager else 0
	var guessed_number: int = _parse_number_from_text(user_text)
	var diff: int = abs(guessed_number - actual_count) if guessed_number >= 0 else 999
	var is_exact: bool = (guessed_number == actual_count and guessed_number >= 0)
	var comment := ""

	if is_exact:
		comment = "Tepat sekali!"
	elif diff <= 2:
		comment = "Hampir tepat sasaran, tebakanmu tipis banget"
	elif diff <= 10:
		comment = "Kelihatannya ramai dan banyak sekali ya bunganya"
	else:
		comment = "Wah, serasa kita memborong seisi kebun bintang sekaligus ya"

	_close_and_emit(func(): count_evaluation_submitted.emit(user_text, is_exact, comment, actual_count))

## Evaluasi Warna Bunga yang Dipetik (Scene 5: Target Warna = Biru)
func _process_flower_color_eval(user_text: String) -> void:
	is_processing = true
	reflection_input.editable = false
	submit_btn.disabled = true

	var lower = user_text.to_lower().strip_edges()
	var words = lower.split(" ", false)
	var is_correct := false
	
	# Target warna adalah "biru" (dengan variasi seperti cyan, toska, kosmik, blue)
	var target_keywords = ["biru", "cyan", "toska", "blue", "kosmik"]
	for kw in target_keywords:
		if kw in lower:
			is_correct = true
			break

	# Cek toleransi Levenshtein distance untuk kata typo seperti "bilu", "briu", "birus", "biruu"
	var nlp_mgr = get_node_or_null("/root/NLPManager")
	if not is_correct:
		for w in words:
			var clean_w := ""
			for ch in w:
				if ch.is_subsequence_of("abcdefghijklmnopqrstuvwxyz"):
					clean_w += ch
			if clean_w.is_empty():
				continue
			
			if nlp_mgr and nlp_mgr.has_method("levenshtein"):
				# "bilu", "briu", "biruu", "biur" jarak Levenshtein-nya <= 1 (atau transposisi huruf) terhadap "biru"
				if nlp_mgr.levenshtein(clean_w, "biru") <= 1 or clean_w in ["briu", "biur"]:
					is_correct = true
					break
				if clean_w.length() >= 4 and nlp_mgr.levenshtein(clean_w, "blue") <= 1:
					is_correct = true
					break
			else:
				# Fallback jika NLPManager tidak ada
				if clean_w in ["bilu", "briu", "biur", "biruu", "birus", "blu", "bloo"]:
					is_correct = true
					break

	_close_and_emit(func(): color_evaluation_submitted.emit(user_text, is_correct))

func _close_and_emit(emit_cb: Callable) -> void:
	is_waiting_input = false
	is_processing = false

	if reflection_card:
		reflection_card.hide()
	if backdrop:
		backdrop.modulate.a = 0.0
	hide()

	if emit_cb.is_valid():
		emit_cb.call()

func _parse_number_from_text(text: String) -> int:
	var lower = text.to_lower().strip_edges()
	var word_to_num = {
		"satu": 1, "dua": 2, "tiga": 3, "empat": 4, "lima": 5,
		"enam": 6, "tujuh": 7, "delapan": 8, "sembilan": 9, "sepuluh": 10,
		"nol": 0, "kosong": 0
	}
	for word in word_to_num.keys():
		if word in lower:
			return word_to_num[word]

	# Coba ekstrak digit angka
	var digits := ""
	for ch in lower:
		if ch.is_valid_int():
			digits += ch
	if not digits.is_empty():
		return digits.to_int()

	return -1

func _request_ai_reflection(text: String, ai_mgr: Node, prompt_override: String = "") -> Dictionary:
	var http_request := HTTPRequest.new()
	add_child(http_request)

	var request_headers = [
		"Authorization: Bearer " + str(ai_mgr.get("_api_key")),
		"Content-Type: application/json"
	]

	var system_prompt := prompt_override
	if system_prompt.is_empty():
		system_prompt = """
Kamu adalah Ona, robot asisten AI yang bijak, hangat, ramah, dan empatik untuk anak-anak dalam game petualangan antariksa Memorion+.
Rion (temanmu) baru saja berhasil melompati rintangan sungai batu di planet asing setelah memperhatikan pola kedipan lampu batu.
Ona bertanya: "Bagaimana perasaanmu setelah berhasil melewati rintangan sungai tadi?"
Pemain (Rion) menjawab: "%s"

Tugasmu:
1. Tentukan sentimen emosinya ("positif" jika merasa senang/lega/bangga/percaya diri, atau "negatif" jika merasa lelah/kesal/pusing/sulit/takut).
2. Berikan 1 atau maksimal 2 kalimat balasan LANGSUNG dari Ona yang merespons secara spesifik apa yang dirasakan atau diceritakan Rion dengan penuh empati dan apresiasi.

Gaya bahasa: hangat, sederhana untuk anak, dan JANGAN gunakan tanda pisah panjang (— atau –); gunakan koma atau titik.

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
			if parsed and parsed.has("reply"):
				var sent = String(parsed.get("sentiment", "positif")).to_lower().strip_edges()
				var s = "positif"
				if "negatif" in sent or "negative" in sent:
					s = "negatif"
				return {"sentiment": s, "reply": String(parsed["reply"]).strip_edges()}

	return {}

func _request_ai_anger(text: String, ai_mgr: Node) -> Dictionary:
	var prompt := """
Kamu adalah Ona, robot asisten AI yang hangat, empatik, dan bijak untuk anak-anak dalam game petualangan Memorion+.
Rion menjawab pertanyaan: "Menurutmu, hal apa yang biasanya membuat seseorang merasa marah?"
Jawaban Rion: "%s"

Tugasmu (regulasi positif / psikoedukasi emosi):
1. Validasi dulu perasaannya: tegaskan bahwa marah/kesal itu wajar dan tidak salah.
2. Reframe hal negatif, kegagalan, atau kesalahan menjadi sisi positif. Contoh: jika Rion marah karena sering gagal, ubah menjadi "kamu bukan gagal, kamu kuat karena terus mau mencoba".
3. Beri 1-2 kalimat hangat yang menumbuhkan self-esteem dan karakter baik.
Gunakan bahasa Indonesia sederhana untuk anak.
JANGAN gunakan tanda pisah panjang (— atau –) dalam balasan.

Balas HANYA JSON: { "reply": "<balasan Ona>" }
""" % text
	return await _request_ai_reflection(text, ai_mgr, prompt)

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
