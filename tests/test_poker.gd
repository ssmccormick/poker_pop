extends SceneTree

## Headless test for the poker evaluator.
## Run: godot --headless --path . --script res://tests/test_poker.gd


func _init() -> void:
	var failures := 0
	# suits: 0 spades, 1 hearts, 2 diamonds, 3 clubs
	failures += _check("Royal Flush", [c(14, 1), c(13, 1), c(12, 1), c(11, 1), c(10, 1)])
	failures += _check("Straight Flush", [c(9, 0), c(10, 0), c(11, 0), c(12, 0), c(13, 0)])
	failures += _check("Straight Flush", [c(14, 3), c(2, 3), c(3, 3), c(4, 3), c(5, 3)])
	failures += _check("Five of a Kind", [c(7, 0), c(7, 1), c(7, 2), c(7, 3), c(7, 0)])
	# Five identical cards (rank AND suit): Flushed Five, the top hand.
	failures += _check("Flushed Five", [c(7, 1), c(7, 1), c(7, 1), c(7, 1), c(7, 1)])
	failures += _check("Four of a Kind", [c(9, 0), c(9, 1), c(9, 2), c(9, 3)])
	failures += _check("Full House", [c(4, 0), c(4, 1), c(4, 2), c(11, 0), c(11, 1)])
	failures += _check("Flush", [c(2, 2), c(6, 2), c(9, 2), c(11, 2), c(14, 2)])
	failures += _check("Straight", [c(10, 0), c(11, 1), c(12, 2), c(13, 3), c(14, 0)])
	failures += _check("Straight", [c(14, 0), c(2, 1), c(3, 2), c(4, 3), c(5, 0)])
	failures += _check("Straight", [c(6, 0), c(7, 1), c(8, 2), c(9, 3), c(10, 0)])
	# Straights count in descending selection order too, including the wheel.
	failures += _check("Straight", [c(13, 0), c(12, 1), c(11, 2), c(10, 3), c(9, 0)])
	failures += _check("Straight", [c(5, 0), c(4, 1), c(3, 2), c(2, 3), c(14, 0)])
	failures += _check("Royal Flush", [c(14, 2), c(13, 2), c(12, 2), c(11, 2), c(10, 2)])
	# Out-of-order runs are NOT straights.
	failures += _check("No Hand", [c(10, 0), c(12, 1), c(11, 2), c(13, 3), c(14, 0)])
	failures += _check("Flush", [c(2, 2), c(4, 2), c(3, 2), c(5, 2), c(6, 2)])
	# A suited hand with duplicate ranks (reshuffled deck) is still a Flush.
	failures += _check("Flush", [c(4, 1), c(4, 1), c(9, 1), c(11, 1), c(13, 1)])
	failures += _check("Three of a Kind", [c(8, 0), c(8, 1), c(8, 2)])
	failures += _check("Two Pair", [c(3, 0), c(3, 1), c(9, 0), c(9, 1)])
	failures += _check("Pair", [c(12, 0), c(12, 1)])
	failures += _check("High Card", [c(14, 0)])
	# Kickers invalidate the hand: every card must participate.
	failures += _check("No Hand", [c(9, 0), c(9, 1), c(9, 2), c(9, 3), c(2, 0)])
	failures += _check("No Hand", [c(8, 0), c(8, 1), c(8, 2), c(2, 0), c(5, 1)])
	failures += _check("No Hand", [c(3, 0), c(3, 1), c(9, 0), c(9, 1), c(14, 0)])
	failures += _check("No Hand", [c(12, 0), c(12, 1), c(2, 2), c(5, 3), c(9, 0)])
	failures += _check("No Hand", [c(2, 0), c(7, 1), c(9, 2), c(12, 3), c(14, 0)])
	# 4 suited cards are NOT a flush; 4 in a row are NOT a straight.
	failures += _check("No Hand", [c(2, 2), c(6, 2), c(9, 2), c(11, 2)])
	failures += _check("No Hand", [c(5, 0), c(6, 1), c(7, 2), c(8, 3)])
	# Score sanity: pair of queens = 25 base + 24 pips, and playable.
	var res := Poker.evaluate([c(12, 0), c(12, 1)])
	if res.score != 49 or not res.playable:
		print("FAIL: pair of queens expected playable 49, got %s" % str(res))
		failures += 1
	for bad in [[c(14, 0)], [c(13, 0), c(13, 1), c(2, 2)]]:
		var r2 := Poker.evaluate(bad)
		if r2.playable or r2.score != 0:
			print("FAIL: %s should be unplayable with score 0, got %s" % [str(bad), str(r2)])
			failures += 1
	if Poker.evaluate([]).is_empty() == false:
		print("FAIL: empty selection should return {}")
		failures += 1

	if failures == 0:
		print("ALL POKER TESTS PASSED")
	else:
		print("%d POKER TEST(S) FAILED" % failures)
	quit(failures)


func c(rank: int, suit: int) -> Dictionary:
	return {"rank": rank, "suit": suit}


func _check(expected: String, cards: Array) -> int:
	var res := Poker.evaluate(cards)
	if res.name != expected:
		print("FAIL: expected %s, got %s for %s" % [expected, res.name, str(cards)])
		return 1
	return 0
