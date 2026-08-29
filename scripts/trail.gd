class_name TrailMode
extends Node

## Trail mode: a betting roguelike run. Buy in for a chip stack, ride a
## 12-room tarot trail, wager chips on every room, sculpt your deck as
## you go. Bankruptcy ends the run; cashing out banks chips as cash.
## v1 scope: risk-tiered Normal rooms + shops. Bosses, room-rule
## variety, and card modifiers beyond Cursed come later (TRAIL_MODE.md).

const ROOMS_TOTAL := 12
const REGION_SIZE := 4

# Buy-in tables: [name, cash cost, starting chips, cash-out rate,
# target multiplier, blind multiplier]
const TABLES := [
	{"name": "PENNY ANTE", "cost": 0, "chips": 100, "rate": 1.0, "target_mult": 1.0, "blind_mult": 1.0},
	{"name": "TABLE STAKES", "cost": 50, "chips": 250, "rate": 1.5, "target_mult": 1.35, "blind_mult": 1.5},
	{"name": "HIGH ROLLER", "cost": 200, "chips": 500, "rate": 2.5, "target_mult": 1.75, "blind_mult": 2.0},
]

# Room risk tiers offered by the tarot draw.
const RISKS := [
	{"tarot": "THE SUN", "label": "Steady", "target_scale": 0.85, "odds": 1.0, "hands": 10, "bet_scale": 1.0},
	{"tarot": "WHEEL OF FORTUNE", "label": "Risky", "target_scale": 1.15, "odds": 1.5, "hands": 8, "bet_scale": 1.0},
	{"tarot": "THE TOWER", "label": "Dangerous", "target_scale": 1.5, "odds": 2.0, "hands": 7, "bet_scale": 1.5},
]

# Hazard rooms: better odds, a board full of trouble. From room 2 on,
# some play offers become hazard rooms.
const HAZARD_CHANCE := 0.35
const OBJECTIVE_CHANCE := 0.18   # heist/treasure rooms, from room 2 on
const AMBIENT_CHANCE := 0.12     # bonus safe or chest in plain rooms
const HAZARD_ROOMS := [
	{"tarot": "DEATH", "label": "Bomb", "hazard": "bomb", "odds": 2.0, "hands": 8, "count": 1},
	{"tarot": "THE DEVIL", "label": "Fire", "hazard": "fire", "odds": 2.0, "hands": 8, "count": 2},
	{"tarot": "THE CHARIOT", "label": "Wind", "hazard": "wind", "odds": 1.5, "hands": 8, "count": 2},
	{"tarot": "STRENGTH", "label": "Stone", "hazard": "stone", "odds": 1.5, "hands": 8, "count": 3},
	{"tarot": "TEMPERANCE", "label": "Water", "hazard": "water", "odds": 1.5, "hands": 8, "count": 2},
]

const BASE_TARGET := 300          # room 1 target before scaling
const TARGET_STEP := 110          # + per room
const REGION_BLINDS := [10, 25, 50]
const SHOP_CARD_PRICE := 40       # plain card
const SHOP_DUP_PRICE := 50        # exact duplicate of a card you own
const SHOP_MOD_PRICE := 80        # chip/mult enhanced card
const SHOP_REMOVE_PRICE := 30
const PICK_MOD_CHANCE := 0.10     # card picks: chance of an enhanced offer
const SHOP_MOD_CHANCE := 0.20     # shop slots: chance of an enhanced card
const FATE_KICKER := 15           # chips for trusting The Fool
const COMPLETE_RATE_BONUS := 1.5  # completion multiplies cash-out rate
const COMPLETE_PURSE := 100       # x (tier+1) cash on finishing

const META_PATH := "user://trail_meta.cfg"
const RUN_PATH := "user://trail_run.cfg"

# Relics: run-wide passives, max 5, bought at shops / found in chests.
const MAX_RELICS := 5
const RELIC_PRICES := [60, 120, 250]  # by rarity C/R/L
const RELICS := {
	"horseshoe": {"name": "Horseshoe", "rarity": 0, "desc": "+1 hand in every room"},
	"card_sleeve": {"name": "Card Sleeve", "rarity": 0, "desc": "Card picks offer 4 choices"},
	"snake_oil": {"name": "Snake Oil", "rarity": 0, "desc": "Shop prices -25%"},
	"tin_star": {"name": "Tin Star", "rarity": 0, "desc": "+10 chips each cleared room"},
	"rabbits_foot": {"name": "Rabbit's Foot", "rarity": 0, "desc": "Ambient loot twice as likely"},
	"bomb_badge": {"name": "Bomb Squad Badge", "rarity": 0, "desc": "Bombs start with +2 fuse"},
	"chisel": {"name": "Chisel", "rarity": 0, "desc": "Stones need one fewer use"},
	"fire_blanket": {"name": "Fire Blanket", "rarity": 1, "desc": "Fire only ticks every 2nd hand"},
	"magnifying_glass": {"name": "Magnifying Glass", "rarity": 1, "desc": "Soaked cards still show their suit"},
	"gold_tooth": {"name": "Gold Tooth", "rarity": 1, "desc": "Chip cards pay double"},
	"mirror_shades": {"name": "Mirror Shades", "rarity": 1, "desc": "Mult cards x2 instead of x1.5"},
	"second_wind": {"name": "Second Wind", "rarity": 1, "desc": "First failed room adds no cursed card"},
	"bankroll_clip": {"name": "Bankroll Clip", "rarity": 1, "desc": "Cash-out rate +0.25x"},
	"dowsing_rod": {"name": "Dowsing Rod", "rarity": 1, "desc": "Safe combos use only ranks 2-6"},
	"lucky_chip": {"name": "Lucky Chip", "rarity": 2, "desc": "10% chance a hand costs no hand"},
}

var main: Node2D  # set by main.gd before build()

# Meta (persists forever)
var cash := 0

# Run state
var run_active := false
var table_tier := 0
var chips := 0
var deck: Array = []          # [{rank, suit, cursed}]
var room_index := 0           # 0-based; next room to play
var in_room := false
var room_score := 0
var room_hands_left := 0
var room_target := 0
var room_goal := ""      # "" score target · "safe" heist · "chest" treasure
var room_combo: Array = []
var relics: Array = []   # relic ids held this run
var _second_wind_used := false
var _fire_tick_flip := false
var current_offer := {}
var stake := 0
var _offers: Array = []
var _fate_offer := {}

# UI
var buyin_layer: ColorRect
var tarot_layer: ColorRect
var bet_layer: ColorRect
var pick_layer: ColorRect
var shop_layer: ColorRect
var remove_layer: ColorRect
var end_layer: ColorRect
var _buyin_cash_label: Label
var _buyin_resume_btn: Button
var _tarot_info: Label
var _tarot_cards_box: Control
var _tarot_cashout_btn: Button
var _bet_info: Label
var _bet_slider: HSlider
var _bet_stake_label: Label
var _pick_box: Control
var _shop_info: Label
var _shop_box: Control
var _remove_grid: GridContainer
var _remove_info: Label
var _end_label: Label
var _shop_relic_btn: Button
var _shop_relic_id := ""
var _shop_burn_btn: Button
var _tarot_relics: Label


func _ready() -> void:
	_load_meta()
	main.board.safe_cracked.connect(on_safe_cracked)


# --- Persistence ----------------------------------------------------------

func _load_meta() -> void:
	var cf := ConfigFile.new()
	cf.load(META_PATH)
	cash = int(cf.get_value("meta", "cash", 0))


func _save_meta() -> void:
	if OS.get_environment("POKERPOP_SHOT") != "":
		return  # screenshot runs must not touch real saves
	var cf := ConfigFile.new()
	cf.set_value("meta", "cash", cash)
	cf.save(META_PATH)


func _save_run() -> void:
	if OS.get_environment("POKERPOP_SHOT") != "":
		return
	var cf := ConfigFile.new()
	cf.set_value("run", "active", run_active)
	cf.set_value("run", "tier", table_tier)
	cf.set_value("run", "chips", chips)
	cf.set_value("run", "room", room_index)
	var ranks := PackedInt32Array()
	var suits := PackedInt32Array()
	var curses := PackedInt32Array()
	var mods := PackedStringArray()
	for c in deck:
		ranks.append(c.rank)
		suits.append(c.suit)
		curses.append(1 if c.get("cursed", false) else 0)
		mods.append(c.get("mod", ""))
	cf.set_value("run", "ranks", ranks)
	cf.set_value("run", "suits", suits)
	cf.set_value("run", "curses", curses)
	cf.set_value("run", "mods", mods)
	var relic_arr := PackedStringArray()
	for id in relics:
		relic_arr.append(id)
	cf.set_value("run", "relics", relic_arr)
	cf.set_value("run", "second_wind_used", _second_wind_used)
	cf.save(RUN_PATH)


func _clear_run_save() -> void:
	run_active = false
	var cf := ConfigFile.new()
	cf.set_value("run", "active", false)
	cf.save(RUN_PATH)


func _load_run() -> bool:
	var cf := ConfigFile.new()
	if cf.load(RUN_PATH) != OK or not cf.get_value("run", "active", false):
		return false
	table_tier = int(cf.get_value("run", "tier", 0))
	chips = int(cf.get_value("run", "chips", 0))
	room_index = int(cf.get_value("run", "room", 0))
	var ranks: PackedInt32Array = cf.get_value("run", "ranks", PackedInt32Array())
	var suits: PackedInt32Array = cf.get_value("run", "suits", PackedInt32Array())
	var curses: PackedInt32Array = cf.get_value("run", "curses", PackedInt32Array())
	var mods: PackedStringArray = cf.get_value("run", "mods", PackedStringArray())
	deck.clear()
	for i in ranks.size():
		deck.append({"rank": ranks[i], "suit": suits[i],
				"cursed": curses[i] == 1,
				"mod": mods[i] if i < mods.size() else ""})
	relics.clear()
	for id in cf.get_value("run", "relics", PackedStringArray()):
		relics.append(String(id))
	_second_wind_used = cf.get_value("run", "second_wind_used", false)
	run_active = true
	return true


# --- Run math -------------------------------------------------------------

func _table() -> Dictionary:
	return TABLES[table_tier]


func has_relic(id: String) -> bool:
	return relics.has(id)


## Shop pricing with Snake Oil applied.
func _price(base: int) -> int:
	return int(base * 0.75) if has_relic("snake_oil") else base


## Pushes relic-driven settings into the board/card layer. Call at run
## start, on load, and whenever a relic is gained.
func _apply_relic_effects() -> void:
	main.board.chip_bonus = Board.CHIP_BONUS * (2 if has_relic("gold_tooth") else 1)
	main.board.mult_factor = 2.0 if has_relic("mirror_shades") else Board.MULT_FACTOR
	PlayingCard.washed_show_suit = has_relic("magnifying_glass")


func _gain_relic(id: String) -> void:
	if relics.size() >= MAX_RELICS or relics.has(id):
		return
	relics.append(id)
	_apply_relic_effects()
	_save_run()


## A random relic id the player doesn't own yet, or "" if none left.
func _unowned_relic() -> String:
	var pool: Array = []
	for id in RELICS:
		if not relics.has(id):
			pool.append(id)
	return pool.pick_random() if not pool.is_empty() else ""


func _blind_for(room: int) -> int:
	var region: int = clampi(room / REGION_SIZE, 0, REGION_BLINDS.size() - 1)
	return int(REGION_BLINDS[region] * _table().blind_mult)


func _target_for(room: int, risk: Dictionary) -> int:
	var base := BASE_TARGET + TARGET_STEP * room
	return int(base * risk.target_scale * _table().target_mult)


func _fresh_deck() -> Array:
	var d: Array = []
	for s in 4:
		for r in range(2, 15):
			d.append({"rank": r, "suit": s, "cursed": false})
	return d


func _cashout_value(rate_bonus := 1.0) -> int:
	var rate: float = _table().rate + (0.25 if has_relic("bankroll_clip") else 0.0)
	return int(chips * rate * rate_bonus / 10.0)


func _random_card_offer(mod_chance := PICK_MOD_CHANCE) -> Dictionary:
	var mod := ""
	if randf() < mod_chance:
		mod = "mult" if randf() < 0.5 else "chip"
	# Half the time, offer an exact duplicate of a card already owned
	# (the Five of a Kind / Flushed Five enabler).
	if randf() < 0.5 and not deck.is_empty():
		var src: Dictionary = deck.pick_random()
		if not src.get("cursed", false):
			return {"rank": src.rank, "suit": src.suit, "cursed": false, "mod": mod}
	return {"rank": randi_range(2, 14), "suit": randi_range(0, 3),
			"cursed": false, "mod": mod}


# --- Flow: entry ----------------------------------------------------------

func open_buyin() -> void:
	main.menu_layer.visible = false
	main.menu_open = false
	_hide_all()
	_buyin_cash_label.text = "CASH  $%d" % cash
	_buyin_resume_btn.visible = _has_saved_run()
	buyin_layer.visible = true


func _has_saved_run() -> bool:
	var cf := ConfigFile.new()
	return cf.load(RUN_PATH) == OK and cf.get_value("run", "active", false)


func _start_run(tier: int) -> void:
	var cost: int = TABLES[tier].cost
	if cash < cost:
		return
	cash -= cost
	_save_meta()
	main.menu_open = false
	table_tier = tier
	chips = TABLES[tier].chips
	deck = _fresh_deck()
	room_index = 0
	relics.clear()
	_second_wind_used = false
	_fire_tick_flip = false
	run_active = true
	main.score = 0
	_apply_relic_effects()
	_save_run()
	_show_tarot()


func _resume_run() -> void:
	if _load_run():
		main.score = 0
		_apply_relic_effects()
		_show_tarot()


func back_to_menu() -> void:
	_hide_all()
	main._open_menu()


# --- Flow: tarot (between rooms) -----------------------------------------

func _show_tarot() -> void:
	_hide_all()
	in_room = false
	main.game_started = false
	main.board.locked = true
	# Bankruptcy check against the coming room's blind.
	if chips < _blind_for(room_index):
		_end_run("BUSTED OUT",
				"The table minimum is %d chips and you're down to %d.\nThe trail ends here." % [_blind_for(room_index), chips],
				0)
		return
	_offers = _make_offers()
	_fate_offer = _make_one_offer(true)
	_render_tarot()
	tarot_layer.visible = true


func _make_offers() -> Array:
	var offers: Array = []
	# A shop appears as one of the three choices in the middle-ish of
	# each region (and never two shops at once).
	var want_shop := room_index % REGION_SIZE == 2
	var risk_pool := RISKS.duplicate()
	risk_pool.shuffle()
	for i in 3:
		if want_shop and i == 1:
			offers.append({"kind": "shop", "tarot": "THE HERMIT"})
		else:
			offers.append(_make_one_offer(false, risk_pool[i % risk_pool.size()]))
	return offers


func _make_one_offer(random_risk: bool, risk: Dictionary = {}) -> Dictionary:
	if random_risk:
		if randf() < 0.15:
			return {"kind": "shop", "tarot": "THE HERMIT"}
		risk = RISKS.pick_random()
	var offer := {
		"kind": "play",
		"tarot": risk.tarot,
		"label": risk.label,
		"target": _target_for(room_index, risk),
		"hands": int(risk.hands),
		"odds": float(risk.odds),
		# Never demand more than the player holds (forces all-in instead).
		"min_bet": mini(int(_blind_for(room_index) * risk.bet_scale), chips),
	}
	# Some offers turn hazardous: risky-tier target, hazard on the board.
	if room_index >= 1 and randf() < HAZARD_CHANCE:
		var hz: Dictionary = HAZARD_ROOMS.pick_random()
		offer.tarot = hz.tarot
		offer.label = hz.label
		offer.odds = float(hz.odds)
		offer.hands = int(hz.hands)
		offer.target = _target_for(room_index, RISKS[1])
		offer.min_bet = mini(_blind_for(room_index), chips)
		offer["hazard"] = hz.hazard
		var count: int = hz.count
		if hz.hazard == "bomb" and room_index >= REGION_SIZE * 2:
			count += 1  # late-trail bomb rooms mean business
		offer["hazard_count"] = count
	elif room_index >= 1 and randf() < OBJECTIVE_CHANCE:
		# Objective rooms: no score target — do the job to clear.
		if randf() < 0.5:
			offer.tarot = "THE MOON"
			offer.label = "Heist"
			offer.odds = 2.0
			offer["goal"] = "safe"
		else:
			offer.tarot = "THE STAR"
			offer.label = "Treasure"
			offer.odds = 1.5
			offer["goal"] = "chest"
		offer.hands = 8
		offer.target = 0
		offer.min_bet = mini(_blind_for(room_index), chips)
	return offer


func _render_tarot() -> void:
	for child in _tarot_cards_box.get_children():
		child.queue_free()
	var region := room_index / REGION_SIZE + 1
	_tarot_info.text = "ROOM %d / %d   ·   REGION %d   ·   CHIPS %d   ·   DECK %d cards" \
			% [room_index + 1, ROOMS_TOTAL, region, chips, deck.size()]
	if relics.is_empty():
		_tarot_relics.text = ""
	else:
		var names := PackedStringArray()
		for id in relics:
			names.append(RELICS[id].name)
		_tarot_relics.text = "RELICS:  " + "  ·  ".join(names)
	_tarot_cashout_btn.text = "CASH OUT — TAKE $%d" % _cashout_value()
	for i in _offers.size():
		var offer: Dictionary = _offers[i]
		var b := _tarot_card_button(offer, 300 + i * 330)
		var picked := offer
		b.pressed.connect(func() -> void:
			_choose_offer(picked, false))
	# The Fool: face-down fate.
	var fool: Button = main._button(_tarot_cards_box, "", Vector2(300 + 3 * 330, 0), Vector2(300, 380))
	fool.text = "THE FOOL\n\n?\n\nLet fate decide\n(+%d chips)" % FATE_KICKER
	fool.add_theme_font_size_override("font_size", 22)
	fool.pressed.connect(func() -> void:
		_choose_offer(_fate_offer, true))


func _tarot_card_button(offer: Dictionary, x: float) -> Button:
	var b: Button = main._button(_tarot_cards_box, "", Vector2(x, 0), Vector2(300, 380))
	b.add_theme_font_size_override("font_size", 22)
	if offer.kind == "shop":
		b.text = "THE HERMIT\n\nSHOP\n\nBuy cards\nBurn cards\n\nNo bet"
	else:
		var hazard_line := ""
		if offer.has("hazard"):
			hazard_line = "\nHAZARD: %d × %s" % [offer.hazard_count,
					String(offer.hazard).to_upper()]
		var goal_line := "Target  %d" % offer.target
		if offer.get("goal", "") == "safe":
			goal_line = "CRACK THE SAFE"
		elif offer.get("goal", "") == "chest":
			goal_line = "OPEN THE CHEST"
		b.text = "%s\n\n%s room%s\n%s\nHands  %d\nOdds  %s\n\nMin bet  %d" % [
			offer.tarot, offer.label, hazard_line, goal_line, offer.hands,
			_odds_text(offer.odds), offer.min_bet]
	return b


func _odds_text(odds: float) -> String:
	if is_equal_approx(odds, 1.0):
		return "1 : 1"
	if is_equal_approx(odds, 1.5):
		return "3 : 2"
	return "2 : 1"


func _choose_offer(offer: Dictionary, from_fate: bool) -> void:
	if from_fate:
		chips += FATE_KICKER
	current_offer = offer
	tarot_layer.visible = false
	if offer.kind == "shop":
		_show_shop()
	else:
		_show_bet()


func _do_cashout() -> void:
	var payout := _cashout_value()
	cash += payout
	_save_meta()
	_clear_run_save()
	_end_run("CASHED OUT", "You walk away with $%d.\nThe trail will be waiting." % payout, payout)


# --- Flow: betting --------------------------------------------------------

func _show_bet() -> void:
	_hide_all()
	var o := current_offer
	_bet_info.text = "%s — %s room\nTarget %d in %d hands   ·   odds %s\nYour chips: %d   ·   minimum bet: %d" % [
		o.tarot, o.label, o.target, o.hands, _odds_text(o.odds), chips, o.min_bet]
	_bet_slider.min_value = o.min_bet
	_bet_slider.max_value = chips
	_bet_slider.value = o.min_bet
	_update_stake_label()
	bet_layer.visible = true


func _update_stake_label() -> void:
	stake = int(_bet_slider.value)
	var o := current_offer
	var win_total := stake + int(stake * o.odds)
	_bet_stake_label.text = "STAKE  %d      win pays back %d" % [stake, win_total]


func _confirm_bet() -> void:
	chips -= stake
	bet_layer.visible = false
	_start_room()


# --- Flow: playing a room -------------------------------------------------

func _start_room() -> void:
	in_room = true
	room_score = 0
	room_target = current_offer.target
	room_goal = current_offer.get("goal", "")
	room_combo = []
	room_hands_left = int(current_offer.hands) + (1 if has_relic("horseshoe") else 0)
	main.mode_kind = "trail"
	main.mode_label_text = "Trail · %s" % _table().name.capitalize()
	main.board.custom_deck = deck.duplicate(true)
	main.game_started = true
	main.game_over = false
	main.menu_music.stop()
	if not main.music.playing:
		main._fade_in(main.music)
	if not main.backgrounds.is_empty():
		main.bg_rect.texture = main.backgrounds.pick_random()
	main.board.reset()
	main._begin_countdown()
	_seed_room_specials()


## After the deal settles, put the room's promise on the board: hazards,
## objectives, or (in plain rooms) a surprise ambient bonus.
func _seed_room_specials() -> void:
	while main.board.busy:
		await get_tree().process_frame
	if not in_room:
		return
	if current_offer.has("hazard"):
		main.board.apply_room_hazards(current_offer.hazard, current_offer.hazard_count)
		# Relic adjustments to freshly-seeded hazards.
		for p in main.board.grid:
			var card: PlayingCard = main.board.grid[p]
			if card.hazard == "bomb" and has_relic("bomb_badge"):
				card.fuse += 2
			elif card.hazard == "stone" and has_relic("chisel"):
				card.stone_hits = Board.STONE_HITS_START - 1
	elif room_goal == "safe":
		room_combo = _generate_combo()
		main.board.spawn_safe(room_combo)
	elif room_goal == "chest":
		main.board.spawn_key_and_chest()
	elif randf() < AMBIENT_CHANCE * (2.0 if has_relic("rabbits_foot") else 1.0):
		# Surprise loot in a plain room.
		if randf() < 0.5:
			room_combo = _generate_combo()
			main.board.spawn_safe(room_combo)
		else:
			main.board.spawn_key_and_chest()


## A 4-digit combination drawn from low ranks present on the board.
func _generate_combo() -> Array:
	var max_rank := 6 if has_relic("dowsing_rod") else 9
	var pool: Array = []
	for p in main.board.grid:
		var card: PlayingCard = main.board.grid[p]
		if not card.cursed and not card.is_safe and card.rank <= max_rank:
			pool.append(card.rank)
	var combo: Array = []
	for i in 4:
		combo.append(pool.pick_random() if not pool.is_empty() else randi_range(2, max_rank))
	return combo


func on_hand_played(result: Dictionary) -> void:
	# main already added result.score to the run total (main.score).
	chips += result.get("bonus_chips", 0)
	room_score += result.score
	if result.get("chest_opened", false):
		_open_chest()
		if room_goal == "chest":
			_room_cleared()
			return
	if room_goal == "" and room_score >= room_target:
		_room_cleared()
		return
	if room_goal == "chest" and not main.board.has_objective("key"):
		# The key (or chest) went into a hand without its partner.
		_room_failed("THE KEY IS LOST")
		return
	_consume_hand()


## A hand (or a safe crack) is spent; run out and the room is lost.
func _consume_hand() -> void:
	if has_relic("lucky_chip") and randf() < 0.10:
		_announce_after_settle("LUCKY CHIP — free hand!")
	else:
		room_hands_left -= 1
	if room_hands_left <= 0:
		_room_failed()
	else:
		_tick_room_hazards()


func on_safe_cracked() -> void:
	if room_goal == "safe":
		_room_cleared()
		return
	# Ambient safe: bonus loot, but the crack still costs a hand.
	var region := room_index / REGION_SIZE + 1
	var loot := 40 + 20 * region
	chips += loot
	_announce_after_settle("SAFE LOOT  +%d CHIPS" % loot)
	_consume_hand()


## Chest reward roll (treasure rooms and ambient chests).
func _open_chest() -> void:
	var region := room_index / REGION_SIZE + 1
	var roll := randf()
	if roll < 0.45:
		var loot := 30 + 15 * region
		chips += loot
		_announce_after_settle("CHEST  +%d CHIPS" % loot)
	elif roll < 0.65:
		var card := _random_card_offer(0.25)
		deck.append(card)
		_announce_after_settle("CHEST  NEW CARD FOR YOUR DECK")
	elif roll < 0.80:
		var dollars := 5 + 5 * region
		cash += dollars
		_save_meta()
		_announce_after_settle("CHEST  +$%d CASH" % dollars)
	elif roll < 0.90 and relics.size() < MAX_RELICS and _unowned_relic() != "":
		var id := _unowned_relic()
		_gain_relic(id)
		_announce_after_settle("CHEST  RELIC: %s!" % RELICS[id].name)
	else:
		var enhanced := {"rank": randi_range(2, 14), "suit": randi_range(0, 3),
				"cursed": false, "mod": "mult" if randf() < 0.5 else "chip"}
		deck.append(enhanced)
		_announce_after_settle("CHEST  AN ENHANCED CARD!")
	_save_run()


## Matched combo digits on the board's safe (0-4), for the room banner.
func safe_progress() -> int:
	for p in main.board.grid:
		if main.board.grid[p].is_safe:
			return main.board.grid[p].combo_progress
	return 0


func _announce_after_settle(text: String) -> void:
	while main.board.busy:
		await get_tree().process_frame
	main._announce(text)


## After the hand fully resolves, hazards act: fires tick and spread,
## bomb fuses drop. A detonation loses the room.
func _tick_room_hazards() -> void:
	while main.board.busy:
		await get_tree().process_frame
	if not in_room:
		return
	var tick_fire := true
	if has_relic("fire_blanket"):
		_fire_tick_flip = not _fire_tick_flip
		tick_fire = _fire_tick_flip
	var exploded: bool = await main.board.tick_hazards(tick_fire)
	if exploded and in_room:
		_room_failed("KABOOM — THE BOMB WENT OFF")


func _room_cleared() -> void:
	in_room = false
	main.board.locked = true
	main.board.suppress_refill = true
	if main.board._refill_active:
		main.board._skip_refill()
	var winnings := stake + int(stake * current_offer.odds)
	if has_relic("tin_star"):
		winnings += 10
	chips += winnings
	main._announce("ROOM CLEAR  +%d CHIPS" % winnings)
	_after_board_settles(func() -> void:
		room_index += 1
		if room_index >= ROOMS_TOTAL:
			_trail_complete()
		else:
			_save_run()
			_show_pick())


func _room_failed(reason := "BUSTED — CURSED CARD") -> void:
	in_room = false
	main.board.locked = true
	# Fail forward, scarred: stake is already gone; take a cursed card
	# (unless Second Wind spares the first stumble of the run).
	if has_relic("second_wind") and not _second_wind_used:
		_second_wind_used = true
		reason = "BUSTED — SECOND WIND, NO SCAR"
	else:
		deck.append({"rank": randi_range(2, 14), "suit": randi_range(0, 3), "cursed": true})
	main._announce(reason, main.RED)
	_after_board_settles(func() -> void:
		room_index += 1
		if room_index >= ROOMS_TOTAL:
			_trail_complete()
		else:
			_save_run()
			_show_tarot())


func _after_board_settles(then: Callable) -> void:
	while main.board.busy:
		await get_tree().process_frame
	then.call()


## Player bailed mid-room (M to menu): the stake is already spent, so it
## just counts as a fail — scar applied, save written.
func on_abandon_room() -> void:
	if not in_room:
		return
	in_room = false
	deck.append({"rank": randi_range(2, 14), "suit": randi_range(0, 3), "cursed": true})
	room_index += 1
	if room_index >= ROOMS_TOTAL:
		room_index = ROOMS_TOTAL - 1  # abandoning the finale just fails it
	_save_run()


func _trail_complete() -> void:
	var payout := _cashout_value(COMPLETE_RATE_BONUS) + COMPLETE_PURSE * (table_tier + 1)
	cash += payout
	_save_meta()
	_clear_run_save()
	_end_run("TRAIL COMPLETE",
			"You rode all %d rooms and the table pays tribute.\nWinnings banked: $%d" % [ROOMS_TOTAL, payout],
			payout)


# --- Flow: card pick ------------------------------------------------------

func _show_pick() -> void:
	_hide_all()
	main.game_started = false
	for child in _pick_box.get_children():
		child.queue_free()
	var pick_count := 4 if has_relic("card_sleeve") else 3
	var start_x := 545.0 if pick_count == 4 else 660.0
	for i in pick_count:
		var card_data := _random_card_offer()
		var holder: Button = main._button(_pick_box, "", Vector2(start_x + i * 220, 0), Vector2(170, 240))
		var pc := PlayingCard.new()
		pc.rank = card_data.rank
		pc.suit = card_data.suit
		pc.mod = card_data.get("mod", "")
		pc.material = Themes.current_material()
		pc.scale = Vector2(1.6, 1.6)
		pc.position = Vector2(85, 120)
		holder.add_child(pc)
		var data := card_data
		holder.pressed.connect(func() -> void:
			deck.append(data)
			main.board._play_sound(Board.SFX_FLIP, 1.1, -8.0)
			_save_run()
			_show_tarot())
	pick_layer.visible = true


# --- Flow: shop -----------------------------------------------------------

## One shop slot: the card data plus its price tier.
func _shop_card_offer() -> Dictionary:
	if randf() < SHOP_MOD_CHANCE:
		return {"data": {"rank": randi_range(2, 14), "suit": randi_range(0, 3),
				"cursed": false, "mod": "mult" if randf() < 0.5 else "chip"},
				"price": _price(SHOP_MOD_PRICE)}
	if randf() < 0.5 and not deck.is_empty():
		var src: Dictionary = deck.pick_random()
		if not src.get("cursed", false):
			return {"data": {"rank": src.rank, "suit": src.suit,
					"cursed": false, "mod": ""}, "price": _price(SHOP_DUP_PRICE)}
	return {"data": {"rank": randi_range(2, 14), "suit": randi_range(0, 3),
			"cursed": false, "mod": ""}, "price": _price(SHOP_CARD_PRICE)}


func _show_shop() -> void:
	_hide_all()
	main.game_started = false
	_shop_info.text = "CHIPS  %d" % chips
	_shop_burn_btn.text = "BURN A CARD — %d chips" % _price(SHOP_REMOVE_PRICE)
	# Relic slot: one unowned relic per visit.
	_shop_relic_id = _unowned_relic()
	if _shop_relic_id == "" or relics.size() >= MAX_RELICS:
		_shop_relic_btn.text = "NO RELICS IN STOCK"
		_shop_relic_btn.disabled = true
	else:
		var r: Dictionary = RELICS[_shop_relic_id]
		_shop_relic_btn.text = "RELIC: %s — %d chips\n%s" % [r.name,
				_price(RELIC_PRICES[r.rarity]), r.desc]
		_shop_relic_btn.disabled = false
	for child in _shop_box.get_children():
		child.queue_free()
	for i in 10:
		var offer := _shop_card_offer()
		var col := i % 5
		var row := i / 5
		var holder: Button = main._button(_shop_box, "",
				Vector2(445 + col * 220, row * 280), Vector2(170, 250))
		var pc := PlayingCard.new()
		pc.rank = offer.data.rank
		pc.suit = offer.data.suit
		pc.mod = offer.data.mod
		pc.material = Themes.current_material()
		pc.scale = Vector2(1.3, 1.3)
		pc.position = Vector2(85, 95)
		holder.add_child(pc)
		var price: int = offer.price
		var price_tag: Label = main._label(holder, "%d chips" % price,
				Vector2(0, 212), 18, main.GOLD)
		price_tag.size = Vector2(170, 30)
		price_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var data: Dictionary = offer.data
		holder.pressed.connect(func() -> void:
			if chips >= price:
				chips -= price
				deck.append(data)
				main.board._play_sound(Board.SFX_FLIP, 1.1, -8.0)
				holder.disabled = true
				_shop_info.text = "CHIPS  %d" % chips
				_save_run())
	shop_layer.visible = true


func _leave_shop() -> void:
	room_index += 1
	if room_index >= ROOMS_TOTAL:
		_trail_complete()
	else:
		_save_run()
		_show_tarot()


func _show_remove() -> void:
	shop_layer.visible = false
	_remove_info.text = "Pick a card to burn — %d chips" % _price(SHOP_REMOVE_PRICE)
	for child in _remove_grid.get_children():
		child.queue_free()
	for i in deck.size():
		var card_data: Dictionary = deck[i]
		var holder := Button.new()
		holder.custom_minimum_size = Vector2(100, 140)
		holder.focus_mode = Control.FOCUS_NONE
		var pc := PlayingCard.new()
		pc.rank = card_data.rank
		pc.suit = card_data.suit
		pc.cursed = card_data.get("cursed", false)
		pc.material = Themes.current_material()
		pc.position = Vector2(50, 70)
		holder.add_child(pc)
		var idx := i
		holder.pressed.connect(func() -> void:
			if chips >= _price(SHOP_REMOVE_PRICE):
				chips -= _price(SHOP_REMOVE_PRICE)
				deck.remove_at(idx)
				main.board._play_sound(Board.SFX_POPS.pick_random(), 1.0, -8.0)
				_save_run()
				_show_shop())
		_remove_grid.add_child(holder)
	remove_layer.visible = true


# --- Flow: run end --------------------------------------------------------

func _end_run(title: String, body: String, _payout: int) -> void:
	_hide_all()
	run_active = false
	main.game_started = false
	if title == "BUSTED OUT":
		_clear_run_save()
	_end_label.text = "%s\n\n%s\n\nTotal run score: %d\nCash: $%d" % [title, body, main.score, cash]
	end_layer.visible = true


# --- UI construction ------------------------------------------------------

func build_ui() -> void:
	buyin_layer = _layer()
	_screen_title(buyin_layer, "THE TRAIL")
	_buyin_cash_label = _center(buyin_layer, "", 240, 30, main.GOLD)
	for i in TABLES.size():
		var t: Dictionary = TABLES[i]
		var label: String
		if t.cost == 0:
			label = "%s\n%d chips · payout ×%.1f" % [t.name, t.chips, t.rate]
		else:
			label = "%s — $%d\n%d chips · payout ×%.1f · harder" % [t.name, t.cost, t.chips, t.rate]
		var b: Button = main._button(buyin_layer, label, Vector2(660, 330 + i * 130), Vector2(600, 100))
		b.add_theme_font_size_override("font_size", 24)
		var tier := i
		b.pressed.connect(func() -> void:
			_start_run(tier))
	_buyin_resume_btn = main._button(buyin_layer, "RESUME YOUR RIDE", Vector2(660, 740), Vector2(600, 70))
	_buyin_resume_btn.add_theme_font_size_override("font_size", 24)
	_buyin_resume_btn.pressed.connect(_resume_run)
	_back_button(buyin_layer, back_to_menu)

	tarot_layer = _layer()
	_screen_title(tarot_layer, "FATE DEALS")
	_tarot_info = _center(tarot_layer, "", 230, 24, main.OFFWHITE)
	_tarot_cards_box = Control.new()
	_tarot_cards_box.position = Vector2(0, 330)
	tarot_layer.add_child(_tarot_cards_box)
	_tarot_relics = _center(tarot_layer, "", 272, 18, main.GOLD)
	_tarot_cashout_btn = main._button(tarot_layer, "", Vector2(760, 790), Vector2(400, 64))
	_tarot_cashout_btn.add_theme_font_size_override("font_size", 24)
	_tarot_cashout_btn.pressed.connect(_do_cashout)
	_center(tarot_layer, "Cashing out ends the run and banks your chips as cash.", 870, 18, main.DIM)
	_back_button(tarot_layer, back_to_menu, "MENU")

	bet_layer = _layer()
	_screen_title(bet_layer, "PLACE YOUR BET")
	_bet_info = _center(bet_layer, "", 250, 26, main.OFFWHITE)
	_bet_slider = HSlider.new()
	_bet_slider.position = Vector2(560, 460)
	_bet_slider.size = Vector2(800, 40)
	_bet_slider.step = 1
	_bet_slider.value_changed.connect(func(_v: float) -> void:
		_update_stake_label())
	bet_layer.add_child(_bet_slider)
	_bet_stake_label = _center(bet_layer, "", 520, 32, main.GOLD)
	var presets := [["MIN", 1.0], ["2×", 2.0], ["5×", 5.0], ["ALL IN", -1.0]]
	for i in presets.size():
		var p: Array = presets[i]
		var b: Button = main._button(bet_layer, p[0], Vector2(660 + i * 160, 600), Vector2(140, 56))
		b.add_theme_font_size_override("font_size", 22)
		var mult: float = p[1]
		b.pressed.connect(func() -> void:
			if mult < 0.0:
				_bet_slider.value = _bet_slider.max_value
			else:
				_bet_slider.value = _bet_slider.min_value * mult)
	var deal: Button = main._button(bet_layer, "DEAL ME IN", Vector2(760, 720), Vector2(400, 70))
	deal.add_theme_font_size_override("font_size", 28)
	deal.pressed.connect(_confirm_bet)
	var bet_back := func() -> void:
		bet_layer.visible = false
		_show_tarot()
	_back_button(bet_layer, bet_back, "BACK")

	pick_layer = _layer()
	_screen_title(pick_layer, "TAKE A CARD")
	_center(pick_layer, "One joins your deck — or take none.", 240, 22, main.DIM)
	_pick_box = Control.new()
	_pick_box.position = Vector2(0, 360)
	pick_layer.add_child(_pick_box)
	var skip: Button = main._button(pick_layer, "SKIP", Vector2(835, 740), Vector2(250, 60))
	skip.add_theme_font_size_override("font_size", 24)
	skip.pressed.connect(func() -> void:
		_show_tarot())

	shop_layer = _layer()
	_screen_title(shop_layer, "THE HERMIT'S SHOP")
	_shop_info = _center(shop_layer, "", 178, 28, main.GOLD)
	_shop_box = Control.new()
	_shop_box.position = Vector2(0, 240)
	shop_layer.add_child(_shop_box)
	_shop_relic_btn = main._button(shop_layer, "", Vector2(125, 840), Vector2(380, 76))
	_shop_relic_btn.add_theme_font_size_override("font_size", 16)
	_shop_relic_btn.pressed.connect(func() -> void:
		if _shop_relic_id == "":
			return
		var cost := _price(RELIC_PRICES[RELICS[_shop_relic_id].rarity])
		if chips >= cost and relics.size() < MAX_RELICS:
			chips -= cost
			_gain_relic(_shop_relic_id)
			main.board._play_sound(Board.SFX_SHUFFLE, 1.3, -8.0)
			_shop_relic_btn.disabled = true
			_shop_info.text = "CHIPS  %d" % chips)
	_shop_burn_btn = main._button(shop_layer, "", Vector2(555, 850), Vector2(380, 56))
	_shop_burn_btn.add_theme_font_size_override("font_size", 20)
	_shop_burn_btn.pressed.connect(_show_remove)
	var leave: Button = main._button(shop_layer, "BACK ON THE TRAIL", Vector2(985, 850), Vector2(380, 56))
	leave.add_theme_font_size_override("font_size", 20)
	leave.pressed.connect(_leave_shop)

	remove_layer = _layer()
	_screen_title(remove_layer, "BURN A CARD")
	_remove_info = _center(remove_layer, "", 210, 24, main.OFFWHITE)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(360, 270)
	scroll.size = Vector2(1200, 620)
	remove_layer.add_child(scroll)
	_remove_grid = GridContainer.new()
	_remove_grid.columns = 11
	scroll.add_child(_remove_grid)
	var remove_back := func() -> void:
		remove_layer.visible = false
		_show_shop()
	_back_button(remove_layer, remove_back, "CANCEL")

	end_layer = _layer()
	_end_label = Label.new()
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_end_label.add_theme_font_size_override("font_size", 40)
	_end_label.add_theme_color_override("font_color", main.OFFWHITE)
	_end_label.size = main.VIEW
	end_layer.add_child(_end_label)
	var out: Button = main._button(end_layer, "LEAVE THE TABLE", Vector2(760, 860), Vector2(400, 64))
	out.add_theme_font_size_override("font_size", 24)
	out.pressed.connect(back_to_menu)


func _layer() -> ColorRect:
	var l := ColorRect.new()
	l.color = main.BG
	l.size = main.VIEW
	l.visible = false
	main.ui_root.add_child(l)
	return l


func _hide_all() -> void:
	for l in [buyin_layer, tarot_layer, bet_layer, pick_layer, shop_layer, remove_layer, end_layer]:
		if l:
			l.visible = false


func _screen_title(parent: Control, text: String) -> void:
	var t := _center(parent, text, 100, 64, main.GOLD)
	t.add_theme_color_override("font_color", main.GOLD)


func _center(parent: Control, text: String, y: float, font_size: int, color: Color) -> Label:
	var l: Label = main._label(parent, text, Vector2(0, y), font_size, color)
	l.size = Vector2(main.VIEW.x, font_size * 2.2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _back_button(parent: Control, action: Callable, text := "BACK") -> void:
	var b: Button = main._button(parent, text, Vector2(60, 970), Vector2(200, 54))
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(action)
