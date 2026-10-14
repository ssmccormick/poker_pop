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
		"desc": "Every time you play this hand, it scores 20 more points before any multipliers."},
	"matched_pair": {"name": "Matched Pair", "rarity": 0, "slots": 2, "hands": ["Pair"], "side": "drifter",
		"fx": {"mult": 1.5}, "glyph": ["mod_emblem", "mult"],
		"desc": "Your Pairs score 1.5 times as much."},
	"triple_threat": {"name": "Triple Threat", "rarity": 0, "slots": 2, "hands": ["Three of a Kind"], "side": "drifter",
		"fx": {"flat": 60}, "glyph": ["relic_glyph", "lucky_chip"],
		"desc": "Your Three of a Kinds score 60 more points before any multipliers."},
	"hot_brand": {"name": "Hot Brand", "rarity": 0, "slots": 2, "hands": [], "side": "drifter",
		"fx": {"enhance": "plus"}, "glyph": ["provision_glyph", "branding_iron"],
		"desc": "Every time you play this hand, the next plain card off the deck gets a Plus enhancement."},
	"branded_for_life": {"name": "Branded for Life", "rarity": 3, "slots": 5, "side": "drifter",
		"hands": ["Flush", "Straight Flush", "Royal Flush", "Flushed Five"],
		"fx": {"brand": "mult"}, "glyph": ["provision_glyph", "branding_iron"],
		"desc": "Every time you play this hand, one plain card in it becomes a Mult card in your deck for the rest of the ride."},
	"good_bad_ugly": {"name": "The Good, the Bad and the Ugly", "rarity": 3, "slots": 5, "hands": [],
		"side": "drifter", "fx": {"sides_mult": 0.5}, "glyph": ["twist_icon", "storm"],
		"desc": "Scores 50% more for each side you ride with: Sheriff, Outlaw and Bounty Hunter. With all three, it scores 2.5 times as much."},

	# --- Sheriffs: keep the peace -------------------------------------------
	"keep_the_peace": {"name": "Keep the Peace", "rarity": 0, "slots": 1, "hands": [], "side": "sheriff",
		"fx": {"posse_flat": 15}, "glyph": ["relic_glyph", "tin_star"],
		"desc": "Scores 15 more points for every Sheriff ability you have equipped, this one included."},
	"reach_for_the_sky": {"name": "Reach for the Sky", "rarity": 0, "slots": 2, "hands": [], "side": "sheriff",
		"fx": {"clean_flat": 50}, "glyph": ["twist_icon", "play_only"],
		"desc": "Scores 50 more points when there isn't a single hazard on the table."},
	"push_broom": {"name": "Push Broom", "rarity": 0, "slots": 2, "hands": [], "side": "sheriff",
		"fx": {"clear": 1}, "glyph": ["provision_glyph", "canteen"],
		"desc": "Every time you play this hand, it clears a random hazard (never a stone)."},
	"borrowed_time": {"name": "Borrowed Time", "rarity": 0, "slots": 1, "hands": [], "side": "sheriff",
		"fx": {"time": 5, "hand_every": 4}, "glyph": ["icon", "watch"],
		"desc": "On a clock table, this hand gives you 5 more seconds. On a hands table, every fourth time you play it you get a hand back."},
	"lookout": {"name": "Lookout", "rarity": 0, "slots": 2, "hands": [], "side": "sheriff",
		"fx": {"refill_hazard_mult": 0.5}, "glyph": ["relic_glyph", "mirror_shades"],
		"desc": "While it's equipped, new cards come in with hazards only half as often."},
	"deputy_badge": {"name": "Deputy's Badge", "rarity": 1, "slots": 2, "hands": [], "side": "sheriff",
		"fx": {"enhance": "chip"}, "glyph": ["relic_glyph", "tin_star"],
		"desc": "Every time you play this hand, the next plain card off the deck becomes a Cash card."},
	"cool_head": {"name": "Cool Head", "rarity": 1, "slots": 2, "hands": [], "side": "sheriff",
		"fx": {"fuse": 1}, "glyph": ["relic_glyph", "bomb_squad_badge"],
		"desc": "Every time you play this hand, every bomb on the table gets one more hand on its fuse."},
	"rain_barrel": {"name": "Rain Barrel", "rarity": 1, "slots": 3, "hands": [], "side": "sheriff",
		"fx": {"douse": 2}, "glyph": ["relic_glyph", "fire_blanket"],
		"desc": "Every time you play this hand, it puts out up to two fires."},
	"saddle_horn": {"name": "Saddle Horn", "rarity": 1, "slots": 3, "hands": [], "side": "sheriff",
		"fx": {"extra_hands": 1}, "glyph": ["relic_glyph", "saddlebags"],
		"desc": "While it's equipped, you get one extra hand at every table, or 15 more seconds on a clock."},
	"posse_up": {"name": "Posse Up", "rarity": 1, "slots": 2, "hands": [], "side": "sheriff",
		"fx": {"posse_hands": 3}, "glyph": ["relic_glyph", "chuck_wagon"],
		"desc": "While it's equipped, you get one extra hand at every table (or 15 seconds on a clock) for every three Sheriff abilities you have equipped."},
	"law_and_order": {"name": "Law and Order", "rarity": 1, "slots": 3, "hands": [], "side": "sheriff",
		"fx": {"clean_mult": 1.5}, "glyph": ["relic_glyph", "swimming_goggles"],
		"desc": "Scores 1.5 times as much when there isn't a single hazard on the table."},
	"high_noon": {"name": "Showdown at High Noon", "rarity": 1, "slots": 3, "hands": [], "side": "sheriff",
		"fx": {"clutch_mult": 2.0}, "glyph": ["twist_icon", "clock"],
		"desc": "Scores double when it's your last hand at the table, or when there are 30 seconds or less on the clock."},
	"clean_sweep": {"name": "Clean Sweep", "rarity": 2, "slots": 4, "hands": ["Straight"], "side": "sheriff",
		"fx": {"clear": 3}, "glyph": ["provision_glyph", "canteen"],
		"desc": "Every time you play a Straight, it clears up to three random hazards (never stones)."},
	"huckleberry": {"name": "I'm Your Huckleberry", "rarity": 2, "slots": 2, "hands": [], "side": "sheriff",
		"fx": {"next_flat": 100}, "glyph": ["provision_glyph", "pocket_flask"],
		"desc": "Every time you play this hand, the next hand you play scores 100 more points before any multipliers."},
	"law_of_the_land": {"name": "Law of the Land", "rarity": 2, "slots": 4, "hands": [], "side": "sheriff",
		"fx": {"posse_mult": 0.2}, "glyph": ["relic_glyph", "tin_star"],
		"desc": "Scores 20% more for every Sheriff ability you have equipped, this one included."},
	"rio_bravo": {"name": "Rio Bravo", "rarity": 3, "slots": 5, "hands": [], "side": "sheriff",
		"fx": {"last_stand": 2}, "glyph": ["relic_glyph", "second_wind"],
		"desc": "While it's equipped, once at every table, when you'd run out of hands you get two more (or 30 more seconds on a clock)."},

	# --- Outlaws: take what you can -------------------------------------------
	"hole_in_the_wall": {"name": "Hole in the Wall Gang", "rarity": 0, "slots": 1, "hands": [], "side": "outlaw",
		"fx": {"posse_flat": 15}, "glyph": ["provision_glyph", "dynamite_stick"],
		"desc": "Scores 15 more points for every Outlaw ability you have equipped, this one included."},
	"side_bet": {"name": "Side Bet", "rarity": 0, "slots": 1, "hands": [], "side": "outlaw",
		"fx": {"cash": 1}, "glyph": ["mod_emblem", "chip"],
		"desc": "Every time you play this hand, you win $1."},
	"powder_keg": {"name": "Powder Keg", "rarity": 0, "slots": 2, "hands": [], "side": "outlaw",
		"fx": {"flat_per_hazard": 25}, "glyph": ["twist_icon", "hz_bomb"],
		"desc": "Scores 25 more points for every hazard on the table."},
	"fistful_of_dollars": {"name": "A Fistful of Dollars", "rarity": 0, "slots": 2, "hands": [], "side": "outlaw",
		"fx": {"cash": 1, "cash_per_mod": 1}, "glyph": ["relic_glyph", "gold_tooth"],
		"desc": "Every time you play this hand, you win $1, plus $1 for every Cash or Gold card in it."},
	"few_dollars_more": {"name": "For a Few Dollars More", "rarity": 1, "slots": 3, "hands": [], "side": "outlaw",
		"fx": {"flat_per_cash": 4}, "glyph": ["relic_glyph", "bankroll_clip"],
		"desc": "Scores 4 more points for every $1 of trail cash you're carrying, up to 400 more."},
	"bad_reputation": {"name": "Bad Reputation", "rarity": 1, "slots": 2, "hands": [], "side": "outlaw",
		"fx": {"flat_per_curse": 40}, "glyph": ["twist_icon", "tough"],
		"desc": "Scores 40 more points for every cursed card in your deck."},
	"marked_card": {"name": "Marked Card", "rarity": 2, "slots": 3, "hands": [], "side": "outlaw",
		"fx": {"enhance": "mult"}, "glyph": ["mod_emblem", "mult"],
		"desc": "Every time you play this hand, the next plain card off the deck gets a Mult enhancement."},
	"double_down": {"name": "Double Down", "rarity": 2, "slots": 3, "hands": [], "side": "outlaw",
		"fx": {"next_mult": 2.0}, "glyph": ["provision_glyph", "rattlesnake_tonic"],
		"desc": "Every time you play this hand, the next hand you play counts double."},
	"on_the_house": {"name": "On the House", "rarity": 2, "slots": 4, "hands": [], "side": "outlaw",
		"fx": {"free": 8}, "glyph": ["relic_glyph", "lucky_chip"],
		"desc": "This hand doesn't use up a hand. On a clock table, you get 8 seconds back instead."},
	"dead_mans_hand": {"name": "Dead Man's Hand", "rarity": 2, "slots": 4, "hands": ["Two Pair"], "side": "outlaw",
		"fx": {"dead_mans": [1.5, 4.0]}, "glyph": ["mod_emblem", "mult"],
		"desc": "Your Two Pairs score 1.5 times as much, or 4 times as much if they're Aces and Eights."},
	"wild_bunch": {"name": "The Wild Bunch", "rarity": 2, "slots": 4, "hands": [], "side": "outlaw",
		"fx": {"posse_mult": 0.2}, "glyph": ["provision_glyph", "dynamite_stick"],
		"desc": "Scores 20% more for every Outlaw ability you have equipped, this one included."},
	"great_train_robbery": {"name": "The Great Train Robbery", "rarity": 2, "slots": 3, "hands": [], "side": "outlaw",
		"fx": {"brand": "gold"}, "glyph": ["provision_glyph", "gold_pan"],
		"desc": "Every time you play this hand, one plain card in it becomes a Gold card in your deck for the rest of the ride."},
	"house_money": {"name": "House Money", "rarity": 3, "slots": 5, "hands": ["Full House"], "side": "outlaw",
		"fx": {"mult": 2.0, "free": 8}, "glyph": ["mod_emblem", "gold"],
		"desc": "Your Full Houses score double, and they don't use up a hand (or give 8 seconds back on a clock)."},
	"desperado": {"name": "Desperado", "rarity": 3, "slots": 5, "hands": [], "side": "outlaw",
		"fx": {"pay_mult": [2, 3.0]}, "glyph": ["relic_glyph", "snake_oil"],
		"desc": "Scores triple, but it costs $2 of trail cash every time. With less than $2 on you, it doesn't fire."},

	# --- Bounty hunters: bring 'em in ------------------------------------------
	"hunting_party": {"name": "Hunting Party", "rarity": 0, "slots": 1, "hands": [], "side": "bounty",
		"fx": {"posse_flat": 15}, "glyph": ["relic_glyph", "dowsing_rod"],
		"desc": "Scores 15 more points for every Bounty Hunter ability you have equipped, this one included."},
	"notches": {"name": "Notches on the Gun", "rarity": 0, "slots": 2, "hands": [], "side": "bounty",
		"fx": {"notch_flat": 5}, "glyph": ["provision_glyph", "barbers_razor"],
		"desc": "Scores 5 more points for every time you've already played this hand on this ride."},
	"scattergun": {"name": "Scattergun", "rarity": 1, "slots": 3, "hands": [], "side": "bounty",
		"fx": {"mult": 1.5}, "glyph": ["draw", "bullet"],
		"desc": "This hand scores 1.5 times as much."},
	"fan_the_hammer": {"name": "Fan the Hammer", "rarity": 1, "slots": 4, "side": "bounty",
		"hands": ["Two Pair", "Four of a Kind"],
		"fx": {"flat": 100}, "glyph": ["draw", "bullet"],
		"desc": "Your Two Pairs and Four of a Kinds score 100 more points before any multipliers."},
	"hired_gun": {"name": "Hired Gun", "rarity": 1, "slots": 2, "hands": [], "side": "bounty",
		"fx": {"extra_hit": 1}, "glyph": ["draw", "bullet"],
		"desc": "At a bounty table, when this hand hits the outlaw, it hits him one more time."},
	"dead_or_alive": {"name": "Dead or Alive", "rarity": 1, "slots": 3, "hands": [], "side": "bounty",
		"fx": {"bounty_mult": 2.0, "off_flat": 40}, "glyph": ["relic_glyph", "rabbits_foot"],
		"desc": "Scores double at a bounty table, and 40 more points at any other table."},
	"true_grit": {"name": "True Grit", "rarity": 1, "slots": 2, "hands": [], "side": "bounty",
		"fx": {"flat_per_played": 20}, "glyph": ["relic_glyph", "horseshoe"],
		"desc": "Scores 20 more points for every hand you've already played at this table."},
	"reward_money": {"name": "Reward Money", "rarity": 1, "slots": 2, "hands": [], "side": "bounty",
		"fx": {"cash_per_hit": 2}, "glyph": ["relic_glyph", "bankroll_clip"],
		"desc": "At a bounty table, every hit this hand lands on the outlaw pays $2."},
	"big_iron": {"name": "Big Iron", "rarity": 2, "slots": 5, "hands": FIVE_CARD, "side": "bounty",
		"fx": {"mult": 2.0}, "glyph": ["draw", "bullet"],
		"desc": "This hand scores double. It only fits five-card hands."},
	"this_is_the_way": {"name": "This Is the Way", "rarity": 2, "slots": 3, "hands": [], "side": "bounty",
		"fx": {"mult_per_caught": 0.15}, "glyph": ["relic_glyph", "chisel"],
		"desc": "Scores 15% more for every outlaw you've brought in on this ride."},
	"hang_em_high": {"name": "Hang 'Em High", "rarity": 2, "slots": 4, "hands": [], "side": "bounty",
		"fx": {"posse_mult": 0.2}, "glyph": ["relic_glyph", "dowsing_rod"],
		"desc": "Scores 20% more for every Bounty Hunter ability you have equipped, this one included."},
	"fastest_gun": {"name": "Fastest Gun", "rarity": 3, "slots": 5, "hands": [], "side": "bounty",
		"fx": {"first_mult": 3.0}, "glyph": ["icon", "laser"],
		"desc": "While it's equipped, the first hand you play at every table counts triple."},
	"no_name": {"name": "The Man with No Name", "rarity": 3, "slots": 5, "hands": [], "side": "any",
		"fx": {"mult": 1.5}, "glyph": ["icon", "sleeve"],
		"desc": "Counts as a Sheriff, an Outlaw and a Bounty Hunter for every bonus that counts them, and scores 1.5 times as much."},
}


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
## "sides": how many of the three have at least one.
static func posse_counts(ids: Array) -> Dictionary:
	var out := {"sheriff": 0, "outlaw": 0, "bounty": 0}
	for id in ids:
		for s in SIDES:
			if rides_with(String(id), s):
				out[s] = int(out[s]) + 1
	var sides := 0
	for s in SIDES:
		if int(out[s]) > 0:
			sides += 1
	out["sides"] = sides
	return out


static func has(id: String) -> bool:
	return DEFS.has(id)


static func def(id: String) -> Dictionary:
	return DEFS.get(id, {})


static func ability_name(id: String) -> String:
	return String(def(id).get("name", id))


static func slots(id: String) -> int:
	return int(def(id).get("slots", 1))


static func rarity(id: String) -> int:
	return int(def(id).get("rarity", 0))


static func is_passive(id: String) -> bool:
	for k in def(id).get("fx", {}):
		if k in PASSIVE_FX:
			return true
	return false


## Whether this ability can sit on this hand at all (room aside).
static func fits(id: String, hand: String) -> bool:
	if not DEFS.has(id) or not HAND_SLOTS.has(hand):
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
