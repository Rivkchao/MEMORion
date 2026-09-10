# scenes/ui/ReflectionDialog.gd
extends CanvasLayer

signal reflection_submitted(sentiment: String)
signal badge_closed

@onready var backdrop: ColorRect = $Backdrop
@onready var reflection_card: Control = $CardContainer/ReflectionCard
@onready var reflection_input: LineEdit = $CardContainer/ReflectionCard/Margin/VBox/InputContainer/ReflectionInput
@onready var submit_btn: Button = $CardContainer/ReflectionCard/Margin/VBox/SubmitButton
@onready var badge_card: Control = $CardContainer/BadgeCard
@onready var badge_close_btn: Button = $CardContainer/BadgeCard/Margin/VBox/CloseButton
@onready var card_container: Control = $CardContainer

var is_waiting_input: bool = false
var is_waiting_badge: bool = false

# Kata kunci sentimen bahasa Indonesia untuk offline fallback
const POSITIVE_KEYWORDS: Array[String] = [
	"bisa", "senang", "lega", "seru", "mudah", "gampang", "berhasil", "hebat",
	"percaya", "diri", "keren", "mantap", "semangat", "yakin", "tenang", "sabar",
	"asyik", "bangga", "siap", "sukses", "aman", "paham", "mengerti", "happy"
]

const NEGATIVE_KEYWORDS: Array[String] = [
	"susah", "sulit", "capek", "lelah", "kesal", "marah", "takut", "gagal",
	"bingung", "pusing", "berat", "panik", "cemas", "ribet", "jengkel",
	"putus asa", "kalah", "lemah", "ragu", "bosan", "repot"
]

func _ready() -> void:
	add_to_group("reflection_dialog")
	hide()
	reflection_card.hide()
	badge_card.hide()
	backdrop.modulate.a = 0.0

	reflection_input.text_submitted.connect(_on_input_submitted)
	submit_btn.pressed.connect(_on_submit_pressed)
	badge_close_btn.pressed.connect(_on_badge_close_pressed)

func show_reflection_prompt() -> void:
	show()
	badge_card.hide()
	reflection_card.show()
	reflection_input.text = ""
	is_waiting_input = true

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
	if not is_waiting_input:
		return
	_submit_text(reflection_input.text)

func _on_input_submitted(text: String) -> void:
	if not is_waiting_input:
		return
	_submit_text(text)

func _submit_text(raw_text: String) -> void:
	var cleaned = raw_text.strip_edges()
	if cleaned.is_empty():
		cleaned = "Awalnya susah tapi akhirnya bisa"

	is_waiting_input = false

	# 1. Analisis sentimen lokal secara instan (0 ms latency)
	var sentiment = _local_keyword_sentiment(cleaned)

	# 2. Sembunyikan reflection card dan dialog seketika
	if reflection_card:
		reflection_card.hide()
	if backdrop:
		backdrop.modulate.a = 0.0
	hide()

	# 3. Emit sentimen seketika agar dialog box cerita langsung muncul tanpa lag
	reflection_submitted.emit(sentiment)

func _analyze_sentiment(text: String) -> String:
	var ai_mgr = get_node_or_null("/root/AIManager") if is_inside_tree() else null
	# 1. Coba lewat AIManager jika API key tersedia
	if ai_mgr and ai_mgr.get("_api_key") != "" and ai_mgr.get("_api_key") != "ISI_API_KEY_KAMU_DISINI":
		var result = await _request_ai_sentiment(text, ai_mgr)
		if result != "":
			return result

	# 2. Offline NLP keyword matching
	return _local_keyword_sentiment(text)

func _request_ai_sentiment(text: String, ai_mgr: Node) -> String:
	var http_request := HTTPRequest.new()
	add_child(http_request)

	var request_headers = [
		"Authorization: Bearer " + str(ai_mgr.get("_api_key")),
		"Content-Type: application/json"
	]

	var system_prompt = """
	Kamu adalah AI sentimen analyzer untuk game anak-anak.
	Analisis kalimat input dan kategorikan HANYA menjadi: 'positif' atau 'negatif'.
	Aturan:
	Keluarkan HANYA JSON: {"sentiment": "positif"} atau {"sentiment": "negatif"}.
	"""

	var payload = {
		"model": "openai/gpt-4o-mini",
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": text}
		],
		"temperature": 0.2,
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
		return ""

	var res = await http_request.request_completed
	http_request.queue_free()

	var response_code = res[1]
	var body: PackedByteArray = res[3]
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json.has("choices") and json["choices"].size() > 0:
			var content_str = json["choices"][0]["message"]["content"]
			var parsed = JSON.parse_string(content_str)
			if parsed and parsed.has("sentiment"):
				var sent = String(parsed["sentiment"]).to_lower().strip_edges()
				if "positif" in sent or "positive" in sent:
					return "positif"
				elif "negatif" in sent or "negative" in sent:
					return "negatif"
	return ""

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
