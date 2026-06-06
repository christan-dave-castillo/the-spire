extends Node2D

signal intro_finished

# References
@onready var canvas_layer = $CanvasLayer
@onready var speaker_label = $CanvasLayer/DialogueUI/DialogueBox/MarginContainer/VBoxContainer/SpeakerLabel
@onready var dialogue_text = $CanvasLayer/DialogueUI/DialogueBox/MarginContainer/VBoxContainer/DialogueText
@onready var next_button = $CanvasLayer/DialogueUI/DialogueBox/MarginContainer/VBoxContainer/HBoxContainer/NextButton
@onready var day_badge = $CanvasLayer/DialogueUI/DialogueBox/MarginContainer/VBoxContainer/HBoxContainer/DayBadge
@onready var dots_row = $CanvasLayer/DialogueUI/DialogueBox/MarginContainer/VBoxContainer/HBoxContainer/StepDotsRow

var dialogue_lines = [
	{
		"speaker": "SUPERVISOR",
		"text": "Hey, new guy! You are our new Security Operations Center Analyst. Welcome to the team."
	},
	{
		"speaker": "SUPERVISOR",
		"text": "Your job is to monitor threats, investigate alerts, and contain breaches before they take down our systems."
	},
	{
		"speaker": "SUPERVISOR",
		"text": "You'll use security cards each turn — investigation, containment, hardening, and more."
	},
	{
		"speaker": "SUPERVISOR",
		"text": "Your first threat is already active. Check the Threat Codex before you play cards. Good luck."
	}
]

var current_step: int = 0
var is_typing: bool = false
var full_text: String = ""
var type_tween: Tween

func _ready():
	# Start hidden
	visible = false
	if canvas_layer:
		canvas_layer.visible = false
	
	day_badge.text = "DAY 1 — SHIFT START"
	next_button.pressed.connect(_on_next_pressed)
	
	# Pre-load first step but don't show yet
	show_step(0)

# ====================== NEW HELPER FUNCTIONS ======================

func show_intro(day_number: int = 1):
	current_step = 0
	day_badge.text = "DAY %d — SHIFT START" % day_number
	
	visible = true
	canvas_layer.visible = true
	modulate.a = 0.0
	
	var fade = create_tween()
	fade.tween_property(self, "modulate:a", 1.0, 0.6)
	
	show_step(0)

func hide_intro():
	var fade = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.5)
	fade.tween_callback(func():
		visible = false
		if canvas_layer:
			canvas_layer.visible = false
		modulate.a = 1.0
		emit_signal("intro_finished")
	)

# ====================== ORIGINAL FUNCTIONS ======================

func show_step(index: int):
	var line = dialogue_lines[index]
	speaker_label.text = line["speaker"]
	full_text = line["text"]
	dialogue_text.text = ""
	is_typing = true
	
	if type_tween:
		type_tween.kill()
	
	type_tween = create_tween()
	type_tween.tween_method(_set_text_progress, 0.0, 1.0, full_text.length() * 0.035)
	type_tween.tween_callback(func():
		is_typing = false
		dialogue_text.text = full_text + " [pulse freq=1.0 color=#4a90d9]▮[/pulse]"
	)
	
	_update_dots()

func _set_text_progress(progress: float):
	var char_count = int(full_text.length() * progress)
	dialogue_text.text = full_text.substr(0, char_count)

func _on_next_pressed():
	if is_typing:
		if type_tween:
			type_tween.kill()
		dialogue_text.text = full_text
		is_typing = false
		return
	
	current_step += 1
	if current_step >= dialogue_lines.size():
		hide_intro()           # Changed to use new function
	else:
		show_step(current_step)

func _input(event):
	if event.is_action_pressed("ui_accept"):
		_on_next_pressed()

func _update_dots():
	var dots = dots_row.get_children()
	for i in dots.size():
		if i < current_step:
			dots[i].modulate = Color("#2a5a2a")
		elif i == current_step:
			dots[i].modulate = Color("#4a90d9")
		else:
			dots[i].modulate = Color("#1e3a5f")
