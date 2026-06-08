class_name GameController extends Node

const MAIN_MENU    = preload("uid://1tvesdjtd4om")
const SETTINGS_UI  = preload("uid://d2d2acmbg6wb0")
const STAGE_SELECT = preload("uid://b4dos0mcf16p7")
const EDIT_DECK    = preload("res://Scenes/EditDeck.tscn")
const PLAY_UI      = preload("res://Scenes/play_ui.tscn")

## Set to true by PlayUI before opening EditDeck mid-game so the back button
## returns to PLAY_UI instead of STAGE_SELECT.
var return_to_play_ui: bool = false

@onready var scene_holder = $CurrentSceneHolder

func _ready() -> void:
	GlobalVars.game_controller = self
	GlobalVars.settings_ui     = $SettingsUi
	GlobalVars.shop_ui         = $ShopUI

	# InformationBook is a MarginContainer (main canvas, layer 0) which renders
	# behind any CanvasLayer.  Reparent it into a dedicated CanvasLayer at
	# layer 10 so it draws above the HUD (layer 1).
	var info := $InformationBook
	var book_layer       := CanvasLayer.new()
	book_layer.name      = "InfoBookLayer"
	book_layer.layer     = 10
	add_child(book_layer)
	info.reparent(book_layer)
	GlobalVars.info_book = info

	change_sub_scene(MAIN_MENU)
	GlobalVars.shop_ui.hide()

func change_sub_scene(new_scene_blueprint: PackedScene) -> void:
	for child in scene_holder.get_children():
		child.queue_free()

	var new_scene_instance = new_scene_blueprint.instantiate()
	scene_holder.add_child(new_scene_instance)

	if new_scene_instance.has_signal("open_stage_select"):
		# Capture the flag now; reset before the lambda so re-entries are clean.
		var _to_play := return_to_play_ui
		return_to_play_ui = false
		new_scene_instance.open_stage_select.connect(func():
			change_sub_scene(PLAY_UI if _to_play else STAGE_SELECT)
		)

	if new_scene_instance.has_signal("back_to_main_menu"):
		new_scene_instance.back_to_main_menu.connect(func(): change_sub_scene(MAIN_MENU))

	if new_scene_instance.has_signal("open_settings"):
		new_scene_instance.open_settings.connect(func(): change_sub_scene(SETTINGS_UI))

	if new_scene_instance.has_signal("open_edit_deck"):
		new_scene_instance.open_edit_deck.connect(func(): change_sub_scene(EDIT_DECK))

	# StageSelect center-card → start the selected day's gameplay
	if new_scene_instance.has_signal("stage_selected"):
		new_scene_instance.stage_selected.connect(func(day_index: int):
			GameManager.current_day = day_index
			change_sub_scene(PLAY_UI)
		)
