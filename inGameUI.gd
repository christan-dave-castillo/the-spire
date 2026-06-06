extends Control

# References to all major screens
@onready var main_menu = $MainMenu
@onready var stage_select = $StageSelect
@onready var story_intro = $StoryIntro
@onready var play_ui = $PlayUi

func _ready():
	_hide_all_screens()
	
	if main_menu:
		main_menu.visible = true
	else:
		push_warning("MainMenu node not found under inGameUI!")
	
	# Connect signal safely
	if story_intro and story_intro.has_signal("intro_finished"):
		story_intro.intro_finished.connect(_on_intro_finished)
	else:
		push_warning("StoryIntro or intro_finished signal not found!")

# ====================== CORE FUNCTIONS ======================

func _hide_all_screens():
	if main_menu: main_menu.visible = false
	if stage_select: stage_select.visible = false
	if story_intro: story_intro.visible = false
	if play_ui: play_ui.visible = false

func go_to_stage_select():
	_hide_all_screens()
	if stage_select:
		stage_select.visible = true
	else:
		push_error("StageSelect node not found!")

func start_selected_stage():
	_hide_all_screens()
	
	if play_ui:
		play_ui.visible = true
	else:
		push_error("PlayUI node not found!")
	
	if story_intro:
		story_intro.show_intro(1)
	else:
		push_error("StoryIntro node not found!")

func _on_intro_finished():
	if story_intro:
		story_intro.visible = false
	
	if play_ui:
		play_ui.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(play_ui, "modulate:a", 1.0, 0.6)

# ====================== HELPER FUNCTIONS ======================

func go_to_main_menu():
	_hide_all_screens()
	if main_menu:
		main_menu.visible = true

func go_back_to_stage_select():
	_hide_all_screens()
	if stage_select:
		stage_select.visible = true



func _on_play_pressed() -> void:
	go_to_stage_select()



func _on_center_card_pressed() -> void:
	start_selected_stage()


func _on_prev_button_pressed() -> void:
	go_to_main_menu()
