class_name Ascension
extends RefCounted

## ASCENSION 0-20: the trail's difficulty ladder, Slay-the-Spire style.
## Each rider climbs their own: beating Ascension N with a rider opens
## N+1 for them. Every level adds one rule and keeps all the ones below
## it. Ascension 0 is the plain trail, built for a first ride. Pure
## numbers — TrailMode and Board read these knobs.

const MAX := 20

## Level 1..20, in order. LEVELS[n - 1] is the rule Ascension n adds.
const LEVELS := [
	{"name": "Tougher Tables", "desc": "Tables ask 10% more score."},
	{"name": "Restless Trail", "desc": "Hazards turn up 10% more often."},
	{"name": "Light Purse", "desc": "Start the ride with 30 fewer chips."},
	{"name": "Steeper Blinds", "desc": "Antes and minimum bets cost 25% more."},
	{"name": "Hardened Bosses", "desc": "Bosses' score pools are 20% deeper."},
	{"name": "Sore Losers", "desc": "A lost table costs 2 HP instead of 1."},
	{"name": "Short-Handed", "desc": "One fewer hand at every table (30 s less on a clock)."},
	{"name": "Price Gouging", "desc": "Merchants charge 20% more."},
	{"name": "Bad Deal", "desc": "Fresh cards arrive hazarded 1.5× as often."},
	{"name": "Tougher Tables II", "desc": "Tables ask another 10% more score."},
	{"name": "Cold Camp", "desc": "Resting at a campfire heals 3 HP instead of 5."},
	{"name": "Short Fuses", "desc": "A bomb blast costs 3 HP instead of 2."},
	{"name": "Meaner Outlaws", "desc": "Outlaws have +1 HP and shoot under a higher score."},
	{"name": "Storm Season", "desc": "Hazard tables seed one extra hazard."},
	{"name": "Hardened Bosses II", "desc": "Bosses' pools another 20% deeper; the Jack's bar climbs faster."},
	{"name": "Marked Deck", "desc": "The ride starts with a cursed card in the deck."},
	{"name": "Short-Handed II", "desc": "Another hand fewer at every table (another 30 s on a clock)."},
	{"name": "Worn Out", "desc": "Max HP is 8."},
	{"name": "Tougher Tables III", "desc": "Tables ask another 15% more score."},
	{"name": "The Long Snake", "desc": "King Cobra's tail grows two more segments."},
]

const BASE_CHIPS := 180
const BASE_MAX_HP := 10


static func clamp_a(a: int) -> int:
	return clampi(a, 0, MAX)


## Score targets.
static func target_mult(a: int) -> float:
	return 1.0 + (0.10 if a >= 1 else 0.0) + (0.10 if a >= 10 else 0.0) \
			+ (0.15 if a >= 19 else 0.0)


## Added to every table's chance of seeding hazards.
static func hazard_bonus(a: int) -> float:
	return 0.10 if a >= 2 else 0.0


static func start_chips(a: int) -> int:
	return BASE_CHIPS - (30 if a >= 3 else 0)


## Antes and minimum bets.
static func blind_mult(a: int) -> float:
	return 1.25 if a >= 4 else 1.0


## Boss score pools.
static func boss_mult(a: int) -> float:
	return 1.0 + (0.20 if a >= 5 else 0.0) + (0.20 if a >= 15 else 0.0)


## Extra climb on the Jack's bar per hit.
static func jack_bar_bonus(a: int) -> int:
	return 10 if a >= 15 else 0


static func lost_table_hp(a: int) -> int:
	return 2 if a >= 6 else 1


## Hands taken off every table's budget.
static func hands_minus(a: int) -> int:
	return (1 if a >= 7 else 0) + (1 if a >= 17 else 0)


## Seconds taken off every clock table.
static func clock_minus_secs(a: int) -> float:
	return 30.0 * hands_minus(a)


static func shop_mult(a: int) -> float:
	return 1.2 if a >= 8 else 1.0


## Scales the chance a refilled card arrives hazarded.
static func refill_mult(a: int) -> float:
	return 1.5 if a >= 9 else 1.0


static func camp_rest(a: int) -> int:
	return 3 if a >= 11 else 5


static func bomb_hp(a: int) -> int:
	return 3 if a >= 12 else 2


static func outlaw_hp_plus(a: int) -> int:
	return 1 if a >= 13 else 0


static func outlaw_bar_plus(a: int) -> int:
	return 25 if a >= 13 else 0


## Extra hazards seeded on a table that rolls hazards.
static func extra_seed(a: int) -> int:
	return 1 if a >= 14 else 0


static func cursed_start(a: int) -> int:
	return 1 if a >= 16 else 0


static func max_hp(a: int) -> int:
	return 8 if a >= 18 else BASE_MAX_HP


## King Cobra's starting tail, from the board's base length.
static func cobra_tail(a: int, base: int) -> int:
	return base + (2 if a >= 20 else 0)


# --- Rewards climb with the risk -----------------------------------------

static func exp_mult(a: int) -> float:
	return 1.0 + 0.05 * clamp_a(a)


## Added to the cash-out rate (1.0 at Ascension 0; 2.5 at 20).
static func rate_bonus(a: int) -> float:
	return 0.075 * clamp_a(a)


## Scales the trail-completion purse.
static func purse_mult(a: int) -> float:
	return 1.0 + clamp_a(a) / 4.0


## The rules in force at `a`, lowest first: [[n, row], ...].
static func active(a: int) -> Array:
	var out: Array = []
	for n in range(1, clamp_a(a) + 1):
		out.append([n, LEVELS[n - 1]])
	return out
