extends SceneTree

## Headless test for the Doctor's pocket-watch snapshot: capture a
## varied board, mutate everything, restore, and compare.
## Run: godot --headless --path . --script res://tests/test_watch.gd


func _init() -> void:
	var failures := 0
	var board := Board.new()
	var specs := [
		[2, 0, Vector2i(0, 0)], [13, 1, Vector2i(1, 0)],
		[7, 2, Vector2i(0, 1)], [7, 3, Vector2i(1, 1)],
	]
	for s in specs:
		var card := PlayingCard.new()
		card.rank = s[0]
		card.suit = s[1]
		card.grid_pos = s[2]
		board.grid[s[2]] = card
		board.add_child(card)
	var burning: PlayingCard = board.grid[Vector2i(0, 0)]
	burning.hazard = "fire"
	var marked: PlayingCard = board.grid[Vector2i(1, 0)]
	marked.objective = "chest"
	marked.mod = "gold"
	var bomb: PlayingCard = board.grid[Vector2i(1, 1)]
	bomb.hazard = "bomb"
	bomb.fuse = 3
	board.deck = [{"rank": 5, "suit": 2, "cursed": false, "mod": "", "finish": ""}]
	board.jack_bar = 123
	board.undo_enabled = true
	board.snapshot_state()
	failures += _expect(board.has_undo(), "snapshot taken")

	# Mutate hard: clear a card, rewrite others, drain the deck.
	board.grid.erase(Vector2i(0, 1))
	burning.hazard = ""
	burning.rank = 9
	marked.objective = ""
	marked.mod = ""
	bomb.fuse = 1
	board.deck.clear()
	board.jack_bar = 0

	failures += _expect(board.restore_state(), "restore ran")
	failures += _expect(board.grid.size() == 4, "all four cards back")
	var b2: PlayingCard = board.grid[Vector2i(0, 0)]
	failures += _expect(b2.hazard == "fire" and b2.rank == 2, "fire card restored")
	var m2: PlayingCard = board.grid[Vector2i(1, 0)]
	failures += _expect(m2.objective == "chest" and m2.mod == "gold",
			"chest card restored")
	var f2: PlayingCard = board.grid[Vector2i(1, 1)]
	failures += _expect(f2.hazard == "bomb" and f2.fuse == 3, "fuse rewound")
	failures += _expect(board.deck.size() == 1 and int(board.deck[0].rank) == 5,
			"deck restored")
	failures += _expect(board.jack_bar == 123, "jack bar restored")
	failures += _expect(not board.has_undo(), "snapshot consumed")
	failures += _expect(not board.restore_state(), "no double rewind")

	if failures == 0:
		print("ALL WATCH TESTS PASSED")
	else:
		print("%d WATCH TEST(S) FAILED" % failures)
	quit(failures)


func _expect(ok: bool, label: String) -> int:
	if ok:
		return 0
	print("FAIL: %s" % label)
	return 1
