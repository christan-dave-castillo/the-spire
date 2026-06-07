extends VBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _on_backto_main_menu_pressed() -> void:
	get_parent().visible = false  # hides the SettingsUi CanvasLayer
