extends VBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _on_play_pressed() -> void:
	var root_node = owner 
	root_node.open_stage_select.emit()

func _on_settings_pressed() -> void:
	GlobalVars.settings_ui.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()
