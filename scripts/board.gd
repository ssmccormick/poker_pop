class_name Board
extends Node2D

## The card grid: dealing, chain selection, hand playing, gravity and refill.
##
## Selection is an ordered chain: after the first card, each new pick must be
## adjacent (8-way) to the previous one. Clicking a selected card removes it
## and everything picked after it.

signal selection_changed
signal hand_played(result: Dictionary)
signal dead_board

const GAP := 8
const CELL_W := PlayingCard.W + GAP
const CELL_H := PlayingCard.H + GAP
const MAX_SELECT := 5

var cols := 5
var rows := 5
var single_deck := false  # deck never reshuffles; the board runs dry

var grid := {}  # Vector2i -> PlayingCard
var deck: Array = []
var selected: Array[PlayingCard] = []
var busy := false    # animations in flight, input ignored
var locked := false  # game over, input ignored
var dragging := false

const SFX_FLIP := preload("res://assets/sfx/card_flip.wav")
const SFX_DEAL := preload("res://assets/sfx/deal_card.wav")
const SFX_SWOOSH := preload("res://assets/sfx/deal_swoosh.wav")
const SFX_POPS := [
	preload("res://assets/sfx/pop_1.wav"),
	preload("res://assets/sfx/pop_2.wav"),
	preload("res://assets/sfx/pop_3.wav"),
]


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
	_refill_deck()
	selection_changed.emit()
	await _fall_and_fill(true)
	busy = false
	if not has_playable_hand():
		dead_board.emit()


func _refill_deck() -> void:
	for s in 4:
		for r in range(2, 15):
			deck.append({"rank": r, "suit": s})
	deck.shuffle()


## Returns {} when a single deck runs out.
func draw_card() -> Dictionary:
	if deck.is_empty():
		if single_deck:
			return {}
		_refill_deck()
	return deck.pop_back()


func cell_center(p: Vector2i) -> Vector2:
	return Vector2(p.x * CELL_W + PlayingCard.W / 2.0, p.y * CELL_H + PlayingCard.H / 2.0)


## Unscaled pixel size of the full grid.
func board_px_size() -> Vector2:
	return Vector2(cols * CELL_W - GAP, rows * CELL_H - GAP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dragging = false
	if busy or locked:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var card := _card_under_mouse(true)
			if card:
				# Only arm dragging when the press SELECTED the card —
				# otherwise mouse jitter during a deselect click would
				# drag-reselect it in the same click.
				var was_selected := card.selected
				_toggle_select(card)
				dragging = not was_selected
			else:
				dragging = true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			clear_selection()
	elif event is InputEventMouseMotion and dragging:
		_drag_over(_card_under_mouse(false))


## strict = true rejects the gap between cards (for clicks). Drags use a
## smaller central hitbox per card, leaving dead corridors between cards
## so a diagonal drag doesn't clip an orthogonal neighbor on the way.
const DRAG_HIT := 0.30  # half-extent of the drag hitbox, as a card fraction

func _card_under_mouse(strict: bool) -> PlayingCard:
	var local := to_local(get_global_mouse_position())
	var cx := floori(local.x / CELL_W)
	var cy := floori(local.y / CELL_H)
	if cx < 0 or cx >= cols or cy < 0 or cy >= rows:
		return null
	if strict:
		if local.x - cx * CELL_W > PlayingCard.W or local.y - cy * CELL_H > PlayingCard.H:
			return null
	else:
		var center := cell_center(Vector2i(cx, cy))
		if absf(local.x - center.x) > PlayingCard.W * DRAG_HIT \
				or absf(local.y - center.y) > PlayingCard.H * DRAG_HIT:
			return null
	return grid.get(Vector2i(cx, cy))


func _drag_over(card: PlayingCard) -> void:
	if card == null:
		return
	if selected.is_empty():
		_toggle_select(card)
		return
	if card == selected.back():
		return
	if selected.size() >= 2 and card == selected[-2]:
		# Dragging back over the previous card undoes the last step.
		_toggle_select(selected.back())
	elif not card.selected:
		if selected.size() < MAX_SELECT and _is_adjacent(card.grid_pos, selected.back().grid_pos):
			_toggle_select(card)


static func _is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	var d := (a - b).abs()
	return maxi(d.x, d.y) == 1


func _toggle_select(card: PlayingCard) -> void:
	if card.selected:
		# Remove this card and everything chained after it.
		var idx := selected.find(card)
		for i in range(selected.size() - 1, idx - 1, -1):
			selected[i].selected = false
			selected.remove_at(i)
		_play_sound(SFX_FLIP, 0.85, -8.0)
	else:
		if selected.size() >= MAX_SELECT:
			return
		if not selected.is_empty() and not _is_adjacent(card.grid_pos, selected.back().grid_pos):
			return
		card.selected = true
		selected.append(card)
		# Flip pitch climbs as the chain grows.
		_play_sound(SFX_FLIP, 1.0 + 0.07 * (selected.size() - 1), -8.0)
	_sync_chain_indices()
	selection_changed.emit()


func _sync_chain_indices() -> void:
	for i in selected.size():
		selected[i].chain_index = i + 1


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
	if not result.playable:
		return  # every selected card must be part of a real hand
	result["count"] = selected.size()
	busy = true
	hand_played.emit(result)

	var played := selected.duplicate()
	selected.clear()
	selection_changed.emit()

	var center := Vector2.ZERO
	for card in played:
		center += card.position
	center /= played.size()
	_spawn_float_text("+%d" % result.score, center)

	var tw := create_tween().set_parallel(true)
	for i in played.size():
		var card: PlayingCard = played[i]
		var delay := 0.06 * i
		grid.erase(card.grid_pos)
		card.selected = false
		tw.tween_property(card, "scale", Vector2.ZERO, 0.2) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(delay)
		tw.tween_property(card, "rotation", randf_range(-0.7, 0.7), 0.2).set_delay(delay)
		tw.tween_callback(_play_pop.bind(1.0 + 0.08 * i + randf_range(-0.04, 0.04))) \
				.set_delay(delay + 0.1)
	await tw.finished
	for card in played:
		card.queue_free()

	await _fall_and_fill(false)
	busy = false
	if not has_playable_hand():
		dead_board.emit()


## Drops surviving cards to the bottom of their column and deals new cards
## in from above the board. Awaits until every card has landed.
func _fall_and_fill(initial_deal: bool) -> void:
	var tw := create_tween().set_parallel(true)
	var moved := false
	for x in cols:
		var col_cards: Array = []
		for y in rows:
			var p := Vector2i(x, y)
			if grid.has(p):
				col_cards.append(grid[p])
				grid.erase(p)
		var target_y := rows - 1
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
		# New cards fall in from above to fill the rest (a spent single
		# deck stops mid-column and leaves the top cells empty).
		var missing := target_y + 1
		var column_got_cards := false
		var column_delay := 0.0
		for row in range(target_y, -1, -1):
			var data := draw_card()
			if data.is_empty():
				break
			var card := PlayingCard.new()
			card.material = Themes.current_material()
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
			if not column_got_cards:
				column_delay = delay
			column_got_cards = true
			tw.tween_property(card, "position", cell_center(p), 0.4) \
					.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT) \
					.set_delay(delay)
			moved = true
		if column_got_cards:
			# One deal sound per refilled column, timed with its cards.
			_play_sound(SFX_DEAL, randf_range(0.92, 1.12), -10.0, column_delay + 0.15)
	if moved:
		await tw.finished
	else:
		tw.kill()


# --- Dead-board detection -------------------------------------------------

## True if any submittable hand can be chained on the current board.
## Every card in a chain must participate in the hand (no kickers), so a
## hand is playable only if its exact cards form an adjacent chain.
func has_playable_hand() -> bool:
	# Rank-group hands (pair, trips, quads, five, two pair, full house):
	# chains using at most two distinct ranks.
	for p in grid:
		var card: PlayingCard = grid[p]
		if _group_chain_exists(p, {p: true}, {card.rank: 1}):
			return true
	# 5-card flush chains.
	for p in grid:
		if _suit_chain_exists(p, {p: true}, 1):
			return true
	# 5-card straight chains (any pick order along the chain).
	for p in grid:
		if _straight_chain_exists(p, {p: true}, {grid[p].rank: true}):
			return true
	return false


## rank_counts holds the ranks used by the chain so far. A chain qualifies
## the moment its rank multiset is an exact hand: all one rank (2-5 cards),
## two pairs (2+2), or a full house (3+2).
func _group_chain_exists(p: Vector2i, visited: Dictionary, rank_counts: Dictionary) -> bool:
	var counts: Array = rank_counts.values()
	counts.sort()
	if counts == [2] or counts == [3] or counts == [4] or counts == [5] \
			or counts == [2, 2] or counts == [2, 3]:
		return true
	if visited.size() == MAX_SELECT:
		return false
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var q := p + Vector2i(dx, dy)
			if not grid.has(q) or visited.has(q):
				continue
			var r: int = grid[q].rank
			# A third distinct rank can never resolve into an exact hand.
			if not rank_counts.has(r) and rank_counts.size() >= 2:
				continue
			rank_counts[r] = rank_counts.get(r, 0) + 1
			visited[q] = true
			if _group_chain_exists(q, visited, rank_counts):
				return true
			visited.erase(q)
			rank_counts[r] -= 1
			if rank_counts[r] == 0:
				rank_counts.erase(r)
	return false


func _suit_chain_exists(p: Vector2i, visited: Dictionary, depth: int) -> bool:
	if depth == MAX_SELECT:
		return true
	var suit: int = grid[p].suit
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var q := p + Vector2i(dx, dy)
			if grid.has(q) and not visited.has(q) and grid[q].suit == suit:
				visited[q] = true
				if _suit_chain_exists(q, visited, depth + 1):
					return true
				visited.erase(q)
	return false


## Searches for a 5-card chain whose distinct ranks form a consecutive run
## (or the wheel A-2-3-4-5) — pick order along the chain doesn't matter.
func _straight_chain_exists(p: Vector2i, visited: Dictionary, ranks: Dictionary) -> bool:
	if visited.size() == MAX_SELECT:
		var arr: Array = ranks.keys()
		arr.sort()
		return arr[4] - arr[0] == 4 or arr == [2, 3, 4, 5, 14]
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var q := p + Vector2i(dx, dy)
			if not grid.has(q) or visited.has(q):
				continue
			var r: int = grid[q].rank
			if ranks.has(r):
				continue
			ranks[r] = true
			if _straight_possible(ranks):
				visited[q] = true
				if _straight_chain_exists(q, visited, ranks):
					return true
				visited.erase(q)
			ranks.erase(r)
	return false


## Can this rank set still grow into a straight? Either the span fits a
## 5-run, or it's a subset of the wheel {2,3,4,5,A}.
func _straight_possible(ranks: Dictionary) -> bool:
	var arr: Array = ranks.keys()
	arr.sort()
	if arr.back() - arr[0] <= 4:
		return true
	for r in arr:
		if r != 14 and r > 5:
			return false
	return true


## Rearranges the existing cards into a new layout that has a playable
## hand, with a slide animation. With 14+ cards a duplicate rank always
## exists, so a playable arrangement is always reachable.
func shuffle_board() -> void:
	if busy or grid.is_empty():
		return
	busy = true
	clear_selection()
	_play_sound(SFX_SWOOSH, 1.0, -6.0)
	var cards: Array = grid.values()
	var cells: Array = grid.keys()
	for attempt in 100:
		cells.shuffle()
		grid.clear()
		for i in cards.size():
			grid[cells[i]] = cards[i]
			cards[i].grid_pos = cells[i]
		if has_playable_hand():
			break
	var tw := create_tween().set_parallel(true)
	for p in grid:
		tw.tween_property(grid[p], "position", cell_center(p), 0.5) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	busy = false


## Restyles every card on the board for the current theme.
func apply_theme() -> void:
	PlayingCard.rebuild_theme()
	var mat := Themes.current_material()
	for card in grid.values():
		card.material = mat
		card.queue_redraw()


# --- Juice ----------------------------------------------------------------

func _spawn_float_text(text: String, center: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", PlayingCard.GOLD)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.size = Vector2(200, 44)
	l.position = center - Vector2(100, 22)
	l.z_index = 10
	add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 80, 1.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.45).set_delay(0.65)
	tw.chain().tween_callback(l.queue_free)


func _play_pop(pitch: float) -> void:
	_play_sound(SFX_POPS.pick_random(), pitch, -5.0)


## Fire-and-forget one-shot player, with an optional delay.
func _play_sound(stream: AudioStream, pitch: float, volume_db: float, delay := 0.0) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if not is_inside_tree():
			return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.bus = "SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


