extends Control

signal stage_selected(day_index: int)
signal back_to_main_menu

const STAGES = [
	{ "label": "Day 1", "sub": "The journey begins",         "locked": false },
	{ "label": "Day 2", "sub": "Tensions rise at the spire", "locked": false },
	{ "label": "Day 3", "sub": "A new threat emerges",       "locked": false },
	{ "label": "Day 4", "sub": "Push deeper into the spire", "locked": true  },
	{ "label": "Day 5", "sub": "The climb intensifies",      "locked": true  },
	{ "label": "Day 6", "sub": "Final approach",             "locked": true  },
]

var current_index: int = 0

@onready var day_label      = $VBoxContainer/DayLabel
@onready var prev_button    = $VBoxContainer/CarouselContainer/PrevButton
@onready var next_button    = $VBoxContainer/CarouselContainer/NextButton
@onready var prev_card      = $VBoxContainer/CarouselContainer/CardViewport/PrevCard
@onready var center_card    = $VBoxContainer/CarouselContainer/CardViewport/CenterCard
@onready var next_card      = $VBoxContainer/CarouselContainer/CardViewport/NextCard
@onready var dots_container = $VBoxContainer/DotsContainer
@onready var back_button    = $BackButton


func _ready() -> void:
	_build_dots()
	_update_carousel()


	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	# CenterCard is a Button so use .pressed instead of gui_input
	center_card.pressed.connect(_on_center_card_pressed)


# ── Navigation ────────────────────────────────────────────────────────────────

func _on_prev_pressed() -> void:
	if current_index > 0:
		current_index -= 1
		_update_carousel()


func _on_next_pressed() -> void:
	if current_index < STAGES.size() - 1:
		current_index += 1
		_update_carousel()

func _on_back_button_pressed() -> void:
	back_to_main_menu.emit()

# ── Center card click to play ─────────────────────────────────────────────────

func _on_center_card_pressed() -> void:
	var stage = STAGES[current_index]
	if not stage["locked"]:
		emit_signal("stage_selected", current_index)


# ── Carousel update ───────────────────────────────────────────────────────────

func _update_carousel() -> void:
	day_label.text = STAGES[current_index]["label"]

	_update_card(prev_card,   current_index - 1, false)
	_update_card(center_card, current_index,     true)
	_update_card(next_card,   current_index + 1, false)

	prev_button.disabled = current_index == 0
	next_button.disabled = current_index == STAGES.size() - 1

	_update_dots()


# card can be Button or PanelContainer so use Control as the type
func _update_card(card: Control, index: int, is_center: bool) -> void:
	if index < 0 or index >= STAGES.size():
		card.hide()
		return

	card.show()
	var stage = STAGES[index]

	card.get_node("VBoxContainer/TitleLabel").text = stage["label"]
	card.get_node("VBoxContainer/SubLabel").text   = stage["sub"]

	var lock_overlay = card.get_node_or_null("LockedOverlay")
	if lock_overlay:
		lock_overlay.visible = stage["locked"]

	if is_center:
		card.modulate = Color(1, 1, 1, 1)
		card.scale    = Vector2(1.0, 1.0)
	else:
		card.modulate = Color(1, 1, 1, 0.4)
		card.scale    = Vector2(0.92, 0.92)

	var play_hint = card.get_node_or_null("PlayHint")
	if play_hint:
		play_hint.visible = is_center and not stage["locked"]


# ── Dots ──────────────────────────────────────────────────────────────────────

func _build_dots() -> void:
	for child in dots_container.get_children():
		child.queue_free()

	for i in STAGES.size():
		var dot = ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.name = "Dot" + str(i)
		dots_container.add_child(dot)


func _update_dots() -> void:
	for i in STAGES.size():
		var dot = dots_container.get_node_or_null("Dot" + str(i))
		if dot:
			dot.color = Color.WHITE if i == current_index else Color(1, 1, 1, 0.3)


# ── Unlock a day (call from GameManager when stage is cleared) ────────────────

func unlock_day(index: int) -> void:
	if index < STAGES.size():
		STAGES[index]["locked"] = false
		_update_carousel()


func _on_play_pressed() -> void:
	pass # Replace with function body.

func _on_settings_button_pressed() -> void:
	GlobalVars.settings_ui.visible = true


func _on_types_info_button_pressed() -> void:
	GlobalVars.info_book.visible = true


func _on_shop_button_pressed() -> void:
	GlobalVars.shop_ui.open_shop()
