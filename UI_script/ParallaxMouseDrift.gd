# ParallaxMouseDrift.gd
# Attached to your absolute top-most MainMenu root Control node.

extends Control

## How many pixels the node shifts at the screen edge.
@export var drift_strength: float = 5.0

## Smoothing speed — higher = snappier, lower = floatier.
@export var smoothing: float = 6.0

## Set this if you want to control a different node than the one this script is on.
@export var target: Node = null

@onready var boot_label = get_node_or_null("IntroCmdBootSequence")
@onready var menu_buttons = get_node_or_null("TitleAndButtons")

signal open_stage_select
signal open_settings

var _origin: Vector2
var _target_offset: Vector2
var _current_offset: Vector2

func _ready() -> void:
	# 1. Handle UI Layout states immediately on frame zero before child nodes load
	if GlobalVars.boot_sequence_played:
		print("🟢 ROOT MENU: Skipping boot sequence and revealing controls!")
		modulate.a = 1.0
		if menu_buttons:
			menu_buttons.visible = true
		if boot_label and boot_label.has_method("skip_boot_sequence"):
			boot_label.skip_boot_sequence()
	else:
		print("🟢 ROOT MENU: Playing fresh boot sequence...")
		if menu_buttons:
			menu_buttons.visible = false
			
	# 2. Pause one frame to map screen viewport boundaries securely
	await get_tree().process_frame
	
	var node = _get_drift_target()
	if node:
		_origin = _get_drift_node_position(node)
		set_process(true)


func _process(delta: float) -> void:
	var node = _get_drift_target()
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
	
	_apply_drift_movement(node, _origin + _current_offset)


# ────────────────────────────────────────────────
# Unique Helper Functions to Support Both Node2D and Control (No Name Clashes!)
# ────────────────────────────────────────────────

func _get_drift_target() -> Node:
	if target:
		return target
	# Fallback to self so it moves the MainMenu node, NOT the master invisible stage holder container!
	return self


func _get_drift_node_position(node: Node) -> Vector2:
	if node is Node2D or node is Control:
		return node.position
	return Vector2.ZERO


func _apply_drift_movement(node: Node, new_pos: Vector2) -> void:
	if node is Node2D or node is Control:
		node.position = new_pos
