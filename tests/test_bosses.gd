extends SceneTree

## Headless tests for boss logic that doesn't need a scene tree:
## cobra eat/revert bookkeeping and the sticky (queen/honey) hand gate.
## Run: godot --headless --path . --script res://tests/test_bosses.gd


func _init() -> void:
	var failures := 0

	# --- cobra eats and reverts --------------------------------------------
	var b := _board([[5, 0, 0, 0], [9, 1, 1, 0], [11, 2, 2, 0]])
	var head: PlayingCard = b.grid[Vector2i(0, 0)]
	head.boss = "cobra"
	head.rank = 7
	head.suit = 3
	b._cobra_eat(head, true)
	failures += _check(head.grid_pos == Vector2i(1, 0), "head moved into the victim's cell")
	failures += _check(head.rank == 9 and head.suit == 1, "head took the victim's identity")
	failures += _check(b.grid[Vector2i(0, 0)].snake_tail, "old head cell is now tail")
	failures += _check(head.cobra_stack.size() == 1
			and head.cobra_stack[0].rank == 7 and head.cobra_stack[0].suit == 3,
			"previous identity stored on the stack")
	b._cobra_eat(head, true)
	failures += _check(head.grid_pos == Vector2i(2, 0) and head.rank == 11,
			"second meal continues the line")
	failures += _check(head.cobra_stack.size() == 2, "stack grows per meal")

	b._cobra_revert(head)
	failures += _check(head.stunned, "revert stuns the cobra")
	failures += _check(head.rank == 9 and head.suit == 1, "identity reverts to previous meal")
	failures += _check(head.cobra_stack.size() == 1, "stack popped")
	var tails := 0
	for p in b.grid:
		if b.grid[p].snake_tail:
			tails += 1
	failures += _check(tails == 1, "newest tail segment removed")
	_free_board(b)

	# --- sticky hands: queen/honey only in 2-3 card hands -------------------
	b = _board([[8, 0, 0, 0], [8, 1, 1, 0], [8, 2, 2, 0], [8, 3, 3, 0]])
	b.grid[Vector2i(0, 0)].honey = true
	b.selected.assign([b.grid[Vector2i(0, 0)], b.grid[Vector2i(1, 0)]])
	b._update_hand_validity()
	failures += _check(b.grid[Vector2i(0, 0)].hand_valid,
			"honey pair (2 cards) is valid")
	b.selected.assign([b.grid[Vector2i(0, 0)], b.grid[Vector2i(1, 0)],
			b.grid[Vector2i(2, 0)], b.grid[Vector2i(3, 0)]])
	b._update_hand_validity()
	failures += _check(not b.grid[Vector2i(0, 0)].hand_valid,
			"honey in a 4-card hand is too sticky")
	b.selected.clear()
	_free_board(b)

	if failures == 0:
		print("ALL BOSS TESTS PASSED")
	else:
		print("%d BOSS TEST(S) FAILED" % failures)
	quit(failures)


func _board(cards: Array) -> Board:
	var b := Board.new()
	for c in cards:
		var card := PlayingCard.new()
		card.rank = c[0]
		card.suit = c[1]
		b.grid[Vector2i(c[2], c[3])] = card
	return b


func _free_board(b: Board) -> void:
	for card in b.grid.values():
		card.free()
	b.free()


func _check(cond: bool, label: String) -> int:
	if not cond:
		print("FAIL: " + label)
		return 1
	return 0
