extends Node

## Legacy file — the active autoloader is Scripts/Autoloader/GlobalVars.gd
## Kept here to avoid broken UID references in the editor cache.
## Do not add logic here; edit Scripts/Autoloader/GlobalVars.gd instead.

var boot_sequence_played: bool = false
var game_controller: GameController = null
var settings_ui: CanvasLayer = null
var info_book: MarginContainer = null
var shop_ui: CanvasLayer = null
var player_deck: Array[Dictionary] = []
