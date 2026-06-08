class_name Tutorial
extends CanvasLayer

signal tutorial_finished

@onready var overlay:     ColorRect     = $Overlay
@onready var highlight:   Panel         = $Highlight
@onready var tooltip_box: PanelContainer = $TooltipBox
@onready var step_lbl:    Label         = $TooltipBox/VBox/StepLabel
@onready var header_lbl:  Label         = $TooltipBox/VBox/HeaderLabel
@onready var body_lbl:    Label         = $TooltipBox/VBox/BodyLabel
@onready var next_btn:    Button        = $TooltipBox/VBox/Buttons/NextButton
@onready var skip_btn:    Button        = $TooltipBox/VBox/Buttons/SkipButton

var _steps:   Array[Dictionary] = []
var _current: int               = 0

const VP := Vector2(640.0, 360.0)   # fixed viewport size
const TIP_W := 175.0                 # tooltip panel width

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Style the highlight border (transparent fill, bright cyan border)
	var sb := StyleBoxFlat.new()
	sb.bg_color     = Color(0, 0, 0, 0)
	sb.border_color = Color(0.2, 0.9, 1.0, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	highlight.add_theme_stylebox_override("panel", sb)

	next_btn.pressed.connect(_on_next)
	skip_btn.pressed.connect(_finish)

func start(steps: Array[Dictionary]) -> void:
	_steps   = steps
	_current = 0
	visible  = true
	_show_step(0)

# ─────────────────────────────────────────────────────────────────────────────
func _on_next() -> void:
	_current += 1
	if _current >= _steps.size():
		_finish()
	else:
		_show_step(_current)

func _finish() -> void:
	visible = false
	tutorial_finished.emit()

# ─────────────────────────────────────────────────────────────────────────────
func _show_step(i: int) -> void:
	var step: Dictionary = _steps[i]
	step_lbl.text   = "%d / %d" % [i + 1, _steps.size()]
	header_lbl.text = step.get("header", "")
	body_lbl.text   = step.get("body",   "")

	next_btn.text = "DONE ✓" if i == _steps.size() - 1 else "NEXT ▶"

	# ── Highlight ────────────────────────────────────────────────────────────
	var rect: Rect2 = step.get("rect", Rect2())
	if rect.size.x > 4.0 and rect.size.y > 4.0:
		highlight.visible  = true
		highlight.position = rect.position - Vector2(4.0, 4.0)
		highlight.size     = rect.size     + Vector2(8.0, 8.0)
	else:
		highlight.visible = false

	# ── Tooltip position: prefer right of target, fallback left ─────────────
	await get_tree().process_frame          # wait 1 frame so size is computed
	var tp_h := tooltip_box.size.y
	var tx   := rect.end.x   + 8.0
	var ty   := rect.position.y

	if tx + TIP_W > VP.x - 2.0:            # would clip right edge
		tx = rect.position.x - TIP_W - 8.0
	if tx < 2.0:                            # fallback: centre below target
		tx = (VP.x - TIP_W) * 0.5
		ty = rect.end.y + 8.0

	ty = clamp(ty, 2.0, VP.y - tp_h - 2.0)
	tooltip_box.position = Vector2(tx, ty)
