extends CanvasLayer

signal item_purchased(item: Dictionary)
signal shop_closed

@onready var shop_panel: PanelContainer = $ShopPanel
@onready var close_button: Button = $ShopPanel/MarginContainer/VBoxContainer/Header/CloseButton
@onready var cards_container: GridContainer = $ShopPanel/MarginContainer/VBoxContainer/ScrollContainer/CardsGrid
@onready var coins_label: Label = $ShopPanel/MarginContainer/VBoxContainer/Header/CoinsLabel

const CARD_TEXTURE = preload("res://UI_asset/images/Card.png")

const CARD_W = 96
const CARD_H = 144
const ICON_ZONE_H = 82
const PATCH_L = 6
const PATCH_R = 6
const PATCH_T = 8
const PATCH_B = 6

const TYPE_COLORS = {
	"Investigation": Color(0.3, 0.6, 1.0, 0.5),
	"Monitoring":    Color(0.3, 0.9, 0.6, 0.5),
	"Hardening":     Color(0.9, 0.7, 0.2, 0.5),
	"Response":      Color(1.0, 0.35, 0.35, 0.5),
	"Recovery":      Color(0.5, 0.85, 0.4, 0.5),
	"Automation":    Color(0.6, 0.4, 1.0, 0.5),
	"Rare":          Color(1.0, 0.85, 0.2, 0.7),
}

var player_coins: int = 500
var shop_items: Array[Dictionary] = []

const ALL_CARDS: Array[Dictionary] = [
	# Investigation
	{ "id": "review_logs",          "name": "Review Logs",            "type": "Investigation", "energy": 1, "logic": "Reveal 1 Clue",                       "tooltip": "Examine security logs for suspicious activity" },
	{ "id": "threat_intel_lookup",  "name": "Threat Intel Lookup",    "type": "Investigation", "energy": 1, "logic": "Reveal 1 Clue\n+5 Containment",        "tooltip": "Compare findings against known threats" },
	{ "id": "packet_capture",       "name": "Packet Capture",         "type": "Investigation", "energy": 2, "logic": "Reveal 2 Clues",                       "tooltip": "Inspect network traffic for suspicious comms" },
	{ "id": "analyze_email_header", "name": "Analyze Email Header",   "type": "Investigation", "energy": 1, "logic": "Reveal 2 Clues",                       "tooltip": "Inspect sender and routing information" },
	{ "id": "threat_hunt",          "name": "Threat Hunt",            "type": "Investigation", "energy": 2, "logic": "Reveal 3 Clues",                       "tooltip": "Proactively search for hidden threats" },
	{ "id": "forensic_analysis",    "name": "Forensic Analysis",      "type": "Investigation", "energy": 2, "logic": "Reveal 2 Clues\n+5 Containment",       "tooltip": "Detailed examination of compromised systems" },
	# Monitoring
	{ "id": "siem_platform",        "name": "SIEM Platform",          "type": "Monitoring",    "energy": 2, "logic": "Gain 1 Clue each turn",                "tooltip": "Centralize and analyze security events" },
	{ "id": "edr_monitoring",       "name": "EDR Monitoring",         "type": "Monitoring",    "energy": 2, "logic": "Gain Detection each turn",              "tooltip": "Continuously monitor endpoints" },
	{ "id": "threat_intel_feed",    "name": "Threat Intel Feed",      "type": "Monitoring",    "energy": 1, "logic": "Investigation cards\nreveal +1 Clue",   "tooltip": "Receive updated threat information" },
	{ "id": "dlp_monitoring",       "name": "DLP Monitoring",         "type": "Monitoring",    "energy": 2, "logic": "Reduce Breach from\ndata theft",        "tooltip": "Monitor sensitive data movement" },
	# Hardening
	{ "id": "mfa",                  "name": "Multi-Factor Auth",      "type": "Hardening",     "energy": 2, "logic": "Reduce future\nbreach progress",        "tooltip": "Require an additional verification step" },
	{ "id": "patch_management",     "name": "Patch Management",       "type": "Hardening",     "energy": 2, "logic": "Reduce future\nbreach progress",        "tooltip": "Apply security updates to systems" },
	{ "id": "least_privilege",      "name": "Least Privilege",        "type": "Hardening",     "energy": 2, "logic": "Reduce future\nbreach progress",        "tooltip": "Limit access to only what is necessary" },
	{ "id": "app_whitelisting",     "name": "App Whitelisting",       "type": "Hardening",     "energy": 2, "logic": "Reduce future\nbreach progress",        "tooltip": "Allow only approved applications to run" },
	{ "id": "security_training",    "name": "Security Training",      "type": "Hardening",     "energy": 2, "logic": "Reduce future\nbreach progress",        "tooltip": "Teach users to recognize suspicious activity" },
	# Response
	{ "id": "host_isolation",       "name": "Host Isolation",         "type": "Response",      "energy": 2, "logic": "Gain 20 Containment",                  "tooltip": "Disconnect an affected device from network" },
	{ "id": "disable_account",      "name": "Disable Account",        "type": "Response",      "energy": 1, "logic": "Gain 15 Containment",                  "tooltip": "Prevent use of a compromised account" },
	{ "id": "block_ip",             "name": "Block IP Address",       "type": "Response",      "energy": 1, "logic": "Gain 10 Containment",                  "tooltip": "Block a suspicious network source" },
	{ "id": "network_segmentation", "name": "Network Segmentation",   "type": "Response",      "energy": 3, "logic": "Gain 25 Containment\n-10 Breach",      "tooltip": "Separate systems into security zones" },
	{ "id": "quarantine_file",      "name": "Quarantine File",        "type": "Response",      "energy": 1, "logic": "Gain 15 Containment",                  "tooltip": "Prevent a suspicious file from executing" },
	# Recovery
	{ "id": "backup_recovery",      "name": "Backup Recovery",        "type": "Recovery",      "energy": 3, "logic": "Restore 30 Integrity",                 "tooltip": "Recover systems from backups" },
	{ "id": "system_restore",       "name": "System Restore",         "type": "Recovery",      "energy": 2, "logic": "Restore 20 Integrity",                 "tooltip": "Return systems to a previous state" },
	{ "id": "data_recovery",        "name": "Data Recovery",          "type": "Recovery",      "energy": 3, "logic": "Restore 25 Integrity",                 "tooltip": "Recover lost or deleted information" },
	{ "id": "recovery_validation",  "name": "Recovery Validation",    "type": "Recovery",      "energy": 1, "logic": "Gain 10 Integrity\nDraw 1 card",       "tooltip": "Verify that recovery actions succeeded" },
	# Automation
	{ "id": "soar_playbook",        "name": "SOAR Playbook",          "type": "Automation",    "energy": 3, "logic": "Auto-play a random\nResponse card",    "tooltip": "Automate incident response actions" },
	{ "id": "auto_lockout",         "name": "Auto Account Lockout",   "type": "Automation",    "energy": 2, "logic": "Auto-respond to\nsuspicious logins",    "tooltip": "Lock accounts after repeated failed logins" },
	{ "id": "scheduled_scan",       "name": "Scheduled Scan",         "type": "Automation",    "energy": 1, "logic": "Reveal 1 Clue\nat start of turn",      "tooltip": "Run routine security scans automatically" },
	{ "id": "threat_feed_auto",     "name": "Threat Feed Automation", "type": "Automation",    "energy": 1, "logic": "Intel cards\ncost 1 less energy",      "tooltip": "Automatically import threat intel updates" },
	# Rare
	{ "id": "zero_trust",           "name": "Zero Trust",             "type": "Rare",          "energy": 4, "logic": "Reduce all Breach\ngain by 25%",       "tooltip": "Never trust, always verify" },
	{ "id": "mdr",                  "name": "Managed Detection",      "type": "Rare",          "energy": 4, "logic": "Gain 1 Clue\n+5 Containment/turn",     "tooltip": "External experts assist detection & response" },
	{ "id": "soc_expansion",        "name": "SOC Expansion",          "type": "Rare",          "energy": 4, "logic": "Gain 1 Energy\neach turn",             "tooltip": "Expand analyst capacity and operations" },
]


func _ready() -> void:
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.08, 0.06)
	panel_style.border_color = Color(0.55, 0.38, 0.15)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(10)
	shop_panel.add_theme_stylebox_override("panel", panel_style)

	close_button.pressed.connect(close_shop)
	_update_coins_display()
	open_shop()


func open_shop(coins_earned: int = 0) -> void:
	player_coins += coins_earned
	_update_coins_display()
	_pick_shop_cards()
	_build_cards()
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


func _pick_shop_cards() -> void:
	var pool = ALL_CARDS.duplicate()
	pool.shuffle()
	shop_items.clear()
	for card in pool.slice(0, 6):
		var item: Dictionary = card.duplicate()
		var base = item["energy"] * 30
		if item["type"] == "Rare":
			base = item["energy"] * 50
		item["price"] = base
		shop_items.append(item)


func _build_cards() -> void:
	for child in cards_container.get_children():
		child.queue_free()
	for item in shop_items:
		cards_container.add_child(_create_card(item))


func _create_card(item: Dictionary) -> Control:
	var root = Control.new()
	root.custom_minimum_size = Vector2(CARD_W, CARD_H)
	root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.name = "Card_" + item["id"]

	# NinePatchRect background using Card.png
	var bg = NinePatchRect.new()
	bg.texture = CARD_TEXTURE
	bg.patch_margin_left   = PATCH_L
	bg.patch_margin_right  = PATCH_R
	bg.patch_margin_top    = PATCH_T
	bg.patch_margin_bottom = PATCH_B
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	# Colored tint overlay on icon zone to show card type
	var tint = ColorRect.new()
	tint.color = TYPE_COLORS.get(item["type"], Color(1, 1, 1, 0.1))
	tint.set_anchor_and_offset(SIDE_LEFT,   0, 8)
	tint.set_anchor_and_offset(SIDE_RIGHT,  1, -8)
	tint.set_anchor_and_offset(SIDE_TOP,    0, 8)
	tint.set_anchor_and_offset(SIDE_BOTTOM, 0, ICON_ZONE_H - 2)
	root.add_child(tint)

	# Energy cost (top of icon zone)
	var energy_lbl = Label.new()
	energy_lbl.text = "⚡%d" % item["energy"]
	energy_lbl.add_theme_font_size_override("font_size", 11)
	energy_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3))
	energy_lbl.set_anchor_and_offset(SIDE_LEFT,   0, 10)
	energy_lbl.set_anchor_and_offset(SIDE_TOP,    0, 10)
	energy_lbl.set_anchor_and_offset(SIDE_RIGHT,  1, -10)
	energy_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0, 26)
	root.add_child(energy_lbl)

	# Logic text in icon zone center
	var logic_lbl = Label.new()
	logic_lbl.text = item["logic"]
	logic_lbl.add_theme_font_size_override("font_size", 10)
	logic_lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.15))
	logic_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logic_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logic_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	logic_lbl.set_anchor_and_offset(SIDE_LEFT,   0, 10)
	logic_lbl.set_anchor_and_offset(SIDE_RIGHT,  1, -10)
	logic_lbl.set_anchor_and_offset(SIDE_TOP,    0, 26)
	logic_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0, ICON_ZONE_H - 4)
	root.add_child(logic_lbl)

	# Text zone — sits in the tan area below (your tuned offsets kept)
	var text_zone = VBoxContainer.new()
	text_zone.set_anchor_and_offset(SIDE_LEFT,   0, 6)
	text_zone.set_anchor_and_offset(SIDE_RIGHT,  1, -6)
	text_zone.set_anchor_and_offset(SIDE_TOP,    0, ICON_ZONE_H + -8)
	text_zone.set_anchor_and_offset(SIDE_BOTTOM, 1, -6)
	text_zone.add_theme_constant_override("separation", 10)
	root.add_child(text_zone)

	var name_lbl = Label.new()
	name_lbl.text = item["name"]
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", Color(0.18, 0.10, 0.04))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_zone.add_child(name_lbl)

	var type_lbl = Label.new()
	type_lbl.text = item["type"]
	type_lbl.add_theme_font_size_override("font_size", 8)
	type_lbl.add_theme_color_override("font_color", Color(0.45, 0.28, 0.10))
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_zone.add_child(type_lbl)

	var buy_btn = Button.new()
	buy_btn.text = "🪙 %d" % item["price"]
	buy_btn.name = "BuyButton"
	buy_btn.add_theme_font_size_override("font_size", 9)
	buy_btn.custom_minimum_size = Vector2(0, 18)

	var sn = StyleBoxFlat.new()
	sn.bg_color = Color(0.55, 0.38, 0.15)
	sn.set_corner_radius_all(3)
	buy_btn.add_theme_stylebox_override("normal", sn)
	var sh = sn.duplicate(); sh.bg_color = Color(0.72, 0.52, 0.22)
	buy_btn.add_theme_stylebox_override("hover", sh)
	var sp = sn.duplicate(); sp.bg_color = Color(0.42, 0.28, 0.10)
	buy_btn.add_theme_stylebox_override("pressed", sp)
	var sd = StyleBoxFlat.new(); sd.bg_color = Color(0.35, 0.35, 0.35); sd.set_corner_radius_all(3)
	buy_btn.add_theme_stylebox_override("disabled", sd)
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
		btn.disabled = player_coins < card.get_meta("item")["price"]


func _flash_card(card: Control) -> void:
	var bg: NinePatchRect = card.get_child(0)
	bg.modulate = Color(1.0, 0.3, 0.3)
	await get_tree().create_timer(0.25).timeout
	bg.modulate = Color.WHITE
