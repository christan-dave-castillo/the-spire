## MatrixRain.gd
## Attach to a Node2D placed above your background but below your UI layer.
## The rain is drawn entirely with _draw() — no sprites needed.
##
## Scene tree setup:
##   MainMenu (Control or Node2D)
##   ├── BackgroundImage (TextureRect) ← your static bg
##   ├── MatrixRain (Node2D)           ← this script
##   └── UILayer (Control)             ← title + buttons

extends Node2D

# ─── Tunables ────────────────────────────────────────────────────────────────
@export var font_size: int = 14
@export var column_spacing: int = 14     # px between columns; match font_size
@export var drop_speed_min: float = 60.0 # px/sec
@export var drop_speed_max: float = 120.0
@export var rain_opacity: float = 0.55   # overall layer opacity (0.0–1.0)
@export var trail_length: int = 20       # characters in each column trail
@export var respawn_chance: float = 0.015 # per frame, chance a finished column resets

# Colours
@export var color_head: Color    = Color(1.0, 1.0, 1.0, 1.0)   # leading char
@export var color_bright: Color  = Color(0.67, 1.0, 0.88, 1.0) # top of trail
@export var color_mid: Color     = Color(0.0, 0.8, 0.4, 1.0)   # mid trail
@export var color_dim: Color     = Color(0.0, 0.5, 0.25, 0.0)  # tail (fades out)
# ─────────────────────────────────────────────────────────────────────────────

const KATAKANA = "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン"
const LATIN    = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const DIGITS   = "0123456789"

var _charset: Array[String] = []
var _font: Font

class Column:
	var x: float
	var y: float          # current head position in px
	var speed: float
	var chars: Array[String] = []  # current visible characters (trail)
	var max_trail: int

	func init(px: float, scr_h: float, sp_min: float, sp_max: float, trail: int, charset: Array[String]) -> void:
		x = px
		speed = randf_range(sp_min, sp_max)
		max_trail = trail + randi() % 8
		y = randf_range(-scr_h, 0.0)  # stagger starts
		_refill(charset)

	func _refill(charset: Array[String]) -> void:
		chars.clear()
		for i in range(max_trail):
			chars.append(charset[randi() % charset.size()])

	func advance(delta: float, scr_h: float, charset: Array[String]) -> bool:
		y += speed * delta
		# Randomly scramble one char in trail each frame for glitch effect
		if randf() < 0.3:
			var idx = randi() % chars.size()
			chars[idx] = charset[randi() % charset.size()]
		# Return true when the full trail has scrolled off screen
		return y - max_trail * 14 > scr_h

var _columns: Array[Column] = []
var _screen_size: Vector2

func _ready() -> void:
	# Build charset array
	for ch in KATAKANA + LATIN + DIGITS:
		_charset.append(ch)

	_font = ThemeDB.fallback_font

	_screen_size = get_viewport().get_visible_rect().size
	_build_columns()

	# Allow sub-pixel drawing
	use_parent_material = false
	modulate.a = rain_opacity

	# Redraw every frame
	set_process(true)


func _build_columns() -> void:
	_columns.clear()
	var cols = int(_screen_size.x / column_spacing) + 2
	for i in range(cols):
		var c = Column.new()
		c.init(i * column_spacing, _screen_size.y, drop_speed_min, drop_speed_max, trail_length, _charset)
		_columns.append(c)


func _process(delta: float) -> void:
	for col in _columns:
		var finished = col.advance(delta, _screen_size.y, _charset)
		if finished and randf() < respawn_chance + delta * 0.5:
			col.y = randf_range(-_screen_size.y * 0.3, 0.0)
			col.speed = randf_range(drop_speed_min, drop_speed_max)
	queue_redraw()


func _draw() -> void:
	for col in _columns:
		var n = col.chars.size()
		for i in range(n):
			var cy = col.y - i * font_size
			# Skip characters off screen
			if cy < -font_size or cy > _screen_size.y:
				continue

			var t = float(i) / float(n)  # 0 = head, 1 = tail
			var col_color: Color

			if i == 0:
				col_color = color_head
			elif t < 0.15:
				col_color = color_head.lerp(color_bright, t / 0.15)
			elif t < 0.5:
				col_color = color_bright.lerp(color_mid, (t - 0.15) / 0.35)
			else:
				col_color = color_mid.lerp(color_dim, (t - 0.5) / 0.5)

			draw_string(
				_font,
				Vector2(col.x, cy),
				col.chars[i],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				col_color
			)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_screen_size = get_viewport().get_visible_rect().size
		_build_columns()
