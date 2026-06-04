## MatrixRain.gd
## Now supports an optional clip_rect so rain is confined to a specific region
## (e.g. the TV screen). Set clip_rect in the Inspector to the TV's screen area
## in local coordinates. If clip_rect has zero size, the full viewport is used.

extends Node2D

# ─── Tunables ────────────────────────────────────────────────────────────────
@export var font_size: int = 8
@export var column_spacing: int = 14
@export var drop_speed_min: float = 60.0
@export var drop_speed_max: float = 300.0
@export var rain_opacity: float = 0.55
@export var trail_length: int = 12
@export var respawn_chance: float = 0.015

## Set this to the TV screen rectangle (in this node's local space).
## Example: Rect2(480, 130, 560, 360)  — x, y, width, height
## Leave as Rect2(0,0,0,0) to fill the whole viewport (old behaviour).
@export var clip_rect: Rect2 = Rect2(0, 0, 0, 0)

@export var color_head: Color   = Color(1.0, 1.0, 1.0, 1.0)
@export var color_bright: Color = Color(0.67, 1.0, 0.88, 1.0)
@export var color_mid: Color    = Color(0.0, 0.8, 0.4, 1.0)
@export var color_dim: Color    = Color(0.0, 0.5, 0.25, 0.0)
# ─────────────────────────────────────────────────────────────────────────────

const KATAKANA = "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン"
const LATIN    = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const DIGITS   = "0123456789"

var _charset: Array[String] = []
var _font: Font

class Column:
	var x: float
	var y: float
	var speed: float
	var chars: Array[String] = []
	var max_trail: int

	func init(px: float, scr_h: float, sp_min: float, sp_max: float, trail: int, charset: Array[String]) -> void:
		x = px
		speed = randf_range(sp_min, sp_max)
		max_trail = trail + randi() % 8
		y = randf_range(-scr_h, 0.0)
		_refill(charset)

	func _refill(charset: Array[String]) -> void:
		chars.clear()
		for i in range(max_trail):
			chars.append(charset[randi() % charset.size()])

	func advance(delta: float, scr_h: float, charset: Array[String]) -> bool:
		y += speed * delta
		if randf() < 0.3:
			var idx = randi() % chars.size()
			chars[idx] = charset[randi() % charset.size()]
		return y - max_trail * 14 > scr_h

var _columns: Array[Column] = []
var _screen_size: Vector2
var _draw_rect: Rect2   # the active region (clip_rect or full viewport)

func _ready() -> void:
	for ch in KATAKANA + LATIN + DIGITS:
		_charset.append(ch)
	_font = ThemeDB.fallback_font
	_screen_size = get_viewport().get_visible_rect().size
	_update_draw_rect()
	_build_columns()
	use_parent_material = false
	modulate.a = rain_opacity
	set_process(true)

func _update_draw_rect() -> void:
	if clip_rect.size == Vector2.ZERO:
		_draw_rect = Rect2(Vector2.ZERO, _screen_size)
	else:
		_draw_rect = clip_rect

func _build_columns() -> void:
	_columns.clear()
	var cols = int(_draw_rect.size.x / column_spacing) + 2
	for i in range(cols):
		var c = Column.new()
		# x offset starts at the left edge of the draw rect
		c.init(_draw_rect.position.x + i * column_spacing,
			   _draw_rect.size.y, drop_speed_min, drop_speed_max,
			   trail_length, _charset)
		# Reset y relative to the rect's top
		c.y = randf_range(-_draw_rect.size.y, _draw_rect.position.y)
		_columns.append(c)

func _process(delta: float) -> void:
	for col in _columns:
		var finished = col.advance(delta, _draw_rect.position.y + _draw_rect.size.y, _charset)
		if finished and randf() < respawn_chance + delta * 0.5:
			col.y = randf_range(-_draw_rect.size.y * 0.3, _draw_rect.position.y)
			col.speed = randf_range(drop_speed_min, drop_speed_max)
	queue_redraw()

func _draw() -> void:
	# Push a clip rect so nothing renders outside the TV screen
	var use_clip = clip_rect.size != Vector2.ZERO
	if use_clip:
		RenderingServer.canvas_item_set_custom_rect(get_canvas_item(), true, _draw_rect)

	for col in _columns:
		var n = col.chars.size()
		for i in range(n):
			var cy = col.y - i * font_size
			# Skip chars outside the draw rect vertically
			if cy < _draw_rect.position.y - font_size or cy > _draw_rect.position.y + _draw_rect.size.y:
				continue
			# Skip chars outside horizontally
			if col.x < _draw_rect.position.x - column_spacing or col.x > _draw_rect.position.x + _draw_rect.size.x:
				continue

			var t = float(i) / float(n)
			var col_color: Color
			if i == 0:
				col_color = color_head
			elif t < 0.15:
				col_color = color_head.lerp(color_bright, t / 0.15)
			elif t < 0.5:
				col_color = color_bright.lerp(color_mid, (t - 0.15) / 0.35)
			else:
				col_color = color_mid.lerp(color_dim, (t - 0.5) / 0.5)

			draw_string(_font, Vector2(col.x, cy), col.chars[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col_color)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_screen_size = get_viewport().get_visible_rect().size
		_update_draw_rect()
		_build_columns()
