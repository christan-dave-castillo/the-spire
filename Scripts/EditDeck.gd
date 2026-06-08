class_name EditDeck
extends Control

## Emitted by the Back button — GameController routes this to STAGE_SELECT.
signal open_stage_select

const CARD_SCENE    := preload("res://Scenes/card_node.tscn")
const MAX_DECK_SIZE := 10
const SAVE_PATH     := "user://deck.cfg"

# ── State ─────────────────────────────────────────────────────────────────────
var all_cards:      Array[Dictionary] = []
var current_deck:   Array[Dictionary] = []
var _active_filter: String            = "All"

## Short button label → full card type name used in card data.
const FILTER_MAP: Dictionary = {
	"All":  "",
	"Inv":  "Investigation",
	"Mon":  "Monitoring",
	"Hard": "Hardening",
	"Resp": "Response",
	"Rec":  "Recovery",
	"Auto": "Automation",
	"Rare": "Rare",
}

## Per-filter accent colours (matches CardNode.TYPE_COLORS palette).
const FILTER_COLORS: Dictionary = {
	"All":  Color(0.70, 0.72, 0.80),
	"Inv":  Color(0.3,  0.6,  1.0),
	"Mon":  Color(0.3,  0.9,  0.6),
	"Hard": Color(0.9,  0.7,  0.2),
	"Resp": Color(1.0,  0.35, 0.35),
	"Rec":  Color(0.5,  0.85, 0.4),
	"Auto": Color(0.6,  0.4,  1.0),
	"Rare": Color(1.0,  0.85, 0.2),
}

# ── Scene node refs ───────────────────────────────────────────────────────────
@onready var back_btn:        Button        = %BackButton
@onready var deck_name_edit:  LineEdit      = %DeckNameEdit
@onready var search_bar:      LineEdit      = %SearchBar
@onready var library_grid:    GridContainer = %LibraryGrid
@onready var deck_list:       VBoxContainer = %DeckList
@onready var deck_count_lbl:  Label         = %DeckCountLabel
@onready var save_btn:        Button        = %SaveButton
@onready var clear_btn:       Button        = %ClearButton
@onready var preview_panel:   Control       = %PreviewPanel
@onready var preview_name:    Label         = %PreviewName
@onready var preview_type:    Label         = %PreviewType
@onready var preview_energy:  Label         = %PreviewEnergy
@onready var preview_tooltip: Label         = %PreviewTooltip

var _filter_btns: Array[Button] = []

# ═════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	_load_all_cards()
	_restore_deck()
	_collect_filter_buttons()
	_wire_signals()
	preview_panel.visible = false
	_refresh_library()
	_refresh_deck_list()

func _wire_signals() -> void:
	back_btn.pressed.connect(func(): open_stage_select.emit())
	save_btn.pressed.connect(_on_save)
	clear_btn.pressed.connect(_on_clear)
	search_bar.text_changed.connect(func(_t: String): _refresh_library())

func _collect_filter_buttons() -> void:
	for child in (%FilterRow as HBoxContainer).get_children():
		if child is Button:
			var btn    := child as Button
			var col    := FILTER_COLORS.get(btn.text, Color.WHITE) as Color
			_filter_btns.append(btn)

			# Normal StyleBox: very dark tinted background
			var sb_normal := StyleBoxFlat.new()
			sb_normal.bg_color = col.darkened(0.72)
			sb_normal.set_corner_radius_all(2)
			sb_normal.set_content_margin_all(2)
			btn.add_theme_stylebox_override("normal", sb_normal)

			# Hover StyleBox: slightly lighter
			var sb_hover := StyleBoxFlat.new()
			sb_hover.bg_color = col.darkened(0.50)
			sb_hover.set_corner_radius_all(2)
			sb_hover.set_content_margin_all(2)
			btn.add_theme_stylebox_override("hover", sb_hover)

			# Pressed / active StyleBox: accent colour with border
			var sb_pressed := StyleBoxFlat.new()
			sb_pressed.bg_color    = col.darkened(0.30)
			sb_pressed.border_color = col
			sb_pressed.set_border_width_all(1)
			sb_pressed.set_corner_radius_all(2)
			sb_pressed.set_content_margin_all(2)
			btn.add_theme_stylebox_override("pressed",         sb_pressed)
			btn.add_theme_stylebox_override("hover_pressed",   sb_pressed)

			# Font colours
			btn.add_theme_color_override("font_color",          col.darkened(0.10))
			btn.add_theme_color_override("font_hover_color",    col)
			btn.add_theme_color_override("font_pressed_color",  Color.WHITE)
			btn.add_theme_color_override("font_focus_color",    col)

			btn.pressed.connect(_on_filter.bind(btn.text))

	_highlight_filter("All")

# ── Data loading ──────────────────────────────────────────────────────────────

func _load_all_cards() -> void:
	# ── Path 1: ShopUI runtime (preferred — correct field names) ──────────────
	var shop = GlobalVars.shop_ui
	if shop:
		# Try Object.get() first (works for vars and sometimes consts)
		var raw: Variant = shop.get("ALL_CARDS")
		# Fallback: read constants directly from the GDScript
		if raw == null or not (raw is Array):
			var scr := shop.get_script() as GDScript
			if scr:
				raw = scr.get_script_constant_map().get("ALL_CARDS", null)
		if raw is Array:
			for c in (raw as Array):
				if c is Dictionary:
					all_cards.append((c as Dictionary).duplicate())
			if not all_cards.is_empty():
				return

	# ── Path 2: CSV fallback ──────────────────────────────────────────────────
	var file := FileAccess.open("res://CSV/cards.csv", FileAccess.READ)
	if not file:
		return
	var headers := file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2:
			continue
		var entry: Dictionary = {}
		for i in mini(headers.size(), row.size()):
			entry[headers[i].strip_edges()] = row[i].strip_edges()
		# Remap CSV header names → names the rest of the code expects
		if not entry.has("type") and entry.has("card_type"):
			entry["type"] = entry["card_type"]
		if not entry.has("energy") and entry.has("energy_cost"):
			entry["energy"] = int(str(entry["energy_cost"]).to_int())
		if not entry.has("id"):
			entry["id"] = str(entry.get("name", "")).to_lower().replace(" ", "_")
		if str(entry.get("name", "")) != "":
			all_cards.append(entry)
	file.close()

func _restore_deck() -> void:
	# Load deck from GlobalVars (set by ShopUI purchases or a previous EditDeck save)
	if not GlobalVars.player_deck.is_empty():
		for card in GlobalVars.player_deck:
			current_deck.append(card.duplicate())
	else:
		# Try disk — deck saved in a previous session
		var cfg := ConfigFile.new()
		if cfg.load(SAVE_PATH) == OK:
			var saved = cfg.get_value("deck", "cards", [])
			if saved is Array:
				for c in (saved as Array):
					if c is Dictionary:
						current_deck.append((c as Dictionary).duplicate())
	# Restore deck name
	deck_name_edit.text = "My Deck"
	var cfg2 := ConfigFile.new()
	if cfg2.load(SAVE_PATH) == OK:
		deck_name_edit.text = str(cfg2.get_value("deck", "name", "My Deck"))

# ── Library display ───────────────────────────────────────────────────────────

func _refresh_library() -> void:
	for c in library_grid.get_children():
		c.queue_free()

	var query       := search_bar.text.strip_edges().to_lower()
	var type_filter := FILTER_MAP.get(_active_filter, "") as String

	for card in all_cards:
		var ctype := str(card.get("type", ""))
		var cname := str(card.get("name", "")).to_lower()
		if type_filter != "" and ctype != type_filter:
			continue
		if query != "" and not cname.contains(query):
			continue

		var node := CARD_SCENE.instantiate() as CardNode
		node.custom_minimum_size = Vector2(70, 79)
		library_grid.add_child(node)
		node.setup(card)
		node.card_played.connect(func(cdata: Dictionary): _add_to_deck(cdata))
		node.mouse_entered.connect(func(): _show_preview(card))
		node.mouse_exited.connect(func():
			if is_instance_valid(preview_panel):
				preview_panel.visible = false
		)

# ── Deck list display ─────────────────────────────────────────────────────────

func _refresh_deck_list() -> void:
	for c in deck_list.get_children():
		c.queue_free()

	var counts: Dictionary  = {}
	var order:  Array[String] = []
	for card in current_deck:
		var id := str(card.get("id", card.get("name", "")))
		if not counts.has(id):
			counts[id] = {"card": card, "count": 0}
			order.append(id)
		counts[id]["count"] = (counts[id]["count"] as int) + 1

	for id in order:
		_make_deck_row(
			counts[id]["card"]  as Dictionary,
			id,
			counts[id]["count"] as int
		)

	_update_count_label()

func _make_deck_row(card: Dictionary, id: String, count: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(5, 5)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.color               = CardNode.TYPE_COLORS.get(
		str(card.get("type", "")), Color(0.5, 0.5, 0.5))
	dot.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	row.add_child(dot)

	var name_lbl := Label.new()
	name_lbl.text                  = str(card.get("name", ""))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 8)
	row.add_child(name_lbl)

	var count_lbl := Label.new()
	count_lbl.text                 = "×%d" % count
	count_lbl.custom_minimum_size  = Vector2(18, 0)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	count_lbl.add_theme_font_size_override("font_size", 8)
	row.add_child(count_lbl)

	var rm := Button.new()
	rm.text                = "−"
	rm.flat                = true
	rm.custom_minimum_size = Vector2(16, 14)
	rm.pressed.connect(_remove_one.bind(id))
	row.add_child(rm)

	deck_list.add_child(row)

func _update_count_label() -> void:
	var n := current_deck.size()
	deck_count_lbl.text = "%d / %d" % [n, MAX_DECK_SIZE]
	# Tint red when full
	deck_count_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.35, 0.35) if n >= MAX_DECK_SIZE else Color(0.65, 0.65, 0.65))

# ── Card operations ───────────────────────────────────────────────────────────

func _add_to_deck(card: Dictionary) -> void:
	if current_deck.size() >= MAX_DECK_SIZE:
		# Flash the count label to signal "deck full"
		deck_count_lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		get_tree().create_timer(0.4).timeout.connect(func(): _update_count_label())
		return
	current_deck.append(card.duplicate())
	_refresh_deck_list()

func _remove_one(card_id: String) -> void:
	for i in range(current_deck.size() - 1, -1, -1):
		if str(current_deck[i].get("id", current_deck[i].get("name", ""))) == card_id:
			current_deck.remove_at(i)
			break
	_refresh_deck_list()

# ── Hover preview ─────────────────────────────────────────────────────────────

func _show_preview(card: Dictionary) -> void:
	preview_name.text    = str(card.get("name",    ""))
	preview_type.text    = str(card.get("type",    ""))
	preview_energy.text  = "⚡ %s" % str(card.get("energy", "?"))
	preview_tooltip.text = str(card.get("tooltip", str(card.get("logic", ""))))
	preview_panel.visible = true

# ── Filter ────────────────────────────────────────────────────────────────────

func _on_filter(label: String) -> void:
	_active_filter = label
	_highlight_filter(label)
	_refresh_library()

func _highlight_filter(active: String) -> void:
	for btn in _filter_btns:
		btn.button_pressed = (btn.text == active)

# ── Save / Clear ──────────────────────────────────────────────────────────────

func _on_save() -> void:
	# Push to runtime so PlayUI picks it up immediately
	GlobalVars.player_deck.clear()
	for card in current_deck:
		GlobalVars.player_deck.append(card.duplicate())

	# Persist to disk so it survives restarts
	var cfg := ConfigFile.new()
	cfg.set_value("deck", "name",  deck_name_edit.text)
	cfg.set_value("deck", "cards", current_deck)
	cfg.save(SAVE_PATH)

	save_btn.text = "SAVED ✓"
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(save_btn):
			save_btn.text = "SAVE"
	)

func _on_clear() -> void:
	current_deck.clear()
	_refresh_deck_list()
