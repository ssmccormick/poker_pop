class_name TableMods
extends RefCounted

## Table modifiers. Every trail table has ONE objective (how you win:
## the score target, the safe, the bounty, the gold mine...) and any
## number of TWISTS stacked on top. Twists change the rules and pay for
## it in better odds. The objective is the offer's `goal` (plain = "");
## twists ride on the offer as `twists: [{id, ...params}]`.

## Hazard twists, by hazard kind.
const HAZARD_TWISTS := {"bomb": "hz_bomb", "fire": "hz_fire", "wind": "hz_wind",
		"stone": "hz_stone", "water": "hz_water"}

## id -> {name, odds (added to the table's odds), desc}. `name` and
## `desc` may carry a %s for the twist's own detail (the wild rank, the
## listed hands). `forced` twists come with their objective and add no odds.
const TWISTS := {
	"wild": {"name": "Wild %ss", "odds": 0.0,
		"desc": "Every %s on the table is wild. Score tables ask a quarter more for it."},
	"hz_bomb": {"name": "Lit Fuses", "odds": 0.4,
		"desc": "Bombs start on the table and keep coming. Play them before their fuses run out."},
	"hz_fire": {"name": "Brushfire", "odds": 0.4,
		"desc": "Fires start on the table and keep coming. They burn cards down and spread."},
	"hz_wind": {"name": "High Winds", "odds": 0.3,
		"desc": "Wind cards start on the table and keep coming. Each one blows a line of cards off."},
	"hz_stone": {"name": "Rockslide", "odds": 0.3,
		"desc": "Stones start on the table and keep coming. Each one covers a card until you chip it off."},
	"hz_water": {"name": "Rising Water", "odds": 0.3,
		"desc": "Water cards start on the table and keep coming. They fill up and hide what cards are."},
	"clock": {"name": "On the Clock", "odds": 0.2,
		"desc": "This table runs on a timer instead of a hand count."},
	"short": {"name": "Short Stack", "odds": 0.3,
		"desc": "You get two fewer hands here, or a minute less on the clock."},
	"tough": {"name": "Tough Crowd", "odds": 0.25,
		"desc": "The target is a fifth higher than usual."},
	"play_only": {"name": "House Rules", "odds": 0.5,
		"desc": "You can only play %s at this table."},
	"score_only": {"name": "Picky Crowd", "odds": 0.5,
		"desc": "Any hand plays, but only %s count toward the score."},
	"storm": {"name": "Stormy", "odds": 0.0,
		"desc": "The table comes with a mix of hazards already on it."},
}

## The twists the wall can roll (clock and storm come from the objective).
const ROLLABLE := ["wild", "hz_bomb", "hz_fire", "hz_wind", "hz_stone", "hz_water",
		"short", "tough", "play_only", "score_only"]
const MAX_TWISTS := 4
## Hands a House Rules table may list (Pair is always one of them) and
## the ones a Picky Crowd may count.
const PLAY_ONLY_EXTRA := ["Two Pair", "Three of a Kind", "Straight", "Flush", "Full House"]
const SCORE_ONLY_LOW := ["Pair", "Two Pair", "Three of a Kind"]
const SCORE_ONLY_HIGH := ["Straight", "Flush", "Full House", "Four of a Kind"]


static func has_twist(offer: Dictionary, id: String) -> bool:
	return not twist(offer, id).is_empty()


static func twist(offer: Dictionary, id: String) -> Dictionary:
	for t in offer.get("twists", []):
		if String(t.get("id", "")) == id:
			return t
	return {}


## The wild rank a table plays with (0 when none).
static func wild_rank(offer: Dictionary) -> int:
	return int(twist(offer, "wild").get("rank", 0))


static func rank_word(rank: int) -> String:
	match rank:
		11:
			return "Jack"
		12:
			return "Queen"
		13:
			return "King"
		14:
			return "Ace"
	return str(rank)


static func _detail(t: Dictionary) -> String:
	match String(t.get("id", "")):
		"wild":
			return rank_word(int(t.get("rank", 8)))
		"play_only", "score_only":
			return join_and(t.get("hands", []))
	return ""


static func twist_name(t: Dictionary) -> String:
	var d: Dictionary = TWISTS.get(String(t.get("id", "")), {})
	var n := String(d.get("name", ""))
	return n % _detail(t) if n.contains("%s") else n


static func twist_desc(t: Dictionary) -> String:
	var d: Dictionary = TWISTS.get(String(t.get("id", "")), {})
	var s := String(d.get("desc", ""))
	return s % _detail(t) if s.contains("%s") else s


## "Pairs and Straights" style lists for the sentences.
static func join_and(hands: Array) -> String:
	var words: Array = []
	for h in hands:
		var w := String(h)
		words.append(w + ("es" if w.ends_with("sh") else "s"))
	if words.size() <= 1:
		return "" if words.is_empty() else String(words[0])
	return "%s and %s" % [", ".join(PackedStringArray(words.slice(0, words.size() - 1))),
			String(words.back())]


## Whether a twist can join this offer (its objective and the twists
## already on it).
static func fits(id: String, offer: Dictionary) -> bool:
	if has_twist(offer, id):
		return false
	var goal := String(offer.get("goal", ""))
	match id:
		"wild":
			return not goal in ["blackjack", "safe", "holdem"]
		"hz_bomb", "hz_fire", "hz_wind", "hz_water":
			var kind := id.substr(3)
			return goal != "blackjack" and not (goal == "purge" and String(offer.get("purge_kind", "")) == kind)
		"hz_stone":
			return not goal in ["blackjack", "mine"]
		"short":
			return goal != "blackjack"
		"tough":
			return goal in ["", "holdem"] and int(offer.get("target", 0)) > 0
		"play_only":
			return not goal in ["hands", "blackjack", "holdem", "safe"] \
					and not has_twist(offer, "score_only")
		"score_only":
			return goal == "" and not has_twist(offer, "play_only")
	return true


## How many twists a seat rolls: by risk tier, then region (never on the
## first table).
static func twist_count(room: int, tier: int, region: int, rng: RandomNumberGenerator) -> int:
	if room == 0:
		return 0
	var n: int = [rng.randi_range(0, 1), 1, rng.randi_range(1, 2)][clampi(tier, 0, 2)]
	if region == 1:
		n += rng.randi_range(0, 1)
	elif region >= 2:
		n += 1
	return clampi(n, 0, MAX_TWISTS)
