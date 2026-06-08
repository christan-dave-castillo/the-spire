extends Control

signal back_to_main_menu

# ── Assets ───────────────────────────────────────────────────────────────────
const FONT_BOLD        = preload("res://UI_asset/font/Silkscreen-Bold.ttf")
const FONT_BODY        = preload("res://UI_asset/font/m3x6.ttf")
const CARD_TEXTURE     = preload("res://UI_asset/card_images/Card.png")
const DISCARD_TEXTURE  = preload("res://UI_asset/card_images/discardpile.png")

# ── Game state ────────────────────────────────────────────────────────────────
var integrity:            int  = 100   # HP — 0 → lose
var containment:          int  = 0     # player bar — 100 → win
var breach:               int  = 0     # enemy bar  — 100 → integrity−30, reset
var energy:               int  = 3
var max_energy:           int  = 3
var hand_size_max:        int  = 6
var breach_per_turn:      int  = 15
var clues_revealed:       int  = 0
var intel_cost_reduction: int  = 0
var _animating:           bool = false  # blocks card clicks during animation

# ── Threat / Alert state ──────────────────────────────────────────────────────
var current_threat:      Dictionary    = {}
var threat_alerts:       Array[String] = []
var threat_clues:        Array[String] = []
var revealed_clue_count: int           = 0

var deck_manager: DeckManager
var _vp: Vector2   # cached viewport size (640 × 360)

# ── HUD node refs ─────────────────────────────────────────────────────────────
var integrity_bar:           ProgressBar
var containment_bar:         ProgressBar
var breach_bar:              ProgressBar
var energy_label:            Label
var clue_label:              Label
var hand_container:          HBoxContainer
var deck_count_label:        Label
var discard_count_label:     Label
var end_turn_btn:            Button
var result_panel:            Control
var result_label:            Label

# Alert panel refs
var clue_count_label:        Label
var alert_clue_labels:       Array[Label]     = []
var alert_clue_placeholders: Array[ColorRect] = []

# ── Embedded starter deck ─────────────────────────────────────────────────────
# Guaranteed fallback when launched directly from editor (no GameController)
const STARTER_CARDS: Array[Dictionary] = [
	{ "id": "review_logs", "name": "Review Logs", "type": "Investigation",
	  "energy": 1, "logic": "Reveal 1 Clue",
	  "tooltip": "Examine logs for suspicious activity." },
	{ "id": "review_logs", "name": "Review Logs", "type": "Investigation",
	  "energy": 1, "logic": "Reveal 1 Clue",
	  "tooltip": "Examine logs for suspicious activity." },
	{ "id": "review_logs", "name": "Review Logs", "type": "Investigation",
	  "energy": 1, "logic": "Reveal 1 Clue",
	  "tooltip": "Examine logs for suspicious activity." },
	{ "id": "review_logs", "name": "Review Logs", "type": "Investigation",
	  "energy": 1, "logic": "Reveal 1 Clue",
	  "tooltip": "Examine logs for suspicious activity." },
	{ "id": "analyze_email_header", "name": "Analyze Email", "type": "Investigation",
	  "energy": 1, "logic": "Reveal 2 Clues",
	  "tooltip": "Inspect sender and routing headers." },
	{ "id": "analyze_email_header", "name": "Analyze Email", "type": "Investigation",
	  "energy": 1, "logic": "Reveal 2 Clues",
	  "tooltip": "Inspect sender and routing headers." },
	{ "id": "host_isolation", "name": "Host Isolation", "type": "Response",
	  "energy": 2, "logic": "Gain 20 Containment",
	  "tooltip": "Disconnect the affected host from network." },
	{ "id": "host_isolation", "name": "Host Isolation", "type": "Response",
	  "energy": 2, "logic": "Gain 20 Containment",
	  "tooltip": "Disconnect the affected host from network." },
	{ "id": "system_restore", "name": "System Restore", "type": "Recovery",
	  "energy": 2, "logic": "Restore 20 Integrity",
	  "tooltip": "Roll back systems to a clean snapshot." },
	{ "id": "system_restore", "name": "System Restore", "type": "Recovery",
	  "energy": 2, "logic": "Restore 20 Integrity",
	  "tooltip": "Roll back systems to a clean snapshot." },
	{ "id": "quarantine_file", "name": "Quarantine File", "type": "Response",
	  "energy": 1, "logic": "Gain 15 Containment",
	  "tooltip": "Prevent a suspicious file from executing." },
	{ "id": "quarantine_file", "name": "Quarantine File", "type": "Response",
	  "energy": 1, "logic": "Gain 15 Containment",
	  "tooltip": "Prevent a suspicious file from executing." },
]

const STARTER_IDS: Array = [
	"review_logs", "review_logs", "review_logs", "review_logs",
	"analyze_email_header", "analyze_email_header",
	"host_isolation", "host_isolation",
	"system_restore", "system_restore",
	"quarantine_file", "quarantine_file",
]

# ═════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	_vp = get_viewport().get_visible_rect().size   # 640 × 360
	_load_current_threat()
	deck_manager = DeckManager.new()
	deck_manager.initialize(_build_deck())
	_build_hud()
	_start_turn()

# ── Threat CSV loading ────────────────────────────────────────────────────────

func _load_current_threat() -> void:
	var day: int = 0
	var gm_day = GameManager.get("current_day") if GameManager else null
	if gm_day is int:
		day = gm_day

	var file := FileAccess.open("res://CSV/threats.csv", FileAccess.READ)
	if not file:
		return
	var headers := file.get_csv_line()
	var rows: Array[Dictionary] = []
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2:
			continue
		var entry: Dictionary = {}
		for i in min(headers.size(), row.size()):
			entry[headers[i].strip_edges()] = row[i].strip_edges()
		rows.append(entry)
	file.close()

	if rows.is_empty():
		return
	current_threat = rows[day % rows.size()]

	var alerts_str: String = str(current_threat.get("alerts", ""))
	for segment in alerts_str.split("|"):
		var t: String = segment.strip_edges()
		if t != "":
			threat_alerts.append(t)
	var clues_str: String = str(current_threat.get("clues", ""))
	for segment in clues_str.split("|"):
		var t: String = segment.strip_edges()
		if t != "":
			threat_clues.append(t)

# ── Deck building ─────────────────────────────────────────────────────────────

func _build_deck() -> Array[Dictionary]:
	# 1. Cards purchased in the shop take priority
	var saved = GlobalVars.get("player_deck")
	if saved is Array and not (saved as Array).is_empty():
		return (saved as Array).duplicate(true)
	# 2. Try ShopUI's card database
	var shop = GlobalVars.get("shop_ui")
	if shop != null:
		var _raw = shop.get("ALL_CARDS")
		var src: Array = _raw if _raw is Array else []
		if not src.is_empty():
			var id_map: Dictionary = {}
			for c in src:
				id_map[c["id"]] = c
			var result: Array[Dictionary] = []
			for id in STARTER_IDS:
				if id_map.has(id):
					result.append(id_map[id].duplicate())
			if not result.is_empty():
				return result
	# 3. Always-available embedded fallback
	return STARTER_CARDS.duplicate(true)

# ═════════════════════════════════════════════════════════════════════════════
# HUD
# All positions use explicit pixels — no anchor presets on CanvasLayer children
# (anchor resolution vs CanvasLayer gives size (0,0)).
# ═════════════════════════════════════════════════════════════════════════════

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 1
	add_child(hud)

	var root := Control.new()
	root.position     = Vector2.ZERO
	root.size         = _vp
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)

	_build_top_bar(root)
	_build_alert_panel(root)
	_build_bottom_strip(root)
	_build_result_panel(root)

# ── Top bar ───────────────────────────────────────────────────────────────────
# Row 1 (y=2..24):  [INTEGRITY ──── 430 px] [BREACH ─ 198 px]
# Row 2 (y=26..48): [CONTAINMENT ── 430 px] [CLUES  ─ 198 px]

func _build_top_bar(root: Control) -> void:
	const BAR_H   := 50.0
	const LEFT_W  := 410.0
	const RIGHT_X := 418.0
	const RIGHT_W := 218.0
	const ROW_H   := 22.0
	const ROW1_Y  := 2.0
	const ROW2_Y  := 26.0

	_add_rect(root, 0, 0, _vp.x, BAR_H, Color(0.04, 0.04, 0.06, 0.82))

	integrity_bar = _make_bar_column(root, 4, ROW1_Y, LEFT_W, ROW_H,
			"INTEGRITY", Color(0.25, 0.85, 0.35))
	integrity_bar.value = integrity

	breach_bar = _make_bar_column(root, RIGHT_X, ROW1_Y, RIGHT_W, ROW_H,
			"BREACH", Color(0.95, 0.25, 0.15))
	breach_bar.value = breach

	containment_bar = _make_bar_column(root, 4, ROW2_Y, LEFT_W, ROW_H,
			"CONTAINMENT", Color(0.20, 0.65, 1.0))
	containment_bar.value = containment

	clue_label = _make_label(root, RIGHT_X, ROW2_Y, RIGHT_W, ROW_H,
			"CLUES: 0", FONT_BOLD, 8, Color(0.90, 0.90, 0.50), true)

# ── Alert panel ───────────────────────────────────────────────────────────────
# Positioned on the right half of the play area (below top bar, above hand strip).
# Shows current threat's alerts (always visible) and clues (revealed one-by-one
# as Investigation cards are played).

func _build_alert_panel(root: Control) -> void:
	const PNL_X := 416.0
	const PNL_Y := 54.0
	const PNL_W := 220.0
	const PNL_H := 180.0
	const PAD   := 4.0
	const IW    := PNL_W - PAD * 2.0   # inner width

	# Background
	_add_rect(root, PNL_X, PNL_Y, PNL_W, PNL_H, Color(0.04, 0.04, 0.08, 0.90))

	var cy := PNL_Y

	# ── Header (threat name) ──────────────────────────────────────────────
	_add_rect(root, PNL_X, cy, PNL_W, 15, Color(0.55, 0.15, 0.04, 0.95))
	var threat_name: String = str(current_threat.get("threat_type", "UNKNOWN THREAT")).to_upper()
	var hdr := _make_label(root, PNL_X + PAD, cy + 1, IW, 13,
			"⚠ " + threat_name, FONT_BOLD, 7, Color(1.0, 0.85, 0.30), false)
	hdr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cy += 16.0

	# ── ALERTS section ────────────────────────────────────────────────────
	_make_label(root, PNL_X + PAD, cy, IW, 9,
			"ALERTS", FONT_BOLD, 7, Color(0.65, 0.65, 0.65), false)
	cy += 10.0

	var shown_alerts := threat_alerts.slice(0, 5) if threat_alerts.size() > 0 \
			else ["No alerts loaded"]
	for alert_txt in shown_alerts:
		var row := Label.new()
		row.text    = "›  " + alert_txt
		row.position = Vector2(PNL_X + PAD, cy)
		row.size     = Vector2(IW, 10)
		row.add_theme_font_override("font",      FONT_BODY)
		row.add_theme_font_size_override("font_size", 7)
		row.add_theme_color_override("font_color", Color(0.95, 0.75, 0.30))
		row.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		row.clip_contents = true
		root.add_child(row)
		cy += 10.0
	cy += 2.0

	# Divider
	_add_rect(root, PNL_X + PAD, cy, IW, 1, Color(0.35, 0.35, 0.35, 0.70))
	cy += 4.0

	# ── CLUES section ─────────────────────────────────────────────────────
	clue_count_label = _make_label(root, PNL_X + PAD, cy, IW, 10,
			"CLUES  0 / %d" % threat_clues.size(), FONT_BOLD, 7,
			Color(0.60, 0.90, 1.0), false)
	cy += 11.0

	alert_clue_labels.clear()
	alert_clue_placeholders.clear()

	var num_clues := mini(threat_clues.size(), 5)
	for i in num_clues:
		# Redacted-bar placeholder (visible when clue not yet revealed)
		var ph := ColorRect.new()
		ph.color        = Color(0.20, 0.20, 0.26, 0.85)
		ph.position     = Vector2(PNL_X + PAD + 8, cy + 3)
		ph.size         = Vector2(IW - 10, 8)
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(ph)
		alert_clue_placeholders.append(ph)

		# Clue text (hidden until revealed)
		var cl := Label.new()
		cl.text    = "›  " + threat_clues[i]
		cl.visible = false
		cl.position = Vector2(PNL_X + PAD, cy)
		cl.size     = Vector2(IW, 14)
		cl.add_theme_font_override("font",      FONT_BODY)
		cl.add_theme_font_size_override("font_size", 7)
		cl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65))
		cl.autowrap_mode  = TextServer.AUTOWRAP_WORD
		cl.clip_contents  = true
		cl.mouse_filter   = Control.MOUSE_FILTER_IGNORE
		root.add_child(cl)
		alert_clue_labels.append(cl)

		cy += 14.0

# ── Bottom strip ──────────────────────────────────────────────────────────────
# Total: 120 px (y=240..360)
#   Row A (12 px) — ⚡ energy (above deck)   END TURN (above disc)
#   Row B (108 px) — [DECK] [cards] [DISC]

func _build_bottom_strip(root: Control) -> void:
	const STRIP_H  := 120.0
	const CARD_H   := 108.0
	const PILE_W   := 46.0
	const PILE_PAD := 6.0
	const ROW_A_H  := 12.0
	const BTN_W    := 60.0

	var y_top   := _vp.y - STRIP_H          # 240
	var row_a_y := y_top + 2.0              # 242
	var row_b_y := y_top + ROW_A_H + 2.0   # 254

	_add_rect(root, 0, y_top, _vp.x, STRIP_H, Color(0.04, 0.04, 0.06, 0.80))

	var deck_x := PILE_PAD                         # 6
	var disc_x := _vp.x - PILE_W - PILE_PAD       # 588

	# ── Energy label (above deck) ─────────────────────────────────────────
	energy_label = _make_label(root, deck_x, row_a_y, PILE_W + 16, ROW_A_H,
			"⚡ 3/3", FONT_BOLD, 8, Color(1.0, 0.92, 0.20), true)

	# ── END TURN button (above discard, flush-right so text isn't clipped) ─
	end_turn_btn          = Button.new()
	end_turn_btn.text     = "END TURN"
	end_turn_btn.position = Vector2(_vp.x - BTN_W - 2, row_a_y - 1)
	end_turn_btn.size     = Vector2(BTN_W, ROW_A_H + 2)
	end_turn_btn.add_theme_font_override("font",      FONT_BOLD)
	end_turn_btn.add_theme_font_size_override("font_size", 7)
	end_turn_btn.add_theme_stylebox_override("normal",
			_make_flat_style(Color(0.16, 0.44, 0.24), 2, Color(0.30, 0.75, 0.40), 1))
	end_turn_btn.add_theme_stylebox_override("hover",
			_make_flat_style(Color(0.23, 0.58, 0.32), 2))
	end_turn_btn.add_theme_stylebox_override("pressed",
			_make_flat_style(Color(0.10, 0.30, 0.16), 2))
	end_turn_btn.add_theme_stylebox_override("disabled",
			_make_flat_style(Color(0.26, 0.26, 0.26), 2))
	end_turn_btn.add_theme_color_override("font_color",          Color(0.85, 1.0,  0.85))
	end_turn_btn.add_theme_color_override("font_disabled_color", Color(0.50, 0.50, 0.50))
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	root.add_child(end_turn_btn)

	# ── Pile indicators ───────────────────────────────────────────────────
	_build_pile_indicator(root, deck_x, row_b_y, PILE_W, CARD_H, true)
	_build_pile_indicator(root, disc_x, row_b_y, PILE_W, CARD_H, false)

	# ── Hand HBox ─────────────────────────────────────────────────────────
	var hand_x := deck_x + PILE_W + 4.0
	var hand_w := disc_x - hand_x - 4.0

	hand_container          = HBoxContainer.new()
	hand_container.position = Vector2(hand_x, row_b_y)
	hand_container.size     = Vector2(hand_w, CARD_H)
	hand_container.add_theme_constant_override("separation", 5)
	hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(hand_container)

func _build_pile_indicator(root: Control, x: float, y: float,
		w: float, h: float, is_deck: bool) -> void:
	if is_deck:
		for i in 3:
			var off := float(i) * 1.5
			var card_back := TextureRect.new()
			card_back.texture      = CARD_TEXTURE
			card_back.position     = Vector2(x + off, y + 12.0 + off)
			card_back.size         = Vector2(w - off * 2, h - 26.0)
			card_back.stretch_mode = TextureRect.STRETCH_SCALE
			card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(card_back)
	else:
		var disc_img := TextureRect.new()
		disc_img.texture      = DISCARD_TEXTURE
		disc_img.position     = Vector2(x, y + 10.0)
		disc_img.size         = Vector2(w, h - 22.0)
		disc_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		disc_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(disc_img)

	var count_lbl := Label.new()
	count_lbl.text     = "0"
	count_lbl.position = Vector2(x, y)
	count_lbl.size     = Vector2(w, 11)
	count_lbl.add_theme_font_override("font",      FONT_BOLD)
	count_lbl.add_theme_font_size_override("font_size", 9)
	count_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(count_lbl)

	var title_lbl := Label.new()
	title_lbl.text     = "DECK" if is_deck else "DISC"
	title_lbl.position = Vector2(x, y + h - 11.0)
	title_lbl.size     = Vector2(w, 11)
	title_lbl.add_theme_font_override("font",      FONT_BOLD)
	title_lbl.add_theme_font_size_override("font_size", 7)
	title_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title_lbl)

	if is_deck:
		deck_count_label    = count_lbl
	else:
		discard_count_label = count_lbl

# ── Result panel ─────────────────────────────────────────────────────────────

func _build_result_panel(root: Control) -> void:
	result_panel          = Control.new()
	result_panel.position = Vector2.ZERO
	result_panel.size     = _vp
	result_panel.visible  = false
	root.add_child(result_panel)

	_add_rect(result_panel, 0, 0, _vp.x, _vp.y, Color(0, 0, 0, 0.70))

	const PANEL_W := 280.0
	const PANEL_H := 110.0
	var px := (_vp.x - PANEL_W) * 0.5
	var py := (_vp.y - PANEL_H) * 0.5

	var bg := ColorRect.new()
	bg.color    = Color(0.08, 0.06, 0.10)
	bg.position = Vector2(px, py)
	bg.size     = Vector2(PANEL_W, PANEL_H)
	result_panel.add_child(bg)

	result_label          = Label.new()
	result_label.position = Vector2(px, py + 12)
	result_label.size     = Vector2(PANEL_W, 28)
	result_label.add_theme_font_override("font",      FONT_BOLD)
	result_label.add_theme_font_size_override("font_size", 16)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_panel.add_child(result_label)

	var sub := Label.new()
	sub.name     = "SubLabel"
	sub.position = Vector2(px, py + 44)
	sub.size     = Vector2(PANEL_W, 18)
	sub.add_theme_font_override("font",      FONT_BODY)
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_panel.add_child(sub)

	const BTN_W := 160.0
	var btn := Button.new()
	btn.text     = "RETURN TO MENU"
	btn.position = Vector2(px + (PANEL_W - BTN_W) * 0.5, py + 72)
	btn.size     = Vector2(BTN_W, 22)
	btn.add_theme_font_override("font",      FONT_BOLD)
	btn.add_theme_font_size_override("font_size", 9)
	btn.add_theme_stylebox_override("normal",
			_make_flat_style(Color(0.20, 0.20, 0.32), 4, Color(0.45, 0.45, 0.65), 1))
	btn.add_theme_stylebox_override("hover",
			_make_flat_style(Color(0.30, 0.30, 0.46), 4))
	btn.add_theme_color_override("font_color", Color(0.90, 0.90, 1.00))
	btn.pressed.connect(_on_return_to_menu)
	result_panel.add_child(btn)

# ═════════════════════════════════════════════════════════════════════════════
# Game loop
# ═════════════════════════════════════════════════════════════════════════════

func _start_turn() -> void:
	energy = max_energy
	deck_manager.draw_cards(hand_size_max - deck_manager.hand_count())
	_render_hand()
	_update_hud()

func _render_hand() -> void:
	# remove_child BEFORE queue_free so HBoxContainer immediately sees 0 children;
	# otherwise the container lays out 2N nodes (old+new) on the same frame.
	for child in hand_container.get_children():
		hand_container.remove_child(child)
		child.queue_free()

	var delay := 0.0
	for cdata in deck_manager.hand:
		var node := CardNode.new()
		node.scale    = Vector2.ZERO          # start invisible for pop-in
		node.modulate = Color(1.0, 1.0, 1.0, 0.0)
		node.card_played.connect(_on_card_played)
		hand_container.add_child(node)        # _ready() fires → custom_minimum_size set
		node.setup(cdata)                     # build visuals (explicit px, no anchors)
		node.set_playable(_get_effective_cost(cdata) <= energy)

		# Staggered pop-in animation
		var tw := create_tween().set_parallel(true)
		tw.tween_property(node, "scale",      Vector2.ONE, 0.18).set_delay(delay)
		tw.tween_property(node, "modulate:a", 1.0,         0.15).set_delay(delay)
		delay += 0.06

	_update_hud()

func _get_effective_cost(cdata: Dictionary) -> int:
	var cost: int = cdata.get("energy", 0)
	if cdata.get("type", "") in ["Investigation", "Monitoring"]:
		cost = max(0, cost - intel_cost_reduction)
	return cost

# ── Card played ───────────────────────────────────────────────────────────────

func _on_card_played(cdata: Dictionary) -> void:
	if _animating:
		return
	var cost := _get_effective_cost(cdata)
	if cost > energy:
		for child in hand_container.get_children():
			if child is CardNode and child.card_data.get("id") == cdata.get("id"):
				child.flash_red()
				return
		return

	_animating = true
	energy     -= cost
	_apply_card_effect(cdata)
	deck_manager.play_card(cdata)   # removes from hand array

	# Animate the matching node out; it's still in hand_container during the wait
	for child in hand_container.get_children():
		if child is CardNode and child.card_data.get("id") == cdata.get("id"):
			var tw := child.create_tween().set_parallel(true)
			tw.tween_property(child, "scale",      Vector2.ZERO, 0.10)
			tw.tween_property(child, "modulate:a", 0.0,         0.08)
			break

	await get_tree().create_timer(0.12).timeout
	_render_hand()        # removes old children (including the animated one) + draws new
	_animating = false
	_check_win_loss()

func _apply_card_effect(cdata: Dictionary) -> void:
	var logic: String = cdata.get("logic", "")
	var ctype: String = cdata.get("type",  "")

	for line in logic.split("\n"):
		line = line.strip_edges()
		var n := _extract_int(line)

		if "Containment" in line and not line.begins_with("-"):
			containment = min(100, containment + n)
		if "Integrity" in line:
			integrity   = min(100, integrity   + n)
		if "Clue" in line and ("Reveal" in line or "Gain" in line):
			var nc: int = maxi(1, n)
			clues_revealed += nc
			_reveal_clues(nc)          # ← update alert panel
		if "Breach" in line and line.begins_with("-"):
			breach = max(0, breach - n)
		if "breach progress" in line:
			breach_per_turn = max(3, breach_per_turn - 2)
		if "Draw 1 card" in line or "draw 1 card" in line:
			deck_manager.draw_cards(1)
		if "Gain 1 Energy" in line:
			max_energy = min(10, max_energy + 1)
			energy    += 1
		if "Detection each turn" in line:
			containment = min(100, containment + 5)
		if "1 Clue each turn" in line:
			clues_revealed += 1
			_reveal_clues(1)

	match ctype:
		"Automation":
			if "Auto-play" in logic or "Auto-respond" in logic:
				containment = min(100, containment + 10)
			if "cost 1 less" in logic:
				intel_cost_reduction = min(3, intel_cost_reduction + 1)
			if "start of turn" in logic and "Clue" in logic:
				clues_revealed += 1
				_reveal_clues(1)

	_update_hud()

func _extract_int(text: String) -> int:
	var s := ""
	for ch in text:
		if ch >= "0" and ch <= "9":
			s += ch
		elif s != "":
			break
	return s.to_int() if s != "" else 0

# ── Clue reveal ───────────────────────────────────────────────────────────────

func _reveal_clues(count: int) -> void:
	for _i in count:
		if revealed_clue_count < threat_clues.size():
			revealed_clue_count += 1
	_update_alert_panel()

func _update_alert_panel() -> void:
	if clue_count_label:
		clue_count_label.text = "CLUES  %d / %d" % [revealed_clue_count, threat_clues.size()]
	for i in alert_clue_labels.size():
		var lbl := alert_clue_labels[i]
		var ph  := alert_clue_placeholders[i]
		if i < revealed_clue_count:
			lbl.visible = true
			ph.visible  = false
		else:
			lbl.visible = false
			ph.visible  = true

# ── End Turn ─────────────────────────────────────────────────────────────────

func _on_end_turn_pressed() -> void:
	if _animating:
		return
	_animating            = true
	end_turn_btn.disabled = true

	# Animate all hand cards sliding out before discarding
	var hand_nodes := hand_container.get_children()
	if not hand_nodes.is_empty():
		var delay := 0.0
		for node in hand_nodes:
			var tw := node.create_tween().set_parallel(true)
			tw.tween_property(node, "scale",      Vector2.ZERO, 0.12).set_delay(delay)
			tw.tween_property(node, "modulate:a", 0.0,         0.10).set_delay(delay)
			delay += 0.04
		await get_tree().create_timer(delay + 0.14).timeout

	breach += breach_per_turn
	if breach >= 100:
		integrity = max(0, integrity - 30)
		breach    = 0
	deck_manager.discard_hand()
	_update_hud()
	_check_win_loss()

	if result_panel.visible:
		_animating = false
		return

	await get_tree().create_timer(0.18).timeout
	_animating            = false
	_start_turn()
	end_turn_btn.disabled = false

# ── Win / Loss ────────────────────────────────────────────────────────────────

func _check_win_loss() -> void:
	if containment >= 100:
		_show_result(true)
	elif integrity <= 0:
		_show_result(false)

func _show_result(won: bool) -> void:
	end_turn_btn.disabled = true
	result_panel.visible  = true
	var sub: Label = result_panel.find_child("SubLabel", true, false)
	if won:
		result_label.text = "THREAT NEUTRALISED"
		result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		if sub: sub.text  = "Incident contained. System secure."
		GameManager.complete_day(GameManager.current_day)
	else:
		result_label.text = "SYSTEM COMPROMISED"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
		if sub: sub.text  = "Breach exceeded critical threshold."

func _on_return_to_menu() -> void:
	if GlobalVars.game_controller:
		GlobalVars.game_controller.change_sub_scene(GameController.STAGE_SELECT)
	else:
		get_tree().change_scene_to_file("res://Scenes/stage_select.tscn")

# ── HUD refresh ───────────────────────────────────────────────────────────────

func _update_hud() -> void:
	if integrity_bar:
		integrity_bar.value = integrity
		var t := float(integrity) / 100.0
		integrity_bar.add_theme_stylebox_override("fill", _make_flat_style(
				Color(1.0 - t * 0.8, 0.22 + t * 0.63, 0.15 + t * 0.20), 3))
	if containment_bar: containment_bar.value = containment
	if breach_bar:      breach_bar.value      = breach
	if energy_label:    energy_label.text     = "⚡ %d/%d" % [energy, max_energy]
	if clue_label:      clue_label.text       = "CLUES: %d" % clues_revealed
	if deck_count_label:    deck_count_label.text    = str(deck_manager.deck_count())
	if discard_count_label: discard_count_label.text = str(deck_manager.discard_count())
	for child in hand_container.get_children():
		if child is CardNode:
			child.set_playable(_get_effective_cost(child.card_data) <= energy)

# ═════════════════════════════════════════════════════════════════════════════
# Builder helpers
# ═════════════════════════════════════════════════════════════════════════════

func _add_rect(parent: Control, x: float, y: float,
		w: float, h: float, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color        = col
	r.position     = Vector2(x, y)
	r.size         = Vector2(w, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

func _make_label(parent: Control, x: float, y: float, w: float, h: float,
		txt: String, font: Font, sz: int, col: Color, centre: bool) -> Label:
	var lbl := Label.new()
	lbl.text     = txt
	lbl.position = Vector2(x, y)
	lbl.size     = Vector2(w, h)
	lbl.add_theme_font_override("font",      font)
	lbl.add_theme_font_size_override("font_size", sz)
	lbl.add_theme_color_override("font_color", col)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centre else HORIZONTAL_ALIGNMENT_LEFT
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	return lbl

# Label (title) above a ProgressBar; returns the bar.
func _make_bar_column(parent: Control, x: float, y: float, w: float, h: float,
		title: String, fill_col: Color) -> ProgressBar:
	const LBL_H := 9.0
	var lbl := Label.new()
	lbl.text     = title
	lbl.position = Vector2(x, y)
	lbl.size     = Vector2(w, LBL_H)
	lbl.add_theme_font_override("font",      FONT_BOLD)
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.add_theme_color_override("font_color", Color(0.80, 0.80, 0.80))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(lbl)

	var bar := ProgressBar.new()
	bar.min_value       = 0
	bar.max_value       = 100
	bar.value           = 0
	bar.show_percentage = false
	bar.position        = Vector2(x, y + LBL_H)
	bar.size            = Vector2(w, h - LBL_H)
	bar.add_theme_stylebox_override("background", _make_flat_style(Color(0.08, 0.08, 0.10), 3))
	bar.add_theme_stylebox_override("fill",       _make_flat_style(fill_col, 3))
	parent.add_child(bar)
	return bar

func _make_flat_style(col: Color, radius: int = 0,
		border_col: Color = Color.TRANSPARENT, border_w: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.set_border_width_all(border_w)
		s.border_color = border_col
	return s
