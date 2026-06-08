extends Control

signal back_to_main_menu

# ── Game state ────────────────────────────────────────────────────────────────
var integrity:            int  = 100
var containment:          int  = 0
var breach:               int  = 0
var energy:               int  = 3
var max_energy:           int  = 3
var hand_size_max:        int  = 4
var breach_per_turn:      int  = 15
var clues_revealed:       int  = 0
var intel_cost_reduction: int  = 0
var _animating:              bool  = false
var _alert_panel_target_x:  float = 0.0

# ── Threat / Alert state ──────────────────────────────────────────────────────
var current_threat:      Dictionary    = {}
var threat_alerts:       Array[String] = []
var threat_clues:        Array[String] = []
var revealed_clue_count: int           = 0
var alerts_revealed:     int           = 1  # starts at 1; +1 each end turn

var deck_manager: DeckManager

# ── Card scene ────────────────────────────────────────────────────────────────
const CARD_SCENE = preload("res://Scenes/card_node.tscn")

# ── Hand layout — all derived from actual scene node sizes/positions ──────────
# Resize cards  → edit offset_right/offset_bottom on CardNode root in card_node.tscn
# Move piles    → drag DeckPile / DiscardPile / HandContainer in play_ui.tscn
# Everything below is computed in _setup_hud(); nothing is hardcoded here.
var _card_w:   float   = 72.0          # read from card_node.tscn root size
var _card_h:   float   = 108.0         # read from card_node.tscn root size
var _deck_rel: Vector2 = Vector2.ZERO  # deck pile pos relative to hand_container
var _disc_rel: Vector2 = Vector2.ZERO  # disc pile pos relative to hand_container
var _hand_w:   float   = 0.0           # hand container width

# ── Scene node references ─────────────────────────────────────────────────────
@onready var integrity_bar:       ProgressBar = $HUD/HUDRoot/TopBar/IntegrityBar
@onready var containment_bar:     ProgressBar = $HUD/HUDRoot/TopBar/ContainmentBar
@onready var breach_bar:          ProgressBar = $HUD/HUDRoot/TopBar/BreachBar

@onready var energy_label:        Label   = $HUD/HUDRoot/BottomStrip/EnergyLabel
@onready var end_turn_btn:        Button  = $HUD/HUDRoot/BottomStrip/EndTurnButton
@onready var hand_container:      Control = $HUD/HUDRoot/BottomStrip/HandContainer
@onready var deck_pile:           Control = $HUD/HUDRoot/BottomStrip/DeckPile
@onready var disc_pile:           Control = $HUD/HUDRoot/BottomStrip/DiscardPile

@onready var top_bar:             Control = $HUD/HUDRoot/TopBar
@onready var bottom_strip:        Control = $HUD/HUDRoot/BottomStrip
@onready var alert_panel_control: Control = $HUD/HUDRoot/AlertPanel
@onready var threat_name_label:   Label   = $HUD/HUDRoot/AlertPanel/ThreatNameLabel
@onready var clue_count_label:    Label   = $HUD/HUDRoot/AlertPanel/ClueCountLabel

@onready var result_panel:        Control       = $HUD/HUDRoot/ResultPanel
@onready var result_label:        Label         = $HUD/HUDRoot/ResultPanel/ResultLabel
@onready var sub_label:           Label         = $HUD/HUDRoot/ResultPanel/SubLabel
@onready var return_btn:          Button        = $HUD/HUDRoot/ResultPanel/ReturnButton
@onready var shop_btn:            Button        = $HUD/HUDRoot/ResultPanel/ShopButton
@onready var next_day_btn:        Button        = $HUD/HUDRoot/ResultPanel/NextDayButton
@onready var threat_reveal_lbl:   Label         = $HUD/HUDRoot/ResultPanel/ThreatRevealLabel

@onready var settings_btn:        TextureButton = $SettingsButton
@onready var edit_deck_btn_hud:   TextureButton = $EditDeckButton
@onready var infobook_btn:        TextureButton = $InfobookButton

@onready var hud_layer:           CanvasLayer   = $HUD
@onready var story_intro                        = $StoryIntro
@onready var pause_menu:          CanvasLayer   = $PauseMenu

const TUTORIAL_SCENE := preload("res://Scenes/Tutorial.tscn")

# Clue arrays — populated in _setup_hud() by finding children by name
var alert_clue_labels:       Array[Label]     = []
var alert_clue_placeholders: Array[ColorRect] = []

# ── Embedded starter deck ─────────────────────────────────────────────────────
const STARTER_CARDS: Array[Dictionary] = [
	{ "id": "review_logs",          "name": "Review Logs",    "type": "Investigation",
	  "energy": 1, "logic": "Reveal 1 Clue",
	  "tooltip": "Examine logs for suspicious activity." },
	{ "id": "review_logs",          "name": "Review Logs",    "type": "Investigation",
	  "energy": 1, "logic": "Reveal 1 Clue",
	  "tooltip": "Examine logs for suspicious activity." },
	{ "id": "review_logs",          "name": "Review Logs",    "type": "Investigation",
	  "energy": 1, "logic": "Reveal 1 Clue",
	  "tooltip": "Examine logs for suspicious activity." },
	{ "id": "review_logs",          "name": "Review Logs",    "type": "Investigation",
	  "energy": 1, "logic": "Reveal 1 Clue",
	  "tooltip": "Examine logs for suspicious activity." },
	{ "id": "analyze_email_header", "name": "Analyze Email",  "type": "Investigation",
	  "energy": 1, "logic": "Reveal 2 Clues",
	  "tooltip": "Inspect sender and routing headers." },
	{ "id": "analyze_email_header", "name": "Analyze Email",  "type": "Investigation",
	  "energy": 1, "logic": "Reveal 2 Clues",
	  "tooltip": "Inspect sender and routing headers." },
	{ "id": "host_isolation",       "name": "Host Isolation", "type": "Response",
	  "energy": 2, "logic": "Gain 20 Containment",
	  "tooltip": "Disconnect the affected host from network." },
	{ "id": "host_isolation",       "name": "Host Isolation", "type": "Response",
	  "energy": 2, "logic": "Gain 20 Containment",
	  "tooltip": "Disconnect the affected host from network." },
	{ "id": "system_restore",       "name": "System Restore", "type": "Recovery",
	  "energy": 2, "logic": "Restore 20 Integrity",
	  "tooltip": "Roll back systems to a clean snapshot." },
	{ "id": "system_restore",       "name": "System Restore", "type": "Recovery",
	  "energy": 2, "logic": "Restore 20 Integrity",
	  "tooltip": "Roll back systems to a clean snapshot." },
	{ "id": "quarantine_file",      "name": "Quarantine File","type": "Response",
	  "energy": 1, "logic": "Gain 15 Containment",
	  "tooltip": "Prevent a suspicious file from executing." },
	{ "id": "quarantine_file",      "name": "Quarantine File","type": "Response",
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
	_load_current_threat()
	deck_manager = DeckManager.new()
	deck_manager.initialize(_build_deck())
	_setup_hud()
	_start_turn()          # draw first hand; it will be visible once HUD is revealed

	var day := GameManager.current_day
	if day <= 2:           # Days 1–3 get a story intro
		# Hide HUD and overlay buttons while the story intro plays
		hud_layer.visible             = false
		if settings_btn:      settings_btn.visible      = false
		if infobook_btn:      infobook_btn.visible      = false
		if edit_deck_btn_hud: edit_deck_btn_hud.visible = false
		story_intro.show_intro(day + 1)
		story_intro.intro_finished.connect(_on_intro_finished, CONNECT_ONE_SHOT)
	else:
		_animate_alert_panel_in()    # no intro for this day — slide panel in immediately

func _on_intro_finished() -> void:
	# Restore HUD and overlay buttons, then slide the alert panel in
	hud_layer.visible = true
	if settings_btn:      settings_btn.visible      = true
	if infobook_btn:      infobook_btn.visible      = true
	if edit_deck_btn_hud: edit_deck_btn_hud.visible = true
	_animate_alert_panel_in()

	if GameManager.current_day == 0:   # Day 1 only gets the tutorial
		_start_tutorial()

# ── Tutorial ──────────────────────────────────────────────────────────────────

func _start_tutorial() -> void:
	var tut := TUTORIAL_SCENE.instantiate() as Tutorial
	add_child(tut)
	tut.tutorial_finished.connect(func(): tut.queue_free())

	# Build steps using screen-space rects from each node.
	# Alert panel: animation is in-flight so position.x is still 640 — use the stored target X.
	var _ap_rect := alert_panel_control.get_global_rect()
	_ap_rect.position.x = _alert_panel_target_x

	var steps: Array[Dictionary] = [
		{
			"header": "THREAT ALERT PANEL",
			"body":   "Incoming SIEM alerts about the active threat. Investigate cards reveal clues.",
			"rect":   _ap_rect,
		},
		{
			"header": "INTEGRITY",
			"body":   "Your system health. Hits 0 = game over. Recovery cards restore it.",
			"rect":   integrity_bar.get_global_rect(),
		},
		{
			"header": "CONTAINMENT",
			"body":   "Fill this to 100% to neutralise the threat. Response cards are your main tool.",
			"rect":   containment_bar.get_global_rect(),
		},
		{
			"header": "BREACH METER",
			"body":   "Rises every End Turn. If it maxes out, Integrity takes damage. Hardening cards slow it.",
			"rect":   breach_bar.get_global_rect(),
		},
		{
			"header": "YOUR HAND",
			"body":   "Click a card to play it. Investigation reveals clues. Response contains threats.",
			"rect":   hand_container.get_global_rect(),
		},
		{
			"header": "ENERGY",
			"body":   "You start each turn with 3 energy. Cards cost 1–4. Grey cards are unaffordable this turn.",
			"rect":   energy_label.get_global_rect(),
		},
		{
			"header": "DECK PILE",
			"body":   "Your unplayed cards. When empty, the discard reshuffles automatically.",
			"rect":   deck_pile.get_global_rect(),
		},
		{
			"header": "DISCARD PILE",
			"body":   "Played cards land here and return to your deck next shuffle.",
			"rect":   disc_pile.get_global_rect(),
		},
		{
			"header": "END TURN",
			"body":   "Press when done. Breach rises, a new alert appears, and you draw fresh cards.",
			"rect":   end_turn_btn.get_global_rect(),
		},
		{
			"header": "INFORMATION BOOK",
			"body":   "Click to browse every card type and known threat in the intel codex. Essential for planning your deck.",
			"rect":   infobook_btn.get_global_rect() if infobook_btn else Rect2(),
		},
		{
			"header": "DECK EDITOR",
			"body":   "Click to manage your card loadout between runs. Swap cards to counter specific threat types.",
			"rect":   edit_deck_btn_hud.get_global_rect() if edit_deck_btn_hud else Rect2(),
		},
		{
			"header": "SETTINGS",
			"body":   "Audio and display options — available at any time during play.",
			"rect":   settings_btn.get_global_rect() if settings_btn else Rect2(),
		},
		{
			"header": "YOU'RE READY, ANALYST",
			"body":   "Investigate to find clues, identify the threat, then contain and recover. Good luck — this one is already inside the network.",
			"rect":   Rect2(),     # no highlight on final step
		},
	]
	tut.start(steps)

# ── Threat CSV loading ────────────────────────────────────────────────────────

func _load_current_threat() -> void:
	var day: int = 0
	var gm_day = GameManager.get("current_day") if GameManager else null
	if gm_day is int: day = gm_day

	var file := FileAccess.open("res://CSV/threats.csv", FileAccess.READ)
	if not file: return
	var headers := file.get_csv_line()
	var rows: Array[Dictionary] = []
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2: continue
		var entry: Dictionary = {}
		for i in min(headers.size(), row.size()):
			entry[headers[i].strip_edges()] = row[i].strip_edges()
		rows.append(entry)
	file.close()
	if rows.is_empty(): return

	current_threat = rows[day % rows.size()]

	var alerts_str: String = str(current_threat.get("alerts", ""))
	for seg in alerts_str.split("|"):
		var t: String = seg.strip_edges()
		if t != "": threat_alerts.append(t)

	var clues_str: String = str(current_threat.get("clues", ""))
	for seg in clues_str.split("|"):
		var t: String = seg.strip_edges()
		if t != "": threat_clues.append(t)

# ── Deck building ─────────────────────────────────────────────────────────────

const DECK_SAVE_PATH := "user://deck.cfg"

func _build_deck() -> Array[Dictionary]:
	# 1. Runtime deck (set by EditDeck.save or ShopUI purchases this session)
	var saved = GlobalVars.get("player_deck")
	if saved is Array and not (saved as Array).is_empty():
		return (saved as Array).duplicate(true)

	# 2. Disk save (persists across restarts — written by EditDeck._on_save)
	var cfg := ConfigFile.new()
	if cfg.load(DECK_SAVE_PATH) == OK:
		var disk: Variant = cfg.get_value("deck", "cards", null)
		if disk is Array and not (disk as Array).is_empty():
			return (disk as Array).duplicate(true)

	# 3. Fallback: build starter deck from ShopUI card list
	var shop = GlobalVars.get("shop_ui")
	if shop != null:
		var raw: Variant = shop.get("ALL_CARDS")
		if raw == null:
			var scr := (shop as Object).get_script() as GDScript
			if scr: raw = scr.get_script_constant_map().get("ALL_CARDS", null)
		var src: Array = raw if raw is Array else []
		if not src.is_empty():
			var id_map: Dictionary = {}
			for c in src: id_map[c.get("id", "")] = c
			var result: Array[Dictionary] = []
			for id in STARTER_IDS:
				if id_map.has(id): result.append((id_map[id] as Dictionary).duplicate())
			if not result.is_empty(): return result

	return STARTER_CARDS.duplicate(true)

# ═════════════════════════════════════════════════════════════════════════════
# HUD setup — only dynamic content; all styling lives in the .tscn
# ═════════════════════════════════════════════════════════════════════════════

func _setup_hud() -> void:
	# Populate alert panel with threat-specific text from CSV
	_populate_alert_panel()

	# Read card dimensions straight from the scene — no hardcoded constants.
	# To resize cards: change offset_right/offset_bottom on CardNode root in card_node.tscn.
	var _tmp_card := CARD_SCENE.instantiate() as Control
	_card_w = _tmp_card.size.x
	_card_h = _tmp_card.size.y
	_tmp_card.free()

	# Derive fly-animation coords from actual scene node positions.
	# DeckPile / DiscardPile / HandContainer share BottomStrip as parent,
	# so subtracting HandContainer.position gives the relative offset we need.
	_deck_rel = deck_pile.position    - hand_container.position
	_disc_rel = disc_pile.position    - hand_container.position
	_hand_w   = hand_container.size.x

	# Wire up buttons
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	return_btn.pressed.connect(_on_return_to_menu)
	shop_btn.pressed.connect(_on_shop_pressed)
	next_day_btn.pressed.connect(_on_next_day_pressed)
	if settings_btn:
		settings_btn.pressed.connect(func(): pause_menu.open_pause())
	if pause_menu:
		pause_menu.quit_pressed.connect(_on_return_to_menu)
	if infobook_btn:
		infobook_btn.pressed.connect(func(): GlobalVars.info_book.visible = true)
	if edit_deck_btn_hud:
		edit_deck_btn_hud.pressed.connect(_on_edit_deck_pressed)

	# Set initial bar values
	integrity_bar.value   = integrity
	containment_bar.value = containment
	breach_bar.value      = breach

	# Containment bar — static blue fill + dark track
	var cont_fill := StyleBoxFlat.new()
	cont_fill.bg_color = Color(0.15, 0.72, 1.0)
	cont_fill.set_corner_radius_all(3)
	containment_bar.add_theme_stylebox_override("fill", cont_fill)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.05, 0.07, 0.13)
	bar_bg.set_corner_radius_all(3)
	containment_bar.add_theme_stylebox_override("background", bar_bg)

	# Breach bar — dynamic fill set each frame in _update_hud(); only dark track here
	var breach_bg := StyleBoxFlat.new()
	breach_bg.bg_color = Color(0.05, 0.07, 0.13)
	breach_bg.set_corner_radius_all(3)
	breach_bar.add_theme_stylebox_override("background", breach_bg)

	# Park the alert panel off-screen; _animate_alert_panel_in() fires it after intro or immediately
	_alert_panel_target_x          = alert_panel_control.position.x
	alert_panel_control.position.x = 640.0
	alert_panel_control.modulate.a = 0.0

func _animate_alert_panel_in() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(alert_panel_control, "position:x", _alert_panel_target_x, 0.45) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tw.tween_property(alert_panel_control, "modulate:a", 1.0, 0.35)

func _populate_alert_panel() -> void:
	# Threat name hidden until all alerts + clues are revealed
	threat_name_label.text = "⚠ ???"

	# Clue count
	clue_count_label.text = "CLUES  0 / %d" % threat_clues.size()

	# Alert rows — store all text, visibility set by _update_alerts()
	for i in 5:
		var lbl := $HUD/HUDRoot/AlertPanel.get_node("Alert%d" % i) as Label
		if i < threat_alerts.size():
			lbl.text    = "›  " + threat_alerts[i]
			lbl.visible = false   # _update_alerts() will show them one by one
		else:
			lbl.visible = false

	# Clue rows — fill arrays using full absolute paths so no null-chain risk
	alert_clue_labels.clear()
	alert_clue_placeholders.clear()
	var panel := $HUD/HUDRoot/AlertPanel
	for i in 5:
		var ph  := panel.get_node("Clue%dPlaceholder"             % i) as ColorRect
		var lbl := panel.get_node("Clue%dPlaceholder/Clue%dLabel" % [i, i]) as Label
		if ph == null or lbl == null:
			push_error("Clue node %d not found — check AlertPanel scene structure" % i)
			continue
		alert_clue_placeholders.append(ph)
		alert_clue_labels.append(lbl)
		# The scene sets font_size = 12 inside a 9 px tall container — text clips and
		# is invisible.  Override to 8 px (m3x6 at 8 fits in 9 px) and turn off
		# autowrap so long descriptions clip horizontally instead of wrapping.
		lbl.add_theme_font_size_override("font_size", 8)
		lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		if i < threat_clues.size():
			lbl.text = "›  " + threat_clues[i]
		else:
			ph.visible  = false
			lbl.visible = false

	# Apply initial visibility for both alerts and clues
	_update_alerts()
	_update_alert_panel()

# ═════════════════════════════════════════════════════════════════════════════
# Game loop
# ═════════════════════════════════════════════════════════════════════════════

func _start_turn() -> void:
	energy = max_energy
	deck_manager.draw_cards(hand_size_max - deck_manager.hand_count())
	_render_hand()
	_update_hud()

func _render_hand() -> void:
	for child in hand_container.get_children():
		hand_container.remove_child(child)
		child.queue_free()

	var n := deck_manager.hand.size()
	if n == 0:
		_update_hud()
		return

	const GAP   := 5.0
	var total_w : float = float(n) * _card_w + maxf(0.0, float(n - 1)) * GAP
	var start_x : float = (_hand_w - total_w) * 0.5

	for i in n:
		var cdata := deck_manager.hand[i]
		var node  := CARD_SCENE.instantiate() as CardNode
		node.position = _deck_rel
		node.modulate = Color(1.0, 1.0, 1.0, 0.0)
		node.card_played.connect(_on_card_played)
		hand_container.add_child(node)
		node.setup(cdata)
		node.set_playable(_get_effective_cost(cdata) <= energy)

		var target_pos := Vector2(start_x + float(i) * (_card_w + GAP), 0.0)
		var delay      : float = float(i) * 0.07
		var tw := create_tween().set_parallel(true)
		tw.tween_property(node, "position",   target_pos, 0.25).set_delay(delay)
		tw.tween_property(node, "modulate:a", 1.0,        0.18).set_delay(delay)

	_update_hud()

func _get_effective_cost(cdata: Dictionary) -> int:
	var cost: int = cdata.get("energy", 0)
	if cdata.get("type", "") in ["Investigation", "Monitoring"]:
		cost = max(0, cost - intel_cost_reduction)
	return cost

# ── Card played ───────────────────────────────────────────────────────────────

func _on_card_played(cdata: Dictionary) -> void:
	if _animating: return
	var cost := _get_effective_cost(cdata)
	if cost > energy:
		for child in hand_container.get_children():
			if child is CardNode and child.card_data.get("id") == cdata.get("id"):
				child.flash_red(); return
		return

	_animating = true
	energy -= cost
	_apply_card_effect(cdata)

	for child in hand_container.get_children():
		if child is CardNode and child.card_data.get("id") == cdata.get("id"):
			var tw := child.create_tween().set_parallel(true)
			tw.tween_property(child, "position",   _disc_rel, 0.20)
			tw.tween_property(child, "modulate:a", 0.0,       0.16)
			break

	await get_tree().create_timer(0.22).timeout
	deck_manager.play_card(cdata)
	_render_hand()
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
			_reveal_clues(nc)
		if "Breach" in line and line.begins_with("-"):
			breach = max(0, breach - n)
		if "breach progress" in line:
			breach_per_turn = max(3, breach_per_turn - 2)
		if "Draw 1 card" in line or "draw 1 card" in line:
			deck_manager.draw_cards(1)
		if "Gain 1 Energy" in line:
			max_energy = min(10, max_energy + 1); energy += 1
		if "Detection each turn" in line:
			containment = min(100, containment + 5)
		if "1 Clue each turn" in line:
			clues_revealed += 1; _reveal_clues(1)

	match ctype:
		"Automation":
			if "Auto-play" in logic or "Auto-respond" in logic:
				containment = min(100, containment + 10)
			if "cost 1 less" in logic:
				intel_cost_reduction = min(3, intel_cost_reduction + 1)
			if "start of turn" in logic and "Clue" in logic:
				clues_revealed += 1; _reveal_clues(1)

	_update_hud()

func _extract_int(text: String) -> int:
	var s := ""
	for ch in text:
		if ch >= "0" and ch <= "9": s += ch
		elif s != "": break
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
	# Only touch slots that actually have clue data — extras were hidden in _populate_alert_panel()
	var clue_count := mini(alert_clue_labels.size(), threat_clues.size())
	for i in clue_count:
		var revealed := i < revealed_clue_count
		# IMPORTANT: each ClueLabel is a *child* of its CluePlaceholder (ColorRect).
		# Setting placeholder.visible = false propagates to the label child and hides it,
		# even if label.visible = true.  Instead, keep the placeholder node always visible
		# and control the grey bar by zeroing its own color alpha (which does NOT cascade).
		alert_clue_placeholders[i].color.a = 0.0 if revealed else 0.85
		alert_clue_labels[i].visible        = revealed
	_check_threat_reveal()

## Show alerts up to alerts_revealed — called at start and each end turn.
func _update_alerts() -> void:
	for i in threat_alerts.size():
		var lbl := $HUD/HUDRoot/AlertPanel.get_node("Alert%d" % i) as Label
		lbl.visible = i < alerts_revealed
	_check_threat_reveal()

## Reveal the threat name only once every alert has been shown AND every clue found.
func _check_threat_reveal() -> void:
	var all_alerts := alerts_revealed >= threat_alerts.size()
	var all_clues  := threat_clues.is_empty() or revealed_clue_count >= threat_clues.size()
	if all_alerts and all_clues:
		var tname := str(current_threat.get("threat_type", "UNKNOWN THREAT")).to_upper()
		threat_name_label.text = "⚠ " + tname
	else:
		threat_name_label.text = "⚠ ???"

# ── End Turn ─────────────────────────────────────────────────────────────────

func _on_end_turn_pressed() -> void:
	if _animating: return
	_animating            = true
	end_turn_btn.disabled = true

	var hand_nodes := hand_container.get_children()
	if not hand_nodes.is_empty():
		var delay := 0.0
		for node in hand_nodes:
			if node is CardNode:
				var tw := node.create_tween().set_parallel(true)
				tw.tween_property(node, "position",   _disc_rel, 0.20).set_delay(delay)
				tw.tween_property(node, "modulate:a", 0.0,       0.16).set_delay(delay)
				delay += 0.05
		await get_tree().create_timer(delay + 0.22).timeout

	breach += breach_per_turn
	if breach >= 100:
		integrity = max(0, integrity - 30); breach = 0
	deck_manager.discard_hand()

	# Reveal one more alert each end turn (capped at total available)
	alerts_revealed = mini(alerts_revealed + 1, threat_alerts.size())
	_update_alerts()

	_update_hud()
	_check_win_loss()

	if result_panel.visible:
		_animating = false; return

	await get_tree().create_timer(0.18).timeout
	_animating            = false
	_start_turn()
	end_turn_btn.disabled = false

# ── Win / Loss ────────────────────────────────────────────────────────────────

func _check_win_loss() -> void:
	if containment >= 100: _show_result(true)
	elif integrity <= 0:   _show_result(false)

func _show_result(won: bool) -> void:
	end_turn_btn.disabled = true
	# Hide gameplay elements so the result panel's dark overlay stands alone
	top_bar.visible             = false
	alert_panel_control.visible = false
	bottom_strip.visible        = false
	result_panel.visible        = true

	var threat_name := str(current_threat.get("threat_type", "Unknown Threat"))
	var next_day    := GameManager.current_day + 1

	if won:
		result_label.text = "THREAT NEUTRALISED"
		result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		sub_label.text    = "Incident contained. System secure."
		GameManager.complete_day(GameManager.current_day)
		# Show Next Day button only when there's a next day available
		next_day_btn.visible = next_day < 6
		# Reveal what the threat actually was
		threat_reveal_lbl.visible = true
		threat_reveal_lbl.text    = "Threat identified: %s" % threat_name.to_upper()
	else:
		result_label.text = "SYSTEM COMPROMISED"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
		sub_label.text    = "Breach exceeded critical threshold."
		next_day_btn.visible      = false
		threat_reveal_lbl.visible = true
		threat_reveal_lbl.text    = "The threat was: %s" % threat_name.to_upper()

func _on_return_to_menu() -> void:
	if GlobalVars.game_controller:
		GlobalVars.game_controller.change_sub_scene(GameController.STAGE_SELECT)
	else:
		get_tree().change_scene_to_file("res://Scenes/stage_select.tscn")

func _on_shop_pressed() -> void:
	if not GlobalVars.shop_ui:
		return
	# Hide the HUD while the shop is open so there's no overlap
	hud_layer.visible = false
	GlobalVars.shop_ui.open_shop()
	# Restore the result screen (game elements stay hidden) when shop closes
	if not GlobalVars.shop_ui.shop_closed.is_connected(_on_shop_closed):
		GlobalVars.shop_ui.shop_closed.connect(_on_shop_closed, CONNECT_ONE_SHOT)

func _on_shop_closed() -> void:
	# Bring back the HUD — game elements are still hidden, only result panel shows
	hud_layer.visible           = true
	top_bar.visible             = false
	alert_panel_control.visible = false
	bottom_strip.visible        = false

func _on_next_day_pressed() -> void:
	var next_day := GameManager.current_day + 1
	if next_day < 6:
		GameManager.current_day = next_day
		if GlobalVars.game_controller:
			GlobalVars.game_controller.change_sub_scene(GameController.PLAY_UI)

func _on_edit_deck_pressed() -> void:
	_show_deck_viewer()

## Read-only deck viewer — shows all cards currently in the deck (hand + draw + discard)
## as a full-screen overlay.  No navigation away from the game.
func _show_deck_viewer() -> void:
	# All cards wherever they are in the deck cycle
	var full_deck: Array = deck_manager.deck + deck_manager.hand + deck_manager.discard

	# ── CanvasLayer so it renders above HUD ──────────────────────────────────
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)

	# Full-screen click-blocking dim
	var dim := ColorRect.new()
	dim.color       = Color(0.0, 0.02, 0.07, 0.95)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	# Root control for content
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	# Title bar
	var title := Label.new()
	title.text                  = "CURRENT DECK  —  %d CARDS" % full_deck.size()
	title.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title.position              = Vector2(0, 6)
	title.size                  = Vector2(640, 18)
	title.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	title.add_theme_font_size_override("font_size", 10)
	root.add_child(title)

	# Scroll container for the card grid
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(16, 30)
	scroll.size     = Vector2(608, 288)
	root.add_child(scroll)

	# 5-column grid — readable at 70 × 79 card size
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 22)
	scroll.add_child(grid)

	for card_data in full_deck:
		var card_node := CARD_SCENE.instantiate() as CardNode
		# Set minimum size so GridContainer sizes cells correctly
		card_node.custom_minimum_size = Vector2(_card_w, _card_h)
		grid.add_child(card_node)   # add_child before setup (triggers _ready / @onready)
		card_node.setup(card_data)
		card_node.set_playable(true)   # full colour, no grey-out
		# No card_played connection → clicking does nothing (read-only)

	# Close button
	var close_btn := Button.new()
	close_btn.text     = "✕  CLOSE"
	close_btn.position = Vector2(265, 325)
	close_btn.size     = Vector2(110, 22)
	close_btn.add_theme_font_size_override("font_size", 8)
	close_btn.pressed.connect(layer.queue_free)
	root.add_child(close_btn)

# ── HUD refresh ───────────────────────────────────────────────────────────────

func _update_hud() -> void:
	if integrity_bar:
		integrity_bar.value = integrity
		# Integrity fill interpolates red→green based on health — the only dynamic style
		var t    := float(integrity) / 100.0
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(1.0 - t * 0.8, 0.22 + t * 0.63, 0.15 + t * 0.20)
		fill.set_corner_radius_all(3)
		integrity_bar.add_theme_stylebox_override("fill", fill)

	if containment_bar:
		containment_bar.value = containment

	if breach_bar:
		breach_bar.value = breach
		# Fill interpolates yellow → orange → red as breach rises
		var bt     := float(breach) / 100.0
		var bfill  := StyleBoxFlat.new()
		bfill.bg_color = Color(1.0, 0.75 - bt * 0.55, 0.12 - bt * 0.10)
		bfill.set_corner_radius_all(3)
		breach_bar.add_theme_stylebox_override("fill", bfill)
	if energy_label:        energy_label.text        = "⚡ %d/%d" % [energy, max_energy]
	for child in hand_container.get_children():
		if child is CardNode:
			child.set_playable(_get_effective_cost(child.card_data) <= energy)
