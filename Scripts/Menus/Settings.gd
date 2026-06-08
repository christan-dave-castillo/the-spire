extends VBoxContainer

var _pause_caller = null

@onready var back_btn: Button = $BacktoMainMenu

func _ready() -> void:
	# Stays interactive while the game tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

# Called by PauseMenu instead of show()-ing the CanvasLayer directly
func open_from_pause(caller) -> void:
	_pause_caller = caller
	back_btn.text = "Back"

func _on_backto_main_menu_pressed() -> void:
	get_parent().visible = false  # hide the SettingsUi CanvasLayer
	if _pause_caller:
		_pause_caller.show()
		_pause_caller = null
		back_btn.text = "Back to Main Menu"
