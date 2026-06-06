extends RichTextLabel

const BOOT_LINES = [
"Microsoft Windows [Version 10.0.19045.3448]",
"(c) Microsoft Corporation. All rights reserved.",
"",
"C:\\Users\\Admin> INITIALIZING SOC TERMINAL...",
"INITIALIZING SOC TERMINAL...",
"CHECKING MEMORY [64MB]......... OK",
"C:\\Users\\Admin> LOADING THREAT DATABASE...",
"LOADING THREAT DATABASE......... OK",
"C:\\Users\\Admin> SYSTEM INTEGRITY CHECK...",
"SYSTEM INTEGRITY CHECK......... OK",
"",
"C:\\Users\\Admin> STARTING FIREWALL SERVICES...",
"STARTING FIREWALL SERVICES......... OK",
"",
"SYSTEM BOOT SEQUENCE COMPLETE",
"",
"C:\\Users\\Admin> WELCOME USER"
]

@export var char_delay: float = 0.0001
@export var line_delay: float = 0.1
@export var end_delay: float = 1.8

@onready var typing_player: AudioStreamPlayer2D = get_parent().get_node("AudioStreamPlayer2D")

func _ready() -> void:
	text = ""
	bbcode_enabled = true
	fit_content = true
	
	# Make it look like real Command Prompt
	add_theme_color_override("default_color", Color.WHITE)
	
	get_parent().get_node("Matrixrain").visible = false
	get_parent().get_node("MainMenu").modulate.a = 0.0   # Start menu invisible
	
	_type_sequence()

func _type_sequence() -> void:
	play_startup_sound()
	
	for line in BOOT_LINES:
		for ch in line:
			text += ch
			play_typing_sound()
			await get_tree().create_timer(char_delay).timeout
		
		text += "\n"
		await get_tree().create_timer(line_delay).timeout
	
	await get_tree().create_timer(end_delay).timeout
	
	fade_out_boot_and_fade_in_menu()

func fade_out_boot_and_fade_in_menu() -> void:
	var main_menu = get_parent().get_node("MainMenu")
	
	
	# Fade in Main Menu
	var fade_in_tween = create_tween()
	fade_in_tween.tween_property(main_menu, "modulate:a", 1, 0.5) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	
	
	visible = false
	get_parent().get_node("MainMenu/VBoxContainer").visible = true

func play_startup_sound() -> void:
	if typing_player:
		typing_player.pitch_scale = 1.0
		typing_player.volume_db = -10
		typing_player.play()

func play_typing_sound() -> void:
	if typing_player:
		typing_player.pitch_scale = randf_range(0.9, 1.3)
		typing_player.volume_db = -18
		typing_player.play()
