class_name Abilities
extends RefCounted

## Ability cards: the reward for clearing a trail table. They have no
## rank or suit and never go in the deck. You equip them to poker hands,
## and each hand has one slot for every card it uses. An ability either
## fires every time its hand is played, or works passively from the hand
## it sits on. A ride starts with none.
##
## Effects (fx) by where they're applied:
##   board, scoring (pure, so the preview shows them):
##     flat: n            +n to the score before multipliers
##     mult: x            ×x after Mult cards and Jokers
##     chips_per_card: n  +n chips for each card played
##     dead_mans: [a, b]  ×a, or ×b when the hand is Aces and Eights
##   trail, when the hand is played:
##     enhance: mod       the next plain card off the deck gets mod
##     clear: n           clears up to n random hazards (never stones)
##     douse: n           puts out up to n fires
##     fuse: n            every bomb's fuse grows by n
##     time: s            +s seconds on a clock table
##     hand_every: n      on a hands table, every nth fire refunds a hand
##     free: s            the hand doesn't use up a hand (+s seconds on a clock)
##     next_mult: x       the next hand counts ×x
##     extra_hit: n       a hand that hits the outlaw hits him n more times
##     brand: mod         one plain card in the hand gets mod in the deck
##   trail, passive (at table start):
##     refill_hazard_mult: x  refills bring hazards x as often
##     extra_hands: n         +n hands (or +secs on a clock)
##     first_mult: x          the first hand at every table counts ×x

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
const PRICES := [80, 160, 320, 600]   # merchant shelf, before the trail's _price()
const PASSIVE_FX := ["refill_hazard_mult", "extra_hands", "first_mult"]
const SCORE_FX := ["flat", "mult", "chips_per_card", "dead_mans"]

const DEFS := {
	# --- Common ------------------------------------------------------------
	"spurs": {"name": "Spurs", "rarity": 0, "slots": 1, "hands": [],
		"fx": {"flat": 20}, "glyph": ["relic_glyph", "horseshoe"],
		"desc": "Every time you play this hand, it scores 20 more points before any multipliers."},
	"side_bet": {"name": "Side Bet", "rarity": 0, "slots": 1, "hands": [],
		"fx": {"chips_per_card": 4}, "glyph": ["mod_emblem", "chip"],
		"desc": "Every time you play this hand, you win 4 chips for each card in it."},
	"matched_pair": {"name": "Matched Pair", "rarity": 0, "slots": 2, "hands": ["Pair"],
		"fx": {"mult": 1.5}, "glyph": ["mod_emblem", "mult"],
		"desc": "Your Pairs score 1.5 times as much."},
	"triple_threat": {"name": "Triple Threat", "rarity": 0, "slots": 2, "hands": ["Three of a Kind"],
		"fx": {"flat": 60}, "glyph": ["relic_glyph", "lucky_chip"],
		"desc": "Your Three of a Kinds score 60 more points before any multipliers."},
	"hot_brand": {"name": "Hot Brand", "rarity": 0, "slots": 2, "hands": [],
		"fx": {"enhance": "plus"}, "glyph": ["provision_glyph", "branding_iron"],
		"desc": "Every time you play this hand, the next plain card off the deck gets a Plus enhancement."},
	"push_broom": {"name": "Push Broom", "rarity": 0, "slots": 2, "hands": [],
		"fx": {"clear": 1}, "glyph": ["provision_glyph", "canteen"],
		"desc": "Every time you play this hand, it clears a random hazard (never a stone)."},
	"borrowed_time": {"name": "Borrowed Time", "rarity": 0, "slots": 1, "hands": [],
		"fx": {"time": 5, "hand_every": 4}, "glyph": ["icon", "watch"],
		"desc": "On a clock table, this hand gives you 5 more seconds. On a hands table, every fourth time you play it you get a hand back."},
	"lookout": {"name": "Lookout", "rarity": 0, "slots": 2, "hands": [],
		"fx": {"refill_hazard_mult": 0.5}, "glyph": ["relic_glyph", "mirror_shades"],
		"desc": "While it's equipped, new cards come in with hazards only half as often."},
	# --- Rare --------------------------------------------------------------
	"scattergun": {"name": "Scattergun", "rarity": 1, "slots": 3, "hands": [],
		"fx": {"mult": 1.5}, "glyph": ["draw", "bullet"],
		"desc": "This hand scores 1.5 times as much."},
	"deputy_badge": {"name": "Deputy's Badge", "rarity": 1, "slots": 2, "hands": [],
		"fx": {"enhance": "chip"}, "glyph": ["relic_glyph", "tin_star"],
		"desc": "Every time you play this hand, the next plain card off the deck gets a Chip enhancement."},
	"fan_the_hammer": {"name": "Fan the Hammer", "rarity": 1, "slots": 4,
		"hands": ["Two Pair", "Four of a Kind"],
		"fx": {"flat": 100}, "glyph": ["draw", "bullet"],
		"desc": "Your Two Pairs and Four of a Kinds score 100 more points before any multipliers."},
	"cool_head": {"name": "Cool Head", "rarity": 1, "slots": 2, "hands": [],
		"fx": {"fuse": 1}, "glyph": ["relic_glyph", "bomb_squad_badge"],
		"desc": "Every time you play this hand, every bomb on the table gets one more hand on its fuse."},
	"rain_barrel": {"name": "Rain Barrel", "rarity": 1, "slots": 3, "hands": [],
		"fx": {"douse": 2}, "glyph": ["relic_glyph", "fire_blanket"],
		"desc": "Every time you play this hand, it puts out up to two fires."},
	"hired_gun": {"name": "Hired Gun", "rarity": 1, "slots": 2, "hands": [],
		"fx": {"extra_hit": 1}, "glyph": ["draw", "bullet"],
		"desc": "At a bounty table, when this hand hits the outlaw, it hits him one more time."},
	"saddle_horn": {"name": "Saddle Horn", "rarity": 1, "slots": 3, "hands": [],
		"fx": {"extra_hands": 1}, "glyph": ["relic_glyph", "saddlebags"],
		"desc": "While it's equipped, you get one extra hand at every table, or 15 more seconds on a clock."},
	# --- Epic --------------------------------------------------------------
	"marked_card": {"name": "Marked Card", "rarity": 2, "slots": 3, "hands": [],
		"fx": {"enhance": "mult"}, "glyph": ["mod_emblem", "mult"],
		"desc": "Every time you play this hand, the next plain card off the deck gets a Mult enhancement."},
	"double_down": {"name": "Double Down", "rarity": 2, "slots": 3, "hands": [],
		"fx": {"next_mult": 2.0}, "glyph": ["provision_glyph", "rattlesnake_tonic"],
		"desc": "Every time you play this hand, the next hand you play counts double."},
	"on_the_house": {"name": "On the House", "rarity": 2, "slots": 4, "hands": [],
		"fx": {"free": 8}, "glyph": ["relic_glyph", "lucky_chip"],
		"desc": "This hand doesn't use up a hand. On a clock table, you get 8 seconds back instead."},
	"big_iron": {"name": "Big Iron", "rarity": 2, "slots": 5, "hands": FIVE_CARD,
		"fx": {"mult": 2.0}, "glyph": ["draw", "bullet"],
		"desc": "This hand scores double. It only fits five-card hands."},
	"dead_mans_hand": {"name": "Dead Man's Hand", "rarity": 2, "slots": 4, "hands": ["Two Pair"],
		"fx": {"dead_mans": [1.5, 4.0]}, "glyph": ["mod_emblem", "mult"],
		"desc": "Your Two Pairs score 1.5 times as much, or 4 times as much if they're Aces and Eights."},
	"clean_sweep": {"name": "Clean Sweep", "rarity": 2, "slots": 4, "hands": ["Straight"],
		"fx": {"clear": 3}, "glyph": ["provision_glyph", "canteen"],
		"desc": "Every time you play a Straight, it clears up to three random hazards (never stones)."},
	# --- Legendary ---------------------------------------------------------
	"fastest_gun": {"name": "Fastest Gun", "rarity": 3, "slots": 5, "hands": [],
		"fx": {"first_mult": 3.0}, "glyph": ["icon", "laser"],
		"desc": "While it's equipped, the first hand you play at every table counts triple."},
	"branded_for_life": {"name": "Branded for Life", "rarity": 3, "slots": 5,
		"hands": ["Flush", "Straight Flush", "Royal Flush", "Flushed Five"],
		"fx": {"brand": "mult"}, "glyph": ["provision_glyph", "branding_iron"],
		"desc": "Every time you play this hand, one plain card in it becomes a Mult card in your deck for the rest of the ride."},
	"house_money": {"name": "House Money", "rarity": 3, "slots": 5, "hands": ["Full House"],
		"fx": {"mult": 2.0, "free": 8}, "glyph": ["mod_emblem", "gold"],
		"desc": "Your Full Houses score double, and they don't use up a hand (or give 8 seconds back on a clock)."},
}


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
