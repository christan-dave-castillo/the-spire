class_name CardNode
extends Control

signal card_played(card_data: Dictionary)

const CARD_TEXTURE = preload("res://UI_asset/card_images/Card.png")
const FONT_BOLD    = preload("res://UI_asset/font/Silkscreen-Bold.ttf")
const FONT_BODY    = preload("res://UI_asset/font/m3x6.ttf")

const CARD_W      = 72
const CARD_H      = 108
const ICON_ZONE_H = 56   # top portion: energy badge + logic text
const PATCH_L     = 6
const PATCH_R     = 6
const PATCH_T     = 8
const PATCH_B     = 6

const TYPE_COLORS = {
	"Investigation": Color(0.3,  0.6,  1.0,  0.45),
	"Monitoring":    Color(0.3,  0.9,  0.6,  0.45),
	"Hardening":     Color(0.9,  0.7,  0.2,  0.45),
	"Response":      Color(1.0,  0.35, 0.35, 0.45),
	"Recovery":      Color(0.5,  0.85, 0.4,  0.45),
	"Automation":    Color(0.6,  0.4,  1.0,  0.45),
	"Rare":          Color(1.0,  0.85, 0.2,  0.65),
}

var card_data: Dictionary = {}
var _bg: NinePatchRect = null
var _is_affordable: bool = true

func _ready() -> void:
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	size                = Vector2(CARD_W, CARD_H)
	pivot_offset        = Vector2(CARD_W * 0.5, CARD_H)
	mouse_filter        = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(data: Dictionary) -> void:
	card_data = data
	# Clear any previous visual children before rebuilding
	for c in get_children():
		c.queue_free()
	_bg = null
	_build_visual()

# All children use explicit pixel positions based on CARD_W / CARD_H constants
# so they are correct regardless of when the layout engine runs.
func _build_visual() -> void:
	# ── Background (NinePatch) ──────────────────────────────────────────────
	_bg = NinePatchRect.new()
	_bg.texture             = CARD_TEXTURE
	_bg.patch_margin_left   = PATCH_L
	_bg.patch_margin_right  = PATCH_R
	_bg.patch_margin_top    = PATCH_T
	_bg.patch_margin_bottom = PATCH_B
	_bg.position            = Vector2.ZERO
	_bg.size                = Vector2(CARD_W, CARD_H)
	_bg.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# ── Type-colour tint (icon zone) ───────────────────────────────────────
	var tint := ColorRect.new()
	tint.color        = TYPE_COLORS.get(card_data.get("type", ""), Color(0.5, 0.5, 0.5, 0.3))
	tint.position     = Vector2(4, 6)
	tint.size         = Vector2(CARD_W - 8, ICON_ZONE_H - 6)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)

	# ── Energy badge (top-left corner) ─────────────────────────────────────
	var badge_bg := ColorRect.new()
	badge_bg.color        = Color(0.10, 0.10, 0.16, 0.90)
	badge_bg.position     = Vector2(4, 4)
	badge_bg.size         = Vector2(16, 14)
	badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge_bg)

	var energy_lbl := Label.new()
	energy_lbl.text = str(card_data.get("energy", 0))
	energy_lbl.add_theme_font_override("font",      FONT_BOLD)
	energy_lbl.add_theme_font_size_override("font_size", 9)
	energy_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.20))
	energy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	energy_lbl.position     = Vector2(4, 4)
	energy_lbl.size         = Vector2(16, 14)
	energy_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(energy_lbl)

	# ── Logic text (inside icon zone, below badge) ─────────────────────────
	var logic_lbl := Label.new()
	logic_lbl.text = card_data.get("logic", "")
	logic_lbl.add_theme_font_override("font",      FONT_BODY)
	logic_lbl.add_theme_font_size_override("font_size", 9)
	logic_lbl.add_theme_color_override("font_color", Color(0.08, 0.08, 0.12))
	logic_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logic_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	logic_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	logic_lbl.position     = Vector2(6, 20)
	logic_lbl.size         = Vector2(CARD_W - 12, ICON_ZONE_H - 22)
	logic_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logic_lbl)

	# ── Divider line ───────────────────────────────────────────────────────
	var divider := ColorRect.new()
	divider.color        = Color(0.55, 0.45, 0.30, 0.50)
	divider.position     = Vector2(6, ICON_ZONE_H + 1)
	divider.size         = Vector2(CARD_W - 12, 1)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(divider)

	# ── Card name ──────────────────────────────────────────────────────────
	var name_lbl := Label.new()
	name_lbl.text = card_data.get("name", "")
	name_lbl.add_theme_font_override("font",      FONT_BOLD)
	name_lbl.add_theme_font_size_override("font_size", 7)   # 8→7: prevents mid-word splits
	name_lbl.add_theme_color_override("font_color", Color(0.18, 0.10, 0.04))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD        # WORD_SMART can split mid-word
	name_lbl.clip_contents = true
	name_lbl.position     = Vector2(5, ICON_ZONE_H + 4)
	name_lbl.size         = Vector2(CARD_W - 10, 20)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_lbl)

	# ── Tooltip ────────────────────────────────────────────────────────────
	var tip_lbl := Label.new()
	tip_lbl.text = card_data.get("tooltip", "")
	tip_lbl.add_theme_font_override("font",      FONT_BODY)
	tip_lbl.add_theme_font_size_override("font_size", 7)
	tip_lbl.add_theme_color_override("font_color", Color(0.40, 0.24, 0.10))
	tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_lbl.position     = Vector2(5, ICON_ZONE_H + 26)
	tip_lbl.size         = Vector2(CARD_W - 10, CARD_H - ICON_ZONE_H - 30)
	tip_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tip_lbl)

# ── Public helpers ────────────────────────────────────────────────────────────

func set_playable(affordable: bool) -> void:
	_is_affordable = affordable
	modulate = Color.WHITE if affordable else Color(0.5, 0.5, 0.5, 0.85)

func flash_red() -> void:
	if _bg:
		_bg.modulate = Color(1.0, 0.3, 0.3)
		await get_tree().create_timer(0.25).timeout
		if is_instance_valid(_bg):
			_bg.modulate = Color.WHITE

# ── Input / hover ─────────────────────────────────────────────────────────────

func _on_mouse_entered() -> void:
	if _bg: _bg.modulate = Color(1.12, 1.12, 1.05)
	scale   = Vector2(1.06, 1.06)
	z_index = 2

func _on_mouse_exited() -> void:
	if _bg: _bg.modulate = Color.WHITE
	scale   = Vector2.ONE
	z_index = 0

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			emit_signal("card_played", card_data)
