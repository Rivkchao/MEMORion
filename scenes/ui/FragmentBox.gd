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
		"title": "Fragmen Kristal Aliran",
		"congrats": "✦ FRAGMEN MEMORI DITEMUKAN ✦",
		"desc": "Kristal murni yang terbentuk dari harmoni formasi batu sungai. Menjaga aliran air tetap tenang dan membuka jalur rahasia.",
		"texture_path": "res://assets/StoneImage/Cristal.png",
		"glow_color": Color(0.2, 0.8, 1.0)
	},
	"lever_crusher": {
		"title": "Fragmen Besi Penempa",
		"congrats": "✦ FRAGMEN MEMORI DITEMUKAN ✦",
		"desc": "Logam kokoh penopang mesin penghancur bengkel. Simbol ketangguhan kerja keras yang menghidupkan kembali sektor barat.",
		"texture_path": "res://assets/StoneImage/Iron.png",
		"glow_color": Color(0.95, 0.45, 0.2, 1.0)
	},
	"lever_onaprogram": {
		"title": "Fragmen Inti Thorium",
		"congrats": "✦ FRAGMEN MEMORI DITEMUKAN ✦",
		"desc": "Zat energi stabil dari ruang pemrograman Ona. Mengaktifkan kembali baris kode dan kecerdasan artifisial bengkel.",
		"texture_path": "res://assets/StoneImage/Thorium.png",
		"glow_color": Color(0.337, 0.62, 1.0, 1.0)
	},
	"terminal": {
		"title": "Fragmen Titanium Siber",
		"congrats": "✦ FRAGMEN MEMORI DITEMUKAN ✦",
		"desc": "Komponen sirkuit berdensitas tinggi dari terminal data. Menyambungkan kembali memori kabel yang sempat terputus.",
		"texture_path": "res://assets/StoneImage/Titanium.png",
		"glow_color": Color(0.75, 0.45, 1.0)
	},
	"unpacking_rak1": {
		"title": "Fragmen Emas Keteraturan",
		"congrats": "✦ FRAGMEN MEMORI DITEMUKAN ✦",
		"desc": "Kilau logam berharga atas ketelitianmu menata inventaris pertama. Setiap peralatan kini berada di tempat semestinya.",
		"texture_path": "res://assets/StoneImage/Gold.png",
		"glow_color": Color(1.0, 0.85, 0.25)
	},
	"unpacking_rak2": {
		"title": "Fragmen Quartz Bercahaya",
		"congrats": "✦ FRAGMEN MEMORI DITEMUKAN ✦",
		"desc": "Kristal memori yang mengkristal setelah seluruh bengkel ditata rapi. Ruangan kembali bersih dan serpihan masa lalu Rion kian utuh!",
		"texture_path": "res://assets/StoneImage/Quartz.png",
		"glow_color": Color(0.9, 0.75, 1.0)
	},
	"uranium": {
		"title": "Fragmen Uranium Kuno",
		"congrats": "✦ FRAGMEN MEMORI DITEMUKAN ✦",
		"desc": "Batuan radioaktif murni yang menyimpan energi misterius peradaban masa lampau.",
		"texture_path": "res://assets/StoneImage/Uranium.png",
		"glow_color": Color(0.4, 0.9, 0.3)
	}
}

func _ready() -> void:
	layer = 25
	hide()
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

func show_fragment(fragment_key: String) -> void:
	current_fragment_key = fragment_key
	var data = FRAGMENTS_DATA.get(fragment_key, FRAGMENTS_DATA["batu"])
	
	if ResourceLoader.exists(data["texture_path"]):
		stone_texture.texture = load(data["texture_path"])
	
	header_label.text = data["congrats"]
	name_label.text = data["title"]
	desc_label.text = data["desc"]
	
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
