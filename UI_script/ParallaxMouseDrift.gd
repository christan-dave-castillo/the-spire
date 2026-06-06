
# ─── Tunables ────────────────────────────────────────────────────────────────
## How many pixels the node shifts at the screen edge.
## Negative = moves opposite to cursor (background layers).
## Positive = moves with cursor (foreground/UI layers).
# ParallaxMouseDrift.gd
# Attach to any node you want to react to mouse movement.
# Works with BOTH Node2D and Control (UI) nodes.

extends Node

## How many pixels the node shifts at the screen edge.
## Negative = moves opposite to cursor (background layers).
## Positive = moves with cursor (foreground/UI layers).
@export var drift_strength: float = 5.0

## Smoothing speed — higher = snappier, lower = floatier.
@export var smoothing: float = 6.0

## Set this if you want to control a different node than the one this script is on.
@export var target: Node = null

var _origin: Vector2
var _target_offset: Vector2
var _current_offset: Vector2

func _ready() -> void:
	await owner.ready
	
	var node = _get_target()
	if node:
		_origin = _get_position(node)
		set_process(true)


func _process(delta: float) -> void:
	var node = _get_target()
	if not node:
		return
	
	var vp_size = get_viewport().get_visible_rect().size
	var mouse = get_viewport().get_mouse_position()
	
	# Normalize mouse position to -1..1 range from center
	var norm = (mouse - vp_size * 0.5) / (vp_size * 0.5)
	norm = norm.clamp(Vector2(-1, -1), Vector2(1, 1))
	
	_target_offset = norm * drift_strength
	
	# Smooth movement
	_current_offset = _current_offset.lerp(_target_offset, smoothing * delta)
	
	_set_position(node, _origin + _current_offset)


# ────────────────────────────────────────────────
# Helper functions to support both Node2D and Control
# ────────────────────────────────────────────────

func _get_target() -> Node:
	if target:
		return target
	return owner


func _get_position(node: Node) -> Vector2:
	if node is Node2D:
		return node.position
	elif node is Control:
		return node.position
	return Vector2.ZERO


func _set_position(node: Node, new_pos: Vector2) -> void:
	if node is Node2D:
		node.position = new_pos
	elif node is Control:
		node.position = new_pos
