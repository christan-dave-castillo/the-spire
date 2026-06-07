class_name GameController extends Node

const MAIN_MENU = preload("uid://1tvesdjtd4om")
const SETTINGS_UI = preload("uid://d2d2acmbg6wb0")
const STAGE_SELECT = preload("uid://b4dos0mcf16p7")


@onready var scene_holder = $CurrentSceneHolder

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalVars.game_controller = self
	GlobalVars.settings_ui = $SettingsUi
	GlobalVars.info_book = $InformationBook
	change_sub_scene(MAIN_MENU)

func change_sub_scene(new_scene_blueprint: PackedScene) -> void:
	for child in scene_holder.get_children():
		child.queue_free()
	
	var new_scene_instance = new_scene_blueprint.instantiate()
	scene_holder.add_child(new_scene_instance)
	
	if new_scene_instance.has_signal("open_stage_select"):
		new_scene_instance.open_stage_select.connect(func(): change_sub_scene(STAGE_SELECT))

	if new_scene_instance.has_signal("back_to_main_menu"):
		new_scene_instance.back_to_main_menu.connect(func(): change_sub_scene(MAIN_MENU))
	
	if new_scene_instance.has_signal("open_settings"):
		new_scene_instance.open_settings.connect(func(): change_sub_scene(SETTINGS_UI))
