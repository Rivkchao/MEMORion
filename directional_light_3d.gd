extends DirectionalLight3D

@export var cycle_duration: float = 300.0  # 5 menit = 300 detik
@export var sunrise_angle: float = -90.0
@export var sunset_angle: float = 90.0

var elapsed: float = 0.0

func _process(delta: float) -> void:
	elapsed += delta
	
	# Normalize 0.0 - 1.0
	var t = fmod(elapsed, cycle_duration) / cycle_duration
	
	# Rotasi dari sunrise ke sunset ke sunrise lagi
	var angle = lerp(sunrise_angle, sunset_angle, t) if t < 0.5 else lerp(sunset_angle, sunrise_angle + 360.0, (t - 0.5) * 2.0)
	
	rotation_degrees.x = angle
