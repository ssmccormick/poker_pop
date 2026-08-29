class_name Board
extends Node2D

## The card grid: dealing, chain selection, hand playing, gravity and refill.
##
## Selection is an ordered chain: after the first card, each new pick must be
## adjacent (8-way) to the previous one. Clicking a selected card removes it
## and everything picked after it.

signal selection_changed
signal hand_played(result: Dictionary)
signal hand_rejected
signal dead_board
signal card_dealt(card: PlayingCard)  # per-card audio hook, on deal arrival
signal settle_landed                  # fires once when Phase A lands
signal refill_done                    # internal: refill finished or skipped
signal safe_cracked                   # the combo chain opened the safe
signal boss_defeated                  # the room's boss is down

const GAP := 8
const CELL_W := PlayingCard.W + GAP
const CELL_H := PlayingCard.H + GAP
const MAX_SELECT := 5

# --- Refill presentation timing (all scaled by refill_speed) --------------
const SETTLE_DURATION := 0.4       # Phase A: existing cards fall into gaps
const SETTLE_DEAL_OVERLAP := 0.8   # Phase B starts at this fraction of A
const DEAL_CARD_DURATION := 0.9    # flight time of each dealt card
const DEAL_STAGGER_DELAY := 0.14   # gap between dealt cards
const DEAL_SPIN_MIN := 1.2         # throw spin, in full turns
const DEAL_SPIN_MAX := 2.0
const DEAL_SPIN_SETTLE := 0.25     # spin keeps decaying this long AFTER landing
const SETUP_STAGGER_SCALE := 0.6   # full-board setup deals use a tighter stagger
const DEAL_START_SCALE := 2.6      # dealt cards start big (high, near the screen)
const DEAL_ARC_HEIGHT := 460.0     # how high above the flight line the toss peaks

var refill_speed := 1.0  # >1 = faster; scales every refill duration/delay

var _refill_active := false
var _refill_tween: Tween
var _refill_finals: Array = []   # {card, pos} snap targets for skipping
var _refill_shadows: Array = []  # in-flight shadow blobs, freed on land/skip

var cols := 5
var rows := 5
var single_deck := false  # deck never reshuffles; the board runs dry
# Trail mode: when non-empty, the deck refills from this custom card
# list ({rank, suit, cursed}) instead of a standard 52.
var custom_deck: Array = []

# --- Trail hazards --------------------------------------------------------
const BOMB_FUSE := 5
const STONE_HITS_START := 3
const CHIP_BONUS := 8      # chips per played chip-mod card (trail)
const MULT_FACTOR := 1.5   # per played mult-mod card, stacking
# Relic-tunable copies (Gold Tooth / Mirror Shades adjust these).
var chip_bonus := CHIP_BONUS
var mult_factor := MULT_FACTOR
const HAZARD_DIRS: Array[Vector2i] = [
	Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var grid := {}  # Vector2i -> PlayingCard
var deck: Array = []
var selected: Array[PlayingCard] = []
var busy := false    # animations in flight, input ignored
var locked := false  # game over, input ignored
var dragging := false
# Set by main when a level-up is pending: the post-hand refill is
# pointless (the board resets immediately), so skip dealing it.
var suppress_refill := false

const SFX_SELECTS := [
	preload("res://assets/sfx/card_select.wav"),
	preload("res://assets/sfx/card_pick.wav"),
]
const SFX_FLIP := preload("res://assets/sfx/card_flip.wav")
const SFX_DEAL := preload("res://assets/sfx/deal_card.wav")
const SFX_SWOOSH := preload("res://assets/sfx/deal_swoosh.wav")
const SFX_SHUFFLE := preload("res://assets/sfx/shuffle.wav")
const SFX_ERROR := preload("res://assets/sfx/error.wav")
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
	suppress_refill = false
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
	if custom_deck.is_empty():
		for s in 4:
			for r in range(2, 15):
				deck.append({"rank": r, "suit": s})
	else:
		deck = custom_deck.duplicate(true)
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
	# Any click during a refill skips the animation.
	if _refill_active and event is InputEventMouseButton and event.pressed:
		_skip_refill()
		return
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
	if card.cursed or card.snake_tail:
		_play_sound(SFX_FLIP, 0.7, -10.0)
		return
	if card.is_safe and not card.selected:
		# The safe only joins a chain that IS its combination, in order.
		if _chain_matches_combo(card) \
				and _is_adjacent(card.grid_pos, selected.back().grid_pos):
			card.selected = true
			selected.append(card)
			_play_sound(SFX_SELECTS.pick_random(), 1.35, -6.0)
			_sync_chain_indices()
			_update_hand_validity()
			_update_safe_progress()
			selection_changed.emit()
		else:
			_play_sound(SFX_FLIP, 0.7, -10.0)
		return
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
		# Random select sample; pitch climbs as the chain grows.
		_play_sound(SFX_SELECTS.pick_random(),
				1.0 + 0.07 * (selected.size() - 1) + randf_range(-0.02, 0.02), -6.0)
	_sync_chain_indices()
	_update_hand_validity()
	_update_safe_progress()
	selection_changed.emit()


## True when the current chain's ranks equal `safe.combo` exactly.
func _chain_matches_combo(safe: PlayingCard) -> bool:
	if selected.size() != safe.combo.size():
		return false
	for i in selected.size():
		if selected[i].rank != safe.combo[i]:
			return false
	return true


## Lights up each safe's matched combo-prefix digits from the chain.
func _update_safe_progress() -> void:
	for p in grid:
		var card: PlayingCard = grid[p]
		if not card.is_safe:
			continue
		var matched := 0
		for i in mini(selected.size(), card.combo.size()):
			if selected[i].is_safe or selected[i].rank != card.combo[i]:
				break
			matched += 1
		card.combo_progress = matched


func _sync_chain_indices() -> void:
	for i in selected.size():
		selected[i].chain_index = i + 1


func clear_selection() -> void:
	if selected.is_empty():
		return
	for card in selected:
		card.selected = false
		card.hand_valid = false
	selected.clear()
	_update_safe_progress()
	selection_changed.emit()


## Green borders whenever the current chain is a submittable hand.
## A washed (soaked) card in the chain suppresses the green tell — no
## free probing of hidden identities.
func _update_hand_validity() -> void:
	var valid := false
	var has_safe := false
	for card in selected:
		if card.is_safe:
			has_safe = true
			break
	if has_safe:
		# The safe can only have joined via its full combo — crackable.
		valid = true
	elif not selected.is_empty():
		valid = Poker.evaluate(get_selected_data()).playable
		for card in selected:
			if card.washed:
				valid = false
				break
		# Sticky rule: the Queen and her honey only fall to 2-3 card hands.
		if valid and selected.size() > 3:
			for card in selected:
				if card.boss == "queen" or card.honey:
					valid = false
					break
	for card in selected:
		card.hand_valid = valid


func get_selected_data() -> Array:
	var out := []
	for card in selected:
		out.append({"rank": card.rank, "suit": card.suit})
	return out


func play_hand() -> void:
	if busy or locked or selected.is_empty():
		return
	for card in selected:
		if card.is_safe:
			_crack_safe()
			return
	if selected.size() > 3:
		for card in selected:
			if card.boss == "queen" or card.honey:
				_reject_hand()  # too big a hand for something this sticky
				return
	var result := Poker.evaluate(get_selected_data())
	if not result.playable:
		_reject_hand()
		return
	_apply_card_mods(result)
	result["count"] = selected.size()
	# Opening a chest: the hand contains both the key and the chest.
	var has_key := false
	var has_chest := false
	for card in selected:
		if card.objective == "key":
			has_key = true
		elif card.objective == "chest":
			has_chest = true
	if has_key and has_chest:
		result["chest_opened"] = true
	# Predict boss outcomes so trail can clear the room before spending
	# the hand.
	for card in selected:
		match card.boss:
			"jack", "queen":
				if card.boss_hp <= 1:
					result["boss_defeated"] = true
			"cobra":
				if card.cobra_stack.is_empty():
					result["boss_defeated"] = true
	busy = true
	hand_played.emit(result)

	var played := selected.duplicate()
	selected.clear()
	selection_changed.emit()

	var center := Vector2.ZERO
	for card in played:
		center += card.position
	center /= played.size()
	var float_txt := "+%d" % result.score
	if result.get("bonus_chips", 0) > 0:
		float_txt += "  +%d CHIPS" % result.bonus_chips
	_spawn_float_text(float_txt, center)

	# Partition: stones with uses left stay on the board; wind and water
	# effects are snapshotted before their cells change.
	var poppers: Array = []
	var gusts: Array = []     # {"cell", "dir"}
	var splashes: Array = []  # origin cells
	var defeated_boss := false
	for card in played:
		card.selected = false
		card.chain_index = 0
		card.hand_valid = false
		if card.boss == "jack" or card.boss == "queen":
			card.boss_hp -= 1
			if card.boss_hp <= 0:
				defeated_boss = true
				poppers.append(card)  # down he goes
			continue
		if card.boss == "cobra":
			if card.cobra_stack.is_empty():
				defeated_boss = true
				poppers.append(card)
			else:
				_cobra_revert(card)
			continue
		if card.hazard == "stone" and card.stone_hits > 1:
			card.stone_hits -= 1
			continue  # cracked, not cleared — keeps its cell
		if card.hazard == "wind":
			gusts.append({"cell": card.grid_pos, "dir": card.wind_dir})
		elif card.hazard == "water":
			splashes.append(card.grid_pos)
		poppers.append(card)

	if not poppers.is_empty():
		var tw := create_tween().set_parallel(true)
		for i in poppers.size():
			var card: PlayingCard = poppers[i]
			var delay := 0.06 * i
			grid.erase(card.grid_pos)
			tw.tween_property(card, "scale", Vector2.ZERO, 0.2) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(delay)
			tw.tween_property(card, "rotation", randf_range(-0.7, 0.7), 0.2).set_delay(delay)
			tw.tween_callback(_play_pop.bind(1.0 + 0.08 * i + randf_range(-0.04, 0.04))) \
					.set_delay(delay + 0.1)
		await tw.finished
		for card in poppers:
			card.queue_free()
	if defeated_boss:
		boss_defeated.emit()

	if suppress_refill:
		# A level transition is about to reset the board — don't deal.
		suppress_refill = false
		busy = false
		return

	# Water: each played water card soaks one random adjacent plain card.
	for origin in splashes:
		var dirs := HAZARD_DIRS.duplicate()
		dirs.shuffle()
		for d in dirs:
			var q: Vector2i = origin + d
			if grid.has(q):
				var victim: PlayingCard = grid[q]
				if victim.hazard == "" and not victim.cursed and not victim.washed:
					victim.washed = true
					_play_sound(SFX_FLIP, 0.6, -8.0)
					break

	# Wind: gusts blow every card from the wind cell to the edge off the
	# board, unscored.
	var blown := {}  # cell -> dir
	for g in gusts:
		for cell in wind_line_cells(g.cell, g.dir):
			blown[cell] = g.dir
	if not blown.is_empty():
		_play_sound(SFX_SWOOSH, randf_range(1.1, 1.3), -5.0)
		var gtw := create_tween().set_parallel(true)
		var flying: Array = []
		for cell: Vector2i in blown:
			var card: PlayingCard = grid[cell]
			grid.erase(cell)
			flying.append(card)
			card.z_index = 15
			gtw.tween_property(card, "position",
					card.position + Vector2(blown[cell]) * 1700.0, 0.45) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			gtw.tween_property(card, "rotation", card.rotation + 2.2, 0.45)
		await gtw.finished
		for card in flying:
			card.queue_free()

	await _fall_and_fill(false)
	busy = false
	if not has_playable_hand():
		dead_board.emit()


## The combo chain ends on the safe: consume the chain (no score), pop
## the safe open, and let trail decide what it was worth.
func _crack_safe() -> void:
	busy = true
	safe_cracked.emit()
	var played := selected.duplicate()
	selected.clear()
	selection_changed.emit()
	var center := Vector2.ZERO
	for card in played:
		center += card.position
	center /= played.size()
	_spawn_float_text("CRACKED!", center)
	var tw := create_tween().set_parallel(true)
	for i in played.size():
		var card: PlayingCard = played[i]
		var delay := 0.07 * i
		grid.erase(card.grid_pos)
		card.selected = false
		card.chain_index = 0
		tw.tween_property(card, "scale", Vector2.ZERO, 0.22) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(delay)
		tw.tween_callback(_play_pop.bind(1.1 + 0.1 * i)).set_delay(delay + 0.1)
	await tw.finished
	for card in played:
		card.queue_free()
	if suppress_refill:
		suppress_refill = false
		busy = false
		return
	await _fall_and_fill(false)
	busy = false
	if not has_playable_hand():
		dead_board.emit()


## Replaces a random plain card with the locked safe (trail heists).
func spawn_safe(combo: Array) -> void:
	var candidates: Array = []
	for p in grid:
		var card: PlayingCard = grid[p]
		if card.hazard == "" and not card.cursed and not card.washed \
				and card.mod == "" and card.objective == "" and not card.is_safe:
			candidates.append(p)
	if candidates.is_empty():
		return
	var cell: Vector2i = candidates.pick_random()
	var old: PlayingCard = grid[cell]
	var safe := PlayingCard.new()
	safe.is_safe = true
	safe.combo = combo
	safe.material = Themes.current_material()
	safe.grid_pos = cell
	safe.position = old.position
	grid[cell] = safe
	add_child(safe)
	old.queue_free()


## Marks two random plain cards as the key and the chest.
func spawn_key_and_chest() -> void:
	var candidates: Array = []
	for p in grid:
		var card: PlayingCard = grid[p]
		if card.hazard == "" and not card.cursed and not card.washed \
				and card.objective == "" and not card.is_safe:
			candidates.append(card)
	if candidates.size() < 2:
		return
	candidates.shuffle()
	candidates[0].objective = "key"
	candidates[1].objective = "chest"


## True if any card on the board carries the given objective mark.
func has_objective(kind: String) -> bool:
	for p in grid:
		if grid[p].objective == kind:
			return true
	return false


## Invalid submit: error sound, red flash, and a shake on the selected
## cards. The selection stays so the player can fix it.
func _reject_hand() -> void:
	_play_sound(SFX_ERROR, 1.0, -6.0)
	hand_rejected.emit()
	for card in selected:
		card.error_flash = true
		var origin := cell_center(card.grid_pos)
		var tw := create_tween()
		for off in [7.0, -7.0, 5.0, -5.0, 0.0]:
			tw.tween_property(card, "position:x", origin.x + off, 0.05)
	var flashed := selected.duplicate()
	await get_tree().create_timer(0.45, false).timeout
	for card in flashed:
		if is_instance_valid(card):
			card.error_flash = false


## Off-screen point the dealer throws from — bottom center, as if the
## dealer sits on the player's side of the table.
func deck_origin() -> Vector2:
	return Vector2(board_px_size().x * 0.5, board_px_size().y + PlayingCard.H * 2.0)


## Soft blob shadow that sits on the table at the card's landing slot,
## growing and darkening as the card descends onto it.
func _make_deal_shadow(dest: Vector2) -> Panel:
	var sh := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 1.0)
	box.set_corner_radius_all(12)
	sh.add_theme_stylebox_override("panel", box)
	sh.size = Vector2(PlayingCard.W + 12, PlayingCard.H + 12)
	sh.position = dest - sh.size / 2.0
	sh.pivot_offset = sh.size / 2.0
	sh.scale = Vector2(0.3, 0.3)
	sh.modulate = Color(1, 1, 1, 0.1)
	sh.z_index = 5  # above the table cards, below the flying card
	sh.visible = false
	add_child(sh)
	return sh


## The refill, presented as a dealer at a table. Two phases:
##   A) surviving cards settle down into the gaps below them;
##   B) new cards are flicked in one at a time from the deck origin,
##      arcing to their slots in top-to-bottom, left-to-right order.
## B starts when A is SETTLE_DEAL_OVERLAP complete. Any click skips the
## whole sequence and snaps the board to its final state.
## Game logic (which card lands in which slot) is identical to the old
## straight-drop version — the deck is still consumed column by column.
func _fall_and_fill(initial_deal: bool) -> void:
	if initial_deal:
		_play_sound(SFX_SWOOSH, 1.0, -8.0)
	var spd := 1.0 / maxf(refill_speed, 0.01)
	var t_settle := SETTLE_DURATION * spd
	var t_deal := DEAL_CARD_DURATION * spd
	var t_stagger := DEAL_STAGGER_DELAY * spd
	if initial_deal:
		t_stagger *= SETUP_STAGGER_SCALE

	# Compute settle moves and new-card slots (unchanged game logic).
	var settle_moves: Array = []
	var deals: Array = []
	for x in cols:
		var col_cards: Array = []
		for y in rows:
			var p := Vector2i(x, y)
			if grid.has(p):
				col_cards.append(grid[p])
				grid.erase(p)
		var target_y := rows - 1
		for i in range(col_cards.size() - 1, -1, -1):
			var card: PlayingCard = col_cards[i]
			var p := Vector2i(x, target_y)
			grid[p] = card
			card.grid_pos = p
			var dest := cell_center(p)
			if card.position != dest:
				settle_moves.append({"card": card, "pos": dest})
			target_y -= 1
		# A spent single deck stops mid-column, leaving top cells empty.
		for row in range(target_y, -1, -1):
			var data := draw_card()
			if data.is_empty():
				break
			var card := PlayingCard.new()
			card.material = Themes.current_material()
			card.rank = data.rank
			card.suit = data.suit
			card.cursed = data.get("cursed", false)
			card.mod = data.get("mod", "")
			var p := Vector2i(x, row)
			card.grid_pos = p
			grid[p] = card
			card.position = deck_origin()
			# Flicked off the deck: mid-spin, big (up in the air, close to
			# the screen), and drawn above every card already on the table.
			# All cards spin the same way; only the amount/speed varies.
			card.rotation = -TAU * randf_range(DEAL_SPIN_MIN, DEAL_SPIN_MAX)
			card.scale = Vector2(DEAL_START_SCALE, DEAL_START_SCALE)
			card.z_index = 20
			add_child(card)
			deals.append({"card": card, "pos": cell_center(p), "cell": p})
	if settle_moves.is_empty() and deals.is_empty():
		return
	# Presentation order for dealing: top-to-bottom, left-to-right.
	deals.sort_custom(func(a, b) -> bool:
		if a.cell.y != b.cell.y:
			return a.cell.y < b.cell.y
		return a.cell.x < b.cell.x)

	_refill_finals = settle_moves + deals
	_refill_active = true
	var tw := create_tween().set_parallel(true)
	_refill_tween = tw

	# Phase A — settle.
	var deal_base := 0.0
	if not settle_moves.is_empty():
		for m in settle_moves:
			tw.tween_property(m.card, "position", m.pos, t_settle) \
					.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_callback(settle_landed.emit).set_delay(t_settle)
		deal_base = t_settle * SETTLE_DEAL_OVERLAP

	# Phase B — staggered throws: high arc, spinning, shadow growing on
	# the table beneath; the card lands and finishes its spin on the felt.
	# Each card gets its own spin decay time and deceleration curve so
	# the rotation never looks machine-identical.
	var spin_curves: Array = [Tween.TRANS_CUBIC, Tween.TRANS_QUAD, Tween.TRANS_QUART]
	for i in deals.size():
		var d: Dictionary = deals[i]
		var card: PlayingCard = d.card
		var from: Vector2 = card.position
		var to: Vector2 = d.pos
		var ctrl := (from + to) * 0.5 + Vector2(0.0, -DEAL_ARC_HEIGHT)
		var delay := deal_base + i * t_stagger
		var sh := _make_deal_shadow(to)
		_refill_shadows.append(sh)
		var flight := func(t: float) -> void:
			if is_instance_valid(card):
				card.position = from.lerp(ctrl, t).lerp(ctrl.lerp(to, t), t)
		tw.tween_method(flight, 0.0, 1.0, t_deal) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(delay)
		# Stays big (high) through mid-flight, then drops onto the table.
		tw.tween_property(card, "scale", Vector2.ONE, t_deal) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(delay)
		# The spin outlives the landing, decaying to flat on the felt.
		var t_spin := t_deal + DEAL_SPIN_SETTLE * spd * randf_range(0.5, 1.6)
		tw.tween_property(card, "rotation", 0.0, t_spin) \
				.set_trans(spin_curves.pick_random()).set_ease(Tween.EASE_OUT) \
				.set_delay(delay)
		# Shadow: appears with the throw, swells and darkens as the card
		# comes down, and vanishes under the landed card.
		tw.tween_callback(func() -> void:
			if is_instance_valid(sh):
				sh.visible = true).set_delay(delay)
		tw.tween_property(sh, "scale", Vector2.ONE, t_deal) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(delay)
		tw.tween_property(sh, "modulate:a", 0.45, t_deal) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(delay)
		tw.tween_callback(func() -> void:
			if is_instance_valid(sh):
				sh.queue_free()).set_delay(delay + t_deal)
		tw.tween_callback(_on_card_dealt.bind(card)).set_delay(delay + t_deal)

	tw.finished.connect(func() -> void:
		if _refill_active:
			_refill_shadows.clear()
			_refill_active = false
			refill_done.emit())
	await refill_done


func _on_card_dealt(card: PlayingCard) -> void:
	if is_instance_valid(card):
		card.z_index = 0  # back on the table with everyone else
	card_dealt.emit(card)
	_play_sound(SFX_DEAL, randf_range(0.95, 1.15), -13.0)


## Completes the refill instantly: kill the tweens, snap every involved
## card to its final slot, and release the awaiting coroutine.
func _skip_refill() -> void:
	if not _refill_active:
		return
	if _refill_tween and _refill_tween.is_valid():
		_refill_tween.kill()
	for e in _refill_finals:
		if is_instance_valid(e.card):
			e.card.position = e.pos
			e.card.rotation = 0.0
			e.card.scale = Vector2.ONE
			e.card.z_index = 0
	for sh in _refill_shadows:
		if is_instance_valid(sh):
			sh.queue_free()
	_refill_shadows.clear()
	_refill_active = false
	refill_done.emit()


# --- Dead-board detection -------------------------------------------------

## True if any submittable hand can be chained on the current board.
## Every card in a chain must participate in the hand (no kickers), so a
## hand is playable only if its exact cards form an adjacent chain.
func has_playable_hand() -> bool:
	# Rank-group hands (pair, trips, quads, five, two pair, full house):
	# chains using at most two distinct ranks. Cursed cards can't start
	# or join any chain.
	for p in grid:
		var card: PlayingCard = grid[p]
		if card.cursed or card.is_safe or card.snake_tail:
			continue
		if _group_chain_exists(p, {p: true}, {card.rank: 1}):
			return true
	# 5-card flush chains.
	for p in grid:
		if grid[p].cursed or grid[p].is_safe or grid[p].snake_tail:
			continue
		if _suit_chain_exists(p, {p: true}, 1):
			return true
	# 5-card straight chains (any pick order along the chain).
	for p in grid:
		if grid[p].cursed or grid[p].is_safe or grid[p].snake_tail:
			continue
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
			if not grid.has(q) or visited.has(q) or grid[q].cursed or grid[q].is_safe or grid[q].snake_tail:
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
			if grid.has(q) and not visited.has(q) and not grid[q].cursed and not grid[q].is_safe and not grid[q].snake_tail \
					and grid[q].suit == suit:
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
			if not grid.has(q) or visited.has(q) or grid[q].cursed or grid[q].is_safe or grid[q].snake_tail:
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
	_play_sound(SFX_SHUFFLE, 1.0, -5.0)
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


## Applies deck-modifier effects from the current selection to a hand
## result: mult cards multiply the score (stacking), chip cards add
## bonus_chips. Pure on the result dict — headless-testable.
func _apply_card_mods(result: Dictionary) -> void:
	var mults := 0
	var chip_cards := 0
	for card in selected:
		if card.mod == "mult":
			mults += 1
		elif card.mod == "chip":
			chip_cards += 1
	if mults > 0:
		result.score = int(result.score * pow(mult_factor, mults))
	if chip_cards > 0:
		result["bonus_chips"] = chip_cards * chip_bonus


# --- Trail boss engine ----------------------------------------------------

const JACK_HP := 10
const QUEEN_STRIPES := 3
const COBRA_START_TAIL := 2

## Converts a board card into the room's boss.
func spawn_boss(kind: String) -> void:
	var candidates: Array = []
	for p in grid:
		var card: PlayingCard = grid[p]
		if card.hazard == "" and not card.cursed and not card.washed \
				and card.objective == "" and not card.is_safe and card.boss == "":
			candidates.append(p)
	if candidates.is_empty():
		return
	var cell: Vector2i = candidates.pick_random()
	var card: PlayingCard = grid[cell]
	card.boss = kind
	match kind:
		"jack":
			card.boss_hp = JACK_HP
			card.rank = randi_range(2, 14)
			card.suit = randi_range(0, 3)
		"queen":
			card.boss_hp = QUEEN_STRIPES
			card.rank = 12  # she IS a queen — pair her to sting her
			card.suit = randi_range(0, 3)
		"cobra":
			card.rank = randi_range(2, 14)
			card.suit = randi_range(0, 3)
			card.cobra_stack = []
			for i in COBRA_START_TAIL:
				_cobra_eat(card, true)


func _find_boss() -> PlayingCard:
	for p in grid:
		if grid[p].boss != "":
			return grid[p]
	return null


## The cobra eats an orthogonal neighbor: the head takes the victim's
## cell AND identity; the old head cell becomes a tail wall. `instant`
## skips animation (spawn-time setup eats; also headless-testable).
func _cobra_eat(head: PlayingCard, instant: bool) -> void:
	var dirs := HAZARD_DIRS.duplicate()
	dirs.shuffle()
	for d in dirs:
		var q: Vector2i = head.grid_pos + d
		if not grid.has(q):
			continue
		var victim: PlayingCard = grid[q]
		if victim.boss != "" or victim.snake_tail or victim.is_safe \
				or victim.objective != "":
			continue
		# Old head cell becomes a tail segment remembering this identity.
		head.cobra_stack.push_back({"rank": head.rank, "suit": head.suit})
		var tail := PlayingCard.new()
		tail.snake_tail = true
		tail.tail_order = head.cobra_stack.size()
		tail.material = Themes.current_material()
		tail.grid_pos = head.grid_pos
		tail.position = head.position if instant else head.position
		grid[head.grid_pos] = tail
		if is_inside_tree():
			add_child(tail)
		# Head takes the victim's cell and identity.
		var target_pos := victim.position
		grid[q] = head
		head.grid_pos = q
		head.rank = victim.rank
		head.suit = victim.suit
		if victim.is_inside_tree():
			victim.queue_free()
		else:
			victim.free()
		if instant or not is_inside_tree():
			head.position = target_pos
		else:
			var tw := create_tween()
			tw.tween_property(head, "position", target_pos, 0.35) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		return


## Head cleared with tail remaining: pop the newest segment, revert the
## head's identity to the previous meal, and stun him for a hand.
func _cobra_revert(head: PlayingCard) -> void:
	head.stunned = true
	var newest: Vector2i
	var best := -1
	for p in grid:
		if grid[p].snake_tail and grid[p].tail_order > best:
			best = grid[p].tail_order
			newest = p
	if best >= 0:
		var seg: PlayingCard = grid[newest]
		grid.erase(newest)
		if seg.is_inside_tree():
			seg.queue_free()
		else:
			seg.free()
	if not head.cobra_stack.is_empty():
		var identity: Dictionary = head.cobra_stack.pop_back()
		head.rank = identity.rank
		head.suit = identity.suit


## Per-hand boss behavior, after the hand fully resolves.
func tick_boss() -> void:
	var b := _find_boss()
	if b == null:
		return
	busy = true
	match b.boss:
		"jack":
			# Teleport: swap with a random ordinary card, new disguise.
			var candidates: Array = []
			for p in grid:
				var card: PlayingCard = grid[p]
				if card != b and card.boss == "" and not card.snake_tail \
						and not card.is_safe:
					candidates.append(p)
			if not candidates.is_empty():
				var cell: Vector2i = candidates.pick_random()
				var other: PlayingCard = grid[cell]
				var b_cell := b.grid_pos
				grid[cell] = b
				grid[b_cell] = other
				b.grid_pos = cell
				other.grid_pos = b_cell
				var tw := create_tween().set_parallel(true)
				tw.tween_property(b, "position", cell_center(cell), 0.35) \
						.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
				tw.tween_property(other, "position", cell_center(b_cell), 0.35) \
						.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
				await tw.finished
			b.rank = randi_range(2, 14)
			b.suit = randi_range(0, 3)
			_play_sound(SFX_SHUFFLE, 1.4, -10.0)
		"queen":
			# Alternating: spawn honey near the hive / relocate the honey.
			b.stunned = not b.stunned  # reuse as the rhythm flip
			if b.stunned:
				var near: Array = []
				var anywhere: Array = []
				for p in grid:
					var card: PlayingCard = grid[p]
					if card.boss == "" and not card.honey and card.hazard == "" \
							and not card.cursed and not card.is_safe:
						anywhere.append(card)
						var d: Vector2i = (p - b.grid_pos).abs()
						if maxi(d.x, d.y) <= 2:
							near.append(card)
				var pool: Array = near if not near.is_empty() else anywhere
				if not pool.is_empty():
					pool.pick_random().honey = true
					_play_sound(SFX_FLIP, 0.8, -10.0)
			else:
				var honeys: Array = []
				var plains: Array = []
				for p in grid:
					var card: PlayingCard = grid[p]
					if card.honey:
						honeys.append(card)
					elif card.boss == "" and card.hazard == "" \
							and not card.cursed and not card.is_safe:
						plains.append(card)
				plains.shuffle()
				for h in honeys:
					if plains.is_empty():
						break
					h.honey = false
					var target: PlayingCard = plains.pop_back()
					target.honey = true
		"cobra":
			if b.stunned:
				b.stunned = false
			else:
				_cobra_eat(b, false)
				_play_sound(SFX_FLIP, 0.5, -8.0)
				await get_tree().create_timer(0.4, false).timeout
	busy = false


# --- Trail hazard engine --------------------------------------------------

## Seeds `count` random plain cards with a hazard state (trail rooms).
func apply_room_hazards(kind: String, count: int) -> void:
	var candidates: Array = []
	for p in grid:
		var card: PlayingCard = grid[p]
		if card.hazard == "" and not card.cursed and not card.washed:
			candidates.append(card)
	candidates.shuffle()
	for i in mini(count, candidates.size()):
		var card: PlayingCard = candidates[i]
		card.hazard = kind
		match kind:
			"bomb":
				card.fuse = BOMB_FUSE
			"stone":
				card.stone_hits = STONE_HITS_START
			"wind":
				card.wind_dir = HAZARD_DIRS.pick_random()


## Occupied cells in a straight line from `from` (exclusive) to the edge.
func wind_line_cells(from: Vector2i, dir: Vector2i) -> Array:
	var out: Array = []
	var p := from + dir
	while p.x >= 0 and p.x < cols and p.y >= 0 and p.y < rows:
		if grid.has(p):
			out.append(p)
		p += dir
	return out


## Pure hazard bookkeeping for one hand tick: fires lose a rank (burning
## up below 2 and igniting orthogonal plain neighbors), bomb fuses drop.
## Returns {"burned": [cells], "ignited": [cells], "exploded": bool}.
## Board mutation only — no animation — so it's headless-testable.
func _tick_fire_and_bombs(tick_fire := true) -> Dictionary:
	var fires: Array = []
	if tick_fire:
		for p in grid:
			if grid[p].hazard == "fire":
				fires.append(p)
	var burned: Array = []
	for p in fires:
		grid[p].rank -= 1
		if grid[p].rank < 2:
			burned.append(p)
	var ignited: Array = []
	for p in burned:
		for d in HAZARD_DIRS:
			var q: Vector2i = p + d
			if not grid.has(q) or ignited.has(q):
				continue
			var card: PlayingCard = grid[q]
			if card.hazard == "" and not card.cursed and not card.washed:
				card.hazard = "fire"
				ignited.append(q)
	var exploded := false
	for p in grid:
		if grid[p].hazard == "bomb":
			grid[p].fuse -= 1
			if grid[p].fuse <= 0:
				exploded = true
	return {"burned": burned, "ignited": ignited, "exploded": exploded}


## Runs the per-hand hazard tick with animations: called by trail after
## a scoring hand fully resolves. Returns true if a bomb detonated.
func tick_hazards(tick_fire := true) -> bool:
	var any := false
	for p in grid:
		var hz: String = grid[p].hazard
		if hz == "fire" or hz == "bomb":
			any = true
			break
	if not any:
		return false
	busy = true
	var res := _tick_fire_and_bombs(tick_fire)
	var burned: Array = res.burned
	if not burned.is_empty():
		_play_sound(SFX_POPS.pick_random(), 0.75, -6.0)
		var btw := create_tween().set_parallel(true)
		var goners: Array = []
		for cell: Vector2i in burned:
			var card: PlayingCard = grid[cell]
			grid.erase(cell)
			goners.append(card)
			btw.tween_property(card, "scale", Vector2.ZERO, 0.25) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			btw.tween_property(card, "modulate", Color(1.6, 0.7, 0.4), 0.25)
		await btw.finished
		for card in goners:
			card.queue_free()
		await _fall_and_fill(false)
		if not has_playable_hand():
			dead_board.emit()
	busy = false
	return res.exploded


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
		await get_tree().create_timer(delay, false).timeout
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


