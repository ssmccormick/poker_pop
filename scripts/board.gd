class_name Board
extends Node2D

## The card grid: dealing, selection, hand playing, gravity and refill.

signal selection_changed
signal hand_played(result: Dictionary)

const COLS := 7
const ROWS := 5
const GAP := 8
const CELL_W := PlayingCard.W + GAP
const CELL_H := PlayingCard.H + GAP
const MAX_SELECT := 5

const BOARD_W := COLS * CELL_W - GAP
const BOARD_H := ROWS * CELL_H - GAP

var grid := {}  # Vector2i -> PlayingCard
var deck: Array = []
var selected: Array[PlayingCard] = []
var busy := false    # animations in flight, input ignored
var locked := false  # game over, input ignored


func _ready() -> void:
	reset()


func reset() -> void:
	if busy:
		return
	locked = false
	busy = true
	for card in grid.values():
		card.queue_free()
	grid.clear()
	selected.clear()
	deck.clear()
	selection_changed.emit()
	await _fall_and_fill(true)
	busy = false


func _refill_deck() -> void:
	for s in 4:
		for r in range(2, 15):
			deck.append({"rank": r, "suit": s})
	deck.shuffle()


func draw_card() -> Dictionary:
	if deck.is_empty():
		_refill_deck()
	return deck.pop_back()


func cell_center(p: Vector2i) -> Vector2:
	return Vector2(p.x * CELL_W + PlayingCard.W / 2.0, p.y * CELL_H + PlayingCard.H / 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if busy or locked:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var local := to_local(get_global_mouse_position())
			var cx := floori(local.x / CELL_W)
			var cy := floori(local.y / CELL_H)
			if cx < 0 or cx >= COLS or cy < 0 or cy >= ROWS:
				return
			# Ignore clicks in the gap between cards.
			if local.x - cx * CELL_W > PlayingCard.W or local.y - cy * CELL_H > PlayingCard.H:
				return
			var p := Vector2i(cx, cy)
			if grid.has(p):
				_toggle_select(grid[p])
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			clear_selection()


func _toggle_select(card: PlayingCard) -> void:
	if card.selected:
		card.selected = false
		selected.erase(card)
	elif selected.size() < MAX_SELECT:
		card.selected = true
		selected.append(card)
	else:
		return
	selection_changed.emit()


func clear_selection() -> void:
	if selected.is_empty():
		return
	for card in selected:
		card.selected = false
	selected.clear()
	selection_changed.emit()


func get_selected_data() -> Array:
	var out := []
	for card in selected:
		out.append({"rank": card.rank, "suit": card.suit})
	return out


func play_hand() -> void:
	if busy or locked or selected.is_empty():
		return
	var result := Poker.evaluate(get_selected_data())
	result["count"] = selected.size()
	busy = true
	hand_played.emit(result)

	var played := selected.duplicate()
	selected.clear()
	selection_changed.emit()

	var tw := create_tween().set_parallel(true)
	for card in played:
		grid.erase(card.grid_pos)
		card.selected = false
		tw.tween_property(card, "scale", Vector2.ZERO, 0.2) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(card, "rotation", randf_range(-0.7, 0.7), 0.2)
	await tw.finished
	for card in played:
		card.queue_free()

	await _fall_and_fill(false)
	busy = false


## Drops surviving cards to the bottom of their column and deals new cards
## in from above the board. Awaits until every card has landed.
func _fall_and_fill(initial_deal: bool) -> void:
	var tw := create_tween().set_parallel(true)
	var moved := false
	for x in COLS:
		var col_cards: Array = []
		for y in ROWS:
			var p := Vector2i(x, y)
			if grid.has(p):
				col_cards.append(grid[p])
				grid.erase(p)
		var target_y := ROWS - 1
		# Existing cards settle to the bottom, keeping their order.
		for i in range(col_cards.size() - 1, -1, -1):
			var card: PlayingCard = col_cards[i]
			var p := Vector2i(x, target_y)
			grid[p] = card
			card.grid_pos = p
			var dest := cell_center(p)
			if card.position != dest:
				tw.tween_property(card, "position", dest, 0.4) \
						.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
				moved = true
			target_y -= 1
		# New cards fall in from above to fill the rest.
		var missing := target_y + 1
		for row in range(target_y, -1, -1):
			var data := draw_card()
			var card := PlayingCard.new()
			card.rank = data.rank
			card.suit = data.suit
			var p := Vector2i(x, row)
			card.grid_pos = p
			grid[p] = card
			card.position = cell_center(Vector2i(x, row - missing))
			add_child(card)
			var delay := 0.05 * (missing - 1 - row)
			if initial_deal:
				delay += 0.04 * x
			tw.tween_property(card, "position", cell_center(p), 0.4) \
					.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT) \
					.set_delay(delay)
			moved = true
	if moved:
		await tw.finished
	else:
		tw.kill()
