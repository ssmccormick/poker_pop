extends SceneTree

## Headless tests for the trail hazard engine's pure logic
## (wind lines, fire/bomb ticking, seeding, washed validity gate).
## Run: godot --headless --path . --script res://tests/test_hazards.gd


func _init() -> void:
	var failures := 0

	# --- wind_line_cells ---------------------------------------------------
	var b := _board([[5, 0, 0, 0], [6, 1, 1, 0], [9, 2, 3, 0], [4, 3, 0, 2]])
	var line: Array = b.wind_line_cells(Vector2i(0, 0), Vector2i.RIGHT)
	failures += _check(line == [Vector2i(1, 0), Vector2i(3, 0)],
			"wind line collects occupied cells to the right edge, skipping gaps")
	line = b.wind_line_cells(Vector2i(0, 0), Vector2i.DOWN)
	failures += _check(line == [Vector2i(0, 2)], "wind line goes down")
	line = b.wind_line_cells(Vector2i(0, 0), Vector2i.LEFT)
	failures += _check(line.is_empty(), "wind line at the edge is empty")
	var heavy := PlayingCard.new()
	heavy.is_safe = true
	b.grid[Vector2i(2, 0)] = heavy
	line = b.wind_line_cells(Vector2i(0, 0), Vector2i.RIGHT)
	failures += _check(line == [Vector2i(1, 0), Vector2i(3, 0)],
			"the safe is too heavy for the wind")
	_free_board(b)

	# --- apply_room_hazards ------------------------------------------------
	b = _board([[5, 0, 0, 0], [6, 1, 1, 0], [9, 2, 2, 0], [4, 3, 3, 0]])
	b.grid[Vector2i(3, 0)].cursed = true
	b.apply_room_hazards("bomb", 2)
	var bombs := 0
	for p in b.grid:
		if b.grid[p].hazard == "bomb":
			bombs += 1
			failures += _check(b.grid[p].fuse == Board.BOMB_FUSE, "bomb fuse set")
			failures += _check(not b.grid[p].cursed, "cursed cards never hazarded")
	failures += _check(bombs == 2, "exactly two bombs seeded")
	_free_board(b)

	# --- fire spreads each tick, then burns down ---------------------------
	b = _board([[3, 0, 0, 0], [7, 1, 1, 0], [9, 2, 0, 1], [4, 3, 4, 4]])
	b.grid[Vector2i(0, 0)].hazard = "fire"
	b.grid[Vector2i(0, 1)].cursed = true
	var res: Dictionary = b._tick_fire_and_bombs()
	failures += _check(res.ignited == [Vector2i(1, 0)],
			"fire spreads to its one eligible neighbor (cursed skipped)")
	failures += _check(b.grid[Vector2i(1, 0)].hazard == "fire", "neighbor now burning")
	failures += _check(b.grid[Vector2i(1, 0)].rank == 7,
			"a fresh fire doesn't burn down on the tick that lit it")
	failures += _check(b.grid[Vector2i(0, 0)].rank == 2, "fire ticks rank down")
	failures += _check(res.burned.is_empty(), "rank 2 has not burned yet")
	res = b._tick_fire_and_bombs()
	failures += _check(res.burned == [Vector2i(0, 0)], "below 2 burns up")
	failures += _check(res.ignited.is_empty(),
			"no fresh targets — everything adjacent burns or is cursed")
	failures += _check(b.grid[Vector2i(1, 0)].rank == 6, "second fire burns down too")
	failures += _check(b.grid[Vector2i(4, 4)].hazard == "", "distant card untouched")
	_free_board(b)

	# --- water drips on the tick -------------------------------------------
	b = _board([[5, 0, 0, 0], [7, 1, 1, 0]])
	b.grid[Vector2i(0, 0)].hazard = "water"
	var wres: Dictionary = b._tick_fire_and_bombs()
	failures += _check(wres.soaked == [Vector2i(1, 0)],
			"water soaks its orthogonal neighbor on the tick")
	failures += _check(b.grid[Vector2i(1, 0)].washed, "neighbor is washed")
	wres = b._tick_fire_and_bombs()
	failures += _check(wres.soaked.is_empty(),
			"nothing left to soak once neighbors are washed")
	_free_board(b)

	# --- purge prediction: hazards left after pops and gusts ---------------
	b = _board([[5, 0, 0, 0], [7, 1, 1, 0], [9, 2, 2, 0], [4, 3, 0, 1]])
	b.grid[Vector2i(0, 0)].hazard = "bomb"
	b.grid[Vector2i(2, 0)].hazard = "stone"
	b.grid[Vector2i(2, 0)].stone_hits = 3
	b.grid[Vector2i(0, 1)].hazard = "wind"
	b.grid[Vector2i(0, 1)].wind_dir = Vector2i.UP
	b.selected.assign([b.grid[Vector2i(0, 0)], b.grid[Vector2i(2, 0)]])
	failures += _check(b.predicted_hazards_left() == 2,
			"popped bomb goes; kept stone and unplayed wind remain")
	b.selected.assign([b.grid[Vector2i(0, 1)], b.grid[Vector2i(1, 0)]])
	failures += _check(b.predicted_hazards_left() == 1,
			"played wind gusts the bomb away — only the stone remains")
	b.selected.clear()
	_free_board(b)

	# --- bomb fuse ---------------------------------------------------------
	b = _board([[5, 0, 0, 0], [6, 1, 1, 0]])
	b.grid[Vector2i(0, 0)].hazard = "bomb"
	b.grid[Vector2i(0, 0)].fuse = 2
	res = b._tick_fire_and_bombs()
	failures += _check(not res.exploded and b.grid[Vector2i(0, 0)].fuse == 1,
			"fuse ticks without exploding")
	res = b._tick_fire_and_bombs()
	failures += _check(res.exploded, "fuse at zero explodes")
	_free_board(b)

	# --- washed cards suppress the green tell -------------------------------
	b = _board([[8, 0, 0, 0], [8, 1, 1, 0]])
	b.selected.assign([b.grid[Vector2i(0, 0)], b.grid[Vector2i(1, 0)]])
	for c in b.selected:
		c.selected = true
	b._update_hand_validity()
	failures += _check(b.grid[Vector2i(0, 0)].hand_valid, "pair shows green normally")
	b.grid[Vector2i(1, 0)].washed = true
	b._update_hand_validity()
	failures += _check(not b.grid[Vector2i(0, 0)].hand_valid,
			"washed card in the chain kills the green tell")
	_free_board(b)

	# --- safe combo matching -----------------------------------------------
	b = _board([[3, 0, 0, 0], [9, 1, 1, 0], [5, 2, 2, 0], [2, 3, 3, 0]])
	var safe := PlayingCard.new()
	safe.is_safe = true
	safe.combo = [3, 9, 5, 2]
	b.grid[Vector2i(4, 0)] = safe
	b.selected.assign([b.grid[Vector2i(0, 0)], b.grid[Vector2i(1, 0)],
			b.grid[Vector2i(2, 0)], b.grid[Vector2i(3, 0)]])
	failures += _check(b._chain_matches_combo(safe), "exact ordered combo matches")
	b._update_safe_progress()
	failures += _check(safe.combo_progress == 4, "all four digits light up")
	b.selected.assign([b.grid[Vector2i(0, 0)], b.grid[Vector2i(1, 0)],
			b.grid[Vector2i(3, 0)]])
	failures += _check(not b._chain_matches_combo(safe), "wrong length fails")
	b._update_safe_progress()
	failures += _check(safe.combo_progress == 2, "prefix stops at first mismatch")
	b.selected.assign([b.grid[Vector2i(1, 0)], b.grid[Vector2i(0, 0)],
			b.grid[Vector2i(2, 0)], b.grid[Vector2i(3, 0)]])
	failures += _check(not b._chain_matches_combo(safe), "out of order fails")
	b.selected.clear()
	_free_board(b)

	if failures == 0:
		print("ALL HAZARD TESTS PASSED")
	else:
		print("%d HAZARD TEST(S) FAILED" % failures)
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
