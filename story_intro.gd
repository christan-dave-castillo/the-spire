extends Node2D

signal intro_finished

@onready var canvas_layer  = $CanvasLayer
@onready var speaker_label = $CanvasLayer/DialogueUI/DialogueBox/MarginContainer/VBoxContainer/SpeakerLabel
@onready var dialogue_text = $CanvasLayer/DialogueUI/DialogueBox/MarginContainer/VBoxContainer/DialogueText
@onready var next_button   = $CanvasLayer/DialogueUI/DialogueBox/MarginContainer/VBoxContainer/HBoxContainer/NextButton
@onready var day_badge     = $CanvasLayer/DialogueUI/DialogueBox/MarginContainer/VBoxContainer/HBoxContainer/DayBadge
@onready var dots_row      = $CanvasLayer/DialogueUI/DialogueBox/MarginContainer/VBoxContainer/HBoxContainer/StepDotsRow

# ── Per-day dialogue ──────────────────────────────────────────────────────────

const DAY_DIALOGUE: Dictionary = {
	1: [
		{ "speaker": "SUPERVISOR",
		  "text": "Hey — new analyst! Welcome to the SOC. I'm your supervisor. Things are already on fire, so listen fast." },
		{ "speaker": "SUPERVISOR",
		  "text": "Your job is to monitor incoming alerts, investigate threats, and contain breaches before they take our systems offline." },
		{ "speaker": "SUPERVISOR",
		  "text": "Each turn you'll play security cards — Investigation, Response, Recovery, and more. Every card costs Energy. Spend it wisely." },
		{ "speaker": "SUPERVISOR",
		  "text": "Your first threat is already active. I'll walk you through the dashboard. Pay attention — there won't be a second chance." },
	],
	2: [
		{ "speaker": "SUPERVISOR",
		  "text": "Good work yesterday. You kept the systems up. But threats don't take days off." },
		{ "speaker": "SUPERVISOR",
		  "text": "Our EDR is flagging something nasty — unknown executables, C2 callbacks, privilege escalation. This is malware, and it's already inside." },
		{ "speaker": "SUPERVISOR",
		  "text": "Unlike yesterday's credential abuse, malware moves fast. Every turn you delay, it spreads and entrenches deeper." },
		{ "speaker": "SUPERVISOR",
		  "text": "Quarantine infected hosts first. Use Application Whitelisting to cut its execution paths. Let's contain this before it owns the network." },
	],
	3: [
		{ "speaker": "SUPERVISOR",
		  "text": "Two days in and you're still standing. Today's different — ransomware. Files are already encrypting." },
		{ "speaker": "SUPERVISOR",
		  "text": "Every turn you wait, more data locks. They're also targeting our backup systems to maximise leverage." },
		{ "speaker": "SUPERVISOR",
		  "text": "Contain with Network Segmentation first — stop lateral spread. Then hit Backup Recovery before they wipe our snapshots." },
		{ "speaker": "SUPERVISOR",
		  "text": "This one is a race against the clock. Move fast. Good luck." },
	],
}

# Fallback for days without specific dialogue
const DEFAULT_DIALOGUE: Array = [
	{ "speaker": "SUPERVISOR", "text": "Another shift, another threat. You know the drill — investigate, contain, recover." },
	{ "speaker": "SUPERVISOR", "text": "Check the alert panel, manage your energy carefully, and don't let Breach max out. Good luck." },
]

# ── Runtime state ─────────────────────────────────────────────────────────────

var dialogue_lines: Array  = []
var current_step:   int    = 0
var is_typing:      bool   = false
var full_text:      String = ""
var type_tween:     Tween

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	visible = false
	if canvas_layer:
		canvas_layer.visible = false
	next_button.pressed.connect(_on_next_pressed)
	show_step(0)

# ─────────────────────────────────────────────────────────────────────────────
func show_intro(day_number: int = 1) -> void:
	dialogue_lines = DAY_DIALOGUE.get(day_number, DEFAULT_DIALOGUE)
	current_step   = 0

	day_badge.text = "DAY %d — SHIFT START" % day_number

	visible = true
	canvas_layer.visible = true
	modulate.a = 0.0

	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, 0.55)

	_rebuild_dots()
	show_step(0)

func hide_intro() -> void:
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.45)
	fade.tween_callback(func():
		visible = false
		if canvas_layer:
			canvas_layer.visible = false
		modulate.a = 1.0
		emit_signal("intro_finished")
	)

# ─────────────────────────────────────────────────────────────────────────────
func show_step(index: int) -> void:
	if dialogue_lines.is_empty():
		return
	var line: Dictionary = dialogue_lines[index]
	speaker_label.text = line.get("speaker", "")
	full_text          = line.get("text",    "")
	dialogue_text.text = ""
	is_typing          = true

	if type_tween:
		type_tween.kill()

	type_tween = create_tween()
	type_tween.tween_method(_set_text_progress, 0.0, 1.0, full_text.length() * 0.032)
	type_tween.tween_callback(func():
		is_typing          = false
		dialogue_text.text = full_text + " [pulse freq=1.0 color=#4a90d9]▮[/pulse]"
	)

	_update_dots()

func _set_text_progress(progress: float) -> void:
	var char_count := int(full_text.length() * progress)
	dialogue_text.text = full_text.substr(0, char_count)

# ─────────────────────────────────────────────────────────────────────────────
func _on_next_pressed() -> void:
	if is_typing:
		if type_tween:
			type_tween.kill()
		dialogue_text.text = full_text
		is_typing          = false
		return

	current_step += 1
	if current_step >= dialogue_lines.size():
		hide_intro()
	else:
		show_step(current_step)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_accept"):
		_on_next_pressed()

# ── Dots ──────────────────────────────────────────────────────────────────────
func _rebuild_dots() -> void:
	# Adjust dot count to match current dialogue length
	var dots := dots_row.get_children()
	var need  := dialogue_lines.size()
	# Add missing dots
	for _i in range(dots.size(), need):
		var d := Panel.new()
		dots_row.add_child(d)
	# Hide excess dots
	var all := dots_row.get_children()
	for i in all.size():
		all[i].visible = i < need

func _update_dots() -> void:
	var dots := dots_row.get_children()
	for i in dots.size():
		if not dots[i].visible:
			continue
		if i < current_step:
			dots[i].modulate = Color("#2a5a2a")
		elif i == current_step:
			dots[i].modulate = Color("#4a90d9")
		else:
			dots[i].modulate = Color("#1e3a5f")
