class_name Abilities
extends RefCounted

## Ability cards: the reward for clearing a trail table. They have no
## rank or suit and never go in the deck. You equip them to poker hands,
## and each hand has one slot for every card it uses. An ability either
## fires every time its hand is played, or works passively from the hand
## it sits on. A ride starts with none.
##
## Every ability rides with a side: SHERIFF (the law: clean tables,
## clutch hands, a big posse), OUTLAW (chaos, loot and curses, and paying
## to play), BOUNTY HUNTER (the long hunt: notches, bounties, patience),
## or DRIFTER (rides alone). "Posse" effects count every ability of
## their side you have equipped, copies included, so a build leans in.
##
## Effects (fx) by where they're applied:
##   board, scoring (pure, so the preview shows them; `ctx` comes from
##   the trail through Board.ability_ctx):
##     flat: n            +n to the score before multipliers
##     mult: x            ×x after Mult cards and Jokers
##     cash: n            +$n trail cash
##     dead_mans: [a, b]  ×a, or ×b when the hand is Aces and Eights
##     posse_flat: n      +n for every equipped ability of this side
##     posse_mult: x      ×(1 + x per equipped ability of this side)
##     clean_flat: n      +n when the table has no hazards on it
##     clean_mult: x      ×x when the table has no hazards on it
##     clutch_mult: x     ×x on the last hand (or 30 seconds or less)
##     flat_per_hazard: n +n for every hazard on the table
##     flat_per_cash: n   +n for every $1 of trail cash (up to `cap`)
##     flat_per_curse: n  +n for every cursed card in the deck
##     cash_per_mod: n    +$n for every Cash or Gold card in the hand
##     pay_mult: [c, x]   ×x, paid for with $c of trail cash
##     notch_flat: n      +n for every earlier play of this hand this ride
##     flat_per_played: n +n for every hand already played at this table
##     bounty_mult: x     ×x at a bounty table (off_flat: n elsewhere)
##     mult_per_caught: x ×(1 + x per outlaw brought in this ride)
##     sides_mult: x      ×(1 + x per side you have an ability from)
##   trail, when the hand is played:
##     enhance: mod       the next plain card off the deck gets mod
##     clear: n           clears up to n random hazards (never stones)
##     douse: n           puts out up to n fires
##     fuse: n            every bomb's fuse grows by n
##     time: s            +s seconds on a clock table
##     hand_every: n      on a hands table, every nth fire refunds a hand
##     free: s            the hand doesn't use up a hand (+s seconds on a clock)
##     next_mult: x       the next hand counts ×x
##     next_flat: n       the next hand scores +n before multipliers
##     extra_hit: n       a hand that hits the outlaw hits him n more times
##     cash_per_hit: n    every hit on the outlaw pays $n
##     brand: mod         one plain card in the hand gets mod in the deck
##   trail, passive (at table start):
##     refill_hazard_mult: x  refills bring hazards x as often
##     extra_hands: n         +n hands (or +secs on a clock)
##     first_mult: x          the first hand at every table counts ×x
##     posse_hands: n         +1 hand for every n Sheriff abilities
##     last_stand: n          once a table, running out gives n more hands

const HAND_SLOTS := {
	"Pair": 2, "Three of a Kind": 3, "Two Pair": 4, "Four of a Kind": 4,
	"Straight": 5, "Flush": 5, "Full House": 5, "Straight Flush": 5,
	"Five of a Kind": 5, "Royal Flush": 5, "Flushed Five": 5,
}
## The hands in the order the Abilities screen lists them.
const HAND_ORDER := ["Pair", "Three of a Kind", "Two Pair", "Four of a Kind",
		"Straight", "Flush", "Full House", "Straight Flush", "Five of a Kind",
		"Royal Flush", "Flushed Five"]
const FIVE_CARD := ["Straight", "Flush", "Full House", "Straight Flush",
		"Five of a Kind", "Royal Flush", "Flushed Five"]
const RARITY_NAMES := ["Common", "Rare", "Epic", "Legendary"]
const RARITY_IDS := ["common", "rare", "epic", "legendary"]
const PRICES := [8, 16, 32, 60]   # merchant shelf, before the trail's _price()
const PASSIVE_FX := ["refill_hazard_mult", "extra_hands", "first_mult", "posse_hands",
		"last_stand"]
const SIDES := ["sheriff", "outlaw", "bounty"]
const SIDE_NAMES := {"sheriff": "Sheriff", "outlaw": "Outlaw", "bounty": "Bounty Hunter",
		"drifter": "Drifter", "any": "Every side"}
const SIDE_COLORS := {"sheriff": Color("d9b45a"), "outlaw": Color("c65b4e"),
		"bounty": Color("8fb3c9"), "drifter": Color("a89a7c"), "any": Color("e8e0cc")}
const CASH_CAP := 400   # For a Few Dollars More tops out here

const DEFS := {
	# --- Drifters: ride with nobody ----------------------------------------
	"spurs": {"name": "Spurs", "rarity": 0, "slots": 1, "hands": [], "side": "drifter",
		"fx": {"flat": 20}, "glyph": ["relic_glyph", "horseshoe"],
		"desc": "Every time you play this hand, it scores {flat} more points before any multipliers."},
	"matched_pair": {"name": "Matched Pair", "rarity": 0, "slots": 2, "hands": ["Pair"], "side": "drifter",
		"fx": {"mult": 1.5}, "glyph": ["mod_emblem", "mult"],
		"desc": "Your Pairs score {mult}."},
	"triple_threat": {"name": "Triple Threat", "rarity": 0, "slots": 2, "hands": ["Three of a Kind"], "side": "drifter",
		"fx": {"flat": 60}, "glyph": ["relic_glyph", "lucky_chip"],
		"desc": "Your Three of a Kinds score {flat} more points before any multipliers."},
	"hot_brand": {"name": "Hot Brand", "rarity": 0, "slots": 2, "hands": [], "side": "drifter",
		"fx": {"enhance": "plus"}, "glyph": ["provision_glyph", "branding_iron"],
		"desc": "Every time you play this hand, {next_cards} off the deck {gets} a Plus enhancement."},
	"branded_for_life": {"name": "Branded for Life", "rarity": 3, "slots": 5, "side": "drifter",
		"hands": ["Flush", "Straight Flush", "Royal Flush", "Flushed Five"],
		"fx": {"brand": "mult"}, "glyph": ["provision_glyph", "branding_iron"],
		"desc": "Every time you play this hand, {brand_w} plain card{brand_s} in it {brand_becomes} {brand_a}Mult card{brand_s} in your deck for the rest of the ride."},
	"good_bad_ugly": {"name": "The Good, the Bad and the Ugly", "rarity": 3, "slots": 5, "hands": [],
		"side": "drifter", "fx": {"sides_mult": 0.5}, "glyph": ["twist_icon", "storm"],
		"desc": "Scores {sides_pct}% more for each side you ride with: Sheriff, Outlaw and Bounty Hunter. With all three, it scores {sides_all}."},

	# --- Sheriffs: keep the peace -------------------------------------------
	"keep_the_peace": {"name": "Keep the Peace", "rarity": 0, "slots": 1, "hands": [], "side": "sheriff",
		"fx": {"posse_flat": 15}, "glyph": ["relic_glyph", "tin_star"],
		"desc": "Scores {posse_flat} more points for every Sheriff ability you have equipped, this one included."},
	"reach_for_the_sky": {"name": "Reach for the Sky", "rarity": 0, "slots": 2, "hands": [], "side": "sheriff",
		"fx": {"clean_flat": 50}, "glyph": ["twist_icon", "play_only"],
		"desc": "Scores {clean_flat} more points when there isn't a single hazard on the table."},
	"push_broom": {"name": "Push Broom", "rarity": 0, "slots": 2, "hands": [], "side": "sheriff",
		"fx": {"clear": 1}, "glyph": ["provision_glyph", "canteen"],
		"desc": "Every time you play this hand, it clears {clear_hazards}. Honey counts, but a stone never does."},
	"borrowed_time": {"name": "Borrowed Time", "rarity": 0, "slots": 1, "hands": [], "side": "sheriff",
		"fx": {"time": 5, "hand_every": 4}, "glyph": ["icon", "watch"],
		"desc": "On a clock table, this hand gives you {time} more seconds. On a hands table, {every_nth} you play it you get a hand back."},
	"lookout": {"name": "Lookout", "rarity": 0, "slots": 2, "hands": [], "side": "sheriff",
		"fx": {"refill_hazard_mult": 0.5}, "glyph": ["relic_glyph", "mirror_shades"],
		"desc": "While it's equipped, new cards come in with hazards only {refill_frac}."},
	"deputy_badge": {"name": "Deputy's Badge", "rarity": 1, "slots": 2, "hands": [], "side": "sheriff",
		"fx": {"enhance": "chip"}, "glyph": ["relic_glyph", "tin_star"],
		"desc": "Every time you play this hand, {next_cards} off the deck {become} {a_}Cash card{card_s}."},
	"cool_head": {"name": "Cool Head", "rarity": 1, "slots": 2, "hands": [], "side": "sheriff",
		"fx": {"fuse": 1}, "glyph": ["relic_glyph", "bomb_squad_badge"],
		"desc": "Every time you play this hand, every bomb on the table gets {fuse_w} more hand{fuse_s} on its fuse."},
	"rain_barrel": {"name": "Rain Barrel", "rarity": 1, "slots": 3, "hands": [], "side": "sheriff",
		"fx": {"douse": 2}, "glyph": ["relic_glyph", "fire_blanket"],
		"desc": "Every time you play this hand, it puts out up to {douse_w} fire{douse_s}."},
	"saddle_horn": {"name": "Saddle Horn", "rarity": 1, "slots": 3, "hands": [], "side": "sheriff",
		"fx": {"extra_hands": 1}, "glyph": ["relic_glyph", "saddlebags"],
		"desc": "While it's equipped, you get {extra_hands_w} extra hand{extra_hands_s} at every table, or {horn_secs} more seconds on a clock."},
	"posse_up": {"name": "Posse Up", "rarity": 1, "slots": 2, "hands": [], "side": "sheriff",
		"fx": {"posse_hands": 3}, "glyph": ["relic_glyph", "chuck_wagon"],
		"desc": "While it's equipped, you get one extra hand at every table (or 15 seconds on a clock) for {posse_every}."},
	"law_and_order": {"name": "Law and Order", "rarity": 1, "slots": 3, "hands": [], "side": "sheriff",
		"fx": {"clean_mult": 1.5}, "glyph": ["relic_glyph", "swimming_goggles"],
		"desc": "Scores {clean_mult} when there isn't a single hazard on the table."},
	"high_noon": {"name": "Showdown at High Noon", "rarity": 1, "slots": 3, "hands": [], "side": "sheriff",
		"fx": {"clutch_mult": 2.0}, "glyph": ["twist_icon", "clock"],
		"desc": "Scores {clutch_mult} when it's your last hand at the table, or when there are 30 seconds or less on the clock."},
	"clean_sweep": {"name": "Clean Sweep", "rarity": 2, "slots": 4, "hands": ["Straight"], "side": "sheriff",
		"fx": {"clear": 3}, "glyph": ["provision_glyph", "canteen"],
		"desc": "Every time you play a Straight, it clears up to {clear} random hazards. Honey counts, but stones never do."},
	"huckleberry": {"name": "I'm Your Huckleberry", "rarity": 2, "slots": 2, "hands": [], "side": "sheriff",
		"fx": {"next_flat": 100}, "glyph": ["provision_glyph", "pocket_flask"],
		"desc": "Every time you play this hand, the next hand you play scores {next_flat} more points before any multipliers."},
	"law_of_the_land": {"name": "Law of the Land", "rarity": 2, "slots": 4, "hands": [], "side": "sheriff",
		"fx": {"posse_mult": 0.2}, "glyph": ["relic_glyph", "tin_star"],
		"desc": "Scores {posse_pct}% more for every Sheriff ability you have equipped, this one included."},
	"rio_bravo": {"name": "Rio Bravo", "rarity": 3, "slots": 5, "hands": [], "side": "sheriff",
		"fx": {"last_stand": 2}, "glyph": ["relic_glyph", "second_wind"],
		"desc": "While it's equipped, once at every table, when you'd run out of hands you get {last_stand_w} more (or {stand_secs} more seconds on a clock)."},

	# --- Outlaws: take what you can -------------------------------------------
	"hole_in_the_wall": {"name": "Hole in the Wall Gang", "rarity": 0, "slots": 1, "hands": [], "side": "outlaw",
		"fx": {"posse_flat": 15}, "glyph": ["provision_glyph", "dynamite_stick"],
		"desc": "Scores {posse_flat} more points for every Outlaw ability you have equipped, this one included."},
	"side_bet": {"name": "Side Bet", "rarity": 0, "slots": 1, "hands": [], "side": "outlaw",
		"fx": {"cash": 1}, "glyph": ["mod_emblem", "chip"],
		"desc": "Every time you play this hand, you win ${cash}."},
	"powder_keg": {"name": "Powder Keg", "rarity": 0, "slots": 2, "hands": [], "side": "outlaw",
		"fx": {"flat_per_hazard": 25}, "glyph": ["twist_icon", "hz_bomb"],
		"desc": "Scores {flat_per_hazard} more points for every hazard on the table."},
	"fistful_of_dollars": {"name": "A Fistful of Dollars", "rarity": 0, "slots": 2, "hands": [], "side": "outlaw",
		"fx": {"cash": 1, "cash_per_mod": 1}, "glyph": ["relic_glyph", "gold_tooth"],
		"desc": "Every time you play this hand, you win ${cash}, plus ${cash_per_mod} for every Cash or Gold card in it."},
	"few_dollars_more": {"name": "For a Few Dollars More", "rarity": 1, "slots": 3, "hands": [], "side": "outlaw",
		"fx": {"flat_per_cash": 4}, "glyph": ["relic_glyph", "bankroll_clip"],
		"desc": "Scores {flat_per_cash} more points for every $1 of trail cash you're carrying, up to {cap} more."},
	"bad_reputation": {"name": "Bad Reputation", "rarity": 1, "slots": 2, "hands": [], "side": "outlaw",
		"fx": {"flat_per_curse": 40}, "glyph": ["twist_icon", "tough"],
		"desc": "Scores {flat_per_curse} more points for every cursed card in your deck."},
	"marked_card": {"name": "Marked Card", "rarity": 2, "slots": 3, "hands": [], "side": "outlaw",
		"fx": {"enhance": "mult"}, "glyph": ["mod_emblem", "mult"],
		"desc": "Every time you play this hand, {next_cards} off the deck {gets} a Mult enhancement."},
	"double_down": {"name": "Double Down", "rarity": 2, "slots": 3, "hands": [], "side": "outlaw",
		"fx": {"next_mult": 2.0}, "glyph": ["provision_glyph", "rattlesnake_tonic"],
		"desc": "Every time you play this hand, the next hand you play counts {next_mult}."},
	"on_the_house": {"name": "On the House", "rarity": 2, "slots": 4, "hands": [], "side": "outlaw",
		"fx": {"free": 8}, "glyph": ["relic_glyph", "lucky_chip"],
		"desc": "This hand doesn't use up a hand. On a clock table, you get {free} seconds back instead."},
	"dead_mans_hand": {"name": "Dead Man's Hand", "rarity": 2, "slots": 4, "hands": ["Two Pair"], "side": "outlaw",
		"fx": {"dead_mans": [1.5, 4.0]}, "glyph": ["mod_emblem", "mult"],
		"desc": "Your Two Pairs score {dm_a}, or {dm_b} if they're Aces and Eights."},
	"wild_bunch": {"name": "The Wild Bunch", "rarity": 2, "slots": 4, "hands": [], "side": "outlaw",
		"fx": {"posse_mult": 0.2}, "glyph": ["provision_glyph", "dynamite_stick"],
		"desc": "Scores {posse_pct}% more for every Outlaw ability you have equipped, this one included."},
	"great_train_robbery": {"name": "The Great Train Robbery", "rarity": 2, "slots": 3, "hands": [], "side": "outlaw",
		"fx": {"brand": "gold"}, "glyph": ["provision_glyph", "gold_pan"],
		"desc": "Every time you play this hand, {brand_w} plain card{brand_s} in it {brand_becomes} {brand_a}Gold card{brand_s} in your deck for the rest of the ride."},
	"house_money": {"name": "House Money", "rarity": 3, "slots": 5, "hands": ["Full House"], "side": "outlaw",
		"fx": {"mult": 2.0, "free": 8}, "glyph": ["mod_emblem", "gold"],
		"desc": "Your Full Houses score {mult}, and they don't use up a hand (or give {free} seconds back on a clock)."},
	"desperado": {"name": "Desperado", "rarity": 3, "slots": 5, "hands": [], "side": "outlaw",
		"fx": {"pay_mult": [2, 3.0]}, "glyph": ["relic_glyph", "snake_oil"],
		"desc": "Scores {pay_mult}, but it costs ${pay_cost} of trail cash every time. With less than ${pay_cost} on you, it doesn't fire."},

	# --- Bounty hunters: bring 'em in ------------------------------------------
	"hunting_party": {"name": "Hunting Party", "rarity": 0, "slots": 1, "hands": [], "side": "bounty",
		"fx": {"posse_flat": 15}, "glyph": ["relic_glyph", "dowsing_rod"],
		"desc": "Scores {posse_flat} more points for every Bounty Hunter ability you have equipped, this one included."},
	"notches": {"name": "Notches on the Gun", "rarity": 0, "slots": 2, "hands": [], "side": "bounty",
		"fx": {"notch_flat": 5}, "glyph": ["provision_glyph", "barbers_razor"],
		"desc": "Scores {notch_flat} more points for every time you've already played this hand on this ride."},
	"scattergun": {"name": "Scattergun", "rarity": 1, "slots": 3, "hands": [], "side": "bounty",
		"fx": {"mult": 1.5}, "glyph": ["draw", "bullet"],
		"desc": "This hand scores {mult}."},
	"fan_the_hammer": {"name": "Fan the Hammer", "rarity": 1, "slots": 4, "side": "bounty",
		"hands": ["Two Pair", "Four of a Kind"],
		"fx": {"flat": 100}, "glyph": ["draw", "bullet"],
		"desc": "Your Two Pairs and Four of a Kinds score {flat} more points before any multipliers."},
	"hired_gun": {"name": "Hired Gun", "rarity": 1, "slots": 2, "hands": [], "side": "bounty",
		"fx": {"extra_hit": 1}, "glyph": ["draw", "bullet"],
		"desc": "At a bounty table, when this hand hits the outlaw, it hits him {extra_hit_w} more time{extra_hit_s}."},
	"dead_or_alive": {"name": "Dead or Alive", "rarity": 1, "slots": 3, "hands": [], "side": "bounty",
		"fx": {"bounty_mult": 2.0, "off_flat": 40}, "glyph": ["relic_glyph", "rabbits_foot"],
		"desc": "Scores {bounty_mult} at a bounty table, and {off_flat} more points at any other table."},
	"true_grit": {"name": "True Grit", "rarity": 1, "slots": 2, "hands": [], "side": "bounty",
		"fx": {"flat_per_played": 20}, "glyph": ["relic_glyph", "horseshoe"],
		"desc": "Scores {flat_per_played} more points for every hand you've already played at this table."},
	"reward_money": {"name": "Reward Money", "rarity": 1, "slots": 2, "hands": [], "side": "bounty",
		"fx": {"cash_per_hit": 2}, "glyph": ["relic_glyph", "bankroll_clip"],
		"desc": "At a bounty table, every hit this hand lands on the outlaw pays ${cash_per_hit}."},
	"big_iron": {"name": "Big Iron", "rarity": 2, "slots": 5, "hands": FIVE_CARD, "side": "bounty",
		"fx": {"mult": 2.0}, "glyph": ["draw", "bullet"],
		"desc": "This hand scores {mult}. It only fits five-card hands."},
	"this_is_the_way": {"name": "This Is the Way", "rarity": 2, "slots": 3, "hands": [], "side": "bounty",
		"fx": {"mult_per_caught": 0.15}, "glyph": ["relic_glyph", "chisel"],
		"desc": "Scores {caught_pct}% more for every outlaw you've brought in on this ride."},
	"hang_em_high": {"name": "Hang 'Em High", "rarity": 2, "slots": 4, "hands": [], "side": "bounty",
		"fx": {"posse_mult": 0.2}, "glyph": ["relic_glyph", "dowsing_rod"],
		"desc": "Scores {posse_pct}% more for every Bounty Hunter ability you have equipped, this one included."},
	"fastest_gun": {"name": "Fastest Gun", "rarity": 3, "slots": 5, "hands": [], "side": "bounty",
		"fx": {"first_mult": 3.0}, "glyph": ["icon", "laser"],
		"desc": "While it's equipped, the first hand you play at every table counts {first_mult}."},
	"no_name": {"name": "The Man with No Name", "rarity": 3, "slots": 5, "hands": [], "side": "any",
		"fx": {"mult": 1.5}, "glyph": ["icon", "sleeve"],
		"desc": "Counts as a Sheriff, an Outlaw and a Bounty Hunter for every bonus that counts them, and scores {mult}."},
}


# --- Levels: two copies at the same level combine into one a level up --------
# A copy's key carries its level after an "@": "spurs" is level 1,
# "spurs@2" level 2. Every lookup here takes a key, so saves, offers and
# the loadout hold keys and never need a second array.
const MAX_LEVEL := 3
const ADDITIVE := ["flat", "posse_flat", "clean_flat", "flat_per_hazard", "flat_per_cash",
		"flat_per_curse", "notch_flat", "flat_per_played", "off_flat", "cash", "cash_per_mod",
		"cash_per_hit", "next_flat", "time", "free", "clear", "douse", "fuse", "extra_hands",
		"extra_hit", "last_stand"]
const MULTIPLIERS := ["mult", "clean_mult", "clutch_mult", "bounty_mult", "first_mult", "next_mult"]
const RATES := ["posse_mult", "mult_per_caught", "sides_mult"]
const ROMAN := ["", "", " II", " III"]
const WORDS := ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
const ORDINALS := {2: "second", 3: "third", 4: "fourth", 5: "fifth"}


static func base(key: String) -> String:
	return key.get_slice("@", 0)


static func level(key: String) -> int:
	return clampi(int(key.get_slice("@", 1)), 1, MAX_LEVEL) if key.contains("@") else 1


static func key_at(id: String, lv: int) -> String:
	return base(id) if lv <= 1 else "%s@%d" % [base(id), mini(lv, MAX_LEVEL)]


## The key two copies of `key` combine into ("" when it's already maxed).
static func combined(key: String) -> String:
	return "" if level(key) >= MAX_LEVEL else key_at(key, level(key) + 1)


## Its name with the level as a numeral: "Spurs", "Spurs II".
static func display_name(key: String) -> String:
	return ability_name(key) + String(ROMAN[level(key)])


## The effects at this copy's level. Points, cash, seconds and counts
## grow ×level; a multiplier's bonus part grows ×level (×1.5 → ×2 →
## ×2.5); per-member rates grow ×level; "every nth" steps come closer.
static func fx(key: String) -> Dictionary:
	var out: Dictionary = (def(key).get("fx", {}) as Dictionary).duplicate(true)
	var k := level(key)
	for f in out.keys():
		if f in ADDITIVE:
			out[f] = int(out[f]) * k
		elif f in MULTIPLIERS:
			out[f] = 1.0 + (float(out[f]) - 1.0) * k
		elif f in RATES:
			out[f] = float(out[f]) * k
	if out.has("dead_mans"):
		out["dead_mans"] = [1.0 + (float(out.dead_mans[0]) - 1.0) * k,
				1.0 + (float(out.dead_mans[1]) - 1.0) * k]
	if out.has("pay_mult"):
		out["pay_mult"] = [int(out.pay_mult[0]), 1.0 + (float(out.pay_mult[1]) - 1.0) * k]
	for f in ["hand_every", "posse_hands"]:
		if out.has(f):
			out[f] = maxi(1, int(out[f]) - (k - 1))
	if out.has("refill_hazard_mult"):
		out["refill_hazard_mult"] = pow(float(out.refill_hazard_mult), k)
	if out.has("enhance"):
		out["enhance_n"] = k
	if out.has("brand"):
		out["brand_n"] = k
	if out.has("flat_per_cash"):
		out["cap"] = CASH_CAP * k
	return out


## What this copy does, in a sentence or two, with its own numbers.
static func describe(key: String) -> String:
	var f := fx(key)
	var t := {}
	for k in f:
		if f[k] is int:
			t[k] = str(f[k])
			t[k + "_w"] = _word(int(f[k]))
			t[k + "_s"] = "" if int(f[k]) == 1 else "s"
		elif f[k] is float:
			t[k] = _times(float(f[k]))
	if f.has("posse_mult"):
		t["posse_pct"] = str(roundi(float(f.posse_mult) * 100.0))
	if f.has("mult_per_caught"):
		t["caught_pct"] = str(roundi(float(f.mult_per_caught) * 100.0))
	if f.has("sides_mult"):
		t["sides_pct"] = str(roundi(float(f.sides_mult) * 100.0))
		t["sides_all"] = _times(1.0 + 3.0 * float(f.sides_mult))
	if f.has("dead_mans"):
		t["dm_a"] = _times(float(f.dead_mans[0]))
		t["dm_b"] = _times(float(f.dead_mans[1]))
	if f.has("pay_mult"):
		t["pay_cost"] = str(int(f.pay_mult[0]))
		t["pay_mult"] = _times(float(f.pay_mult[1]))
	if f.has("clear"):
		t["clear_hazards"] = "a random hazard" if int(f.clear) == 1 \
				else "up to %s random hazards" % _word(int(f.clear))
	if f.has("hand_every"):
		var nth := int(f.hand_every)
		t["every_nth"] = "every time" if nth <= 1 else "every %s time" % String(ORDINALS.get(nth, str(nth) + "th"))
	if f.has("posse_hands"):
		var every := int(f.posse_hands)
		t["posse_every"] = "every Sheriff ability you have equipped" if every <= 1 \
				else "every %s Sheriff abilities you have equipped" % _word(every)
	if f.has("refill_hazard_mult"):
		var x := float(f.refill_hazard_mult)
		t["refill_frac"] = "half as often" if is_equal_approx(x, 0.5) \
				else "a quarter as often" if is_equal_approx(x, 0.25) \
				else "an eighth as often" if is_equal_approx(x, 0.125) \
				else "%d%% as often" % roundi(x * 100.0)
	if f.has("enhance_n"):
		var en := int(f.enhance_n)
		t["next_cards"] = "the next plain card" if en == 1 else "the next %s plain cards" % _word(en)
		t["gets"] = "gets" if en == 1 else "get"
		t["become"] = "becomes" if en == 1 else "become"
		t["a_"] = "a " if en == 1 else ""
		t["card_s"] = "" if en == 1 else "s"
	if f.has("brand_n"):
		var bn := int(f.brand_n)
		t["brand_w"] = _word(bn)
		t["brand_s"] = "" if bn == 1 else "s"
		t["brand_becomes"] = "becomes" if bn == 1 else "become"
		t["brand_a"] = "a " if bn == 1 else ""
	if f.has("extra_hands"):
		t["horn_secs"] = str(15 * int(f.extra_hands))
	if f.has("last_stand"):
		t["stand_secs"] = str(15 * int(f.last_stand))
	if f.has("cap"):
		t["cap"] = str(int(f.cap))
	return String(def(key).get("desc", "")).format(t)


static func _word(n: int) -> String:
	return String(WORDS[n]) if n >= 0 and n < WORDS.size() else str(n)


## "double", "triple", or "1.5 times as much".
static func _times(x: float) -> String:
	if is_equal_approx(x, 2.0):
		return "double"
	if is_equal_approx(x, 3.0):
		return "triple"
	return "%s times as much" % String.num(snappedf(x, 0.01))


## The side an ability rides with: sheriff, outlaw, bounty, drifter or any.
static func side(id: String) -> String:
	return String(def(id).get("side", "drifter"))


static func side_name(id: String) -> String:
	return String(SIDE_NAMES.get(side(id), "Drifter"))


## Whether this ability counts toward a side's posse.
static func rides_with(id: String, s: String) -> bool:
	var mine := side(id)
	return mine == s or (mine == "any" and s in SIDES)


## How many of `ids` ride with each side: {sheriff, outlaw, bounty}, and
## "sides": how many of the three have at least one. A combined copy
## counts once per level, so combining never shrinks the posse.
static func posse_counts(ids: Array) -> Dictionary:
	var out := {"sheriff": 0, "outlaw": 0, "bounty": 0}
	for id in ids:
		for s in SIDES:
			if rides_with(String(id), s):
				out[s] = int(out[s]) + level(String(id))
	var sides := 0
	for s in SIDES:
		if int(out[s]) > 0:
			sides += 1
	out["sides"] = sides
	return out


static func has(id: String) -> bool:
	return DEFS.has(base(id))


static func def(id: String) -> Dictionary:
	return DEFS.get(base(id), {})


static func ability_name(id: String) -> String:
	return String(def(id).get("name", id))


static func slots(id: String) -> int:
	return int(def(id).get("slots", 1))


## Each level up lifts the rarity a step, as far as Legendary.
static func rarity(id: String) -> int:
	return mini(3, int(def(id).get("rarity", 0)) + level(id) - 1)


static func is_passive(id: String) -> bool:
	for k in def(id).get("fx", {}):
		if k in PASSIVE_FX:
			return true
	return false


## Whether this ability can sit on this hand at all (room aside).
static func fits(id: String, hand: String) -> bool:
	if not has(id) or not HAND_SLOTS.has(hand):
		return false
	var allowed: Array = def(id).get("hands", [])
	if not allowed.is_empty() and not allowed.has(hand):
		return false
	return slots(id) <= int(HAND_SLOTS[hand])


## Why it can never go on this hand, in a sentence ("" when it can).
static func misfit_reason(id: String, hand: String) -> String:
	if fits(id, hand):
		return ""
	var allowed: Array = def(id).get("hands", [])
	if allowed == FIVE_CARD:
		return "%s only fits five-card hands." % ability_name(id)
	if not allowed.is_empty() and not allowed.has(hand):
		return "%s only fits %s." % [ability_name(id), _join_or(allowed)]
	return "%s needs %d slots, and a %s only has %d." % [ability_name(id), slots(id),
			hand, int(HAND_SLOTS.get(hand, 0))]


## "Pairs only" style restriction line for the card face ("" for any hand).
static func restriction_line(id: String) -> String:
	var allowed: Array = def(id).get("hands", [])
	if allowed.is_empty():
		return ""
	if allowed == FIVE_CARD:
		return "Five-card hands only"
	if allowed.size() == 1:
		return "%s only" % String(allowed[0])
	return _join_or(allowed) + " only"


## The smallest hand this ability fits (for auto-equipping a first card).
static func smallest_fit(id: String) -> String:
	for hand in HAND_ORDER:
		if fits(id, hand):
			return hand
	return ""


static func ids_of_rarity(r: int) -> Array:
	var out: Array = []
	for id in DEFS:
		if int(DEFS[id].rarity) == r:
			out.append(id)
	return out


static func _join_or(hands: Array) -> String:
	if hands.size() <= 1:
		return "" if hands.is_empty() else String(hands[0])
	var head := ", ".join(PackedStringArray(hands.slice(0, hands.size() - 1)))
	return "%s or %s" % [head, String(hands.back())]
