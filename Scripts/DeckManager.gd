class_name DeckManager

var deck: Array[Dictionary] = []
var hand: Array[Dictionary] = []
var discard: Array[Dictionary] = []

func initialize(card_list: Array[Dictionary]) -> void:
	deck = card_list.duplicate(true)
	deck.shuffle()
	hand.clear()
	discard.clear()

func draw_cards(count: int) -> void:
	for i in count:
		if deck.is_empty():
			if discard.is_empty():
				return
			# Reshuffle discard into deck
			deck = discard.duplicate(true)
			deck.shuffle()
			discard.clear()
		if not deck.is_empty():
			hand.append(deck.pop_back())

func play_card(card_data: Dictionary) -> void:
	# Remove first matching card from hand by id
	for i in hand.size():
		if hand[i].get("id") == card_data.get("id"):
			hand.remove_at(i)
			discard.append(card_data)
			return

func discard_hand() -> void:
	discard.append_array(hand)
	hand.clear()

func deck_count() -> int:
	return deck.size()

func discard_count() -> int:
	return discard.size()

func hand_count() -> int:
	return hand.size()
