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

var _pop_wav: AudioStreamWAV


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
	if not has_playable_hand():
		dead_board.emit()


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
	else:
		if selected.size() >= MAX_SELECT:
			return
		if not selected.is_empty() and not _is_adjacent(card.grid_pos, selected.back().grid_pos):
			return
		card.selected = true
		selected.append(card)
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
	if result.name == "High Card":
		return  # pair minimum — not submittable
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
			tw.tween_property(card, "position", cell_center(p), 0.4) \
					.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT) \
					.set_delay(delay)
			moved = true
	if moved:
		await tw.finished
	else:
		tw.kill()


# --- Dead-board detection -------------------------------------------------

## True if any submittable hand (pair or better) can be chained on the
## current full board.
func has_playable_hand() -> bool:
	# A pair is chainable iff two same-rank cards sit within MAX_SELECT - 1
	# king-moves of each other: the board is full, so a connecting path of
	# cards always exists inside a chain of MAX_SELECT.
	var by_rank := {}
	for p in grid:
		var r: int = grid[p].rank
		if not by_rank.has(r):
			by_rank[r] = []
		by_rank[r].append(p)
	for r in by_rank:
		var cells: Array = by_rank[r]
		for i in cells.size():
			for j in range(i + 1, cells.size()):
				var d: Vector2i = (cells[i] - cells[j]).abs()
				if maxi(d.x, d.y) <= MAX_SELECT - 1:
					return true
	# No pair in reach: a 5-card flush or ordered straight chain could
	# still be playable.
	for p in grid:
		if _suit_chain_exists(p, {p: true}, 1):
			return true
	for p in grid:
		if _straight_chain_exists(p, {p: true}, 1, 1) \
				or _straight_chain_exists(p, {p: true}, 1, -1):
			return true
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


## dir = 1 for ascending picks, -1 for descending. The ace may start an
## ascending wheel (A-2-3-4-5) or end a descending one (5-4-3-2-A).
func _straight_chain_exists(p: Vector2i, visited: Dictionary, depth: int, dir: int) -> bool:
	if depth == MAX_SELECT:
		return true
	var r: int = grid[p].rank
	var targets: Array = []
	if dir == 1:
		if r < 14:
			targets.append(r + 1)
		if r == 14 and depth == 1:
			targets.append(2)
	else:
		if r > 2:
			targets.append(r - 1)
		if r == 2 and depth == MAX_SELECT - 1:
			targets.append(14)
	if targets.is_empty():
		return false
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var q := p + Vector2i(dx, dy)
			if grid.has(q) and not visited.has(q) and grid[q].rank in targets:
				visited[q] = true
				if _straight_chain_exists(q, visited, depth + 1, dir):
					return true
				visited.erase(q)
	return false


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
	if _pop_wav == null:
		_pop_wav = _make_pop_sound()
	var player := AudioStreamPlayer.new()
	player.stream = _pop_wav
	player.pitch_scale = pitch
	player.volume_db = -5.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## Synthesizes a short "pop": a sine sweep from high to low pitch with a
## fast exponential decay. No audio assets needed.
static func _make_pop_sound() -> AudioStreamWAV:
	var rate := 22050
	var length := 0.14
	var n := int(rate * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / rate
		var freq: float = 900.0 * pow(160.0 / 900.0, t / length)
		phase += freq / rate
		var env := exp(-t * 28.0)
		var sample := sin(TAU * phase) * env
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
