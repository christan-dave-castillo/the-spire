extends CanvasLayer
 
## ShopUI.gd
## Instance ShopUI into any scene and call open_shop() when the game ends.
## Example: get_node("ShopUI").open_shop()
 
signal item_purchased(item: Dictionary)
signal shop_closed
 
@onready var shop_panel: PanelContainer = $ShopPanel
@onready var close_button: Button = $ShopPanel/MarginContainer/VBoxContainer/Header/CloseButton
@onready var cards_container: GridContainer = $ShopPanel/MarginContainer/VBoxContainer/ScrollContainer/CardsGrid
@onready var coins_label: Label = $ShopPanel/MarginContainer/VBoxContainer/Header/CoinsLabel
 
const CARD_TEXTURE = preload("res://UI_asset/images/Card.png")
 
const CARD_W = 128
const CARD_H = 192
const ICON_ZONE_H = 108
const PATCH_L = 6
const PATCH_R = 6
const PATCH_T = 8
const PATCH_B = 6
 
var player_coins: int = 500
 
var shop_items: Array[Dictionary] = [
	{ "id": "speed_boost",   "name": "Speed Boost",   "description": "Move 20%\nfaster.",         "price": 80,  "icon": "" },
	{ "id": "shield",        "name": "Shield",         "description": "Block one\nhit of damage.", "price": 120, "icon": "" },
	{ "id": "coin_magnet",   "name": "Coin Magnet",    "description": "Attract nearby\ncoins.",    "price": 60,  "icon": "" },
	{ "id": "double_jump",   "name": "Double Jump",    "description": "Jump again\nairborne.",     "price": 150, "icon": "" },
	{ "id": "health_potion", "name": "Health Potion",  "description": "Restore\n50 HP.",           "price": 40,  "icon": "" },
	{ "id": "mystery_box",   "name": "Mystery Box",    "description": "Random\npowerful item!",   "price": 200, "icon": "" },
]
 
 
func _ready() -> void:
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.08, 0.06)
	panel_style.border_color = Color(0.55, 0.38, 0.15)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(10)
	shop_panel.add_theme_stylebox_override("panel", panel_style)
 
	shop_panel.set_anchor_and_offset(SIDE_LEFT,   0.5, -360)
	shop_panel.set_anchor_and_offset(SIDE_RIGHT,  0.5,  360)
	shop_panel.set_anchor_and_offset(SIDE_TOP,    0.5, -280)
	shop_panel.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  280)
 
	close_button.pressed.connect(close_shop)
	_build_cards()
	_update_coins_display()
	open_shop()
 
 
## Call this when the round ends to show the shop.
## Pass in the coins the player earned this round.
func open_shop(coins_earned: int = 0) -> void:
	player_coins += coins_earned
	_update_coins_display()
	_refresh_card_states()
	shop_panel.show()
 
 
func close_shop() -> void:
	shop_panel.hide()
	emit_signal("shop_closed")
 
 
func set_coins(amount: int) -> void:
	player_coins = amount
	_update_coins_display()
 
 
func _update_coins_display() -> void:
	coins_label.text = "🪙 %d" % player_coins
 
 
func _build_cards() -> void:
	for child in cards_container.get_children():
		child.queue_free()
	for item in shop_items:
		cards_container.add_child(_create_card(item))
 
 
func _create_card(item: Dictionary) -> Control:
	var root = Control.new()
	root.custom_minimum_size = Vector2(CARD_W, CARD_H)
	root.name = "Card_" + item["id"]
 
	var bg = NinePatchRect.new()
	bg.texture = CARD_TEXTURE
	bg.patch_margin_left   = PATCH_L
	bg.patch_margin_right  = PATCH_R
	bg.patch_margin_top    = PATCH_T
	bg.patch_margin_bottom = PATCH_B
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
 
	var icon_zone = Control.new()
	icon_zone.set_anchor_and_offset(SIDE_LEFT,   0, 10)
	icon_zone.set_anchor_and_offset(SIDE_RIGHT,  1, -10)
	icon_zone.set_anchor_and_offset(SIDE_TOP,    0, 10)
	icon_zone.set_anchor_and_offset(SIDE_BOTTOM, 0, ICON_ZONE_H - 4)
	root.add_child(icon_zone)
 
	if item["icon"] != "":
		var icon_rect = TextureRect.new()
		icon_rect.texture = load(item["icon"])
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_zone.add_child(icon_rect)
	else:
		var placeholder = Label.new()
		placeholder.text = "?"
		placeholder.add_theme_font_size_override("font_size", 40)
		placeholder.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_zone.add_child(placeholder)
 
	var text_zone = VBoxContainer.new()
	text_zone.set_anchor_and_offset(SIDE_LEFT,   0, 8)
	text_zone.set_anchor_and_offset(SIDE_RIGHT,  1, -8)
	text_zone.set_anchor_and_offset(SIDE_TOP,    0, ICON_ZONE_H + 2)
	text_zone.set_anchor_and_offset(SIDE_BOTTOM, 1, -8)
	text_zone.add_theme_constant_override("separation", 3)
	root.add_child(text_zone)
 
	var name_label = Label.new()
	name_label.text = item["name"]
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.18, 0.10, 0.04))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_zone.add_child(name_label)
 
	var desc_label = Label.new()
	desc_label.text = item["description"]
	desc_label.add_theme_font_size_override("font_size", 9)
	desc_label.add_theme_color_override("font_color", Color(0.35, 0.22, 0.10))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_zone.add_child(desc_label)
 
	var buy_btn = Button.new()
	buy_btn.text = "🪙 %d" % item["price"]
	buy_btn.name = "BuyButton"
	buy_btn.add_theme_font_size_override("font_size", 10)
	buy_btn.custom_minimum_size = Vector2(0, 22)
 
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.55, 0.38, 0.15)
	btn_normal.set_corner_radius_all(4)
	buy_btn.add_theme_stylebox_override("normal", btn_normal)
 
	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.72, 0.52, 0.22)
	buy_btn.add_theme_stylebox_override("hover", btn_hover)
 
	var btn_pressed = btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.42, 0.28, 0.10)
	buy_btn.add_theme_stylebox_override("pressed", btn_pressed)
 
	var btn_disabled = StyleBoxFlat.new()
	btn_disabled.bg_color = Color(0.35, 0.35, 0.35)
	btn_disabled.set_corner_radius_all(4)
	buy_btn.add_theme_stylebox_override("disabled", btn_disabled)
 
	buy_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	buy_btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6))
	buy_btn.pressed.connect(_on_buy_pressed.bind(item, root, buy_btn))
	text_zone.add_child(buy_btn)
 
	root.set_meta("item", item)
	root.set_meta("buy_button", buy_btn)
	return root
 
 
func _on_buy_pressed(item: Dictionary, card: Control, btn: Button) -> void:
	if player_coins < item["price"]:
		_flash_card(card)
		return
	player_coins -= item["price"]
	_update_coins_display()
	btn.text = "✓ Owned"
	btn.disabled = true
	emit_signal("item_purchased", item)
	_refresh_card_states()
 
 
func _refresh_card_states() -> void:
	for card in cards_container.get_children():
		if not card.has_meta("buy_button"):
			continue
		var btn: Button = card.get_meta("buy_button")
		if btn.disabled:
			continue
		var item = card.get_meta("item")
		btn.disabled = player_coins < item["price"]
 
 
func _flash_card(card: Control) -> void:
	var bg: NinePatchRect = card.get_child(0)
	bg.modulate = Color(1.0, 0.3, 0.3)
	await get_tree().create_timer(0.25).timeout
	bg.modulate = Color.WHITE
