# scenes/props/FlowerBasket.gd
extends Node3D

@onready var flower_container: Node3D = get_node_or_null("FlowersInside")
var base_scale: Vector3 = Vector3.ONE
var _pop_tween: Tween = null

func _ready() -> void:
	add_to_group("flower_basket")
	base_scale = scale
	var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	update_flower_display(gm.collected_flower_count if gm else 0)

## Dipanggil pemasang keranjang setelah mengatur skala akhir (mis. saat dipasang di tangan Rion)
func set_base_scale(new_scale: Vector3) -> void:
	base_scale = new_scale
	scale = new_scale

func update_flower_display(count: int) -> void:
	if flower_container == null:
		return
	var children = flower_container.get_children()
	for i in range(children.size()):
		children[i].visible = (i < count)

func play_collect_pop() -> void:
	# Selalu kembali ke base_scale terkini, dan jangan menumpuk tween (agar tidak membesar terus)
	if _pop_tween and _pop_tween.is_valid():
		_pop_tween.kill()
		scale = base_scale
	_pop_tween = create_tween()
	_pop_tween.tween_property(self, "scale", base_scale * 1.12, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(self, "scale", base_scale, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
