class_name TrailMode
extends Node

## Trail mode: a betting roguelike run. Buy in for a chip stack, ride a
## 12-room tarot trail, wager chips on every room, sculpt your deck as
## you go. Bankruptcy ends the run; cashing out banks chips as cash.
## v1 scope: risk-tiered Normal rooms + shops. Bosses, room-rule
## variety, and card modifiers beyond Cursed come later (TRAIL_MODE.md).

const ROOMS_TOTAL := 21
const REGION_SIZE := 7
# Every 7th room is a boss; the tarot deals a single court card.
const BOSS_ROOMS := {6: "jack", 13: "queen", 20: "cobra"}
const BOSSES := {
	"jack": {"tarot": "THE JACK", "name": "Jack of All Trades", "hands": 18},
	"queen": {"tarot": "THE QUEEN", "name": "Queen Bee", "hands": 14},
	"cobra": {"tarot": "THE KING", "name": "King Cobra", "hands": 14},
}

# Buy-in tables: [name, cash cost, starting chips, cash-out rate,
# target multiplier, blind multiplier]
const TABLES := [
	{"name": "PENNY ANTE", "cost": 0, "chips": 100, "rate": 1.0, "target_mult": 1.0, "blind_mult": 1.0},
	{"name": "TABLE STAKES", "cost": 250, "chips": 250, "rate": 1.5, "target_mult": 1.35, "blind_mult": 1.5},
	{"name": "HIGH ROLLER", "cost": 1000, "chips": 500, "rate": 2.5, "target_mult": 1.75, "blind_mult": 2.0},
]

# Room risk tiers offered by the tarot draw. "hands" is only a
# reference budget now — the stakes screen starts at zero hands and
# every one is bought.
const RISKS := [
	{"tarot": "THE SUN", "label": "Steady", "target_scale": 0.85, "odds": 1.0, "hands": 10},
	{"tarot": "WHEEL OF FORTUNE", "label": "Risky", "target_scale": 1.15, "odds": 1.5, "hands": 8},
	{"tarot": "THE TOWER", "label": "Dangerous", "target_scale": 1.5, "odds": 2.0, "hands": 7},
]

# Entering a room costs its ANTE (the house keeps it, win or lose),
# then you BET chips on yourself. Hands are free — but they're the
# thing you're betting on: effective odds = base odds × reference
# hands ÷ hands taken, so promising a fast clear fattens the payout
# and taking lazy hands shrinks it.
const MAX_HANDS_BUY := 12
const MIN_HANDS_TAKE := 1

# Hazards are AMBIENT: any play room (bosses included) can be seeded,
# with the chance and count climbing with depth and table stakes. The
# tarot decides only the room's GOAL.
const HAZARD_KINDS := ["bomb", "fire", "wind", "stone", "water"]
const HAZARD_BASE_CHANCE := 0.20
const HAZARD_ROOM_STEP := 0.04   # + per room index
const HAZARD_TIER_STEP := 0.15   # + per buy-in tier
const OBJECTIVE_CHANCE := 0.15   # heist/treasure rooms, from room 2 on
const PURGE_CHANCE := 0.18       # purge rooms: board of one hazard, clear them all
const REQUIRE_CHANCE := 0.17     # called-hands rooms: play the demanded hands
const ROYAL_CHANCE := 0.10       # of called-hands rooms (region 2+): THE WORLD
const AMBIENT_CHANCE := 0.12     # bonus safe or chest in plain rooms

const PURGE_TAROTS := {"bomb": "DEATH", "fire": "THE DEVIL",
		"wind": "THE CHARIOT", "stone": "STRENGTH", "water": "TEMPERANCE"}
# Called-hands templates by region: [hand name, count] — exact hands
# only (this game scores exact compositions, so a Full House is NOT
# three Pairs).
const REQUIRE_POOLS := [
	[[["Pair", 3]], [["Pair", 2], ["Two Pair", 1]],
			[["Three of a Kind", 1], ["Pair", 1]]],
	[[["Two Pair", 2]], [["Three of a Kind", 2]],
			[["Straight", 1], ["Pair", 2]], [["Flush", 1]]],
	[[["Flush", 2]], [["Full House", 1]], [["Straight", 2]],
			[["Four of a Kind", 1]]],
]

const BASE_TARGET := 300          # table 1 target before scaling
const TARGET_STEP := 65           # + per table (21-table curve)
const BLIND_BASE := 25            # table 1 ante / minimum bet
const BLIND_STEP := 8             # + per table cleared — the floor climbs
const SHOP_CARD_PRICE := 40       # plain card
const SHOP_DUP_PRICE := 50        # exact duplicate of a card you own
const SHOP_MOD_PRICE := 80        # chip/mult enhanced card
const SHOP_REMOVE_PRICE := 30     # first burn; climbs every use
const SHOP_REMOVE_STEP := 25      # + per burn used this run
const PICK_MOD_CHANCE := 0.25     # card picks: chance of an enhanced offer
const SHOP_MOD_CHANCE := 0.35     # shop slots: chance of an enhanced card
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
var room_goal := ""      # "" score · safe · chest · purge · hands · boss
var room_combo: Array = []
var room_require: Array = []     # [[hand name, remaining count], ...]
var room_require_total := 0      # hands demanded at room start (progress bar)
var room_chests_needed := 1      # treasure rooms: pairs to open
var room_chests_opened := 0
var relics: Array = []   # relic ids held this run
var burns_used := 0      # run-wide: each burn costs more than the last
var _second_wind_used := false
var _fire_tick_flip := false
var _shop_stock: Array = []      # this shop room's shelves (no restocking)
var _shop_stock_room := -1
var _shop_stock_relic := ""
var _shop_burned_here := false   # one burn per shop
var pending_retry := {}          # a failed room that MUST be retried
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
var _bet_stake_label: Label
var _bet_hands := 8
var _bet_hands_label: Label
var _bet_amount := 0
var _bet_amount_label: Label
var _bet_deal_btn: Button
var _deck_view_burn := true   # deck viewer doubles as the shop's burn picker
var _deck_stat: Label
var stake_odds := 1.0    # effective odds locked in when the bet is placed
var _pick_box: Control
var _shop_info: Label
var _shop_box: Control
var _remove_grid: GridContainer
var _remove_info: Label
var _end_label: Label
var _shop_relic_btn: Button
var _shop_burn_btn: Button
var _bet_back_btn: Button
var _tarot_relics: Label


func _ready() -> void:
	_load_meta()
	main.board.safe_cracked.connect(on_safe_cracked)
	main.board.boss_defeated.connect(func() -> void:
		pass)  # handled via result.boss_defeated in on_hand_played


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
	cf.set_value("run", "burns_used", burns_used)
	cf.set_value("run", "pending", pending_retry)
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
	burns_used = int(cf.get_value("run", "burns_used", 0))
	pending_retry = cf.get_value("run", "pending", {})
	_shop_stock_room = -1  # resumed runs sit at a tarot or a retry bet
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
	return int((BLIND_BASE + BLIND_STEP * room) * _table().blind_mult)


## The least a seat at this table can cost: the ante plus the minimum
## bet (also the ante). Bosses take the whole stack anyway, so just
## the ante.
func _cheapest_seat(room: int) -> int:
	if BOSS_ROOMS.has(room):
		return _blind_for(room)
	return _blind_for(room) * 2


## True if the stack can't cover `cost` — and in that case the run is
## over: zero chips busts outright, anything short of the seat gets
## force-cashed out (the house shows you the door with what's left).
func _short_stacked(cost: int) -> bool:
	if chips >= cost:
		return false
	if chips <= 0:
		_clear_run_save()
		_end_run("BUSTED OUT",
				"That table took your last chip.\nThe trail ends here.", 0)
		return true
	var payout := _cashout_value()
	cash += payout
	_save_meta()
	_clear_run_save()
	_end_run("BLINDED OUT",
			"A seat at this table costs at least %d chips — you're down to %d.\nThe house cashes you out: $%d." % [cost, chips, payout],
			payout)
	return true


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


## Weighted enhancement roll: the classics stay common, the exotic
## payloads (boost / chip burst / cash) come up rarer.
func _random_mod() -> String:
	var roll := randf()
	if roll < 0.30:
		return "mult"
	if roll < 0.60:
		return "chip"
	if roll < 0.75:
		return "boost"
	if roll < 0.90:
		return "chipsplode"
	return "cash"


func _random_card_offer(mod_chance := PICK_MOD_CHANCE) -> Dictionary:
	var mod := ""
	if randf() < mod_chance:
		mod = _random_mod()
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
	burns_used = 0
	_second_wind_used = false
	_fire_tick_flip = false
	_shop_stock_room = -1
	pending_retry = {}
	run_active = true
	main.score = 0
	_apply_relic_effects()
	_save_run()
	_show_tarot()


func _resume_run() -> void:
	if _load_run():
		main.score = 0
		_apply_relic_effects()
		if not pending_retry.is_empty():
			# A failed room still bars the way — back to its table.
			if _short_stacked(_cheapest_seat(room_index)):
				return
			main.menu_open = false
			current_offer = pending_retry.duplicate(true)
			_hide_all()
			_show_bet()
		else:
			pending_retry = {}
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
	main.play_music("tarot")
	# Bankruptcy check against the coming room's cheapest seat.
	if _short_stacked(_cheapest_seat(room_index)):
		return
	_offers = _make_offers()
	_fate_offer = _make_one_offer(true)
	_render_tarot()
	tarot_layer.visible = true


func _make_offers() -> Array:
	# Boss rooms: fate deals exactly one court card.
	if BOSS_ROOMS.has(room_index):
		var kind: String = BOSS_ROOMS[room_index]
		var b: Dictionary = BOSSES[kind]
		return [{
			"kind": "play",
			"tarot": b.tarot,
			"label": b.name,
			"target": 0,
			"hands": int(b.hands),
			"odds": 3.0,
			"min_bet": mini(_blind_for(room_index), chips),
			"boss": kind,
		}]
	var offers: Array = []
	# Shops appear twice per 7-room region.
	var want_shop := room_index % REGION_SIZE in [2, 5]
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
	var region := room_index / REGION_SIZE
	var offer := {
		"kind": "play",
		"tarot": risk.tarot,
		"label": risk.label,
		"target": _target_for(room_index, risk),
		"hands": maxi(1, int(risk.hands) - region),
		"odds": float(risk.odds),
		"min_bet": _blind_for(room_index),
	}
	if room_index >= 1:
		var roll := randf()
		if roll < OBJECTIVE_CHANCE:
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
				# Deeper trails demand more pairs; each opened pair
				# respawns a fresh key and chest.
				offer["chest_count"] = mini(2 + region, 4)
				offer.hands = mini(MAX_HANDS_BUY, 3 * int(offer.chest_count))
			if offer.get("goal", "") == "safe":
				offer.hands = maxi(1, 8 - region)
			offer.target = 0
		elif roll < OBJECTIVE_CHANCE + PURGE_CHANCE:
			# Purge rooms: a board full of one hazard — remove them all.
			var kind: String = HAZARD_KINDS.pick_random()
			offer.tarot = String(PURGE_TAROTS[kind])
			offer.label = "Purge"
			offer.odds = 2.0 if kind in ["bomb", "fire"] else 1.5
			offer["goal"] = "purge"
			offer["purge_kind"] = kind
			offer["purge_count"] = mini((2 if kind == "stone" else 3) + region, 6)
			offer.hands = maxi(1, 8 - region)
			offer.target = 0
		elif roll < OBJECTIVE_CHANCE + PURGE_CHANCE + REQUIRE_CHANCE:
			# Called hands: play exactly what the table demands.
			offer["goal"] = "hands"
			if region >= 1 and randf() < ROYAL_CHANCE:
				offer.tarot = "THE WORLD"
				offer.label = "Royal Hunt"
				offer.odds = 5.0
				offer["require"] = [["Royal Flush", 1]]
			else:
				offer.tarot = "JUDGEMENT"
				offer.label = "Called Hands"
				offer.odds = 1.5 if region == 0 else 2.0
				var pool: Array = REQUIRE_POOLS[mini(region, REQUIRE_POOLS.size() - 1)]
				offer["require"] = (pool.pick_random() as Array).duplicate(true)
			offer.hands = maxi(1, 9 - region)
			offer.target = 0
	return offer


func _render_tarot() -> void:
	for child in _tarot_cards_box.get_children():
		child.queue_free()
	var is_boss := BOSS_ROOMS.has(room_index)
	var region := room_index / REGION_SIZE + 1
	_tarot_info.text = "TABLE %d / %d   ·   REGION %d   ·   CHIPS %d   ·   DECK %d cards" \
			% [room_index + 1, ROOMS_TOTAL, region, chips, deck.size()]
	if relics.is_empty():
		_tarot_relics.text = ""
	else:
		var names := PackedStringArray()
		for id in relics:
			names.append(RELICS[id].name)
		_tarot_relics.text = "RELICS:  " + "  ·  ".join(names)
	_tarot_cashout_btn.text = "CASH OUT — TAKE $%d" % _cashout_value()
	var slot_count := _offers.size() + (0 if is_boss else 1)
	var total_w := slot_count * 330 - 30
	var start_x := (1920.0 - total_w) / 2.0
	for i in _offers.size():
		var offer: Dictionary = _offers[i]
		var b := _tarot_card_button(offer, start_x + i * 330)
		var picked := offer
		b.pressed.connect(func() -> void:
			_choose_offer(picked, false))
	if not is_boss:
		# The Fool: face-down fate.
		var fool: Button = main._button(_tarot_cards_box, "",
				Vector2(start_x + _offers.size() * 330, 0), Vector2(300, 380))
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
		var goal_line := "Target  %d" % offer.target
		if offer.has("boss"):
			goal_line = "BOSS FIGHT"
		elif offer.get("goal", "") == "safe":
			goal_line = "CRACK THE SAFE"
		elif offer.get("goal", "") == "chest":
			var pairs := int(offer.get("chest_count", 1))
			goal_line = "OPEN THE CHEST" if pairs == 1 else "OPEN %d CHESTS" % pairs
		elif offer.get("goal", "") == "purge":
			goal_line = "CLEAR %d %s CARDS" % [offer.purge_count,
					String(offer.purge_kind).to_upper()]
		elif offer.get("goal", "") == "hands":
			goal_line = "PLAY  " + _require_text(offer.require)
		var bet_line := "Ante  %d  ·  ~%d hands" % [offer.min_bet, offer.hands]
		if offer.has("boss"):
			bet_line = "ALL IN"
		b.text = "%s\n\n%s table\n%s\nOdds  %s\n\n%s" % [
			offer.tarot, offer.label, goal_line,
			_odds_text(offer.odds), bet_line]
	return b


func _odds_text(odds: float) -> String:
	if is_equal_approx(odds, 1.5):
		return "3 : 2"
	return "%d : 1" % maxi(1, int(round(odds)))


func _require_text(req: Array) -> String:
	var parts := PackedStringArray()
	for r in req:
		parts.append("%d× %s" % [int(r[1]), String(r[0]).to_upper()])
	return " + ".join(parts)


func _choose_offer(offer: Dictionary, from_fate: bool) -> void:
	if from_fate:
		chips += FATE_KICKER
	current_offer = offer
	tarot_layer.visible = false
	if offer.kind == "shop":
		_show_shop()
	elif offer.has("boss"):
		# The house demands everything at a boss table.
		stake = chips
		stake_odds = float(offer.odds)
		chips = 0
		_start_room()
	else:
		_show_bet()


func _do_cashout() -> void:
	var payout := _cashout_value()
	cash += payout
	_save_meta()
	_clear_run_save()
	_end_run("CASHED OUT", "You walk away with $%d.\nThe trail will be waiting." % payout, payout)


# --- Flow: betting --------------------------------------------------------

## The stakes screen: the blind is forced, the hands are bought.
func _show_bet() -> void:
	_hide_all()
	var o := current_offer
	if o.has("boss"):
		# The house demands everything at a boss table, retry included.
		stake = chips
		stake_odds = float(o.odds)
		chips = 0
		_start_room()
		return
	# A failed room bars the way — no backing out of a retry.
	_bet_back_btn.visible = pending_retry.is_empty()
	_bet_amount = int(o.min_bet)
	# Hands are free — they're what you're betting ON. Start at the
	# tier's reference count (base odds, no bonus, no penalty).
	_bet_hands = clampi(int(o.hands), MIN_HANDS_TAKE, MAX_HANDS_BUY)
	_refresh_bet_labels()
	bet_layer.visible = true


## Promise a faster clear, get fatter odds: base odds scaled by the
## tier's reference hand count over the hands you actually take.
func _eff_odds() -> float:
	var o := current_offer
	return float(o.odds) * float(o.hands) / float(maxi(MIN_HANDS_TAKE, _bet_hands))


func _max_bet() -> int:
	return maxi(int(current_offer.min_bet), chips - int(current_offer.min_bet))


func _bet_goal_text(o: Dictionary) -> String:
	match String(o.get("goal", "")):
		"safe":
			return "Crack the safe"
		"chest":
			var pairs := int(o.get("chest_count", 1))
			return "Open the chest" if pairs == 1 else "Open %d chests" % pairs
		"purge":
			return "Clear all %d %s cards" % [o.purge_count, o.purge_kind]
		"hands":
			return "Play " + _require_text(o.require)
	return "Target %d" % o.target


func _refresh_bet_labels() -> void:
	var o := current_offer
	var retry_line := ""
	if not pending_retry.is_empty():
		retry_line = "\nTHE TABLE STILL BARS THE WAY — beat it or bust."
	var blind := int(o.min_bet)
	_bet_amount = clampi(_bet_amount, blind, _max_bet())
	_bet_info.text = "%s — %s table\n%s   ·   base odds %s at %d hands\nAnte %d — the house keeps it\nYour chips: %d%s" % [
		o.tarot, o.label, _bet_goal_text(o), _odds_text(o.odds), int(o.hands),
		blind, chips, retry_line]
	_bet_amount_label.text = "BET  %d" % _bet_amount
	_bet_hands_label.text = "%d HANDS" % _bet_hands
	_bet_stake_label.text = "Odds ×%.2f      clearing pays back %d" % [
		_eff_odds(), _bet_amount + int(_bet_amount * _eff_odds())]


func _confirm_bet() -> void:
	var o := current_offer
	var blind := int(o.min_bet)
	stake = clampi(_bet_amount, blind, maxi(blind, chips - blind))
	stake_odds = _eff_odds()
	chips -= blind + stake
	o["hands_bought"] = _bet_hands
	bet_layer.visible = false
	_start_room()


# --- Flow: playing a room -------------------------------------------------

func _start_room() -> void:
	in_room = true
	room_score = 0
	room_target = current_offer.target
	room_goal = current_offer.get("goal", "")
	if current_offer.has("boss"):
		room_goal = "boss"
	room_combo = []
	room_require = (current_offer.get("require", []) as Array).duplicate(true)
	room_require_total = 0
	for r in room_require:
		room_require_total += int(r[1])
	room_chests_needed = int(current_offer.get("chest_count", 1))
	room_chests_opened = 0
	room_hands_left = int(current_offer.get("hands_bought", current_offer.hands)) \
			+ (1 if has_relic("horseshoe") else 0)
	main.mode_kind = "trail"
	main.mode_label_text = "Trail · %s" % _table().name.capitalize()
	main.board.custom_deck = deck.duplicate(true)
	main.game_started = true
	main.game_over = false
	main.play_music("boss" if current_offer.has("boss") else "room")
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
	# The tarot decided the GOAL; seed it first.
	if current_offer.has("boss"):
		main.board.spawn_boss(current_offer.boss)
		main._announce(String(BOSSES[current_offer.boss].name).to_upper(), main.RED)
	elif room_goal == "safe":
		room_combo = _generate_combo()
		main.board.spawn_safe(room_combo)
	elif room_goal == "chest":
		main.board.spawn_key_and_chest()
	elif room_goal == "purge":
		main.board.apply_room_hazards(String(current_offer.purge_kind),
				int(current_offer.purge_count))
	elif randf() < AMBIENT_CHANCE * (2.0 if has_relic("rabbits_foot") else 1.0):
		# Surprise loot in a plain room.
		if randf() < 0.5:
			room_combo = _generate_combo()
			main.board.spawn_safe(room_combo)
		else:
			main.board.spawn_key_and_chest()
	# Hazards are ambient in EVERY play room — bosses included — and
	# get more frequent and more numerous with depth and stakes.
	# Purge rooms are exempt: their hazards ARE the room.
	if room_goal != "purge":
		var hz_chance := clampf(HAZARD_BASE_CHANCE + HAZARD_ROOM_STEP * room_index
				+ HAZARD_TIER_STEP * table_tier, 0.0, 0.95)
		if randf() < hz_chance:
			var count := 1 + room_index / REGION_SIZE
			if table_tier == 2 and randf() < 0.5:
				count += 1
			count = mini(count, 4)
			for i in count:
				main.board.apply_room_hazards(HAZARD_KINDS.pick_random(), 1)
	# Relic adjustments to freshly-seeded hazards (purge seeds included).
	for p in main.board.grid:
		var card: PlayingCard = main.board.grid[p]
		if card.hazard == "bomb" and has_relic("bomb_badge"):
			card.fuse = Board.BOMB_FUSE + 2
		elif card.hazard == "stone" and has_relic("chisel"):
			card.stone_hits = Board.STONE_HITS_START - 1


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
	var earned := int(result.get("cash_earned", 0))
	if earned > 0:
		# Cash cards pay real money, banked on the spot.
		cash += earned
		_save_meta()
		_announce_after_settle("CASH CARD  +$%d" % earned)
	if result.get("boss_defeated", false):
		_room_cleared()
		return
	if result.get("chest_opened", false):
		_open_chest()
		if room_goal == "chest":
			room_chests_opened += 1
			if room_chests_opened >= room_chests_needed:
				_room_cleared()
				return
			# The job's not done: a fresh pair hits the board.
			_consume_hand()
			_respawn_treasure()
			return
	if room_goal == "" and room_score >= room_target:
		_room_cleared()
		return
	if room_goal == "purge" and int(result.get("hazards_left", -1)) == 0:
		_room_cleared()
		return
	if room_goal == "hands":
		for r in room_require:
			if String(r[0]) == String(result.name) and int(r[1]) > 0:
				r[1] = int(r[1]) - 1
				break
		if _require_left() == 0:
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


## Treasure rooms demand several pairs: once the board settles from
## the opened one, a fresh key and chest are dealt onto plain cards.
func _respawn_treasure() -> void:
	while main.board.busy:
		await get_tree().process_frame
	if not in_room or room_goal != "chest":
		return
	main.board.spawn_key_and_chest()
	main._announce("ANOTHER KEY, ANOTHER CHEST  (%d / %d)"
			% [room_chests_opened, room_chests_needed])


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
				"cursed": false, "mod": _random_mod()}
		deck.append(enhanced)
		_announce_after_settle("CHEST  AN ENHANCED CARD!")
	_save_run()


## Hazard cards still on the board — purge-room progress.
func purge_left() -> int:
	var n := 0
	for p in main.board.grid:
		if main.board.grid[p].hazard != "":
			n += 1
	return n


func _require_left() -> int:
	var left := 0
	for r in room_require:
		left += int(r[1])
	return left


## Remaining demanded hands, for the room banner.
func require_status() -> String:
	var parts := PackedStringArray()
	for r in room_require:
		if int(r[1]) > 0:
			parts.append("%d× %s" % [int(r[1]), String(r[0]).to_upper()])
	return " · ".join(parts)


## Fraction of the demanded hands already played (banner progress bar).
func require_frac() -> float:
	if room_require_total <= 0:
		return 0.0
	return 1.0 - float(_require_left()) / float(room_require_total)


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
## bomb fuses drop. A detonation loses the room. In boss rooms the boss
## takes his turn instead.
func _tick_room_hazards() -> void:
	while main.board.busy:
		await get_tree().process_frame
	if not in_room:
		return
	if room_goal == "boss":
		await main.board.tick_boss()
		return
	var tick_fire := true
	if has_relic("fire_blanket"):
		_fire_tick_flip = not _fire_tick_flip
		tick_fire = _fire_tick_flip
	var exploded: bool = await main.board.tick_hazards(tick_fire)
	if exploded and in_room:
		_room_failed("KABOOM — THE BOMB WENT OFF")
		return
	# A fire can burn ITSELF out on the tick — that finishes a purge too.
	if room_goal == "purge" and in_room and purge_left() == 0:
		_room_cleared()


func _room_cleared() -> void:
	in_room = false
	pending_retry = {}
	main.board.locked = true
	main.board.suppress_refill = true
	if main.board._refill_active:
		main.board._skip_refill()
	var winnings := stake + int(stake * stake_odds)
	if has_relic("tin_star"):
		winnings += 10
	chips += winnings
	main._announce("TABLE CLEARED  +%d CHIPS" % winnings)
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
	# The stake is gone and a curse joins the deck (unless Second Wind
	# spares the first stumble) — and the room does NOT clear: the same
	# table must be beaten before the trail continues.
	if has_relic("second_wind") and not _second_wind_used:
		_second_wind_used = true
		reason = "BUSTED — SECOND WIND, NO SCAR"
	else:
		deck.append({"rank": randi_range(2, 14), "suit": randi_range(0, 3), "cursed": true})
	main._announce(reason, main.RED)
	_after_board_settles(_retry_room)


## Back to the same room's table: re-bet or bust.
func _retry_room() -> void:
	if _short_stacked(_cheapest_seat(room_index)):
		return
	pending_retry = current_offer.duplicate(true)
	_save_run()
	_show_bet()


func _after_board_settles(then: Callable) -> void:
	while main.board.busy:
		await get_tree().process_frame
	then.call()


## Player bailed mid-room (M to menu): the stake is already spent, so it
## counts as a fail — scar applied, and the room still awaits on resume.
func on_abandon_room() -> void:
	if not in_room:
		return
	in_room = false
	deck.append({"rank": randi_range(2, 14), "suit": randi_range(0, 3), "cursed": true})
	pending_retry = current_offer.duplicate(true)
	_save_run()


func _trail_complete() -> void:
	var payout := _cashout_value(COMPLETE_RATE_BONUS) + COMPLETE_PURSE * (table_tier + 1)
	cash += payout
	_save_meta()
	_clear_run_save()
	var body := "You rode all %d rooms and the table pays tribute.\nWinnings banked: $%d" % [ROOMS_TOTAL, payout]
	if table_tier == 2:
		body += "\n\nSomewhere past the last saloon, THE DEALER shuffles\na perfect deck and waits. (His table opens soon.)"
	_end_run("TRAIL COMPLETE", body, payout)


## Room banner text for boss fights.
func boss_status() -> String:
	for p in main.board.grid:
		var card: PlayingCard = main.board.grid[p]
		match card.boss:
			"jack":
				return "JACK OF ALL TRADES   HP %d" % card.boss_hp
			"queen":
				return "QUEEN BEE   STRIPES %d   (2-3 card hands!)" % card.boss_hp
			"cobra":
				var tail := 0
				for q in main.board.grid:
					if main.board.grid[q].snake_tail:
						tail += 1
				return "KING COBRA   TAIL %d" % tail
	return "THE BOSS IS DOWN"


# --- Flow: card pick ------------------------------------------------------

func _show_pick() -> void:
	_hide_all()
	main.game_started = false
	main.play_music("tarot")
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
				"cursed": false, "mod": _random_mod()},
				"price": _price(SHOP_MOD_PRICE)}
	if randf() < 0.5 and not deck.is_empty():
		var src: Dictionary = deck.pick_random()
		if not src.get("cursed", false):
			return {"data": {"rank": src.rank, "suit": src.suit,
					"cursed": false, "mod": ""}, "price": _price(SHOP_DUP_PRICE)}
	return {"data": {"rank": randi_range(2, 14), "suit": randi_range(0, 3),
			"cursed": false, "mod": ""}, "price": _price(SHOP_CARD_PRICE)}


## The Hermit's price for the next burn — it climbs with every use.
func _burn_price() -> int:
	return _price(SHOP_REMOVE_PRICE + SHOP_REMOVE_STEP * burns_used)


func _show_shop() -> void:
	_hide_all()
	main.game_started = false
	main.play_music("shop")
	# Stock is fixed per shop room: no restocking by leaving/burning.
	if _shop_stock_room != room_index:
		_shop_stock = []
		for i in 10:
			var o := _shop_card_offer()
			o["bought"] = false
			_shop_stock.append(o)
		_shop_stock_relic = _unowned_relic()
		_shop_burned_here = false
		_shop_stock_room = room_index
	_shop_info.text = "CHIPS  %d" % chips
	_shop_burn_btn.text = "BURN A CARD — %d chips" % _burn_price()
	_shop_burn_btn.disabled = _shop_burned_here
	if _shop_burned_here:
		_shop_burn_btn.text = "THE FORGE IS COLD (one burn per shop)"
	if _shop_stock_relic == "" or relics.size() >= MAX_RELICS \
			or relics.has(_shop_stock_relic):
		_shop_relic_btn.text = "NO RELICS IN STOCK"
		_shop_relic_btn.disabled = true
	else:
		var r: Dictionary = RELICS[_shop_stock_relic]
		_shop_relic_btn.text = "RELIC: %s — %d chips\n%s" % [r.name,
				_price(RELIC_PRICES[r.rarity]), r.desc]
		_shop_relic_btn.disabled = false
	for child in _shop_box.get_children():
		child.queue_free()
	for i in _shop_stock.size():
		var offer: Dictionary = _shop_stock[i]
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
		if offer.bought:
			holder.disabled = true
			price_tag.text = "SOLD"
		var slot := offer
		holder.pressed.connect(func() -> void:
			if not slot.bought and chips >= price:
				chips -= price
				slot.bought = true
				deck.append(slot.data)
				main.board._play_sound(Board.SFX_FLIP, 1.1, -8.0)
				holder.disabled = true
				price_tag.text = "SOLD"
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
	_deck_view_burn = true
	_remove_info.text = "Pick a card to burn — %d chips (one per shop)" % _burn_price()
	_populate_deck_view()


## Read-only deck browser, reachable from the tarot screen.
func _show_deck() -> void:
	_hide_all()
	_deck_view_burn = false
	_remove_info.text = "Your deck — %d cards. Hover a card for its story." % deck.size()
	_populate_deck_view()


func _populate_deck_view() -> void:
	_deck_stat.text = "Hover a card\nfor details."
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
		pc.mod = card_data.get("mod", "")
		pc.material = Themes.current_material()
		pc.position = Vector2(50, 70)
		holder.add_child(pc)
		var idx := i
		holder.mouse_entered.connect(func() -> void:
			if idx < deck.size():
				_deck_stat.text = _deck_stat_text(deck[idx]))
		holder.pressed.connect(func() -> void:
			if idx < deck.size():
				_deck_stat.text = _deck_stat_text(deck[idx])
			if _deck_view_burn and chips >= _burn_price() and not _shop_burned_here:
				chips -= _burn_price()
				burns_used += 1
				_shop_burned_here = true
				deck.remove_at(idx)
				main.board._play_sound(Board.SFX_POPS.pick_random(), 1.0, -8.0)
				_save_run()
				_show_shop())
		_remove_grid.add_child(holder)
	remove_layer.visible = true


## The hover panel: what this card is and what it does.
func _deck_stat_text(d: Dictionary) -> String:
	var rank := int(d.rank)
	var rank_names := {11: "JACK", 12: "QUEEN", 13: "KING", 14: "ACE"}
	var text := "%s OF %s\nPip value  %d\n\n" % [rank_names.get(rank, str(rank)),
			String(PlayingCard.SUIT_NAMES[int(d.suit)]).to_upper(), rank]
	if d.get("cursed", false):
		return text + "CURSED\nDead weight: it can't be played and it blocks chains. Burn it at a shop."
	match String(d.get("mod", "")):
		"chip":
			text += "CHIP\nPays +%d bonus chips every time it's played." % main.board.chip_bonus
		"mult":
			text += "MULT\nMultiplies the whole hand's score ×%.1f. Stacks with other mult cards." % main.board.mult_factor
		"cash":
			text += "CASH\nPays $1 of real, bankable cash when played."
		"chipsplode":
			text += "CHIP EXPLOSION\nWhen cleared, every card around it becomes a CHIP card."
		"boost":
			text += "BOOST\nWhen cleared, the card its arrow points at gains +1 rank. The arrow turns a quarter every hand — time it."
		_:
			text += "No enhancement.\nHonest cardboard."
	return text


# --- Flow: run end --------------------------------------------------------

func _end_run(title: String, body: String, _payout: int) -> void:
	_hide_all()
	run_active = false
	main.game_started = false
	main.play_music("lost" if title in ["BUSTED OUT", "BLINDED OUT"] else "menu")
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
	var deck_btn: Button = main._button(tarot_layer, "VIEW DECK", Vector2(1660, 970), Vector2(200, 54))
	deck_btn.add_theme_font_size_override("font_size", 20)
	deck_btn.pressed.connect(_show_deck)

	bet_layer = _layer()
	_screen_title(bet_layer, "THE STAKES")
	_bet_info = _center(bet_layer, "", 250, 26, main.OFFWHITE)
	var bminus: Button = main._button(bet_layer, "−", Vector2(700, 410), Vector2(100, 70))
	bminus.add_theme_font_size_override("font_size", 40)
	bminus.pressed.connect(func() -> void:
		_bet_amount -= int(current_offer.min_bet)
		_refresh_bet_labels())
	_bet_amount_label = _center(bet_layer, "", 428, 34, main.OFFWHITE)
	var bplus: Button = main._button(bet_layer, "+", Vector2(1120, 410), Vector2(100, 70))
	bplus.add_theme_font_size_override("font_size", 40)
	bplus.pressed.connect(func() -> void:
		_bet_amount += int(current_offer.min_bet)
		_refresh_bet_labels())
	var minus: Button = main._button(bet_layer, "−", Vector2(700, 510), Vector2(100, 70))
	minus.add_theme_font_size_override("font_size", 40)
	minus.pressed.connect(func() -> void:
		_bet_hands = maxi(MIN_HANDS_TAKE, _bet_hands - 1)
		_refresh_bet_labels())
	_bet_hands_label = _center(bet_layer, "", 528, 34, main.OFFWHITE)
	var plus: Button = main._button(bet_layer, "+", Vector2(1120, 510), Vector2(100, 70))
	plus.add_theme_font_size_override("font_size", 40)
	plus.pressed.connect(func() -> void:
		_bet_hands = mini(MAX_HANDS_BUY, _bet_hands + 1)
		_refresh_bet_labels())
	_center(bet_layer, "Hands are free — fewer hands promised, fatter odds on your bet.", 600, 18, main.DIM)
	_bet_stake_label = _center(bet_layer, "", 640, 36, main.GOLD)
	_bet_deal_btn = main._button(bet_layer, "DEAL ME IN", Vector2(760, 720), Vector2(400, 70))
	_bet_deal_btn.add_theme_font_size_override("font_size", 28)
	_bet_deal_btn.pressed.connect(_confirm_bet)
	var bet_back := func() -> void:
		bet_layer.visible = false
		_show_tarot()
	_bet_back_btn = _back_button(bet_layer, bet_back, "BACK")

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
		if _shop_stock_relic == "":
			return
		var cost := _price(RELIC_PRICES[RELICS[_shop_stock_relic].rarity])
		if chips >= cost and relics.size() < MAX_RELICS:
			chips -= cost
			_gain_relic(_shop_stock_relic)
			main.board._play_sound(Board.SFX_SHUFFLE, 1.3, -8.0)
			_shop_stock_relic = ""
			_shop_relic_btn.disabled = true
			_shop_info.text = "CHIPS  %d" % chips)
	_shop_burn_btn = main._button(shop_layer, "", Vector2(555, 850), Vector2(380, 56))
	_shop_burn_btn.add_theme_font_size_override("font_size", 20)
	_shop_burn_btn.pressed.connect(_show_remove)
	var leave: Button = main._button(shop_layer, "BACK ON THE TRAIL", Vector2(985, 850), Vector2(380, 56))
	leave.add_theme_font_size_override("font_size", 20)
	leave.pressed.connect(_leave_shop)

	remove_layer = _layer()
	_screen_title(remove_layer, "THE DECK")
	_remove_info = _center(remove_layer, "", 210, 24, main.OFFWHITE)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(240, 270)
	scroll.size = Vector2(1100, 620)
	remove_layer.add_child(scroll)
	_remove_grid = GridContainer.new()
	_remove_grid.columns = 10
	scroll.add_child(_remove_grid)
	_deck_stat = Label.new()
	_deck_stat.position = Vector2(1400, 290)
	_deck_stat.size = Vector2(440, 580)
	_deck_stat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_deck_stat.add_theme_font_size_override("font_size", 24)
	_deck_stat.add_theme_color_override("font_color", main.GOLD)
	remove_layer.add_child(_deck_stat)
	var remove_back := func() -> void:
		remove_layer.visible = false
		if _deck_view_burn:
			_show_shop()
		else:
			_show_tarot()
	_back_button(remove_layer, remove_back, "BACK")

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


## Chunky, casino-visible slider: thick gold-rimmed track, gold fill,
## and a fat round knob (drawn to a texture in code — no assets).
func _back_button(parent: Control, action: Callable, text := "BACK") -> Button:
	var b: Button = main._button(parent, text, Vector2(60, 970), Vector2(200, 54))
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(action)
	return b
