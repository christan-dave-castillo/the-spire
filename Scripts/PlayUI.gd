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
var _animating:           bool = false

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

@onready var alert_panel_control: Control = $HUD/HUDRoot/AlertPanel
@onready var threat_name_label:   Label   = $HUD/HUDRoot/AlertPanel/ThreatNameLabel
@onready var clue_count_label:    Label   = $HUD/HUDRoot/AlertPanel/ClueCountLabel

@onready var result_panel:        Control = $HUD/HUDRoot/ResultPanel
@onready var result_label:        Label   = $HUD/HUDRoot/ResultPanel/ResultLabel
@onready var sub_label:           Label   = $HUD/HUDRoot/ResultPanel/SubLabel
@onready var return_btn:          Button  = $HUD/HUDRoot/ResultPanel/ReturnButton

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
	_start_turn()

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

func _build_deck() -> Array[Dictionary]:
	var saved = GlobalVars.get("player_deck")
	if saved is Array and not (saved as Array).is_empty():
		return (saved as Array).duplicate(true)
	var shop = GlobalVars.get("shop_ui")
	if shop != null:
		var _raw = shop.get("ALL_CARDS")
		var src: Array = _raw if _raw is Array else []
		if not src.is_empty():
			var id_map: Dictionary = {}
			for c in src: id_map[c["id"]] = c
			var result: Array[Dictionary] = []
			for id in STARTER_IDS:
				if id_map.has(id): result.append(id_map[id].duplicate())
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

	# Set initial bar values
	integrity_bar.value   = integrity
	containment_bar.value = containment
	breach_bar.value      = breach

	# Slide alert panel in from off-screen right
	var final_x := alert_panel_control.position.x
	alert_panel_control.position.x = 640.0
	alert_panel_control.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(alert_panel_control, "position:x", final_x, 0.45) \
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
		alert_clue_labels[i].visible       = i < revealed_clue_count   # show when revealed
		alert_clue_placeholders[i].visible = i >= revealed_clue_count  # show when unrevealed
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
	result_panel.visible  = true
	if won:
		result_label.text = "THREAT NEUTRALISED"
		result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		sub_label.text    = "Incident contained. System secure."
		GameManager.complete_day(GameManager.current_day)
	else:
		result_label.text = "SYSTEM COMPROMISED"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
		sub_label.text    = "Breach exceeded critical threshold."

func _on_return_to_menu() -> void:
	if GlobalVars.game_controller:
		GlobalVars.game_controller.change_sub_scene(GameController.STAGE_SELECT)
	else:
		get_tree().change_scene_to_file("res://Scenes/stage_select.tscn")

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

	if containment_bar:     containment_bar.value    = containment
	if breach_bar:          breach_bar.value         = breach
	if energy_label:        energy_label.text        = "⚡ %d/%d" % [energy, max_energy]
	for child in hand_container.get_children():
		if child is CardNode:
			child.set_playable(_get_effective_cost(child.card_data) <= energy)
