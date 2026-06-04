## ParallaxMouseDrift.gd
## Attach this script to each node you want to drift on mouse move.
## Each node gets its own drift_strength so layers move at different depths.
##
## Typical setup:
##   BackgroundImage.gd  → drift_strength = -18  (moves opposite, slowly)
##   MatrixRain.gd       → drift_strength = -9
##   UILayer.gd          → drift_strength =  5   (moves with mouse, subtly)

extends Node

# ─── Tunables ────────────────────────────────────────────────────────────────
## How many pixels the node shifts at the screen edge.
## Negative = moves opposite to cursor (background layers).
## Positive = moves with cursor (foreground/UI layers).
@export var drift_strength: float = 5.0

## Smoothing speed — higher = snappier, lower = floatier.
@export var smoothing: float = 6.0

## Set to the Control or Node2D you want to move.
## Leave blank to move the node this script is attached to.
@export var target: Node2D = null
# ─────────────────────────────────────────────────────────────────────────────

var _origin: Vector2        # resting position (set once on ready)
var _target_offset: Vector2 # where we want to be
var _current_offset: Vector2

func _ready() -> void:
	await owner.ready  # wait for parent scene to finish
	var node = _get_target()
	if node:
		_origin = node.position
	set_process(true)


func _process(delta: float) -> void:
	var node = _get_target()
	if not node:
		return

	var vp_size = get_viewport().get_visible_rect().size
	var mouse = get_viewport().get_mouse_position()

	# Normalise mouse to -1..1 from viewport centre
	var norm = (mouse - vp_size * 0.5) / (vp_size * 0.5)
	norm = norm.clamp(Vector2(-1, -1), Vector2(1, 1))

	_target_offset = norm * drift_strength

	# Smooth interpolation
	_current_offset = _current_offset.lerp(_target_offset, smoothing * delta)

	node.position = _origin + _current_offset


func _get_target() -> Node2D:
	if target:
		return target
	if owner is Node2D:
		return owner as Node2D
	return null
