extends Node

var boot_sequence_played: bool = false
var game_controller: GameController
var settings_ui: CanvasLayer
var info_book: MarginContainer
var shop_ui: CanvasLayer
var player_deck: Array[Dictionary] = []   # populated by ShopUI purchases; used by PlayUI
