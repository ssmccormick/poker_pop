class_name Poker
extends RefCounted

## Poker hand evaluator for Poker Pop.
## Hands may contain 1 to 5 cards. Straights and flushes require exactly 5.
## Five of a Kind is possible because the board can hold cards from more
## than one deck cycle.

# Ordered worst-to-best. Insertion order is preserved, so this doubles
# as the ranking list for the payout table.
const BASE_SCORES := {
	"High Card": 5,
	"Pair": 25,
	"Two Pair": 60,
	"Three of a Kind": 100,
	"Straight": 200,
	"Flush": 250,
	"Full House": 350,
	"Four of a Kind": 600,
	"Five of a Kind": 900,
	"Straight Flush": 1200,
	"Royal Flush": 2000,
}


## cards: Array of {"rank": int (2..14, ace = 14), "suit": int (0..3)}
## Returns {"name", "base", "pips", "score"} or {} for an empty selection.
static func evaluate(cards: Array) -> Dictionary:
	if cards.is_empty():
		return {}
	var n := cards.size()
	var rank_counts := {}
	var suit_set := {}
	var pips := 0
	for c in cards:
		rank_counts[c.rank] = rank_counts.get(c.rank, 0) + 1
		suit_set[c.suit] = true
		pips += c.rank

	var counts: Array = rank_counts.values()
	counts.sort()

	var is_flush := n == 5 and suit_set.size() == 1
	var is_straight := false
	var straight_high := 0
	if n == 5 and rank_counts.size() == 5:
		var ranks: Array = rank_counts.keys()
		ranks.sort()
		if ranks[4] - ranks[0] == 4:
			is_straight = true
			straight_high = ranks[4]
		elif ranks == [2, 3, 4, 5, 14]:
			is_straight = true
			straight_high = 5  # wheel: A-2-3-4-5

	var hand_name := "High Card"
	if is_flush and is_straight and straight_high == 14:
		hand_name = "Royal Flush"
	elif is_flush and is_straight:
		hand_name = "Straight Flush"
	elif counts.back() == 5:
		hand_name = "Five of a Kind"
	elif counts.back() == 4:
		hand_name = "Four of a Kind"
	elif counts == [2, 3]:
		hand_name = "Full House"
	elif is_flush:
		hand_name = "Flush"
	elif is_straight:
		hand_name = "Straight"
	elif counts.back() == 3:
		hand_name = "Three of a Kind"
	elif counts.size() >= 2 and counts[-1] == 2 and counts[-2] == 2:
		hand_name = "Two Pair"
	elif counts.back() == 2:
		hand_name = "Pair"

	var base: int = BASE_SCORES[hand_name]
	return {"name": hand_name, "base": base, "pips": pips, "score": base + pips}
