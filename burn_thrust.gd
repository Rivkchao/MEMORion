extends MeshInstance3D

@export var toggle_action: String = "ui_home"

# Pulls the flame down into the nozzle for shutdown
@export var off_uv_middle: float = -1.5 
@export var off_intensity: float = 0.0
@export var off_noise_strength: float = 0.1 # Low turbulence when off

var is_on: bool = true
var tween: Tween
var thrust_material: ShaderMaterial

var on_uv_middle: float
var on_intensity: float
var on_noise_strength: float
var on_color_core: Color
var on_color_mid: Color
var on_color_edge: Color

func _ready() -> void:
	thrust_material = material_override.duplicate() as ShaderMaterial
	material_override = thrust_material
		
	on_uv_middle = thrust_material.get_shader_parameter("uv_middle")
	on_intensity = thrust_material.get_shader_parameter("intensity")
	on_noise_strength = thrust_material.get_shader_parameter("noise_strength")
	on_color_core = thrust_material.get_shader_parameter("color_core")
	on_color_mid = thrust_material.get_shader_parameter("color_mid")
	on_color_edge = thrust_material.get_shader_parameter("color_edge")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		is_on = not is_on
		if tween and tween.is_valid(): tween.kill()
		tween = create_tween().set_parallel(true)
		
		if is_on:
			# Power on: elastic overshoot and bounce into shape
			tween.set_trans(Tween.TRANS_ELASTIC)
			tween.set_ease(Tween.EASE_OUT) 
			
			tween.tween_property(thrust_material, "shader_parameter/uv_middle", on_uv_middle, 1.0)
			tween.tween_property(thrust_material, "shader_parameter/intensity", on_intensity, 0.8)
			tween.tween_property(thrust_material, "shader_parameter/noise_strength", on_noise_strength, 0.8)
			
			tween.tween_property(thrust_material, "shader_parameter/color_core", on_color_core, 0.5)
			tween.tween_property(thrust_material, "shader_parameter/color_mid", on_color_mid, 0.5)
			tween.tween_property(thrust_material, "shader_parameter/color_edge", on_color_edge, 0.5)
			
		else:
			# Power off: fast drop followed by slow fade
			tween.set_trans(Tween.TRANS_EXPO)
			tween.set_ease(Tween.EASE_OUT)
			
			tween.tween_property(thrust_material, "shader_parameter/uv_middle", off_uv_middle, 0.8)
			tween.tween_property(thrust_material, "shader_parameter/intensity", off_intensity, 0.8)
			tween.tween_property(thrust_material, "shader_parameter/noise_strength", off_noise_strength, 0.6)
			
			var off_core = Color(on_color_core.r, on_color_core.g, on_color_core.b, 0.0)
			var off_mid = Color(on_color_mid.r, on_color_mid.g, on_color_mid.b, 0.0)
			var off_edge = Color(on_color_edge.r, on_color_edge.g, on_color_edge.b, 0.0)
			tween.tween_property(thrust_material, "shader_parameter/color_core", off_core, 0.8)
			tween.tween_property(thrust_material, "shader_parameter/color_mid", off_mid, 0.8)
			tween.tween_property(thrust_material, "shader_parameter/color_edge", off_edge, 0.8)
