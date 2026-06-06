extends Node

# Add this as an Autoload in Project > Project Settings > Autoload
# Name it "GameManager"

const STAGE_SCENES = [
	"res://scenes/stages/day_1.tscn",
	"res://scenes/stages/day_2.tscn",
	"res://scenes/stages/day_3.tscn",
	"res://scenes/stages/day_4.tscn",
	"res://scenes/stages/day_5.tscn",
	"res://scenes/stages/day_6.tscn",
]

var current_day: int = 0
var days_unlocked: int = 3  # How many days are unlocked at start


func _ready() -> void:
	# Connect to StageSelect once the scene is ready
	# Call this after your main_menu scene loads
	pass


func connect_stage_select(stage_select_node: Control) -> void:
	stage_select_node.stage_selected.connect(_on_stage_selected)


func _on_stage_selected(day_index: int) -> void:
	current_day = day_index
	get_tree().change_scene_to_file(STAGE_SCENES[day_index])


func complete_day(day_index: int) -> void:
	# Call this when the player finishes a stage
	days_unlocked = max(days_unlocked, day_index + 2)
	# Optionally save progress here
	_save_progress()


func _save_progress() -> void:
	var save = ConfigFile.new()
	save.set_value("progress", "days_unlocked", days_unlocked)
	save.save("user://save.cfg")


func load_progress() -> void:
	var save = ConfigFile.new()
	if save.load("user://save.cfg") == OK:
		days_unlocked = save.get_value("progress", "days_unlocked", 3)
