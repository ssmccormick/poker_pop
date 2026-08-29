extends SceneTree

## Headless tests for boss logic that doesn't need a scene tree:
## cobra eat/revert bookkeeping and the sticky (queen/honey) hand gate.
## Run: godot --headless --path . --script res://tests/test_bosses.gd


func _init() -> void:
	var failures := 0

	# --- cobra slithers (body follows the head) -----------------------------
	# Head at (1,0) with one segment behind it at (0,0); victim at (2,0).
	var b := _board([[5, 0, 0, 0], [7, 3, 1, 0], [9, 1, 2, 0]])
	var head: PlayingCard = b.grid[Vector2i(1, 0)]
	head.boss = "cobra"
	var seg: PlayingCard = b.grid[Vector2i(0, 0)]
	seg.snake_tail = true
	head.cobra_body = [seg]
	head.cobra_stack = [{"rank": 5, "suit": 0}]
	var moved: bool = await b._cobra_eat(head, true)
	failures += _check(moved, "the cobra moved")
	failures += _check(head.grid_pos == Vector2i(2, 0), "head slid into the victim's cell")
	failures += _check(head.rank == 9 and head.suit == 1, "head took the victim's identity")
	failures += _check(head.cobra_stack.size() == 2, "previous identity pushed onto the stack")
	failures += _check(b.grid.has(Vector2i(1, 0)) and b.grid[Vector2i(1, 0)] == seg,
			"the segment followed into the head's old cell")
	failures += _check(not b.grid.has(Vector2i(0, 0)),
			"the tail tip's old cell is vacated for the refill")

	b._cobra_revert(head)
	failures += _check(head.stunned, "revert stuns the cobra")
	failures += _check(head.rank == 7 and head.suit == 3, "identity reverts to previous meal")
	failures += _check(head.cobra_body.is_empty(), "tail tip crumbled")
	failures += _check(not b.grid.has(Vector2i(1, 0)), "tip removed from the board")
	_free_board(b)

	# --- cobra spawn grows a connected body ---------------------------------
	b = _board([[5, 0, 0, 0], [6, 1, 1, 0], [9, 2, 2, 0], [4, 3, 0, 1], [8, 0, 1, 1]])
	b.spawn_boss("cobra")
	var found_head: PlayingCard = null
	var tails := 0
	for p in b.grid:
		if b.grid[p].boss == "cobra":
			found_head = b.grid[p]
		elif b.grid[p].snake_tail:
			tails += 1
	failures += _check(found_head != null, "cobra head spawned")
	failures += _check(tails == Board.COBRA_START_TAIL
			and found_head.cobra_body.size() == Board.COBRA_START_TAIL,
			"starting body segments placed and tracked")
	failures += _check(found_head.cobra_stack.size() == Board.COBRA_START_TAIL,
			"starting identities stored")
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
		card.grid_pos = Vector2i(c[2], c[3])
		b.grid[card.grid_pos] = card
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
