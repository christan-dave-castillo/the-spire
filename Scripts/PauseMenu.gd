extends CanvasLayer

signal quit_pressed

func _ready() -> void:
	# Must process while the tree is paused so buttons remain interactive
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

# ── Public API ────────────────────────────────────────────────────────────────

func open_pause() -> void:
	show()
	get_tree().paused = true

func close_pause() -> void:
	hide()
	get_tree().paused = false

# ── Button handlers ───────────────────────────────────────────────────────────

func _on_resume_pressed() -> void:
	close_pause()

func _on_settings_pressed() -> void:
	hide()
	var settings_ui = GlobalVars.settings_ui
	settings_ui.get_node("VBoxContainer").open_from_pause(self)
	settings_ui.visible = true

func _on_quit_pressed() -> void:
	close_pause()
	quit_pressed.emit()
