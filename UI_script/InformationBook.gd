extends MarginContainer

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var card_grid: GridContainer   = $MarginContainer/Info_Types/CardInfo_EnemyTypes/"Card Info"/ScrollContainer/GridContainer
@onready var enemy_grid: GridContainer  = $MarginContainer/Info_Types/CardInfo_EnemyTypes/"Enemy Type"/ScrollContainer/GridContainer
@onready var preview_image: TextureRect = $MarginContainer2/RightSide/TextureRect
@onready var entry_name: Label          = $MarginContainer2/RightSide/VBoxContainer/EntryName
@onready var type_label: Label          = $MarginContainer2/RightSide/VBoxContainer/Label
@onready var desc_rich: RichTextLabel   = $MarginContainer2/RightSide/VBoxContainer/RichTextLabel

# ── State ─────────────────────────────────────────────────────────────────────
var _selected_btn: Button = null
var _unlocked_cards:   Array[String] = []
var _unlocked_enemies: Array[String] = []

var _all_cards:   Array[Dictionary] = []
var _all_enemies: Array[Dictionary] = []

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_all_cards   = _load_cards("res://CSV/cards.csv")
	_all_enemies = _load_enemies("res://CSV/threats.csv")
	_populate_grid(card_grid,  _all_cards,   _unlocked_cards)
	_populate_grid(enemy_grid, _all_enemies, _unlocked_enemies)
	_clear_detail()

# ── CSV Loaders ───────────────────────────────────────────────────────────────
func _load_cards(path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Codex: could not open %s" % path)
		return result

	var headers := file.get_csv_line()

	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 0 or (row.size() == 1 and row[0].strip_edges() == ""):
			continue
		if row.size() < headers.size():
			continue

		var entry: Dictionary = {}
		for i in headers.size():
			entry[headers[i].strip_edges()] = row[i].strip_edges()

		entry["type"]     = "CARD"
		entry["category"] = entry.get("card_type", "")
		# tooltip is the short in-game flavour text; description is the full codex body
		# both columns exist in the CSV; no remapping needed

		result.append(entry)

	file.close()
	return result


func _load_enemies(path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Codex: could not open %s" % path)
		return result

	var headers := file.get_csv_line()

	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 0 or (row.size() == 1 and row[0].strip_edges() == ""):
			continue
		if row.size() < headers.size():
			continue

		var entry: Dictionary = {}
		for i in headers.size():
			entry[headers[i].strip_edges()] = row[i].strip_edges()

		# Pipe-separated fields become newline-separated for display
		entry["alerts"] = entry.get("alerts", "").replace("|", "\n")
		entry["clues"]  = entry.get("clues",  "").replace("|", "\n")

		entry["type"]     = "ENEMY"
		entry["name"]     = entry.get("threat_type", "Unknown")
		entry["category"] = entry.get("threat_type", "")

		result.append(entry)

	file.close()
	return result

# ── Grid ──────────────────────────────────────────────────────────────────────
func _populate_grid(grid: GridContainer, entries: Array[Dictionary], unlocked: Array[String]) -> void:
	for child in grid.get_children():
		child.queue_free()

	for entry in entries:
		var is_unlocked: bool = unlocked.is_empty() or entry["name"] in unlocked
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(40, 40)

		if is_unlocked:
			btn.text = entry["name"]
			btn.tooltip_text = entry.get("category", "")
			btn.pressed.connect(_on_entry_pressed.bind(entry, btn))
		else:
			btn.text = "???"
			btn.disabled = true

		grid.add_child(btn)

# ── Selection ─────────────────────────────────────────────────────────────────
func _on_entry_pressed(entry: Dictionary, btn: Button) -> void:
	if _selected_btn:
		_selected_btn.button_pressed = false
	_selected_btn = btn
	btn.button_pressed = true
	_show_detail(entry)

func _show_detail(entry: Dictionary) -> void:
	entry_name.text = entry["name"]

	if entry["type"] == "CARD":
		type_label.text = "CARD — " + entry.get("category", "").to_upper()
	else:
		type_label.text = "ENEMY TYPE — " + entry.get("category", "").to_upper()

	var body := ""
	if entry["type"] == "CARD":
		body += "[b]What it does[/b]\n%s\n\n"        % entry.get("logic", "")
		body += "[b]In practice[/b]\n%s\n\n"          % entry.get("description", "")
		body += "[b]Real-world example[/b]\n%s\n\n"   % entry.get("real_world", "")
		body += "[b]// Analyst hint[/b]\n%s"           % entry.get("hint", "")
	else:
		body += "[b]What it is[/b]\n%s\n\n"           % entry.get("description", "")
		body += "[b]Real-world example[/b]\n%s\n\n"   % entry.get("real_world", "")
		body += "[b]Alerts to watch[/b]\n%s\n\n"      % entry.get("alerts", "")
		body += "[b]Clues you'll find[/b]\n%s\n\n"    % entry.get("clues", "")
		body += "[b]// Analyst hint[/b]\n%s"           % entry.get("hint", "")

	desc_rich.text = body

func _clear_detail() -> void:
	entry_name.text       = ""
	type_label.text       = ""
	desc_rich.text        = "Select a card or enemy on the left to read its entry."
	preview_image.texture = null

# ── Unlock API ────────────────────────────────────────────────────────────────
func unlock(entry_name_to_unlock: String) -> void:
	for entry in _all_cards:
		if entry["name"] == entry_name_to_unlock and entry_name_to_unlock not in _unlocked_cards:
			_unlocked_cards.append(entry_name_to_unlock)
			_populate_grid(card_grid, _all_cards, _unlocked_cards)
			return
	for entry in _all_enemies:
		if entry["name"] == entry_name_to_unlock and entry_name_to_unlock not in _unlocked_enemies:
			_unlocked_enemies.append(entry_name_to_unlock)
			_populate_grid(enemy_grid, _all_enemies, _unlocked_enemies)
			return

func set_all_locked(locked: bool) -> void:
	if locked:
		_unlocked_cards.clear()
		_unlocked_enemies.clear()
	else:
		for e in _all_cards:
			if e["name"] not in _unlocked_cards:
				_unlocked_cards.append(e["name"])
		for e in _all_enemies:
			if e["name"] not in _unlocked_enemies:
				_unlocked_enemies.append(e["name"])
	_populate_grid(card_grid,  _all_cards,   _unlocked_cards)
	_populate_grid(enemy_grid, _all_enemies, _unlocked_enemies)


func _on_cross_pressed() -> void:
	$Button.pressed.connect(func(): visible = false)
