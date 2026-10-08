class_name Board
extends Node2D

## The card grid: dealing, chain selection, hand playing, gravity and refill.
##
## Selection is an ordered chain: after the first card, each new pick must be
## adjacent (8-way) to the previous one. Clicking a selected card removes it
## and everything picked after it.

signal selection_changed
signal hand_played(result: Dictionary)
signal shake_requested(strength: float)
signal hand_rejected
signal dead_board
signal card_dealt(card: PlayingCard)  # per-card audio hook, on deal arrival
signal settle_landed                  # fires once when Phase A lands
signal refill_done                    # internal: refill finished or skipped
signal safe_cracked                   # the combo chain opened the safe
signal boss_defeated                  # the room's boss is down
signal provision_targeted(card)       # aimed provision picked a card (null = holstered)
signal hand_committing                # a valid submit is about to resolve

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
# The drawn table under the cards (wood rim, felt, cell slots).
var table: TableSurface


func _init() -> void:
	table = TableSurface.new()
	table.retheme()
	add_child(table)
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
var gold_pay := 1               # $ per played gold card (POWER upgrades)
var holo_bonus := 50            # flat score per HOLO card in a hand (POWER upgrades)
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
# Broken stones can uncover gold cards in the rubble — everywhere.
const GOLD_FIND_CHANCE := 0.35
var gold_find_chance := GOLD_FIND_CHANCE  # the Chisel's POWER lifts it
# LAND RUSH rooms: cells a scored card has been cleared from (drawn
# as claim stakes under the cards).
var landrush_marks := {}
var landrush_active := false
# Trail rooms: each freshly dealt refill card may arrive already
# hazarded (set per room by trail; 0 everywhere else).
var refill_hazard_chance := 0.0
# Mid-room hazards (storm replenishes, purge trickles) queue here and
# ride in ON the next refill's dealt cards — never appearing out of
# nowhere on cards already sitting at the table.
var _pending_refill_hazards: Array = []


func queue_refill_hazards(kind: String, count: int) -> void:
	for i in count:
		_pending_refill_hazards.append(kind)
const HAZARD_KINDS := ["bomb", "fire", "wind", "stone", "water"]
# Ledger of every hazard ever put on this board, by kind. Purge rooms
# read cleared = spawned − still standing, which is exact no matter
# HOW a hazard left (played, burned out, gusted, shoved, blown up).
var hazards_spawned := {}

# Particle helper (set by main; null on detached test boards).
var fx: Fx

# --- Variant-room rules (trail) -------------------------------------------
signal community_changed
# TEXAS HOLD'EM: 5 shared cards; you pick exactly 2 hole cards.
var holdem_community: Array = []
# BLACKJACK (0 = poker rules): while the hole card is hidden this is
# the dealer's UP card; once he plays out, his full total.
var blackjack_target := 0
var blackjack_dealer_cards: Array = []  # the dealer's FULL hand (pre-computed)
var blackjack_hole_hidden := true       # second card face-down until you commit
var blackjack_revealed := 2             # how many of his cards the panel shows
var blackjack_presenting := false       # he's playing his hand out — table locked
var blackjack_facedown := false         # this table deals its refills face-down
# CRAZY 8s: every 8 on the board counts as wild.
var eights_wild := false
# Provisions: a targeted one waiting for its card, and the Rattlesnake
# Tonic's promise (applied by _apply_card_mods, consumed by play_hand).
var pending_provision := ""
var next_hand_mult := 1.0


func _select_cap() -> int:
	return 2 if not holdem_community.is_empty() else MAX_SELECT


## Deals (or re-deals) the hold'em community: five fresh shared cards.
func deal_community() -> void:
	holdem_community.clear()
	for i in 5:
		holdem_community.append({"rank": randi_range(2, 14),
				"suit": randi_range(0, 3)})
	community_changed.emit()


## Best 5-card hand from the 2 hole cards plus the community.
func holdem_result() -> Dictionary:
	return Poker.best_of(get_selected_data() + holdem_community)


## A fresh blackjack round: the dealer takes two cards — one on show,
## the hole card face-down until the player commits a hand.
func deal_blackjack_dealer() -> void:
	blackjack_dealer_cards = [
		{"rank": randi_range(2, 14), "suit": randi_range(0, 3)},
		{"rank": randi_range(2, 14), "suit": randi_range(0, 3)}]
	blackjack_hole_hidden = true
	blackjack_presenting = false
	blackjack_revealed = 2
	blackjack_target = Poker.blackjack_sum([blackjack_dealer_cards[0]])
	community_changed.emit()


## Presentation step: the dealer turns over his hole card.
func flip_hole() -> void:
	blackjack_hole_hidden = false
	blackjack_target = Poker.blackjack_sum(
			blackjack_dealer_cards.slice(0, blackjack_revealed))
	_play_sound(SFX_FLIP, 1.1, -8.0)
	community_changed.emit()


## Presentation step: one more of the dealer's drawn cards hits the
## felt. Returns his revealed total.
func reveal_dealer_card() -> int:
	blackjack_revealed = mini(blackjack_revealed + 1, blackjack_dealer_cards.size())
	blackjack_target = Poker.blackjack_sum(
			blackjack_dealer_cards.slice(0, blackjack_revealed))
	_play_sound(SFX_FLIP, randf_range(1.0, 1.2), -8.0)
	community_changed.emit()
	return blackjack_target


## Flips the table for a blackjack room: everything face-down except
## the four corner starting points; refills arrive face-down too.
## Hazards always burn through the card back.
func set_blackjack_facedown() -> void:
	blackjack_facedown = true
	for p in grid:
		var card: PlayingCard = grid[p]
		if card.hazard == "" and not card.is_safe and card.boss == "":
			card.face_down = true
	for corner in [Vector2i(0, 0), Vector2i(cols - 1, 0),
			Vector2i(0, rows - 1), Vector2i(cols - 1, rows - 1)]:
		if grid.has(corner):
			grid[corner].face_down = false


## One random face-down card turns over (blackjack rooms: one reveal
## per submitted hand).
func reveal_random_card() -> void:
	var hidden: Array = []
	for p in grid:
		if grid[p].face_down:
			hidden.append(grid[p])
	if hidden.is_empty():
		return
	var card: PlayingCard = hidden.pick_random()
	card.face_down = false
	_play_sound(SFX_FLIP, 1.2, -10.0)
	_fx(card.position, "sparks")


## Whatever card row the current variant wants shown in the panel.
## The dealer's drawn cards appear one by one as he plays them.
func panel_cards() -> Array:
	if not blackjack_dealer_cards.is_empty():
		return blackjack_dealer_cards.slice(0, blackjack_revealed)
	return holdem_community


func _fx(pos: Vector2, kind: String, tint := Color.WHITE, dir := Vector2.UP) -> void:
	if fx != null:
		fx.burst(pos, kind, tint, dir)


func confetti() -> void:
	_fx(Vector2(cols * CELL_W * 0.5, -20.0), "confetti")

const SFX_SELECTS := [
	preload("res://assets/sfx/card_select.wav"),
	preload("res://assets/sfx/card_pick.wav"),
]
const SFX_FLIP := preload("res://assets/sfx/card_flip.wav")
const SFX_SWOOSH := preload("res://assets/sfx/deal_swoosh.wav")
const SFX_ERROR := preload("res://assets/sfx/error.wav")
const SFX_POPS := [
	preload("res://assets/sfx/pop_1.wav"),
	preload("res://assets/sfx/pop_2.wav"),
	preload("res://assets/sfx/pop_3.wav"),
]
# Western Audio Bundle one-shots. Trail reaches these as Board.SFX_*.
const SFX_DEALS := [
	preload("res://assets/sfx/west/card_deliver_1.mp3"),
	preload("res://assets/sfx/west/card_deliver_2.mp3"),
]
const SFX_SHUFFLES := [
	preload("res://assets/sfx/west/cards_shuffle_1.mp3"),
	preload("res://assets/sfx/west/cards_shuffle_2.mp3"),
]
# UI click: the short card-pick tick, quiet and fixed-pitch (the
# bundle's "Button" sounds were musical stingers — too much).
const SFX_CLICK := preload("res://assets/sfx/card_pick.wav")
const SFX_COINS := [
	preload("res://assets/sfx/west/coins_1.mp3"),
	preload("res://assets/sfx/west/coins_2.mp3"),
]
const SFX_WINDS := [
	preload("res://assets/sfx/west/wind_1.mp3"),
	preload("res://assets/sfx/west/wind_2.mp3"),
]
const SFX_MATCHES := [
	preload("res://assets/sfx/west/match_1.mp3"),
	preload("res://assets/sfx/west/match_2.mp3"),
]
const SFX_KNIVES := [
	preload("res://assets/sfx/west/knife_1.mp3"),
	preload("res://assets/sfx/west/knife_2.mp3"),
]
const SFX_DYNAMITES := [
	preload("res://assets/sfx/west/dynamite_1.mp3"),
	preload("res://assets/sfx/west/dynamite_2.mp3"),
	preload("res://assets/sfx/west/dynamite_3.mp3"),
]
const SFX_SNAKES := [
	preload("res://assets/sfx/west/snake_1.mp3"),
	preload("res://assets/sfx/west/snake_2.mp3"),
	preload("res://assets/sfx/west/snake_3.mp3"),
]
const SFX_REVOLVERS := [
	preload("res://assets/sfx/west/revolver_1.mp3"),
	preload("res://assets/sfx/west/revolver_2.mp3"),
	preload("res://assets/sfx/west/revolver_3.mp3"),
	preload("res://assets/sfx/west/revolver_4.mp3"),
]
const SFX_SPITS := [
	preload("res://assets/sfx/west/spit_1.mp3"),
	preload("res://assets/sfx/west/spit_2.mp3"),
	preload("res://assets/sfx/west/spit_3.mp3"),
]
const SFX_SALOON_DOORS := [
	preload("res://assets/sfx/west/saloon_doors_1.mp3"),
	preload("res://assets/sfx/west/saloon_doors_2.mp3"),
]
const SFX_WHISKYS := [
	preload("res://assets/sfx/west/whisky_1.mp3"),
	preload("res://assets/sfx/west/whisky_2.mp3"),
]
const SFX_CROWS := [
	preload("res://assets/sfx/west/crow_1.mp3"),
	preload("res://assets/sfx/west/crow_2.mp3"),
]
const SFX_LOSS_HOWLS := [
	preload("res://assets/sfx/west/coyote_1.mp3"),
	preload("res://assets/sfx/west/coyote_2.mp3"),
	preload("res://assets/sfx/west/vulture.mp3"),
]
const SFX_BELL := preload("res://assets/sfx/west/bell.mp3")
const SFX_FUSE_START := preload("res://assets/sfx/west/fuse_start.mp3")
const SFX_FUSE_LOOP := preload("res://assets/sfx/west/fuse_loop.mp3")
const SFX_LAUGHS := [
	preload("res://assets/sfx/west/laugh_1.mp3"),
	preload("res://assets/sfx/west/laugh_2.mp3"),
	preload("res://assets/sfx/west/laugh_3.mp3"),
]
const SFX_REVOLVER_CHARGE := preload("res://assets/sfx/west/revolver_charge.mp3")
const SFX_STING_WIN := preload("res://assets/sfx/west/sting_win.mp3")
const SFX_STING_BOSS := preload("res://assets/sfx/west/sting_boss.mp3")
const SFX_STING_COMPLETE := preload("res://assets/sfx/west/sting_complete.mp3")


## `deal_facedown` deals the fresh board card-backs-up from the very
## first flick (blackjack tables).
func reset(deal_facedown := false) -> void:
	if busy:
		return
	locked = false
	busy = true
	suppress_refill = false
	refill_hazard_chance = 0.0
	_pending_refill_hazards.clear()
	hazards_spawned.clear()
	landrush_marks.clear()
	landrush_active = false
	queue_redraw()
	jack_bar = 0
	holdem_community.clear()
	blackjack_target = 0
	blackjack_dealer_cards.clear()
	blackjack_hole_hidden = true
	blackjack_presenting = false
	blackjack_revealed = 2
	blackjack_facedown = deal_facedown
	eights_wild = false
	PlayingCard.eights_wild = false
	pending_provision = ""
	next_hand_mult = 1.0
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


var _fuse_player: AudioStreamPlayer


## The dynamite is IMPOSSIBLE to ignore: while any bomb sits on the
## board, a burning-fuse sizzle plays loud on loop. Main calls this
## every frame with whether the table is actually live.
func update_fuse_loop(active: bool) -> void:
	var want := false
	if active and is_inside_tree():
		for p in grid:
			if grid[p].hazard == "bomb":
				want = true
				break
	if want:
		if _fuse_player == null:
			_fuse_player = AudioStreamPlayer.new()
			var s := SFX_FUSE_LOOP
			s.loop = true
			_fuse_player.stream = s
			_fuse_player.volume_db = -6.0
			_fuse_player.pitch_scale = 1.45
			_fuse_player.bus = "SFX"
			add_child(_fuse_player)
		if not _fuse_player.playing:
			_fuse_player.play()
	elif _fuse_player != null and _fuse_player.playing:
		_fuse_player.stop()


## Cards drawn from the shoe but not yet thrown (invisible, awaiting
## their turn in the deal) — the HUD stack still shows them on top,
## so each one visibly leaves as its throw begins.
func undealt_in_flight() -> int:
	var n := 0
	for p in grid:
		if not grid[p].visible:
			n += 1
	return n


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
	# A click during a refill skips the animation — and then falls
	# through, so the SAME click selects the card under it. No dead
	# clicks between hands.
	if _refill_active and event is InputEventMouseButton and event.pressed:
		_skip_refill()
	if busy or locked:
		return
	if pending_provision != "" and event is InputEventMouseButton and event.pressed:
		# An aimed provision eats the click: left picks the card, any
		# other button holsters it.
		if event.button_index == MOUSE_BUTTON_LEFT:
			var pick := _card_under_mouse(true)
			if pick != null:
				provision_targeted.emit(pick)
		else:
			pending_provision = ""
			provision_targeted.emit(null)
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
			player_clear()
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
		# Dragging back over the previous card undoes the last step —
		# except at the blackjack table, where a hit is binding.
		if blackjack_target == 0:
			_toggle_select(selected.back())
	elif not card.selected:
		if selected.size() < _select_cap() and _is_adjacent(card.grid_pos, selected.back().grid_pos):
			_toggle_select(card)


static func _is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	var d := (a - b).abs()
	return maxi(d.x, d.y) == 1


## Honey slows the hand: once a honey card is in the chain, only ONE
## more card may join after it.
func _honey_blocks_add() -> bool:
	for i in selected.size():
		if selected[i].honey:
			return selected.size() >= i + 2
	return false


func _toggle_select(card: PlayingCard) -> void:
	if card.cursed or card.snake_tail or card.hazard == "stone":
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
		if blackjack_target > 0:
			# A hit is binding — no take-backs at the blackjack table.
			_play_sound(SFX_FLIP, 0.7, -10.0)
			return
		# Remove this card and everything chained after it.
		var idx := selected.find(card)
		for i in range(selected.size() - 1, idx - 1, -1):
			selected[i].selected = false
			selected.remove_at(i)
		_play_sound(SFX_FLIP, 0.85, -8.0)
	else:
		if selected.size() >= _select_cap():
			return
		if _honey_blocks_add():
			_play_sound(SFX_FLIP, 0.7, -10.0)
			return
		if not selected.is_empty() and not _is_adjacent(card.grid_pos, selected.back().grid_pos):
			return
		if blackjack_target > 0:
			if not blackjack_hole_hidden or blackjack_presenting:
				return  # the dealer is playing his hand out
			if selected.is_empty() and card.face_down:
				# Every hand starts from a face-up card.
				_play_sound(SFX_FLIP, 0.7, -10.0)
				return
		card.selected = true
		selected.append(card)
		if blackjack_target > 0 and card.face_down:
			# The hit: flip it and find out.
			card.face_down = false
			_play_sound(SFX_FLIP, 1.2, -8.0)
			_fx(card.position, "sparks")
		else:
			# Random select sample; pitch climbs as the chain grows —
			# with a whisper of card lifting off the felt underneath.
			_play_sound(SFX_SELECTS.pick_random(),
					1.0 + 0.07 * (selected.size() - 1) + randf_range(-0.02, 0.02), -6.0)
			_play_sound(SFX_FLIP, 1.5, -18.0)
	_sync_chain_indices()
	_update_hand_validity()
	_update_safe_progress()
	selection_changed.emit()
	# The hit that breaks you: flip past 21 and the round resolves on
	# the spot — no submit needed to bust.
	if blackjack_target > 0 and blackjack_hole_hidden \
			and Poker.blackjack_sum(get_selected_data()) > 21:
		play_hand()


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


## Player-initiated clear (button, key, right-click): refused at the
## blackjack table, where a hit is binding.
func player_clear() -> void:
	if blackjack_target > 0 and not selected.is_empty():
		_play_sound(SFX_FLIP, 0.7, -10.0)
		return
	clear_selection()


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
	elif blackjack_target > 0:
		# Any chain can stand — hits are binding, busts self-resolve.
		valid = selected.size() >= 1 and blackjack_hole_hidden \
				and not blackjack_presenting
	elif not holdem_community.is_empty():
		valid = selected.size() == 2 and not holdem_result().is_empty()
	elif not selected.is_empty():
		valid = Poker.evaluate(get_selected_data()).playable
		for card in selected:
			if card.washed:
				valid = false
				break
	for card in selected:
		card.hand_valid = valid


## One Plus or Minus arrow landing on a card. Returns "none", "raised",
## "lowered", "joker" (an Ace lifted into THE JOKER) or "destroy" (a 2
## ground below the deuce; the caller removes it).
func boost_card(c: PlayingCard, arrow: String) -> String:
	if arrow == "plus":
		if c.joker:
			return "none"  # nothing ranks above the Joker
		if c.rank >= 14:
			# One step past the Ace: wild for good, ×2 on every hand.
			c.joker = true
			c.mod = "wild"
			return "joker"
		c.rank += 1
		return "raised"
	if c.joker:
		# One step down from the Joker is a plain Ace.
		c.joker = false
		c.mod = ""
		return "lowered"
	if c.rank <= 2:
		return "destroy"
	c.rank -= 1
	return "lowered"


func get_selected_data() -> Array:
	var out := []
	for card in selected:
		var d := {"rank": card.rank, "suit": card.suit}
		if card.mod == "wild" or (eights_wild and card.rank == 8):
			d["wild"] = true
		out.append(d)
	return out


func play_hand() -> void:
	if busy and _refill_active:
		# Submitting mid-deal fast-forwards the deal (busy clears
		# synchronously) so the hand goes straight in.
		_skip_refill()
	if busy or locked or selected.is_empty():
		return
	for card in selected:
		if card.is_safe:
			_crack_safe()
			return
	# The Doctor's pocket watch: remember the table exactly as it
	# stands before this hand rewrites it.
	hand_committing.emit()
	if undo_enabled:
		snapshot_state()
	var result: Dictionary
	if blackjack_target > 0:
		# BLACKJACK: your hits flip face-up, then the dealer turns his
		# hole card and draws until he beats you, ties you, or busts.
		if not blackjack_hole_hidden or blackjack_presenting:
			_reject_hand()  # between rounds: the dealer is still dealing
			return
		var total := Poker.blackjack_sum(get_selected_data())
		var outcome := "bust"
		if total <= 21:
			# His full hand is decided now; the reveal is paced by the
			# presentation (flip_hole / reveal_dealer_card).
			while Poker.blackjack_sum(blackjack_dealer_cards) < total:
				blackjack_dealer_cards.append(
						{"rank": randi_range(2, 14), "suit": randi_range(0, 3)})
			var dealer := Poker.blackjack_sum(blackjack_dealer_cards)
			if dealer > 21:
				outcome = "win"
			elif dealer == total:
				outcome = "push"
			else:
				outcome = "lose"
		blackjack_presenting = true
		var won := outcome == "win"
		result = {"name": "Twenty-One!" if total == 21 and won else "Blackjack Round",
				"base": 0, "pips": total, "score": (total * 3) if won else 0,
				"playable": true, "blackjack_win": won,
				"blackjack_outcome": outcome, "blackjack_player": total,
				"blackjack_dealer": Poker.blackjack_sum(blackjack_dealer_cards)}
	elif not holdem_community.is_empty():
		# HOLD'EM: exactly 2 hole cards; best 5 of 7 with the community.
		if selected.size() != 2:
			_reject_hand()
			return
		result = holdem_result()
		if result.is_empty():
			_reject_hand()
			return
	else:
		result = Poker.evaluate(get_selected_data())
		if not result.playable:
			_reject_hand()
			return
	_apply_card_mods(result)
	next_hand_mult = 1.0  # the tonic's promise is spent on this hand
	result["count"] = selected.size()
	# Objectives riding in the hand: key+chest pairs, duel bullets, and
	# the hold'em re-deal card.
	var has_key := false
	var has_chest := false
	for card in selected:
		match card.objective:
			"key":
				has_key = true
			"chest":
				has_chest = true
			"bullet":
				result["bullets_you"] = int(result.get("bullets_you", 0)) + 1
				if not result.has("bullet_points"):
					result["bullet_points"] = []
				result.bullet_points.append(card.global_position)
				card.objective = ""  # spent — it's about to pop
			"hisbullet":
				# Caught his bullet — the trail makes him shoot for it.
				result["bullets_his"] = int(result.get("bullets_his", 0)) + 1
				card.objective = ""
			"redeal":
				result["redeal"] = true
	if has_key and has_chest:
		result["chest_opened"] = true
	# Predict boss outcomes so trail can clear the room before spending
	# the hand.
	for card in selected:
		match card.boss:
			"jack":
				# The Jack shrugs off hands under his rising bar; a hand
				# that beats it deals its whole SCORE as damage.
				if jack_bar > 0 and result.score < jack_bar:
					result["jack_shrugged"] = true
				elif card.boss_hp <= result.score:
					result["boss_defeated"] = true
			"queen":
				if card.boss_hp <= result.score:
					result["boss_defeated"] = true
			"cobra":
				if card.cobra_body.is_empty():
					result["boss_defeated"] = true
	# Purge rooms watch this: hazards surviving the pops.
	result["hazards_left"] = predicted_hazards_left()
	busy = true

	var played := selected.duplicate()
	selected.clear()
	selection_changed.emit()

	var center := Vector2.ZERO
	for card in played:
		center += card.position
	center /= played.size()

	# Partition: payload effects are snapshotted before cells change.
	var poppers: Array = []
	var prisms: Array = []    # {"cell", "mod"} — Prism finishes spread their mod
	var arrows: Array = []    # {"cell", "dir", "mod"} — plus/minus aims
	var bumps: Array = []     # {"cell", "dir"} — bumper shoves
	var defeated_boss := false
	var boss_hits: Array = []  # wounded bosses catch a slug after the shoves
	var stays: Array = []     # METAL cards: they score but never clear
	for card in played:
		card.selected = false
		card.chain_index = 0
		card.hand_valid = false
		if card.boss == "jack" and result.get("jack_shrugged", false):
			# Too weak to wound him — he stays, and his tick will
			# reroll and teleport as usual.
			continue
		if card.boss == "jack" or card.boss == "queen":
			# Both royals bleed SCORE; only the Jack raises his bar.
			card.boss_hp -= result.score
			if card.boss == "jack":
				jack_bar += JACK_BAR_STEP
			boss_hits.append(card)  # the shot lands after the shoves
			if card.boss_hp <= 0:
				defeated_boss = true
				poppers.append(card)  # down he goes
			continue
		if card.boss == "cobra":
			if card.cobra_body.is_empty():
				defeated_boss = true
				poppers.append(card)
				boss_hits.append(card)
			else:
				_cobra_revert(card)
			continue
		if card.finish == "prism" and card.mod != "":
			prisms.append({"cell": card.grid_pos, "mod": card.mod})
		if card.mod in ["plus", "minus"]:
			arrows.append({"cell": card.grid_pos, "dir": card.boost_dir,
					"mod": card.mod})
		elif card.mod == "bumper":
			bumps.append({"cell": card.grid_pos, "dir": card.boost_dir})
		if card.finish == "metal" and card.wear_metal():
			stays.append(card)  # scored, but steel stays on the felt
			continue
		poppers.append(card)

	# The new goals watch what actually cleared: identities for the
	# roundups, cells for the land rush.
	var cleared_cards: Array = []
	var cleared_cells: Array = []
	for card in poppers + stays:
		# Metal counts as scored for roundups and chip seasoning, but
		# claims no plot: it never left its cell.
		cleared_cards.append({"rank": card.rank, "suit": card.suit,
				"mod": card.mod, "chip_lv": card.chip_level,
				"joker": card.joker})
		if card.finish != "metal":
			cleared_cells.append(card.grid_pos)
	result["cleared_cards"] = cleared_cards
	result["cleared_cells"] = cleared_cells
	for card in stays:
		# A staying chip card seasons in place, so its deck twin and the
		# table copy stay in step.
		if card.mod == "chip" and not card.joker:
			card.chip_level += 1
		var ring := create_tween()
		card.scale = Vector2.ONE * 1.12
		ring.tween_property(card, "scale", Vector2.ONE, 0.25) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for card in stays:
		if card.metal_wear == PlayingCard.METAL_PINS:
			# The cover comes off: a heavier clank and a spray of sparks.
			_play_sound(SFX_BELL, 1.1, -8.0)
			_fx(card.position, "sparks", Color(0.86, 0.9, 0.95))
		else:
			_play_sound(SFX_CLICK, 2.0, -9.0)  # a pin pings out

	# Stones are blockers now: every cleared card chips each stone
	# beside it, and a stone out of chips crumbles with the pops.
	var breaking := 0
	var broke: Array = []
	for card in poppers:
		for d in HAZARD_DIRS:
			var q: Vector2i = card.grid_pos + d
			if not grid.has(q) or grid[q].hazard != "stone":
				continue
			var st: PlayingCard = grid[q]
			if st.stone_hits <= 0:
				continue
			st.stone_hits -= 1
			_play_sound(SFX_KNIVES.pick_random(), randf_range(0.9, 1.1), -8.0)
			_fx(st.position, "rock")
			if st.stone_hits <= 0:
				breaking += 1
				broke.append(st)
	result["stones_broken"] = breaking
	for st in broke:
		poppers.append(st)

	hand_played.emit(result)

	# Bumpers shove their line one step BEFORE anything pops, so the
	# push visibly comes from the bumper while it still sits on the
	# felt; the far card can go off the table entirely (unscored). A
	# shoved-off BOSS pays a life and storms back onto the vacated cell.
	for bdata in bumps:
		var bumped := _apply_bump(bdata.cell, bdata.dir)
		if bumped.is_empty():
			continue
		_play_sound(SFX_FLIP, 0.9, -7.0)
		_fx(cell_center(bdata.cell + bdata.dir), "dust", Color.WHITE,
				Vector2(bdata.dir))
		var btw := create_tween().set_parallel(true)
		var shoved_off: Array = []
		var bounced_boss: PlayingCard = null
		for m in bumped:
			if m.off:
				m.card.z_index = 15
				btw.tween_property(m.card, "position",
						cell_center(m.to) + Vector2(bdata.dir) * 260.0, 0.3) \
						.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				btw.tween_property(m.card, "modulate:a", 0.0, 0.3)
				if m.card.boss != "":
					bounced_boss = m.card
				else:
					shoved_off.append(m.card)
					poppers.erase(m.card)  # gone over the edge, not popped
			else:
				btw.tween_property(m.card, "position", cell_center(m.to), 0.18) \
						.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await btw.finished
		for c in shoved_off:
			c.queue_free()
		if bounced_boss != null:
			# Off the table costs royalty a thousand points of their
			# score pool.
			bounced_boss.boss_hp -= 1000
			if bounced_boss.boss == "jack":
				jack_bar += JACK_BAR_STEP
			_play_sound(SFX_REVOLVERS.pick_random(), 1.0, -7.0)
			shake_requested.emit(6.0)
			if bounced_boss.boss_hp <= 0:
				defeated_boss = true
				bounced_boss.queue_free()
			else:
				var back: Vector2i = bdata.cell + bdata.dir
				grid[back] = bounced_boss
				bounced_boss.grid_pos = back
				bounced_boss.modulate = Color(1, 1, 1, 1)
				bounced_boss.z_index = 15
				_fx(cell_center(back), "dust")
				var rtw := create_tween()
				rtw.tween_property(bounced_boss, "position", cell_center(back), 0.3) \
						.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				rtw.tween_callback(func() -> void:
					if is_instance_valid(bounced_boss):
						bounced_boss.z_index = 0)

	# Every wound lands as a slug: the scored hand's pieces gather into
	# a bullet that zooms from the hand's center into the boss card.
	for i in boss_hits.size():
		var boss_card: PlayingCard = boss_hits[i]
		if not is_instance_valid(boss_card):
			continue
		await _fire_boss_slug(center, boss_card)

	var float_txt := "+%d" % result.score
	if result.get("bonus_chips", 0) > 0:
		float_txt += "  +%d CHIPS" % result.bonus_chips
	var base: int = int(result.get("base", 0))
	_spawn_float_text(float_txt, center, 3 if base >= 1200 else (2 if base >= 600 else 1))

	if not poppers.is_empty():
		var tw := create_tween().set_parallel(true)
		for i in poppers.size():
			var card: PlayingCard = poppers[i]
			var delay := 0.06 * i
			_fx(card.position, "rock" if card.hazard == "stone" else "pop",
					card.suit_color() if card.hazard != "stone" else Color.WHITE)
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
	if result.get("redeal", false):
		# The re-deal card refreshes the whole community.
		deal_community()
		_play_sound(SFX_SHUFFLES.pick_random(), 1.2, -8.0)

	# Mod payloads land on whatever survived the pops. Explosions spread
	# their mod through the neighborhood; plus/minus feed the card the
	# arrow pointed at.
	for bdata in prisms:
		var spread := false
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				var q: Vector2i = bdata.cell + Vector2i(dx, dy)
				if q == bdata.cell or not grid.has(q):
					continue
				var c: PlayingCard = grid[q]
				if c.mod == "" and not c.cursed and not c.is_safe \
						and c.boss == "" and not c.snake_tail \
						and c.hazard != "stone":
					c.mod = bdata.mod
					if c.mod in ["plus", "minus", "bumper"]:
						c.boost_dir = HAZARD_DIRS.pick_random()
					spread = true
		if spread:
			_play_sound(SFX_POPS.pick_random(), 1.5, -6.0)
			_fx(cell_center(bdata.cell), "smoke")
	for adata in arrows:
		var q: Vector2i = adata.cell + adata.dir
		if grid.has(q):
			var c: PlayingCard = grid[q]
			if not c.is_safe and c.boss == "" and not c.snake_tail \
					and not c.cursed and c.hazard != "stone":
				var outcome := boost_card(c, String(adata.mod))
				if outcome == "none":
					continue
				if outcome == "joker":
					_spawn_float_text("THE JOKER!", c.position)
				elif outcome == "destroy":
					# Ground below the deuce: the card wears away to
					# nothing and leaves the table, unscored.
					grid.erase(q)
					_play_sound(SFX_POPS.pick_random(), 0.7, -6.0)
					_fx(cell_center(q), "pop", c.suit_color())
					var vtw := create_tween()
					vtw.tween_property(c, "scale", Vector2.ZERO, 0.2) \
							.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
					vtw.tween_callback(c.queue_free)
					continue
				_play_sound(SFX_FLIP, 1.4 if adata.mod == "plus" else 0.7, -8.0)
				_fx(cell_center(q), "sparks")
	# A transition (room clear / level clear) suppresses the refill.
	var ending := suppress_refill
	suppress_refill = false

	if ending:
		busy = false
		return
	await _fall_and_fill(false)
	# Every stone ground to dust may leave gold behind — mining pays.
	if breaking > 0:
		for i in breaking:
			if randf() >= gold_find_chance:
				continue
			var plain: Array = []
			for p in grid:
				var c: PlayingCard = grid[p]
				if c.hazard == "" and c.mod == "" and not c.cursed \
						and not c.is_safe and c.boss == "" and not c.snake_tail:
					plain.append(c)
			if not plain.is_empty():
				var lucky: PlayingCard = plain.pick_random()
				lucky.mod = "gold"
				_spawn_float_text("GOLD!", lucky.position)
				_play_sound(SFX_COINS.pick_random(), 1.2, -8.0)
				_fx(lucky.position, "gold")
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
				and card.mod == "" and card.objective == "" and not card.is_safe and not card.hazard_proof():
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


class Slug extends Node2D:
	func _draw() -> void:
		# A gold slug drawn nose-right; rotation aims it.
		draw_rect(Rect2(-16, -4, 4, 8), Color("8a6d1f"))
		draw_rect(Rect2(-14, -4, 20, 8), Color("c9a227"))
		draw_circle(Vector2(6, 0), 4.0, Color("e8c547"))


## The scored hand's pieces gather into a slug that zooms into the
## boss card: flinch, sparks and a table shake on impact.
func _fire_boss_slug(from: Vector2, target: PlayingCard) -> void:
	if not is_inside_tree():
		return
	var s := Slug.new()
	s.z_index = 30
	add_child(s)
	s.position = from
	s.rotation = (target.position - from).angle()
	s.scale = Vector2(0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector2.ONE, 0.08)
	tw.parallel().tween_property(s, "position", target.position, 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	s.queue_free()
	if not is_instance_valid(target):
		return
	_play_sound(SFX_REVOLVERS.pick_random(), randf_range(0.95, 1.1), -7.0)
	_fx(target.position, "sparks")
	shake_requested.emit(5.0)
	if target.boss_hp > 0:
		# Still standing — he flinches under the hit. (A downed boss is
		# about to pop; leave his scale to the pop tween.)
		var ptw := create_tween()
		ptw.tween_property(target, "scale", Vector2(1.14, 1.14), 0.06) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ptw.tween_property(target, "scale", Vector2.ONE, 0.14) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Marks two random plain cards as the key and the chest.
func spawn_key_and_chest() -> void:
	var candidates: Array = []
	for p in grid:
		var card: PlayingCard = grid[p]
		if card.hazard == "" and not card.cursed and not card.washed \
				and card.objective == "" and not card.is_safe and not card.hazard_proof():
			candidates.append(card)
	if candidates.size() < 2:
		return
	candidates.shuffle()
	candidates[0].objective = "key"
	candidates[1].objective = "chest"


## Marks one random plain card as a key or chest (treasure respawns).
func spawn_objective(kind: String) -> void:
	var candidates: Array = []
	for p in grid:
		var card: PlayingCard = grid[p]
		if card.hazard == "" and not card.cursed and not card.washed \
				and card.objective == "" and not card.is_safe and not card.hazard_proof() \
				and card.boss == "" and not card.snake_tail:
			candidates.append(card)
	if not candidates.is_empty():
		var chosen: PlayingCard = candidates.pick_random()
		chosen.objective = kind


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


# The HUD's deck pile (global coords); main points this at the stack
# in the lower-left so every deal visibly comes from the player's deck.
# deal_anchor tracks the pile's current top card; deal_scale is that
# card's on-screen scale relative to the felt (0 = use the default).
var deal_anchor := Vector2.ZERO
var deal_scale := 0.0


## Where the dealer throws from: the HUD deck pile when main has
## anchored one, else a spot just past the near edge of the table rim.
func deck_origin() -> Vector2:
	if deal_anchor != Vector2.ZERO and is_inside_tree():
		return to_local(deal_anchor)
	return Vector2(board_px_size().x * 0.5, board_px_size().y + PlayingCard.H * 0.9)


## The deck itself, drawn as a small stack of card backs at the throw
## point while a deal is in flight.
class DeckStack extends Node2D:
	func _draw() -> void:
		for i in range(3, -1, -1):
			var off := Vector2(i * 2.5, i * 2.5)
			var r := Rect2(off + Vector2(-PlayingCard.W / 2.0, -PlayingCard.H / 2.0),
					Vector2(PlayingCard.W, PlayingCard.H))
			draw_rect(Rect2(r.position + Vector2(2, 4), r.size),
					Color(0, 0, 0, 0.25))
			draw_rect(r, Color("6e2620"))
			draw_rect(r.grow(-3), Color("8a3a30"), false, 2.0)
			draw_rect(r, Color("cab282"), false, 2.0)


var _deck_stack: DeckStack


## Shows the deck at the current throw point (created lazily). When
## main has anchored the throw to its own HUD stack, that stack IS the
## deck — no transient pile on top of it.
func _show_deck_stack() -> void:
	if deal_anchor != Vector2.ZERO:
		return
	if _deck_stack == null:
		_deck_stack = DeckStack.new()
		_deck_stack.z_index = 19  # under the flying cards
		add_child(_deck_stack)
	_deck_stack.position = deck_origin()
	_deck_stack.modulate = Color(1, 1, 1, 1)
	_deck_stack.visible = true


func _hide_deck_stack() -> void:
	if _deck_stack == null or not _deck_stack.visible:
		return
	if not is_inside_tree():
		_deck_stack.visible = false
		return
	var tw := _deck_stack.create_tween()
	tw.tween_property(_deck_stack, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		_deck_stack.visible = false)


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
			card.mod = migrate_mod(data.get("mod", ""))
			card.chip_level = int(data.get("chip_lv", 0))
			card.finish = PlayingCard.finish_of(data)
			if card.mod in ["plus", "minus", "bumper"]:
				card.boost_dir = HAZARD_DIRS.pick_random()
			# Danger off the deck: queued room hazards ride the deal
			# first, then the ambient per-card roll.
			if not initial_deal and not card.cursed and not card.hazard_proof() \
					and not _pending_refill_hazards.is_empty():
				_init_hazard(card, _pending_refill_hazards.pop_front())
			elif not initial_deal and not card.cursed and not card.hazard_proof() \
					and randf() < refill_hazard_chance:
				_init_hazard(card, HAZARD_KINDS.pick_random())
			# Blackjack tables deal their refills face-down.
			if blackjack_facedown and card.hazard == "":
				card.face_down = true
			var p := Vector2i(x, row)
			card.grid_pos = p
			grid[p] = card
			card.position = deck_origin()
			# Flicked off the deck: mid-spin, big (up in the air, close to
			# the screen), and drawn above every card already on the table.
			# All cards spin the same way; only the amount/speed varies.
			# Each waits INVISIBLE in the stack until its own throw, and
			# leaves back-up, flipping face-up mid-flight.
			card.rotation = -TAU * randf_range(DEAL_SPIN_MIN, DEAL_SPIN_MAX)
			# Launch at the HUD stack's exact card size, so the throw IS
			# the top card of the pile leaving it.
			var s0 := deal_scale if deal_scale > 0.0 else DEAL_START_SCALE
			card.scale = Vector2(s0, s0)
			card.z_index = 20
			card.visible = false
			if not card.face_down:
				card.deal_flip = 0.0
			add_child(card)
			deals.append({"card": card, "pos": cell_center(p), "cell": p})
	if settle_moves.is_empty() and deals.is_empty():
		return
	if not deals.is_empty():
		_show_deck_stack()
	# Presentation order for dealing: top-to-bottom, left-to-right.
	deals.sort_custom(func(a, b) -> bool:
		if a.cell.y != b.cell.y:
			return a.cell.y < b.cell.y
		return a.cell.x < b.cell.x)
	# Fresh cards may have landed hazarded (or as new targets): re-aim.
	_aim_spreaders()

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
		var to: Vector2 = d.pos
		var delay := deal_base + i * t_stagger
		var sh := _make_deal_shadow(to)
		_refill_shadows.append(sh)
		# The arc is measured at LAUNCH, from wherever the pile's top
		# card sits right then — the stack shrinks as it deals.
		var fl := {"from": card.position,
				"ctrl": (card.position + to) * 0.5 + Vector2(0.0, -DEAL_ARC_HEIGHT)}
		var flight := func(t: float) -> void:
			if is_instance_valid(card):
				var from: Vector2 = fl.from
				var ctrl: Vector2 = fl.ctrl
				card.position = from.lerp(ctrl, t).lerp(ctrl.lerp(to, t), t)
		# The card appears the moment IT leaves the stack...
		tw.tween_callback(func() -> void:
			if is_instance_valid(card):
				card.position = deck_origin()
				fl.from = card.position
				fl.ctrl = (fl.from + to) * 0.5 + Vector2(0.0, -DEAL_ARC_HEIGHT)
				card.visible = true).set_delay(delay)
		tw.tween_method(flight, 0.0, 1.0, t_deal) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(delay)
		# ...and flips from back to face through the first arc.
		if card.deal_flip < 1.0:
			tw.tween_property(card, "deal_flip", 1.0, t_deal * 0.55) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT) \
					.set_delay(delay + t_deal * 0.12)
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
			_hide_deck_stack()
			refill_done.emit())
	await refill_done


func _on_card_dealt(card: PlayingCard) -> void:
	if is_instance_valid(card):
		card.z_index = 0  # back on the table with everyone else
		card.visible = true
		card.deal_flip = 1.0
		if card.hazard != "":
			# A new hazard announces itself on landing: a burst of its
			# own element, unmistakably fresh trouble.
			match card.hazard:
				"fire":
					_fx(card.position, "embers")
					_play_sound(SFX_MATCHES.pick_random(), 1.0, -9.0)
				"water":
					_fx(card.position, "splash")
					_play_sound(SFX_FLIP, 0.6, -9.0)
				"bomb":
					_fx(card.position, "sparks")
					_play_sound(SFX_FUSE_START, 1.1, -12.0)
				"stone":
					_fx(card.position, "rock")
				"wind":
					_fx(card.position, "dust", Color.WHITE, Vector2(card.wind_dir))
	card_dealt.emit(card)
	_play_sound(SFX_DEALS.pick_random(), randf_range(0.95, 1.15), -13.0)


## Completes the refill instantly: kill the tweens, snap every involved
## card to its final slot, and release the awaiting coroutine.
func _skip_refill() -> void:
	if not _refill_active:
		return
	if _refill_tween and _refill_tween.is_valid():
		_refill_tween.kill()
	_hide_deck_stack()
	for e in _refill_finals:
		if is_instance_valid(e.card):
			e.card.position = e.pos
			e.card.rotation = 0.0
			e.card.scale = Vector2.ONE
			e.card.z_index = 0
			e.card.visible = true
			e.card.deal_flip = 1.0
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
	# Variant rooms judge hands by their own rules; the trail reshuffles
	# dead boards anyway, so never call these dead.
	if blackjack_target > 0 or not holdem_community.is_empty():
		return true
	# Rank-group hands (pair, trips, quads, five, two pair, full house):
	# chains using at most two distinct ranks. Cursed cards can't start
	# or join any chain.
	for p in grid:
		var card: PlayingCard = grid[p]
		if card.cursed or card.is_safe or card.snake_tail or card.hazard == "stone":
			continue
		if _group_chain_exists(p, {p: true}, {card.rank: 1}):
			return true
	# 5-card flush chains.
	for p in grid:
		if grid[p].cursed or grid[p].is_safe or grid[p].snake_tail \
				or grid[p].hazard == "stone":
			continue
		if _suit_chain_exists(p, {p: true}, 1):
			return true
	# 5-card straight chains (any pick order along the chain).
	for p in grid:
		if grid[p].cursed or grid[p].is_safe or grid[p].snake_tail \
				or grid[p].hazard == "stone":
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
			if not grid.has(q) or visited.has(q) or grid[q].cursed \
					or grid[q].is_safe or grid[q].snake_tail \
					or grid[q].hazard == "stone":
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
			if grid.has(q) and not visited.has(q) and not grid[q].cursed \
					and not grid[q].is_safe and not grid[q].snake_tail \
					and grid[q].hazard != "stone" \
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
			if not grid.has(q) or visited.has(q) or grid[q].cursed \
					or grid[q].is_safe or grid[q].snake_tail \
					or grid[q].hazard == "stone":
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
	_play_sound(SFX_SHUFFLES.pick_random(), 1.0, -5.0)
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
	var chip_pay := 0
	var gold_cards := 0
	var jokers := 0
	var holos := 0
	var negatives := 0
	for card in selected:
		# Finishes ride alongside the enhancement.
		if card.finish == "holo":
			holos += 1
		elif card.finish == "negative":
			negatives += 1
		if card.joker:
			jokers += 1  # wild, and his own ×2 on top
		elif card.mod == "mult":
			mults += 1
		elif card.mod == "chip":
			# Seasoned chips pay a full base step more per level.
			chip_pay += chip_bonus * (1 + card.chip_level)
		elif card.mod == "gold":
			gold_cards += 1
	if holos > 0:
		# HOLO: a flat bump to the hand BEFORE any multiplier, so Mult
		# cards, the Joker and the Tonic all multiply it too.
		result.score = int(result.score) + holo_bonus * holos
		result["holo_bonus"] = holo_bonus * holos
	if negatives > 0:
		# NEGATIVE: trail mode hands back a hand (or seconds) per card.
		result["negatives"] = negatives
	if mults > 0:
		result.score = int(result.score * pow(mult_factor, mults))
	if jokers > 0:
		result.score = int(result.score * pow(2.0, jokers))
	if chip_pay > 0:
		result["bonus_chips"] = chip_pay
	if gold_cards > 0:
		# Real money, straight to the pocket: $1 per gold card (more
		# once the Outfitter has gilded them).
		result["cash_earned"] = gold_cards * gold_pay
	if next_hand_mult != 1.0:
		# Rattlesnake Tonic: the promised double, shown in the preview
		# too. play_hand consumes the flag when the hand actually scores.
		result.score = int(result.score * next_hand_mult)
		result["tonic"] = true


# --- Provisions: board primitives (validity rules live in trail) ----------

## Canteen: strips hazard state, flood water and soak off one card.
func provision_clean(card: PlayingCard) -> void:
	card.hazard = ""
	card.washed = false
	card.incoming = ""
	card.fuse = 0
	card.water_level = 0
	card.queue_redraw()
	_play_sound(SFX_FLIP, 0.6, -8.0)
	_fx(card.position, "splash")


## Dynamite: one card leaves the table outright, then gravity settles.
# --- The pocket watch: whole-board undo snapshots -------------------------

## Every card property the watch must carry back. `hazard` sits
## before `fuse` so the fuse setter can place its ambient spark.
const UNDO_CARD_PROPS := ["rank", "suit", "mod", "finish", "metal_wear", "joker", "chip_level",
		"cursed", "washed", "hazard", "hazard_fresh", "fuse", "stone_hits",
		"water_level", "wind_dir", "next_dir", "boost_dir", "objective",
		"bullet_timer", "is_safe", "combo_progress", "boss", "boss_hp",
		"honey", "snake_tail", "stunned", "face_down"]

var undo_enabled := false  # trail arms it when the Doctor sits down
var undo_state := {}

# What the last hazard tick cost the table — trail turns these into
# rider HP damage (burnt-out flames sear, dynamite blasts).
var last_tick_burned := 0
var last_tick_detonated := 0


func has_undo() -> bool:
	return not undo_state.is_empty()


## Captures the full table before a hand resolves. Blackjack rounds
## pace themselves through a presentation and never rewind.
func snapshot_state() -> void:
	undo_state = build_state_snapshot()


## Applies any snapshot (the watch's, or a saved room) to the table.
func apply_state_snapshot(state: Dictionary) -> bool:
	undo_state = state
	return restore_state()


## The full table as pure data — every card, the deck, the ledgers.
## {} for blackjack rounds, which pace themselves and never rewind.
func build_state_snapshot() -> Dictionary:
	if blackjack_target > 0:
		return {}
	var cards := {}
	var cobra_order: Array = []
	for p in grid:
		var card: PlayingCard = grid[p]
		var props := {}
		for key in UNDO_CARD_PROPS:
			props[key] = card.get(key)
		props["combo"] = card.combo.duplicate()
		if card.boss == "cobra":
			props["cobra_stack"] = card.cobra_stack.duplicate(true)
			for seg in card.cobra_body:
				cobra_order.append(seg.grid_pos)
		cards[p] = props
	return {
		"cards": cards,
		"cobra_body": cobra_order,
		"deck": deck.duplicate(true),
		"hazards_spawned": hazards_spawned.duplicate(true),
		"pending_hazards": _pending_refill_hazards.duplicate(),
		"landrush": landrush_marks.duplicate(true),
		"jack_bar": jack_bar,
		"community": holdem_community.duplicate(true),
	}


## Rebuilds the table from the last snapshot — the hand un-happens.
## One rewind per snapshot: restoring consumes it.
func restore_state() -> bool:
	if undo_state.is_empty() or busy or locked:
		return false
	for card in grid.values():
		card.queue_free()
	grid.clear()
	selected.clear()
	selection_changed.emit()
	var mat := Themes.current_material()
	var head: PlayingCard = null
	var cards: Dictionary = undo_state.cards
	for p in cards:
		var props: Dictionary = cards[p]
		var card := PlayingCard.new()
		for key in UNDO_CARD_PROPS:
			if props.has(key):
				card.set(key, props[key])
		if bool(props.get("boom", false)):
			card.finish = "prism"  # snapshots from before the Prism
		if card.joker:
			# Saves from before the Joker moved above the Ace.
			card.rank = 14
			card.joker = true
			card.mod = "wild"
		card.combo = props["combo"].duplicate()
		card.grid_pos = p
		card.position = cell_center(p)
		card.material = mat
		add_child(card)
		grid[p] = card
		if card.boss == "cobra":
			head = card
			card.cobra_stack = props.get("cobra_stack", []).duplicate(true)
	if head != null:
		head.cobra_body = []
		for gp in undo_state.cobra_body:
			if grid.has(gp):
				head.cobra_body.append(grid[gp])
	deck = undo_state.deck.duplicate(true)
	hazards_spawned = undo_state.hazards_spawned.duplicate(true)
	_pending_refill_hazards = undo_state.pending_hazards.duplicate()
	landrush_marks = undo_state.landrush.duplicate(true)
	jack_bar = undo_state.jack_bar
	holdem_community = undo_state.community.duplicate(true)
	community_changed.emit()
	undo_state = {}
	queue_redraw()
	return true


## The Machine's laser: vaporizes every given card at once (the
## caller has already culled what the beam glances off), one teal
## flash per cell and a single refill after.
func laser_destroy(origin: Vector2, cards: Array) -> void:
	if busy or locked or cards.is_empty():
		return
	busy = true
	clear_selection()
	_play_sound(SFX_POPS.pick_random(), 1.7, -6.0)
	_play_sound(SFX_DYNAMITES.pick_random(), 2.2, -16.0, 0.05)
	# Beam flashes from the strike point out to each burned cell.
	var beams: Array = []
	for card in cards:
		if card.position.distance_to(origin) < 1.0:
			continue
		var beam := Line2D.new()
		beam.points = PackedVector2Array([origin, card.position])
		beam.width = 6.0
		beam.default_color = Color(0.5, 0.85, 0.77, 0.9)
		beam.z_index = 30
		add_child(beam)
		beams.append(beam)
	var tw := create_tween().set_parallel(true)
	for card in cards:
		if not grid.has(card.grid_pos) or grid[card.grid_pos] != card:
			continue
		grid.erase(card.grid_pos)
		_fx(card.position, "sparks", Color(0.5, 0.85, 0.77))
		_fx(card.position, "smoke")
		tw.tween_property(card, "scale", Vector2.ZERO, 0.22) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(card, "modulate", Color(0.6, 1.5, 1.35), 0.22)
	for beam in beams:
		tw.tween_property(beam, "modulate:a", 0.0, 0.3)
	shake_requested.emit(8.0)
	await tw.finished
	for card in cards:
		card.queue_free()
	for beam in beams:
		beam.queue_free()
	await _fall_and_fill(false)
	if not has_playable_hand():
		dead_board.emit()
	busy = false


## The Shell Game: two neighbors trade places, cards crossing in the
## air. Everything rides along — hazards, fuses, job pieces.
func provision_swap(a: PlayingCard, b: PlayingCard) -> void:
	if busy or locked:
		return
	if not grid.has(a.grid_pos) or grid[a.grid_pos] != a \
			or not grid.has(b.grid_pos) or grid[b.grid_pos] != b:
		return
	busy = true
	clear_selection()
	var pa := a.grid_pos
	var pb := b.grid_pos
	grid[pa] = b
	grid[pb] = a
	a.grid_pos = pb
	b.grid_pos = pa
	a.z_index = 16
	b.z_index = 15
	_play_sound(SFX_SHUFFLES.pick_random(), 1.35, -8.0)
	_play_sound(SFX_FLIP, 1.1, -10.0, 0.12)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(a, "position", cell_center(pb), 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "position", cell_center(pa), 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	a.z_index = 0
	b.z_index = 0
	_aim_spreaders()
	busy = false


func provision_destroy(card: PlayingCard) -> void:
	if busy or locked or not grid.has(card.grid_pos):
		return
	busy = true
	clear_selection()
	grid.erase(card.grid_pos)
	shake_requested.emit(7.0)
	_play_sound(SFX_POPS.pick_random(), 0.6, -4.0)
	_fx(card.position, "sparks")
	_fx(card.position, "smoke")
	var tw := create_tween()
	tw.tween_property(card, "scale", Vector2.ZERO, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished
	card.queue_free()
	await _fall_and_fill(false)
	busy = false


## Branding Iron / Gold Pan: burns an enhancement onto a plain card.
func provision_enhance(card: PlayingCard, mod: String) -> void:
	card.mod = mod
	if mod in ["plus", "minus", "bumper"]:
		card.boost_dir = HAZARD_DIRS.pick_random()
	card.queue_redraw()
	_play_sound(SFX_MATCHES.pick_random(), 1.2, -8.0)
	_fx(card.position, "sparks", Color("e8c547") if mod == "gold" else Color.WHITE)


## Barber's Razor: a fresh face on the same card (mods survive the cut).
func provision_reroll(card: PlayingCard, min_rank := 2) -> void:
	card.rank = randi_range(clampi(min_rank, 2, 14), 14)
	card.suit = randi_range(0, 3)
	card.queue_redraw()
	_play_sound(SFX_FLIP, 1.3, -8.0)
	_fx(card.position, "pop", card.suit_color())


## Fresh Deck: every plain and enhanced card is swept and re-dealt.
## Anchored things — hazards, bosses, safes, tails, treasure, bullets,
## curses, blackjack backs — hold their ground.
func provision_redeal() -> void:
	if busy or locked:
		return
	var going: Array = []
	for p in grid.keys():
		var c: PlayingCard = grid[p]
		if c.hazard == "" and c.boss == "" and not c.is_safe \
				and not c.snake_tail and c.objective == "" \
				and not c.cursed and not c.face_down and not c.honey:
			going.append(c)
	if going.is_empty():
		return
	busy = true
	clear_selection()
	_play_sound(SFX_SHUFFLES.pick_random(), 1.0, -5.0)
	var tw := create_tween().set_parallel(true)
	for i in going.size():
		var c: PlayingCard = going[i]
		grid.erase(c.grid_pos)
		tw.tween_property(c, "scale", Vector2.ZERO, 0.2) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN) \
				.set_delay(0.02 * i)
	await tw.finished
	for c in going:
		c.queue_free()
	await _fall_and_fill(false)
	busy = false


## Old save/deck mod ids map onto the current family.
static func migrate_mod(mod: String) -> String:
	match mod:
		"cash":
			return "gold"
		"boost":
			return "plus"
		"chipsplode":
			return "chip"  # the spread itself lives on the Prism finish now
	return mod


# --- Trail boss engine ----------------------------------------------------

# The Jack's life is a SCORE pool: qualifying hands deal their score
# as damage, and 2,500 total puts him down. The Queen carries a pool
# too — her defense is the honey and the wandering, not a bar.
const JACK_HP := 2500
const QUEEN_HP := 3000
const COBRA_START_TAIL := 2
# The Jack only respects strong hands: the hand that clears him must
# beat this bar to wound him, and every wound raises it.
const JACK_BAR_BASE := 30
const JACK_BAR_STEP := 25
var jack_bar := 0

## Converts a board card into the room's boss.
func spawn_boss(kind: String) -> void:
	var candidates: Array = []
	for p in grid:
		var card: PlayingCard = grid[p]
		if card.hazard == "" and not card.cursed and not card.washed \
				and card.objective == "" and not card.is_safe and not card.hazard_proof() and card.boss == "":
			candidates.append(p)
	if candidates.is_empty():
		return
	var cell: Vector2i = candidates.pick_random()
	var card: PlayingCard = grid[cell]
	card.boss = kind
	match kind:
		"jack":
			card.boss_hp = JACK_HP
			jack_bar = JACK_BAR_BASE
			card.rank = randi_range(2, 14)
			card.suit = randi_range(0, 3)
		"queen":
			card.boss_hp = QUEEN_HP
			card.rank = 12  # she IS a queen — pair her to sting her
			card.suit = randi_range(0, 3)
		"cobra":
			card.rank = randi_range(2, 14)
			card.suit = randi_range(0, 3)
			_play_sound(SFX_SNAKES.pick_random(), 1.0, -6.0)
			card.cobra_stack = []
			card.cobra_body = []
			# Grow the starting body along a chain of adjacent cells,
			# backtracking so a dead-end first step can't shorten the
			# tail; only a truly cramped board yields a shorter snake.
			var chain: Array = []
			for want in range(COBRA_START_TAIL, 0, -1):
				chain = _grow_cobra_chain([card.grid_pos], want)
				if not chain.is_empty():
					break
			for q: Vector2i in chain:
				var seg: PlayingCard = grid[q]
				card.cobra_stack.push_back({"rank": seg.rank, "suit": seg.suit})
				seg.hazard = ""
				seg.cursed = false
				seg.washed = false
				seg.mod = ""
				seg.honey = false
				seg.snake_tail = true
				card.cobra_body.append(seg)


## Random depth-first walk for the cobra's starting body: extends
## `path` (head first) with `want` more distinct eligible cells, each
## adjacent to the previous. Returns the body cells (head excluded) or
## [] if no chain of that length exists from here.
func _grow_cobra_chain(path: Array, want: int) -> Array:
	if want == 0:
		return path.slice(1)
	var dirs := HAZARD_DIRS.duplicate()
	dirs.shuffle()
	for d in dirs:
		var q: Vector2i = path[-1] + d
		if path.has(q) or not grid.has(q):
			continue
		var seg: PlayingCard = grid[q]
		if seg.boss != "" or seg.snake_tail or seg.is_safe \
				or seg.objective != "":
			continue
		var found: Array = _grow_cobra_chain(path + [q], want - 1)
		if not found.is_empty():
			return found
	return []


func _find_boss() -> PlayingCard:
	for p in grid:
		if grid[p].boss != "":
			return grid[p]
	return null


## The cobra SLITHERS: the head eats an orthogonal victim (taking its
## cell and identity), the whole body follows the path, and the cell
## vacated by the tail tip is left empty for the refill to fill.
## `instant` skips animation (spawn/testing). Returns true if he moved.
func _cobra_eat(head: PlayingCard, instant: bool) -> bool:
	# Consider every edible neighbor and slither toward open space, so
	# he doesn't casually coil himself into a corner.
	var candidates: Array = []
	for d in HAZARD_DIRS:
		var q: Vector2i = head.grid_pos + d
		if not grid.has(q):
			continue
		var victim: PlayingCard = grid[q]
		if victim.boss != "" or victim.snake_tail or victim.is_safe \
				or victim.objective != "":
			continue
		var openness := 0
		for d2 in HAZARD_DIRS:
			var n: Vector2i = q + d2
			if n == head.grid_pos or not grid.has(n):
				continue
			var nc: PlayingCard = grid[n]
			if not nc.snake_tail and nc.boss == "" and not nc.is_safe:
				openness += 1
		candidates.append({"cell": q, "openness": openness})
	if candidates.is_empty():
		return false
	candidates.shuffle()
	candidates.sort_custom(func(a, b) -> bool:
		return a.openness > b.openness)
	var target: Vector2i = candidates[0].cell
	var victim: PlayingCard = grid[target]
	head.cobra_stack.push_back({"rank": head.rank, "suit": head.suit})
	var new_rank: int = victim.rank
	var new_suit: int = victim.suit
	grid.erase(target)
	if victim.is_inside_tree():
		victim.queue_free()
	else:
		victim.free()
	# Slide the snake: head into the victim's cell, each segment into
	# the cell ahead of it. The tip's old cell is left EMPTY.
	var freed_cell := head.grid_pos
	grid.erase(head.grid_pos)
	grid[target] = head
	head.grid_pos = target
	head.rank = new_rank
	head.suit = new_suit
	var moves: Array = []  # {card, cell}
	for seg: PlayingCard in head.cobra_body:
		var seg_old := seg.grid_pos
		grid.erase(seg_old)
		grid[freed_cell] = seg
		seg.grid_pos = freed_cell
		moves.append({"card": seg, "cell": freed_cell})
		freed_cell = seg_old
	# freed_cell is now the vacated tail-tip cell — the refill's job.
	if instant or not is_inside_tree():
		head.position = cell_center(target)
		for m in moves:
			m.card.position = cell_center(m.cell)
	else:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(head, "position", cell_center(target), 0.35) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		for m in moves:
			tw.tween_property(m.card, "position", cell_center(m.cell), 0.35) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
	return true


## Head cleared with body remaining: the tail tip crumbles, the head's
## identity reverts to the previous meal, and he's stunned for a hand.
func _cobra_revert(head: PlayingCard) -> void:
	head.stunned = true
	_play_sound(SFX_SNAKES.pick_random(), 0.8, -8.0)
	_play_sound(SFX_REVOLVERS.pick_random(), 1.0, -9.0)
	if not head.cobra_body.is_empty():
		var tip: PlayingCard = head.cobra_body.pop_back()
		grid.erase(tip.grid_pos)
		if tip.is_inside_tree():
			tip.queue_free()
		else:
			tip.free()
	if not head.cobra_stack.is_empty():
		var identity: Dictionary = head.cobra_stack.pop_back()
		head.rank = identity.rank
		head.suit = identity.suit


## A tail segment leaves the board outside the normal revert path:
## unhook it from its head so the body never holds a
## freed card. The identity it carried is lost with it.
func _cobra_detach_segment(seg: PlayingCard) -> void:
	for p in grid:
		var head: PlayingCard = grid[p]
		if head.boss == "cobra" and head.cobra_body.has(seg):
			head.cobra_body.erase(seg)
			if not head.cobra_stack.is_empty():
				head.cobra_stack.pop_back()
			return


## Hazard cards that will survive this hand: not popped with the
## selection (kept stones stay put).
func predicted_hazards_left() -> int:
	var gone := {}
	for card in selected:
		if card.boss != "":
			continue
		gone[card.grid_pos] = true
	var left := 0
	for p in grid:
		if grid[p].hazard != "" and not gone.has(p):
			left += 1
	return left


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
			_play_sound(SFX_SHUFFLES.pick_random(), 1.4, -10.0)
		"queen":
			# She never sits still: EVERY turn she flits to a new cell
			# and leaves HONEY on the card that takes her old perch.
			# Cornered with nowhere to fly, she coats a neighbor instead.
			var dirs := HAZARD_DIRS.duplicate()
			dirs.shuffle()
			var flew := false
			for d in dirs:
				var q: Vector2i = b.grid_pos + d
				if not grid.has(q):
					continue
				var other: PlayingCard = grid[q]
				if other.boss != "" or other.is_safe or other.snake_tail:
					continue
				var b_cell := b.grid_pos
				grid[q] = b
				grid[b_cell] = other
				b.grid_pos = q
				other.grid_pos = b_cell
				var tw := create_tween().set_parallel(true)
				tw.tween_property(b, "position", cell_center(q), 0.3) \
						.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
				tw.tween_property(other, "position", cell_center(b_cell), 0.3) \
						.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
				await tw.finished
				if other.hazard == "" and not other.cursed and not other.honey:
					other.honey = true
					_play_sound(SFX_FLIP, 0.8, -10.0)
				flew = true
				break
			if not flew:
				for d in dirs:
					var q: Vector2i = b.grid_pos + d
					if not grid.has(q):
						continue
					var card: PlayingCard = grid[q]
					if card.boss == "" and not card.honey and card.hazard == "" \
							and not card.cursed and not card.is_safe:
						card.honey = true
						_play_sound(SFX_FLIP, 0.8, -10.0)
						break
		"cobra":
			if b.stunned:
				b.stunned = false
			else:
				var moved: bool = await _cobra_eat(b, false)
				if moved:
					_play_sound(SFX_SNAKES.pick_random(), randf_range(0.9, 1.1), -8.0)
					_fx(b.position, "dust")
					# The tail tip vacated a cell — deal into the gap.
					await _fall_and_fill(false)
	busy = false


# --- Trail hazard engine --------------------------------------------------

## Seeds `count` random plain cards with a hazard state (trail rooms).
## LAND RUSH: a claimed plot's whole slot fills gold under its card,
## rounded to match the table's slot corners.
static var _claim_box: StyleBoxFlat


func _draw() -> void:
	if not landrush_active:
		return
	if _claim_box == null:
		_claim_box = StyleBoxFlat.new()
		_claim_box.bg_color = Color(0.91, 0.77, 0.28, 0.38)
		_claim_box.set_corner_radius_all(9)
		_claim_box.border_color = Color(0.95, 0.82, 0.35, 0.85)
		_claim_box.set_border_width_all(2)
	for cell: Vector2i in landrush_marks:
		var c := cell_center(cell)
		_claim_box.draw(get_canvas_item(), Rect2(
				c - Vector2(PlayingCard.W / 2.0 + 5.0, PlayingCard.H / 2.0 + 5.0),
				Vector2(PlayingCard.W + 10.0, PlayingCard.H + 10.0)))


func spawned_count(kind: String) -> int:
	return int(hazards_spawned.get(kind, 0))


## Turns one card into a live hazard with its fields initialised.
func _init_hazard(card: PlayingCard, kind: String) -> void:
	hazards_spawned[kind] = spawned_count(kind) + 1
	card.hazard = kind
	card.hazard_fresh = true
	match kind:
		"bomb":
			card.fuse = BOMB_FUSE
		"stone":
			card.stone_hits = STONE_HITS_START
		"wind":
			card.wind_dir = HAZARD_DIRS.pick_random()
		"fire", "water":
			card.next_dir = HAZARD_DIRS.pick_random()


## Direction priority for a spreading hazard: the telegraphed intent
## first, the rest shuffled behind it — so the Weathervane's arrow is
## an honest promise whenever its target is takeable.
func _intent_dirs(card: PlayingCard) -> Array:
	var rest := HAZARD_DIRS.duplicate()
	rest.erase(card.next_dir)
	rest.shuffle()
	return [card.next_dir] + rest


func apply_room_hazards(kind: String, count: int) -> void:
	var candidates: Array = []
	for p in grid:
		var card: PlayingCard = grid[p]
		# Never on a boss, safe, tail, or job piece: those cards can't
		# be cleared the normal way, so a bomb there is a rigged loss.
		if card.hazard == "" and not card.cursed and not card.washed \
				and card.boss == "" and not card.is_safe \
				and not card.snake_tail and card.objective == "" \
				and not card.hazard_proof():
			candidates.append(card)
	candidates.shuffle()
	for i in mini(count, candidates.size()):
		_init_hazard(candidates[i], kind)
	_aim_spreaders()
	# The room announces its danger.
	if count > 0 and not candidates.is_empty():
		if kind == "bomb":
			_play_sound(SFX_FUSE_START, 1.0, -10.0)
		elif kind == "fire":
			_play_sound(SFX_MATCHES.pick_random(), 1.0, -8.0)


## The bumper's shove: pushes the contiguous run of cards next to
## `cell` one step along `dir`. Safes and the Cobra's coils are too
## heavy and block the whole push (the Jack and Queen ride the shove
## — off the edge costs them a life); a gap absorbs it; a run reaching
## the edge shoves its far card off the table. Pure grid mutation —
## returns the moves as {card, to, off} for the caller to animate
## (an "off" card is already out of the grid and must be freed).
func _apply_bump(cell: Vector2i, dir: Vector2i) -> Array:
	var run: Array = []
	var p := cell + dir
	while p.x >= 0 and p.x < cols and p.y >= 0 and p.y < rows and grid.has(p):
		var c: PlayingCard = grid[p]
		# Safes are bolted down and the Cobra is anchored by his coils;
		# the Jack and Queen shove like anyone else.
		if c.is_safe or c.boss == "cobra" or c.snake_tail:
			break
		run.append(p)
		p += dir
	if run.is_empty():
		return []
	var off_edge := not (p.x >= 0 and p.x < cols and p.y >= 0 and p.y < rows)
	if not off_edge and grid.has(p):
		return []  # shoved into something too heavy — nothing budges
	var moves: Array = []
	# Farthest card first so grid writes never collide.
	for i in range(run.size() - 1, -1, -1):
		var from: Vector2i = run[i]
		var card: PlayingCard = grid[from]
		grid.erase(from)
		if i == run.size() - 1 and off_edge:
			moves.append({"card": card, "to": from + dir, "off": true})
		else:
			grid[from + dir] = card
			card.grid_pos = from + dir
			moves.append({"card": card, "to": from + dir, "off": false})
	return moves


## True when every card on the table is burning — the fire has won.
func board_ablaze() -> bool:
	if grid.is_empty():
		return false
	for p in grid:
		if grid[p].hazard != "fire":
			return false
	return true


## Occupied cells in a straight line from `from` (exclusive) to the edge.
func wind_line_cells(from: Vector2i, dir: Vector2i) -> Array:
	var out: Array = []
	var p := from + dir
	while p.x >= 0 and p.x < cols and p.y >= 0 and p.y < rows:
		# Safes and metal are too heavy for the wind: it blows around them.
		if grid.has(p) and not grid[p].is_safe and not grid[p].hazard_proof():
			out.append(p)
		p += dir
	return out


## Pure hazard bookkeeping for one hand tick: each fire spreads to one
## orthogonal plain neighbor and loses a rank (burning up below 2),
## bomb fuses drop, water drips.
## Returns {"burned": [cells], "ignited": [cells], "exploded": bool}.
## Board mutation only — no animation — so it's headless-testable.
func _tick_fire_and_bombs(tick_fire := true) -> Dictionary:
	# EVERY directional card swings its arrow a quarter turn (clockwise)
	# each hand — plus/minus/bumper mods turn here; WIND turns at the
	# END of the tick, after it blows, so the direction the dust was
	# streaming is the direction the gust actually takes.
	for p in grid:
		if grid[p].mod in ["plus", "minus", "bumper"]:
			var bd: Vector2i = grid[p].boost_dir
			grid[p].boost_dir = Vector2i(-bd.y, bd.x)
	# The FLOOD: every water card rises one step per tick, filling in
	# four. A card already at the brim at the start of the tick POURS —
	# and what it pours into BECOMES A WATER CARD itself, one step
	# filled. One card type, making more of itself.
	var soaked: Array = []   # cells where water just started or rose
	var flooded: Array = []  # cells that just reached the brim
	var pourers: Array = []
	var risers: Array = []
	for p in grid:
		var c: PlayingCard = grid[p]
		if c.hazard != "water" or c.hazard_fresh:
			continue  # fresh arrivals start rising next round
		if c.water_level >= PlayingCard.WATER_FULL_LEVEL:
			pourers.append(p)
		else:
			risers.append(p)
	for p in pourers:
		for d in HAZARD_DIRS:
			var q: Vector2i = p + d
			if _victim_ok(q):
				grid[q].hazard = "water"
				grid[q].water_level = 1
				hazards_spawned["water"] = spawned_count("water") + 1
				soaked.append(q)
	for p in risers:
		var c: PlayingCard = grid[p]
		c.water_level += 1
		soaked.append(p)
		if c.water_level >= PlayingCard.WATER_FULL_LEVEL:
			flooded.append(p)
			# At the brim the face is gone — tooltip, preview, and green
			# tell all go quiet. It still plays blind, if you remember.
			c.washed = true
	var fires: Array = []
	if tick_fire:
		for p in grid:
			if grid[p].hazard == "fire" and not grid[p].hazard_fresh:
				fires.append(p)
	# Each fire spreads every tick: one random orthogonal neighbor that
	# isn't already burning (or otherwise off-limits) catches fire.
	# Fresh fires start spreading and burning down on the NEXT tick.
	var ignited: Array = []
	for p in fires:
		for d in _intent_dirs(grid[p]):
			var q: Vector2i = p + d
			if _victim_ok(q):
				grid[q].hazard = "fire"
				hazards_spawned["fire"] = spawned_count("fire") + 1
				ignited.append(q)
				break
	# Then the fire eats: rank drops, and below 2 the card burns up
	# (unscored) — the spreading already happened above.
	var burned: Array = []
	for p in fires:
		grid[p].rank -= 1
		if grid[p].rank < 2:
			burned.append(p)
	var exploded := false
	var detonated: Array = []
	for p in grid:
		if grid[p].hazard == "bomb" and not grid[p].hazard_fresh:
			grid[p].fuse -= 1
			if grid[p].fuse <= 0:
				exploded = true
				detonated.append(p)
	# WIND strips the table every round: each standing wind card blows
	# the first card in its facing direction clean off the board,
	# unscored — its direction just turned a quarter above. Safes,
	# bosses, and cobra coils are too heavy; they block the gust.
	var wind_blown: Array = []  # {"cell", "dir"} — caller animates & removes
	var blown_marks := {}
	for p in grid:
		var w: PlayingCard = grid[p]
		if w.hazard != "wind" or w.hazard_fresh:
			continue
		var q: Vector2i = p + w.wind_dir
		while q.x >= 0 and q.x < cols and q.y >= 0 and q.y < rows:
			if grid.has(q):
				var v: PlayingCard = grid[q]
				if not v.is_safe and v.boss == "" and not v.snake_tail \
						and not blown_marks.has(q):
					blown_marks[q] = true
					wind_blown.append({"cell": q, "dir": w.wind_dir})
				break  # whatever stands there stops the gust either way
			q += w.wind_dir
	# NOW the vanes swing a quarter for the next hand — the blow the
	# player just watched used exactly the direction on display.
	for p in grid:
		if grid[p].hazard == "wind":
			var wd: Vector2i = grid[p].wind_dir
			grid[p].wind_dir = Vector2i(-wd.y, wd.x)
	# Every hazard that sat this round out is seasoned for the next.
	for p in grid:
		grid[p].hazard_fresh = false
	_aim_spreaders()
	return {"burned": burned, "ignited": ignited, "exploded": exploded,
			"detonated": detonated, "soaked": soaked, "flooded": flooded,
			"blown": wind_blown}


## Hazards on the table from the deal fight from hand one — only
## mid-room arrivals sit out their first round. Trail calls this once
## the room's opening seeds are all placed.
func season_hazards() -> void:
	for p in grid:
		grid[p].hazard_fresh = false


## A cell fire can spread to or water can soak: on the board, plain,
## and unclaimed by anything special.
func _victim_ok(q: Vector2i) -> bool:
	if not grid.has(q):
		return false
	var c: PlayingCard = grid[q]
	# A damp card won't catch fire, and pours don't restart it either.
	return c.hazard == "" and not c.cursed and not c.washed \
			and c.boss == "" and not c.is_safe and not c.snake_tail \
			and c.objective == "" and c.water_level == 0 \
			and not c.hazard_proof()


## Points every fire/water card's next strike at a neighbor it can
## actually hit — no telegraphing (or whiffing) at cards that are
## already hazarded. Keeps a still-valid aim; re-rolls a spent one.
## The chosen victims are marked (card.incoming) so the Weathervane
## can show the effect creeping onto them.
func _aim_spreaders() -> void:
	for p in grid:
		grid[p].incoming = ""
	for p in grid:
		var card: PlayingCard = grid[p]
		if card.hazard == "fire":
			if not _victim_ok(p + card.next_dir):
				var dirs := HAZARD_DIRS.duplicate()
				dirs.shuffle()
				for d in dirs:
					if _victim_ok(p + d):
						card.next_dir = d
						break
			if _victim_ok(p + card.next_dir):
				grid[p + card.next_dir].incoming = "fire"
		elif card.water_level >= PlayingCard.WATER_FULL_LEVEL:
			# A full card pours EVERY way at once — warn all of them.
			for d in HAZARD_DIRS:
				if _victim_ok(p + d):
					grid[p + d].incoming = "water"
		elif card.hazard == "wind" and PlayingCard.show_hazard_intent:
			# The Weathervane also marks who the wind takes next hand —
			# without it, the direction (and the victim) stays a secret.
			var q: Vector2i = p + card.wind_dir
			while q.x >= 0 and q.x < cols and q.y >= 0 and q.y < rows:
				if grid.has(q):
					var v: PlayingCard = grid[q]
					if not v.is_safe and v.boss == "" and not v.snake_tail \
							and v.hazard == "" and v.incoming == "":
						v.incoming = "wind"
					break
				q += card.wind_dir


## Runs the per-hand hazard tick with animations: called by trail after
## a scoring hand fully resolves. Returns true if a bomb detonated.
func tick_hazards(tick_fire := true) -> bool:
	last_tick_burned = 0
	last_tick_detonated = 0
	var any := false
	for p in grid:
		var hz: String = grid[p].hazard
		if hz == "fire" or hz == "bomb" or hz == "water" or hz == "wind" \
				or grid[p].mod in ["plus", "minus", "bumper"]:
			any = true
			break
	if not any:
		return false
	busy = true
	var res := _tick_fire_and_bombs(tick_fire)
	# Splash only where the water NEWLY arrived or just hit the brim —
	# a quiet rise every hand would drown the table in noise.
	var splashes: Array = []
	for cell in res.soaked:
		if grid.has(cell) and (grid[cell].water_level == 1
				or grid[cell].water_level >= PlayingCard.WATER_FULL_LEVEL):
			splashes.append(cell)
	if not splashes.is_empty():
		_play_sound(SFX_FLIP, 0.6, -8.0)
		for cell in splashes:
			_fx(cell_center(cell), "splash")
	if not res.ignited.is_empty():
		_play_sound(SFX_MATCHES.pick_random(), randf_range(0.95, 1.1), -8.0)
		for cell in res.ignited:
			_fx(cell_center(cell), "embers")
	for cell in res.burned:
		_fx(cell_center(cell), "embers")
	var detonated: Array = res.get("detonated", [])
	if res.exploded:
		# A detonation is a blast, not a loss: the bomb takes itself
		# (and the rider's HP, which trail collects) and play goes on.
		_play_sound(SFX_DYNAMITES.pick_random(), 1.0, -3.0)
		shake_requested.emit(11.0)
		for cell: Vector2i in detonated:
			_fx(cell_center(cell), "smoke")
			_fx(cell_center(cell), "sparks")
	var burned: Array = res.burned
	last_tick_burned = burned.size()
	last_tick_detonated = detonated.size()
	var gone: Array = burned + detonated
	var blown: Array = res.get("blown", [])
	if not gone.is_empty() or not blown.is_empty():
		var btw := create_tween().set_parallel(true)
		var goners: Array = []
		if not gone.is_empty():
			_play_sound(SFX_POPS.pick_random(), 0.75, -6.0)
			for cell: Vector2i in gone:
				var card: PlayingCard = grid[cell]
				grid.erase(cell)
				goners.append(card)
				btw.tween_property(card, "scale", Vector2.ZERO, 0.25) \
						.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
				btw.tween_property(card, "modulate", Color(1.6, 0.7, 0.4), 0.25)
		if not blown.is_empty():
			# Clipped short with a fast fade — a gust, not a storm front.
			_play_sound(SFX_WINDS.pick_random(), randf_range(1.0, 1.2), -6.0, 0.0, 0.9)
			for b in blown:
				var cell: Vector2i = b.cell
				if not grid.has(cell):
					continue
				var card: PlayingCard = grid[cell]
				if card.snake_tail:
					_cobra_detach_segment(card)
				grid.erase(cell)
				goners.append(card)
				card.z_index = 15
				_fx(card.position, "dust", Color.WHITE, Vector2(b.dir))
				btw.tween_property(card, "position",
						card.position + Vector2(b.dir) * 1700.0, 0.45) \
						.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				btw.tween_property(card, "rotation", card.rotation + 2.2, 0.45)
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
	table.retheme()
	var mat := Themes.current_material()
	for card in grid.values():
		card.material = mat
		card.queue_redraw()


# --- Juice ----------------------------------------------------------------

## Tiered by how big the moment is: 0 = a side-payment trickle,
## 1 = an ordinary hand, 2 = a strong hand, 3 = the parade.
func _spawn_float_text(text: String, center: Vector2, tier := 1) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sizes := [26, 34, 44, 58]
	var colors := [Color("e8e0c8"), PlayingCard.GOLD, PlayingCard.GOLD,
			Color("f0a24a")]
	var fs: int = sizes[clampi(tier, 0, 3)]
	l.add_theme_font_size_override("font_size", fs)
	if fs >= 36 and FontLib.display != null:
		l.add_theme_font_override("font", FontLib.display)
	l.add_theme_color_override("font_color", colors[clampi(tier, 0, 3)])
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.size = Vector2(300, 60)
	l.position = center - Vector2(150, 30)
	l.z_index = 10
	l.pivot_offset = l.size / 2.0
	add_child(l)
	var tw := create_tween().set_parallel(true)
	if tier >= 2:
		l.scale = Vector2(1.35, 1.35)
		tw.tween_property(l, "scale", Vector2.ONE, 0.14) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var rise := 110.0 if tier >= 3 else 80.0
	tw.tween_property(l, "position:y", l.position.y - rise, 1.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.45).set_delay(0.65)
	tw.chain().tween_callback(l.queue_free)


func _play_pop(pitch: float) -> void:
	_play_sound(SFX_POPS.pick_random(), pitch, -5.0)


## Fire-and-forget one-shot player, with an optional delay. Safe on a
## detached board (headless tests): it just stays silent. A max_len
## clips long samples: play ~60% of the window, fade fast, stop.
func _play_sound(stream: AudioStream, pitch: float, volume_db: float, delay := 0.0,
		max_len := 0.0) -> void:
	if not is_inside_tree():
		return
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
	if max_len > 0.0:
		var tw := player.create_tween()
		tw.tween_interval(max_len * 0.6)
		tw.tween_property(player, "volume_db", -40.0, max_len * 0.4)
		tw.tween_callback(player.queue_free)


