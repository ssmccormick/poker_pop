extends SceneTree

## Headless test for Board.has_playable_hand (dead-board detection).
## Builds sparse hand-crafted grids; the pair-distance rule assumes a full
## board in real play, but the chain searches are exact either way.
## Run: godot --headless --path . --script res://tests/test_board.gd


func _init() -> void:
	var failures := 0

	# Two kings adjacent: playable pair.
	failures += _check(true, "adjacent pair", [
		[13, 0, 0, 0], [13, 1, 1, 0],
	])
	# Separated kings can't be played: the filler card between them would
	# not participate in the hand.
	failures += _check(false, "pair split by a filler card", [
		[13, 0, 0, 0], [11, 2, 1, 0], [13, 1, 2, 0],
	])
	# ...but K-Q-K-Q is Two Pair: every chained card participates.
	failures += _check(true, "interleaved two pair chain", [
		[13, 0, 0, 0], [12, 2, 1, 0], [13, 1, 2, 0], [12, 3, 3, 0],
	])
	# K-Q-K-Q-K full house chain.
	failures += _check(true, "interleaved full house chain", [
		[13, 0, 0, 0], [12, 2, 1, 0], [13, 1, 2, 0], [12, 3, 3, 0], [13, 2, 4, 0],
	])
	# Five connected same-suit cards: playable flush chain.
	failures += _check(true, "flush chain", [
		[2, 1, 0, 0], [6, 1, 1, 0], [9, 1, 2, 0], [11, 1, 3, 0], [13, 1, 4, 0],
	])
	# Only four connected suited cards (fifth is isolated): dead.
	failures += _check(false, "broken flush chain", [
		[2, 1, 0, 0], [6, 1, 1, 0], [9, 1, 2, 0], [11, 1, 3, 0], [13, 1, 6, 4],
	])
	# Ascending run in a row: playable straight chain.
	failures += _check(true, "straight chain", [
		[5, 0, 0, 0], [6, 1, 1, 0], [7, 2, 2, 0], [8, 3, 3, 0], [9, 0, 4, 0],
	])
	# Scrambled run in a row: still a straight chain (order-free straights).
	failures += _check(true, "scrambled straight chain", [
		[7, 0, 0, 0], [5, 1, 1, 0], [9, 2, 2, 0], [6, 3, 3, 0], [8, 0, 4, 0],
	])
	# Ascending run along a diagonal: still chainable.
	failures += _check(true, "diagonal straight chain", [
		[5, 0, 0, 0], [6, 1, 1, 1], [7, 2, 2, 2], [8, 3, 3, 3], [9, 0, 4, 4],
	])
	# Wheel in a row (A low): playable.
	failures += _check(true, "wheel straight chain", [
		[5, 0, 0, 0], [4, 1, 1, 0], [3, 2, 2, 0], [2, 3, 3, 0], [14, 0, 4, 0],
	])
	# K-A-2-3-4 is not a straight: no wrap-around.
	failures += _check(false, "wrap-around is not a straight", [
		[13, 0, 0, 0], [14, 1, 1, 0], [2, 2, 2, 0], [3, 3, 3, 0], [4, 0, 4, 0],
	])

	if failures == 0:
		print("ALL BOARD TESTS PASSED")
	else:
		print("%d BOARD TEST(S) FAILED" % failures)
	quit(failures)


## cards: [[rank, suit, x, y], ...]
func _check(expected: bool, label: String, cards: Array) -> int:
	var board := Board.new()
	for c in cards:
		var card := PlayingCard.new()
		card.rank = c[0]
		card.suit = c[1]
		board.grid[Vector2i(c[2], c[3])] = card
	var got := board.has_playable_hand()
	for card in board.grid.values():
		card.free()
	board.free()
	if got != expected:
		print("FAIL: %s — expected %s, got %s" % [label, expected, got])
		return 1
	return 0
