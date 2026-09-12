# FragmentBox.gd
extends CanvasLayer

signal fragment_collected(fragment_key: String)
signal fragment_closed(fragment_key: String)

@onready var backdrop: ColorRect = $Backdrop
@onready var card: Control = $CardContainer/Card
@onready var card_container: Control = $CardContainer
@onready var stone_texture: TextureRect = $CardContainer/Card/Margin/VBox/StoneContainer/StoneTexture
@onready var stone_glow: TextureRect = $CardContainer/Card/Margin/VBox/StoneContainer/GlowTexture
@onready var pulse_fx: Sprite2D = $CardContainer/Card/Margin/VBox/StoneContainer/PulseFX
@onready var shine_fx: Sprite2D = $CardContainer/Card/Margin/VBox/StoneContainer/ShineFX
@onready var header_label: Label = $CardContainer/Card/Margin/VBox/HeaderLabel
@onready var name_label: Label = $CardContainer/Card/Margin/VBox/NameLabel
@onready var desc_label: Label = $CardContainer/Card/Margin/VBox/DescLabel
@onready var claim_button: Button = $CardContainer/Card/Margin/VBox/ClaimButton

var current_fragment_key: String = ""
var is_showing: bool = false
var _float_time: float = 0.0
var _stone_base_pos: Vector2 = Vector2.ZERO

const FRAGMENTS_DATA = {
	"batu": {
		"title": "Fragmen Fokus & Ketenangan",
		"congrats": "✦ MATERI PSIKOEDUKASI DITEMUKAN ✦",
		"desc": "Mengelola Gugup: Saat menghadapi rintangan, tarik napas pelan dan kerjakan satu langkah demi satu langkah. Memusatkan perhatian pada pola yang ada membantumu melewati rasa tegang.",
		"praise": "Kamu anak yang berani mencoba lagi walaupun sempat gugup — itu tanda keberanian!",
		"texture_path": "res://assets/StoneImage/Cristal.png",
		"glow_color": Color(0.2, 0.8, 1.0)
	},
	"lever_crusher": {
		"title": "Fragmen Mengolah Emosi",
		"congrats": "✦ MATERI PSIKOEDUKASI DITEMUKAN ✦",
		"desc": "Mengelola Amarah: Marah adalah emosi yang wajar. Yang penting adalah cara mengolahnya — salurkan energinya ke hal yang membangun, bukan melukai diri sendiri atau orang lain.",
		"praise": "Kamu hebat karena mampu mengubah rasa kesal menjadi tindakan yang membangun.",
		"texture_path": "res://assets/StoneImage/Iron.png",
		"glow_color": Color(0.95, 0.45, 0.2, 1.0)
	},
	"lever_onaprogram": {
		"title": "Fragmen Mengenali Diri",
		"congrats": "✦ MATERI PSIKOEDUKASI DITEMUKAN ✦",
		"desc": "Kesadaran Diri: Seperti program yang bisa dilatih, pikiran dan kebiasaan baik juga bisa kita bentuk. Kenali perasaanmu, lalu pilih respons yang kamu inginkan.",
		"praise": "Kamu pribadi yang mau tumbuh dan belajar hal baru tentang dirimu sendiri.",
		"texture_path": "res://assets/StoneImage/Thorium.png",
		"glow_color": Color(0.337, 0.62, 1.0, 1.0)
	},
	"terminal": {
		"title": "Fragmen Memori & Koneksi",
		"congrats": "✦ MATERI PSIKOEDUKASI DITEMUKAN ✦",
		"desc": "Berbagi Cerita: Ingatan dan cerita membentuk siapa kita. Berbagi cerita dengan orang yang dipercaya membuat kita merasa terhubung dan tidak sendirian.",
		"praise": "Kamu pendengar yang baik dan mampu menyambung kembali cerita yang sempat hilang.",
		"texture_path": "res://assets/StoneImage/Titanium.png",
		"glow_color": Color(0.75, 0.45, 1.0)
	},
	"unpacking_rak1": {
		"title": "Fragmen Keteraturan",
		"congrats": "✦ MATERI PSIKOEDUKASI DITEMUKAN ✦",
		"desc": "Rapi & Kendali Diri: Menata barang di tempatnya membantu pikiran terasa lebih tenang dan terkendali. Mulailah dari hal kecil, satu langkah setiap kali.",
		"praise": "Kamu orang yang sangat teratur dan teliti!",
		"texture_path": "res://assets/StoneImage/Gold.png",
		"glow_color": Color(1.0, 0.85, 0.25)
	},
	"unpacking_rak2": {
		"title": "Fragmen Ketekunan",
		"congrats": "✦ MATERI PSIKOEDUKASI DITEMUKAN ✦",
		"desc": "Menyelesaikan Tugas: Menuntaskan pekerjaan sampai selesai melatih ketekunan dan rasa percaya diri. Kamu sudah membuktikan bisa merampungkan semuanya!",
		"praise": "Kamu pantang menyerah dan selalu menuntaskan apa yang sudah kamu mulai.",
		"texture_path": "res://assets/StoneImage/Quartz.png",
		"glow_color": Color(0.9, 0.75, 1.0)
	},
	"uranium": {
		"title": "Fragmen Ketangguhan",
		"congrats": "✦ MATERI PSIKOEDUKASI DITEMUKAN ✦",
		"desc": "Daya Bangkit: Setiap pengalaman, termasuk yang sulit, menambah kekuatan dalam dirimu. Boleh beristirahat sejenak, lalu bangkit dan lanjut lagi.",
		"praise": "Kamu kuat, dan kamu layak bangga pada dirimu sendiri.",
		"texture_path": "res://assets/StoneImage/Uranium.png",
		"glow_color": Color(0.4, 0.9, 0.3)
	}
}

func _ready() -> void:
	layer = 25
	hide()
	if desc_label:
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	claim_button.pressed.connect(_on_claim_pressed)

func _process(delta: float) -> void:
	if not visible or not is_showing:
		return
	
	_float_time += delta
	# Animasi batu mengambang lembut
	if stone_texture:
		stone_texture.position.y = _stone_base_pos.y + sin(_float_time * 2.5) * 8.0
	if stone_glow:
		stone_glow.scale = Vector2.ONE * (1.0 + sin(_float_time * 2.0) * 0.08)
	if shine_fx:
		shine_fx.rotation += delta * 0.4

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not is_showing:
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_SPACE, KEY_E, KEY_KP_ENTER]:
			get_viewport().set_input_as_handled()
			_on_claim_pressed()
			return

	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		_on_claim_pressed()

func show_fragment(fragment_key: String) -> void:
	current_fragment_key = fragment_key
	var data = FRAGMENTS_DATA.get(fragment_key, FRAGMENTS_DATA["batu"])
	
	if ResourceLoader.exists(data["texture_path"]):
		stone_texture.texture = load(data["texture_path"])
	
	header_label.text = data["congrats"]
	name_label.text = data["title"]
	var praise: String = data.get("praise", "")
	if praise.is_empty():
		desc_label.text = data["desc"]
	else:
		desc_label.text = data["desc"] + "\n\n💚 " + praise
	
	var glow_col: Color = data.get("glow_color", Color(0.4, 0.85, 1.0))
	header_label.modulate = glow_col
	name_label.modulate = Color(1.0, 1.0, 1.0)
	if stone_glow:
		stone_glow.modulate = Color(glow_col.r, glow_col.g, glow_col.b, 0.6)
	if shine_fx:
		shine_fx.modulate = Color(glow_col.r, glow_col.g, glow_col.b, 0.8)
	
	if GameManager:
		GameManager.collected_fragments[fragment_key] = true
	
	show()
	is_showing = true
	
	# Simpan posisi awal untuk floating
	await get_tree().process_frame
	if stone_texture:
		_stone_base_pos = stone_texture.position
	
	_play_open_animation()
	await fragment_closed

func _play_open_animation() -> void:
	backdrop.modulate.a = 0.0
	card.scale = Vector2(0.5, 0.5)
	card.modulate.a = 0.0
	card.pivot_offset = card.size * 0.5
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(backdrop, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE, 0.45)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)

func _on_claim_pressed() -> void:
	if not is_showing:
		return
	is_showing = false
	
	fragment_collected.emit(current_fragment_key)
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(backdrop, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_property(card, "scale", Vector2(0.7, 0.7), 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(card, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	
	await tween.finished
	hide()
	fragment_closed.emit(current_fragment_key)
