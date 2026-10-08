class_name Progression
extends RefCounted

## Meta progression for the trail: every ride's score turns into EXP,
## EXP raises the rider's LEVEL, and each level unlocks ONE thing —
## a relic, a provision, an enhancement, a finish, a rider, a table
## type, a merchant or a stake. Unlocked items with a price must then
## be BOUGHT at the Outfitter before they turn up on the trail; once
## owned they can be upgraded to be FOUND more often (and, for some,
## to hit harder). Pure logic — TrailMode owns one and saves it in the
## [progress] section of the profile's trail_meta.cfg.

const FIND_MULT := [1.0, 1.5, 2.0]   # pool weight by FIND level
const MAX_FIND := 2
const MAX_POWER := 2
const RESERVED_LEVEL := 45           # The Dealer's table, when it opens
const PURSE_PER_LEVEL := 5           # each level-up pays $5 × the new level
# Kinds whose odds a FIND upgrade can lift.
const FINDABLE := ["relic", "provision", "mod", "finish", "room", "merchant"]
# What a starter (owned for free) would have cost — the base its
# upgrade prices are worked out from.
const VIRTUAL_PRICE := {"relic": 80, "provision": 50, "mod": 80, "finish": 150,
		"room": 60, "merchant": 60}

## One row per unlockable. level 1 = the starter set. price 0 = goes
## straight onto the trail on unlock; a price = buy it at the Outfitter.
## `ladder` points riders, tricks and gear at their existing Outfitter
## upgrade (sleeve_rank / laser / watch / sleight / bankroll / provisions).
const CATALOG := [
	# --- The starter set ---------------------------------------------------
	{"kind": "rider", "id": "the_gambler", "name": "The Gambler", "level": 1, "price": 0, "ladder": "sleeve_rank"},
	{"kind": "trick", "id": "sleeve", "name": "Ace up the Sleeve", "level": 1, "price": 0, "ladder": "sleeve_rank"},
	{"kind": "gear", "id": "bankroll", "name": "Bankroll", "level": 1, "price": 0, "ladder": "bankroll"},
	{"kind": "stake", "id": "0", "name": "Penny Ante", "level": 1, "price": 0},
	{"kind": "merchant", "id": "peddler", "name": "The Peddler", "level": 1, "price": 0},
	{"kind": "room", "id": "plain", "name": "Plain tables", "level": 1, "price": 0},
	{"kind": "mod", "id": "mult", "name": "Mult", "level": 1, "price": 0},
	{"kind": "mod", "id": "chip", "name": "Chip", "level": 1, "price": 0},
	{"kind": "mod", "id": "gold", "name": "Gold", "level": 1, "price": 0},
	{"kind": "relic", "id": "horseshoe", "name": "Horseshoe", "level": 1, "price": 0},
	{"kind": "relic", "id": "card_sleeve", "name": "Card Sleeve", "level": 1, "price": 0},
	{"kind": "relic", "id": "snake_oil", "name": "Snake Oil", "level": 1, "price": 0},
	{"kind": "relic", "id": "tin_star", "name": "Tin Star", "level": 1, "price": 0},
	{"kind": "relic", "id": "bomb_badge", "name": "Bomb Squad Badge", "level": 1, "price": 0},
	{"kind": "relic", "id": "chisel", "name": "Chisel", "level": 1, "price": 0},
	{"kind": "provision", "id": "canteen", "name": "Canteen", "level": 1, "price": 0},
	{"kind": "provision", "id": "dynamite", "name": "Dynamite Stick", "level": 1, "price": 0},
	{"kind": "provision", "id": "pocket_flask", "name": "Pocket Flask", "level": 1, "price": 0},
	{"kind": "provision", "id": "gold_pan", "name": "Gold Pan", "level": 1, "price": 0},
	# --- One unlock per level ----------------------------------------------
	{"kind": "room", "id": "clock", "name": "High Noon", "level": 2, "price": 0},
	{"kind": "relic", "id": "rabbits_foot", "name": "Rabbit's Foot", "level": 3, "price": 60},
	{"kind": "room", "id": "safe", "name": "Bank Job", "level": 4, "price": 0},
	{"kind": "provision", "id": "razor", "name": "Barber's Razor", "level": 5, "price": 40},
	{"kind": "room", "id": "outlaw", "name": "Bounty", "level": 6, "price": 0},
	{"kind": "gear", "id": "provisions", "name": "Packed Kit", "level": 7, "price": 0, "ladder": "provisions"},
	{"kind": "mod", "id": "plus", "name": "Plus", "level": 8, "price": 80},
	{"kind": "trick", "id": "sleight", "name": "Sleight of Hand", "level": 9, "price": 150, "ladder": "sleight"},
	{"kind": "room", "id": "hands", "name": "Dealer's Call", "level": 10, "price": 0},
	{"kind": "relic", "id": "fire_blanket", "name": "Fire Blanket", "level": 11, "price": 100},
	{"kind": "provision", "id": "shell_game", "name": "Shell Game", "level": 12, "price": 40},
	{"kind": "room", "id": "chest", "name": "Stagecoach Haul", "level": 13, "price": 0},
	{"kind": "stake", "id": "1", "name": "Table Stakes", "level": 14, "price": 0},
	{"kind": "merchant", "id": "collector", "name": "The Collector", "level": 15, "price": 0},
	{"kind": "mod", "id": "minus", "name": "Minus", "level": 16, "price": 80},
	{"kind": "room", "id": "purge", "name": "Purge jobs", "level": 17, "price": 0},
	{"kind": "rider", "id": "the_machine", "name": "The Machine", "level": 18, "price": 300, "ladder": "laser"},
	{"kind": "relic", "id": "gold_tooth", "name": "Gold Tooth", "level": 19, "price": 120},
	{"kind": "room", "id": "mine", "name": "Gold Mine", "level": 20, "price": 0},
	{"kind": "provision", "id": "branding_iron", "name": "Branding Iron", "level": 21, "price": 60},
	{"kind": "relic", "id": "saddlebags", "name": "Saddlebags", "level": 22, "price": 120},
	{"kind": "room", "id": "collect", "name": "Roundup & Census", "level": 23, "price": 0},
	{"kind": "mod", "id": "bumper", "name": "Bumper", "level": 24, "price": 100},
	{"kind": "relic", "id": "swimming_goggles", "name": "Swimming Goggles", "level": 25, "price": 80},
	{"kind": "finish", "id": "prism", "name": "Prism", "level": 26, "price": 150},
	{"kind": "provision", "id": "fresh_deck", "name": "Fresh Deck", "level": 27, "price": 50},
	{"kind": "merchant", "id": "sharp", "name": "The Card Sharp", "level": 28, "price": 0},
	{"kind": "relic", "id": "second_wind", "name": "Second Wind", "level": 29, "price": 150},
	{"kind": "room", "id": "crazy8", "name": "Crazy 8s", "level": 30, "price": 0},
	{"kind": "relic", "id": "dowsing_rod", "name": "Dowsing Rod", "level": 31, "price": 100},
	{"kind": "stake", "id": "2", "name": "High Roller", "level": 32, "price": 0},
	{"kind": "rider", "id": "the_doctor", "name": "The Doctor", "level": 33, "price": 400, "ladder": "watch"},
	{"kind": "provision", "id": "tonic", "name": "Rattlesnake Tonic", "level": 34, "price": 80},
	{"kind": "room", "id": "landrush", "name": "Land Rush", "level": 35, "price": 0},
	{"kind": "relic", "id": "mirror_shades", "name": "Mirror Shades", "level": 36, "price": 150},
	{"kind": "finish", "id": "metal", "name": "Metal", "level": 37, "price": 200},
	{"kind": "relic", "id": "bankroll_clip", "name": "Bankroll Clip", "level": 38, "price": 150},
	{"kind": "room", "id": "blackjack", "name": "Blackjack", "level": 39, "price": 0},
	{"kind": "relic", "id": "chuck_wagon", "name": "Chuck Wagon", "level": 40, "price": 300},
	{"kind": "room", "id": "holdem", "name": "Texas Hold'em", "level": 41, "price": 0},
	{"kind": "mod", "id": "wild", "name": "Wild", "level": 42, "price": 250},
	{"kind": "room", "id": "royal", "name": "Royal Hunt", "level": 43, "price": 0},
	{"kind": "relic", "id": "lucky_chip", "name": "Lucky Chip", "level": 44, "price": 500},
	{"kind": "room", "id": "dealer", "name": "The Dealer's Table", "level": RESERVED_LEVEL, "price": 0, "reserved": true},
	# --- Past the Dealer: the CardFX finishes ------------------------------
	{"kind": "finish", "id": "holo", "name": "Holo", "level": 46, "price": 200},
	{"kind": "finish", "id": "negative", "name": "Negative", "level": 47, "price": 250},
]

## POWER levels, hand-designed: each value has one entry per level, and
## `pdesc` says what the item does at each level (its length is the
## number of levels, so max POWER = pdesc.size() - 1).
const POWER := {
	"relic:horseshoe": {"vals": {"hands": [1, 1, 2], "secs": [0, 15, 15]},
		"pdesc": ["+1 hand in every room", "+1 hand in every room, +15s on clock tables",
			"+2 hands in every room, +15s on clock tables"]},
	"relic:card_sleeve": {"vals": {"picks": [4, 5]},
		"pdesc": ["Card picks offer 4 choices", "Card picks offer 5 choices"]},
	"relic:snake_oil": {"vals": {"off": [0.25, 0.30, 0.35]},
		"pdesc": ["Shop prices -25%", "Shop prices -30%", "Shop prices -35%"]},
	"relic:tin_star": {"vals": {"blinds": [1.0, 1.5, 2.0]},
		"pdesc": ["Every cleared table pays an extra blind",
			"Every cleared table pays an extra blind and a half",
			"Every cleared table pays two extra blinds"]},
	"relic:rabbits_foot": {"vals": {"x": [2.0, 2.5, 3.0]},
		"pdesc": ["Surprise safes and chests turn up twice as often on plain tables",
			"Surprise safes and chests turn up 2.5× as often on plain tables",
			"Surprise safes and chests turn up three times as often on plain tables"]},
	"relic:bomb_badge": {"vals": {"fuse": [2, 3, 4]},
		"pdesc": ["Bombs start with +2 fuse", "Bombs start with +3 fuse", "Bombs start with +4 fuse"]},
	"relic:chisel": {"vals": {"gold": [0.35, 0.50]},
		"pdesc": ["Stones need one fewer use",
			"Stones need one fewer use, and half of them leave gold in the rubble"]},
	"relic:fire_blanket": {"vals": {"every": [2, 3]},
		"pdesc": ["Fire only ticks every 2nd hand", "Fire only ticks every 3rd hand"]},
	"relic:gold_tooth": {"vals": {"x": [2.0, 2.5, 3.0]},
		"pdesc": ["Chip cards pay double", "Chip cards pay 2.5×", "Chip cards pay triple"]},
	"relic:mirror_shades": {"vals": {"plus": [0.5, 0.75, 1.0]},
		"pdesc": ["Mult cards multiply +0.5 more", "Mult cards multiply +0.75 more",
			"Mult cards multiply +1 more"]},
	"relic:second_wind": {"vals": {"hp": [5, 8, 10]},
		"pdesc": ["One free life: when the trail would end you, rise with 5 HP and chips for the table. Then it's spent",
			"One free life: rise with 8 HP and chips for the table. Then it's spent",
			"One free life: rise with full HP and chips for the table. Then it's spent"]},
	"relic:bankroll_clip": {"vals": {"rate": [0.25, 0.4, 0.5]},
		"pdesc": ["Trail completion pays +0.25x", "Trail completion pays +0.4x",
			"Trail completion pays +0.5x"]},
	"relic:dowsing_rod": {"vals": {"max": [6, 5]},
		"pdesc": ["Safe combos use only ranks 2-6", "Safe combos use only ranks 2-5"]},
	"relic:saddlebags": {"vals": {"packed": [0, 1]},
		"pdesc": ["A 4th slot in your provision kit",
			"A 4th slot in your provision kit, and it arrives packed"]},
	"relic:chuck_wagon": {"vals": {"chips": [0, 1]},
		"pdesc": ["A random provision at every table's start",
			"A random provision at every table's start — a blind in chips if the kit is full"]},
	"relic:lucky_chip": {"vals": {"p": [0.10, 0.15, 0.20]},
		"pdesc": ["10% chance a hand costs no hand", "15% chance a hand costs no hand",
			"20% chance a hand costs no hand"]},
	"provision:pocket_flask": {"vals": {"hands": [2, 3, 4], "secs": [20, 30, 40]},
		"pdesc": ["+2 hands at this table (+20s on a timed one)",
			"+3 hands at this table (+30s on a timed one)",
			"+4 hands at this table (+40s on a timed one)"]},
	"provision:tonic": {"vals": {"x": [2.0, 2.5, 3.0]},
		"pdesc": ["Your next scored hand counts DOUBLE", "Your next scored hand counts 2.5×",
			"Your next scored hand counts TRIPLE"]},
	"provision:shell_game": {"vals": {"any": [0, 1]},
		"pdesc": ["Swap two neighboring cards - pick one, then its neighbor",
			"Swap ANY two cards on the table"]},
	"provision:razor": {"vals": {"up": [0, 1]},
		"pdesc": ["Re-roll one card's rank and suit",
			"Re-roll one card's rank and suit — never to a lower rank"]},
	"provision:canteen": {"vals": {"spread": [0, 1]},
		"pdesc": ["Douse one card: removes any hazard or soak",
			"Douse one card and its four neighbors"]},
	"provision:dynamite": {"vals": {"keep": [0.0, 0.20, 0.35]},
		"pdesc": ["Destroy one card outright, unscored - stones and curses included",
			"Destroy one card outright — 20% chance the stick isn't used up",
			"Destroy one card outright — 35% chance the stick isn't used up"]},
	"provision:gold_pan": {"vals": {"keep": [0.0, 0.20, 0.35]},
		"pdesc": ["Turn one plain card solid GOLD",
			"Turn one plain card solid GOLD — 20% chance the pan isn't used up",
			"Turn one plain card solid GOLD — 35% chance the pan isn't used up"]},
	"provision:branding_iron": {"vals": {"keep": [0.0, 0.20, 0.35]},
		"pdesc": ["Brand a plain card with a random enhancement",
			"Brand a plain card — 20% chance the iron stays hot for another",
			"Brand a plain card — 35% chance the iron stays hot for another"]},
	"provision:fresh_deck": {"vals": {"keep": [0.0, 0.20, 0.35]},
		"pdesc": ["Re-deal every plain and enhanced card on the table",
			"Re-deal the table — 20% chance the deck isn't used up",
			"Re-deal the table — 35% chance the deck isn't used up"]},
	"finish:holo": {"vals": {"score": [50, 75, 100]},
		"pdesc": ["Adds a flat +50 to the hand's score before any multipliers.",
			"Adds a flat +75 to the hand's score before any multipliers.",
			"Adds a flat +100 to the hand's score before any multipliers."]},
	"finish:negative": {"vals": {"secs": [10, 15]},
		"pdesc": ["Scoring it gives the hand back: +1 hand, or +10 seconds on a clock table.",
			"Scoring it gives the hand back: +1 hand, or +15 seconds on a clock table."]},
	"mod:mult": {"vals": {"x": [1.5, 1.6, 1.75]},
		"pdesc": ["×1.5 to the hand's score.", "×1.6 to the hand's score.", "×1.75 to the hand's score."]},
	"mod:chip": {"vals": {"chips": [8, 10, 12]},
		"pdesc": ["+8 chips on every score, growing each time it's played.",
			"+10 chips on every score, growing each time it's played.",
			"+12 chips on every score, growing each time it's played."]},
	"mod:gold": {"vals": {"cash": [1, 2]},
		"pdesc": ["+$1 cash every time it's played.", "+$2 cash every time it's played."]},
}

# --- Per-profile state ----------------------------------------------------
var exp_total := 0
var owned := {}           # "kind:id" -> true (bought, or granted)
var find := {}            # "kind:id" -> FIND level
var power := {}           # "kind:id" -> POWER level
var seen_level := 1       # the level the Outfitter was last opened at (NEW pips)
var last_run_uid := ""    # the last ride already paid out (no double grants)
var grandfathered := false
var contracts_claimed := {}  # contract id -> true
var contracts_seen := {}     # contract id -> true (completion announced)
var contracts_init := false  # contracts met before they existed are marked seen
var unlock_all := false      # screenshots / tests: everything on the trail

static var _index := {}


static func key(kind: String, id: String) -> String:
	return "%s:%s" % [kind, id]


## The CATALOG row for kind/id, or {} when it isn't gated at all.
static func row(kind: String, id: String) -> Dictionary:
	if _index.is_empty():
		for r in CATALOG:
			_index[key(String(r.kind), String(r.id))] = r
	return _index.get(key(kind, id), {})


# --- The curve --------------------------------------------------------------

## EXP needed to climb from `lv` to `lv + 1`.
static func exp_to_next(lv: int) -> int:
	return 80 + 20 * (maxi(lv, 1) - 1)


## Total EXP at which level `lv` is reached (level 1 = 0).
static func exp_at_level(lv: int) -> int:
	var n := maxi(lv, 1) - 1
	return 80 * n + 10 * n * (n - 1)


static func level_for_exp(e: int) -> int:
	var lv := 1
	while exp_at_level(lv + 1) <= e:
		lv += 1
	return lv


func level() -> int:
	return level_for_exp(exp_total)


## [EXP into this level, EXP the level needs].
func exp_into_level() -> Array:
	var lv := level()
	return [exp_total - exp_at_level(lv), exp_to_next(lv)]


## A ride's EXP: {total, rows: [[label, amount], ...]} — the rows are
## the game-over breakdown.
static func run_exp(score: int, reached: int, bosses: int, tier: int,
		complete: bool) -> Dictionary:
	var rows: Array = []
	var score_exp := score / 100
	if score > 100000:
		# Big rides still count, just less per chip past 100k.
		score_exp = mini(2500, 1000 + (score - 100000) / 400)
	rows.append(["SCORE", maxi(score_exp, 0)])
	rows.append(["TABLES REACHED", 10 * reached])
	if bosses > 0:
		rows.append(["BOSSES BEATEN", 50 * bosses])
	if complete:
		rows.append(["TRAIL COMPLETE", 250 * (tier + 1)])
	var sum := 0
	for r in rows:
		sum += int(r[1])
	var mult: float = [1.0, 1.25, 1.5][clampi(tier, 0, 2)]
	var total := roundi(sum * mult)
	if total > sum:
		rows.append(["STAKE BONUS ×%s" % String.num(mult, 2), total - sum])
	return {"total": total, "rows": rows}


## The EXP an old profile has earned by its lifetime stats.
static func grandfather_exp(stats: Dictionary) -> int:
	var est := 60 * int(stats.get("trail_runs", 0)) \
			+ 25 * int(stats.get("tables_cleared", 0)) \
			+ 50 * int(stats.get("bosses_beaten", 0)) \
			+ 600 * int(stats.get("trail_wins", 0))
	var deepest := int(stats.get("deepest_table", 0))
	if deepest >= 7:
		est = maxi(est, exp_at_level(10))
	if deepest >= 14:
		est = maxi(est, exp_at_level(20))
	if int(stats.get("trail_wins", 0)) > 0:
		est = maxi(est, exp_at_level(25))
	return est


## $ paid for climbing from level l0 to l1.
static func purse_between(l0: int, l1: int) -> int:
	var total := 0
	for lv in range(l0 + 1, l1 + 1):
		total += PURSE_PER_LEVEL * lv
	return total


## Catalog rows unlocked by climbing from l0 to l1 (reserved rows aside).
static func unlocks_between(l0: int, l1: int) -> Array:
	var out: Array = []
	for r in CATALOG:
		if int(r.level) > l0 and int(r.level) <= l1 and not r.get("reserved", false):
			out.append(r)
	return out


## Adds EXP; returns {from, to, purse, unlocks} for the level-ups.
func add_exp(n: int) -> Dictionary:
	var from := level()
	exp_total += maxi(n, 0)
	var to := level()
	return {"from": from, "to": to, "purse": purse_between(from, to),
			"unlocks": unlocks_between(from, to)}


# --- Gates ------------------------------------------------------------------

func is_unlocked(kind: String, id: String) -> bool:
	if unlock_all:
		return true
	var r := row(kind, id)
	return r.is_empty() or owned.has(key(kind, id)) or level() >= int(r.level)


## The one gate every pool asks: unlocked, and owned if it has a price.
func is_available(kind: String, id: String) -> bool:
	if unlock_all:
		return true
	var r := row(kind, id)
	if r.is_empty():
		return true
	if r.get("reserved", false):
		return false
	if owned.has(key(kind, id)):
		return true  # bought — or grandfathered in above the curve
	return level() >= int(r.level) and int(r.price) == 0


func find_level(kind: String, id: String) -> int:
	return int(find.get(key(kind, id), 0))


func power_level(kind: String, id: String) -> int:
	return int(power.get(key(kind, id), 0))


## A weighted pick among the AVAILABLE ids in `weights` ({id: base}),
## each scaled by its FIND level. "" when nothing is left.
func pick(kind: String, weights: Dictionary, exclude: Array = []) -> String:
	var ids: Array = []
	var ws: Array = []
	var total := 0.0
	for id in weights:
		var sid := String(id)
		if exclude.has(sid) or not is_available(kind, sid):
			continue
		var w := float(weights[id]) * float(FIND_MULT[clampi(find_level(kind, sid), 0, MAX_FIND)])
		if w <= 0.0:
			continue
		ids.append(sid)
		ws.append(w)
		total += w
	if ids.is_empty():
		return ""
	var roll := randf() * total
	for i in ids.size():
		roll -= float(ws[i])
		if roll < 0.0:
			return String(ids[i])
	return String(ids[-1])


# --- Buying -----------------------------------------------------------------

## Price an upgrade is worked out from (starters use a virtual price).
static func base_price(r: Dictionary) -> int:
	return int(r.price) if int(r.price) > 0 else int(VIRTUAL_PRICE.get(String(r.kind), 0))


## $ to buy kind/id now, 0 when it's free, owned, or still locked.
func buy_cost(kind: String, id: String) -> int:
	var r := row(kind, id)
	if r.is_empty() or owned.has(key(kind, id)) or not is_unlocked(kind, id):
		return 0
	return int(r.price)


func mark_owned(kind: String, id: String) -> void:
	owned[key(kind, id)] = true


## $ for the next FIND level, 0 when maxed or not findable.
func find_cost(kind: String, id: String) -> int:
	var r := row(kind, id)
	if r.is_empty() or not FINDABLE.has(kind) or not is_available(kind, id):
		return 0
	var lv := find_level(kind, id)
	if lv >= MAX_FIND:
		return 0
	var bp := base_price(r)
	return maxi(30, bp / 2) if lv == 0 else maxi(60, bp)


func raise_find(kind: String, id: String) -> void:
	find[key(kind, id)] = mini(MAX_FIND, find_level(kind, id) + 1)


## The highest POWER level kind/id has (0 = no POWER upgrades).
static func power_max(kind: String, id: String) -> int:
	var p: Dictionary = POWER.get(key(kind, id), {})
	return maxi(0, (p.get("pdesc", []) as Array).size() - 1)


## A POWER value at the item's current level (`fallback` if it has none).
func val(kind: String, id: String, k: String, fallback: Variant = 0) -> Variant:
	var p: Dictionary = POWER.get(key(kind, id), {})
	var vals: Array = p.get("vals", {}).get(k, [])
	if vals.is_empty():
		return fallback
	return vals[clampi(power_level(kind, id), 0, vals.size() - 1)]


## What the item does at `lv` (-1 = its current level); "" if no POWER.
func pdesc(kind: String, id: String, lv := -1) -> String:
	var p: Dictionary = POWER.get(key(kind, id), {})
	var lines: Array = p.get("pdesc", [])
	if lines.is_empty():
		return ""
	return String(lines[clampi(power_level(kind, id) if lv < 0 else lv, 0, lines.size() - 1)])


## $ for the next POWER level, 0 when maxed, powerless or not owned.
func power_cost(kind: String, id: String) -> int:
	var r := row(kind, id)
	if r.is_empty() or not is_available(kind, id):
		return 0
	var lv := power_level(kind, id)
	if lv >= power_max(kind, id):
		return 0
	var first := maxi(80, base_price(r))
	return first if lv == 0 else 2 * first


func raise_power(kind: String, id: String) -> void:
	power[key(kind, id)] = mini(power_max(kind, id), power_level(kind, id) + 1)


# --- Save / load ------------------------------------------------------------

func write(cf: ConfigFile) -> void:
	cf.set_value("progress", "exp", exp_total)
	cf.set_value("progress", "owned", PackedStringArray(owned.keys()))
	cf.set_value("progress", "find", find)
	cf.set_value("progress", "power", power)
	cf.set_value("progress", "seen_level", seen_level)
	cf.set_value("progress", "last_run_uid", last_run_uid)
	cf.set_value("progress", "grandfathered", grandfathered)
	cf.set_value("progress", "contracts_claimed", PackedStringArray(contracts_claimed.keys()))
	cf.set_value("progress", "contracts_seen", PackedStringArray(contracts_seen.keys()))
	cf.set_value("progress", "contracts_init", contracts_init)


## Loads from cf. A profile without a [progress] section that has
## trail stats is GRANDFATHERED from them. Returns true when the state
## was just built that way (the caller should save it).
## `legacy` = {"character", "laser", "watch", "sleight"} from [meta].
func read(cf: ConfigFile, stats: Dictionary, legacy: Dictionary = {}) -> bool:
	_reset()
	if cf.has_section("progress"):
		exp_total = maxi(0, int(cf.get_value("progress", "exp", 0)))
		for k in cf.get_value("progress", "owned", PackedStringArray()):
			owned[String(k)] = true
		var f = cf.get_value("progress", "find", {})
		if f is Dictionary:
			find = f.duplicate()
		var p = cf.get_value("progress", "power", {})
		if p is Dictionary:
			power = p.duplicate()
		seen_level = int(cf.get_value("progress", "seen_level", level()))
		last_run_uid = String(cf.get_value("progress", "last_run_uid", ""))
		grandfathered = bool(cf.get_value("progress", "grandfathered", false))
		for k in cf.get_value("progress", "contracts_claimed", PackedStringArray()):
			contracts_claimed[String(k)] = true
		for k in cf.get_value("progress", "contracts_seen", PackedStringArray()):
			contracts_seen[String(k)] = true
		contracts_init = bool(cf.get_value("progress", "contracts_init", false))
		return false
	if int(stats.get("trail_runs", 0)) <= 0:
		return false  # a fresh saddle: level 1, the starter set
	grandfather(stats, legacy)
	return true


## Seats an old profile at the level its stats earned, with everything
## at or below it already owned (and the riders and stakes it used).
func grandfather(stats: Dictionary, legacy: Dictionary = {}) -> void:
	exp_total = grandfather_exp(stats)
	var lv := level()
	for r in CATALOG:
		if int(r.level) <= lv and not r.get("reserved", false):
			mark_owned(String(r.kind), String(r.id))
	var rider := String(legacy.get("character", ""))
	if row("rider", rider).size() > 0:
		mark_owned("rider", rider)
	if int(legacy.get("laser", 0)) > 0:
		mark_owned("rider", "the_machine")
	if int(legacy.get("watch", 0)) > 0:
		mark_owned("rider", "the_doctor")
	if int(legacy.get("sleight", 0)) > 0 or String(legacy.get("gambler_ability", "")) == "sleight":
		mark_owned("trick", "sleight")
	if int(legacy.get("provisions", 0)) > 0:
		mark_owned("gear", "provisions")
	for t in 3:
		mark_owned("stake", str(t))
	seen_level = lv
	grandfathered = true


func owns(kind: String, id: String) -> bool:
	return owned.has(key(kind, id))


func _reset() -> void:
	exp_total = 0
	owned = {}
	find = {}
	power = {}
	seen_level = 1
	last_run_uid = ""
	grandfathered = false
	contracts_claimed = {}
	contracts_seen = {}
	contracts_init = false
