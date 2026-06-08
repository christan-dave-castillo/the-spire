class_name CardNode
extends Control

signal card_played(card_data: Dictionary)

## Card dimensions are read directly from the scene node's size — no constants.
## To resize cards: select the CardNode root in card_node.tscn and change
## offset_right / offset_bottom in the Inspector. Everything adapts at runtime.

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
var _is_affordable: bool = true

# Sub-nodes defined in card_node.tscn — edit positions/fonts/sizes there.
@onready var _bg:            NinePatchRect = $Bg
@onready var _type_tint:     ColorRect     = $TypeTint
@onready var _energy_cost:   Label         = $EnergyCost
@onready var _card_name:     Label         = $CardName
@onready var _card_category: Label         = $Label

func _ready() -> void:
	pivot_offset = Vector2(size.x * 0.5, size.y)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

## Call after add_child() — fills text and type-tint colour from card data.
func setup(data: Dictionary) -> void:
	card_data               = data
	_energy_cost.text       = str(data.get("energy", 0))
	_card_name.text         = str(data.get("name",   ""))
	_card_category.text     = str(data.get("type",   ""))
	_type_tint.color        = TYPE_COLORS.get(
		str(data.get("type", "")), Color(0.5, 0.5, 0.5, 0.3))

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
