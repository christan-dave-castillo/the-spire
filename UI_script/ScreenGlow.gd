# ScreenGlow.gd
extends PointLight2D

@export var base_energy: float = 1.5
@export var pulse_speed: float = 0.8
@export var pulse_amount: float = 0.08
@export var flicker_speed: float = 8.0
@export var flicker_amount: float = 0.12

var time: float = 0.0
var light_texture: GradientTexture2D

func _ready() -> void:
	color = Color(0.0, 0.9, 0.45)
	texture_scale = 3.5
	
	# Create texture safely
	light_texture = _make_light_texture()
	# Use call_deferred to avoid atlas error
	call_deferred("set_texture", light_texture)
	
	time = randf() * 20.0


func _process(delta: float) -> void:
	time += delta
	
	# Smooth breathing pulse
	var pulse = sin(time * pulse_speed) * pulse_amount
	
	# Organic flicker using multiple sine waves
	var flicker = sin(time * flicker_speed) * 0.6 + \
				  sin(time * flicker_speed * 2.3) * 0.3 + \
				  sin(time * flicker_speed * 4.7) * 0.1
	
	energy = base_energy + pulse + (flicker * flicker_amount)
	energy = max(0.4, energy)  # prevent going too dark


func _make_light_texture() -> GradientTexture2D:
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))   # center: bright
	gradient.set_color(1, Color(1, 1, 1, 0))   # edge: fade out
	
	var tex = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256   # increased size for better quality
	tex.height = 256
	
	return tex
