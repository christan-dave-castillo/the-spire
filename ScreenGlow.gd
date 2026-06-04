## ScreenGlow.gd
extends PointLight2D

@export var base_energy: float = 0.6
@export var pulse_speed: float = 0.8
@export var pulse_amount: float = 0.08

func _ready() -> void:
	color = Color(0.0, 0.9, 0.45)
	texture_scale = 3.5
	texture = _make_light_texture()

func _make_light_texture() -> GradientTexture2D:
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))   # center: opaque white
	gradient.set_color(1, Color(1, 1, 1, 0))   # edge: transparent

	var tex = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)  # center
	tex.fill_to = Vector2(1.0, 0.5)    # edge
	tex.width = 128
	tex.height = 128
	return tex

func _process(_delta: float) -> void:
	energy = base_energy + sin(Time.get_ticks_msec() * 0.001 * pulse_speed) * pulse_amount
