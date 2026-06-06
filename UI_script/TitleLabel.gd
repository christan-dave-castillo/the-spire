## TitleLabel.gd
## Attach to the Label showing your game title.
extends RichTextLabel

@export var glow_color: Color = Color(0.0, 0.0, 0.0, 1.0)
@export var flicker_speed: float = 2.5
@export var flicker_min: float = 2   # minimum brightness during flicker
@export var flicker_chance: float = 0.015 # chance per frame of a glitch flicker

var _base_modulate: Color
var _glitch_timer: float = 0.0
var _is_glitching: bool = false

func _ready() -> void:
	_base_modulate = modulate
	# Enable font outline for glow effect
	add_theme_color_override("font_outline_color", glow_color)
	add_theme_constant_override("outline_size", 12)
	# Also add a shadow for extra bloom feel
	add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 0.5))
	add_theme_constant_override("shadow_offset_x", 0)
	add_theme_constant_override("shadow_offset_y", 0)
	add_theme_constant_override("shadow_outline_size", 8)

func _process(delta: float) -> void:
	var t = Time.get_ticks_msec() * 0.001

	# Slow breathing glow
	var breath = 0.9 + 0.1 * sin(t * flicker_speed)

	# Random glitch flicker
	if not _is_glitching and randf() < flicker_chance:
		_is_glitching = true
		_glitch_timer = randf_range(0.05, 0.18)

	if _is_glitching:
		_glitch_timer -= delta
		breath = randf_range(flicker_min, 1.0)
		if _glitch_timer <= 0.0:
			_is_glitching = false

	modulate = Color(_base_modulate.r * breath,
					 _base_modulate.g * breath,
					 _base_modulate.b * breath,
					 _base_modulate.a)
