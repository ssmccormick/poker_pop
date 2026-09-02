extends SceneTree

## Headless tests for chip/mult deck modifier scoring.
## Run: godot --headless --path . --script res://tests/test_mods.gd


func _init() -> void:
	var failures := 0
	var b := Board.new()
	var cards: Array = []
	for spec in [["", 0], ["mult", 0], ["mult", 0], ["chip", 0], ["chip", 0]]:
		var c := PlayingCard.new()
		c.mod = spec[0]
		cards.append(c)

	# No mods: nothing changes.
	b.selected.assign([cards[0]])
	var res := {"score": 100}
	b._apply_card_mods(res)
	failures += _check(res.score == 100 and not res.has("bonus_chips"),
			"plain selection untouched")

	# One mult: x1.5.
	b.selected.assign([cards[0], cards[1]])
	res = {"score": 100}
	b._apply_card_mods(res)
	failures += _check(res.score == 150, "one mult card multiplies x1.5")

	# Two mults stack multiplicatively: x2.25.
	b.selected.assign([cards[1], cards[2]])
	res = {"score": 100}
	b._apply_card_mods(res)
	failures += _check(res.score == 225, "two mult cards stack to x2.25")

	# Chip cards pay bonus chips without touching the score.
	b.selected.assign([cards[3], cards[4]])
	res = {"score": 60}
	b._apply_card_mods(res)
	failures += _check(res.score == 60 and res.bonus_chips == Board.CHIP_BONUS * 2,
			"two chip cards pay double bonus, score unchanged")

	# Mixed hand: both effects apply.
	b.selected.assign([cards[1], cards[3]])
	res = {"score": 100}
	b._apply_card_mods(res)
	failures += _check(res.score == 150 and res.bonus_chips == Board.CHIP_BONUS,
			"mult and chip in one hand both apply")

	# Gold cards bank real dollars: $1 apiece.
	var cash1 := PlayingCard.new()
	cash1.mod = "gold"
	var cash2 := PlayingCard.new()
	cash2.mod = "gold"
	b.selected.assign([cash1, cash2])
	res = {"score": 40}
	b._apply_card_mods(res)
	failures += _check(res.score == 40 and res.cash_earned == 2,
			"two gold cards earn $2, score unchanged")

	b.selected.clear()
	for c in cards:
		c.free()
	cash1.free()
	cash2.free()
	b.free()

	# Plus/minus arrows swing a quarter turn clockwise on every tick.
	b = Board.new()
	var boost := PlayingCard.new()
	boost.mod = "plus"
	boost.boost_dir = Vector2i.RIGHT
	boost.grid_pos = Vector2i(0, 0)
	b.grid[Vector2i(0, 0)] = boost
	b._tick_fire_and_bombs()
	failures += _check(boost.boost_dir == Vector2i.DOWN, "plus arrow turns right→down")
	b._tick_fire_and_bombs()
	b._tick_fire_and_bombs()
	b._tick_fire_and_bombs()
	failures += _check(boost.boost_dir == Vector2i.RIGHT,
			"four ticks bring the arrow full circle")
	boost.free()
	b.free()

	# Bumper shoves: gaps absorb, edges shove off, heavy cards block.
	b = Board.new()
	for spec in [[7, 0, 1, 0], [9, 1, 2, 0]]:
		var c2 := PlayingCard.new()
		c2.rank = spec[0]
		c2.suit = spec[1]
		c2.grid_pos = Vector2i(spec[2], spec[3])
		b.grid[c2.grid_pos] = c2
	var moves: Array = b._apply_bump(Vector2i(0, 0), Vector2i.RIGHT)
	failures += _check(moves.size() == 2 and b.grid.has(Vector2i(3, 0))
			and b.grid.has(Vector2i(2, 0)) and not b.grid.has(Vector2i(1, 0)),
			"a gap absorbs the shove — both cards slide one step")
	b._apply_bump(Vector2i(1, 0), Vector2i.RIGHT)  # slide to cols 3 and 4
	moves = b._apply_bump(Vector2i(2, 0), Vector2i.RIGHT)
	var shoved: Array = moves.filter(func(m): return m.off)
	failures += _check(shoved.size() == 1 and b.grid.has(Vector2i(4, 0))
			and not b.grid.has(Vector2i(3, 0)),
			"a run reaching the edge shoves the far card off the table")
	for m in moves:
		if m.off:
			m.card.free()
	var pushed := PlayingCard.new()
	pushed.grid_pos = Vector2i(2, 0)
	b.grid[Vector2i(2, 0)] = pushed
	var wall := PlayingCard.new()
	wall.is_safe = true
	wall.grid_pos = Vector2i(3, 0)
	b.grid[Vector2i(3, 0)] = wall
	moves = b._apply_bump(Vector2i(1, 0), Vector2i.RIGHT)
	failures += _check(moves.is_empty() and b.grid.has(Vector2i(2, 0)),
			"a safe blocks the push — nothing budges")
	for card in b.grid.values():
		card.free()
	b.free()

	# Old save ids map onto the current mod family.
	failures += _check(Board.migrate_mod("cash") == "gold"
			and Board.migrate_mod("boost") == "plus"
			and Board.migrate_mod("chipsplode") == "chip"
			and Board.migrate_mod("wild") == "wild",
			"legacy mod ids migrate")

	if failures == 0:
		print("ALL MOD TESTS PASSED")
	else:
		print("%d MOD TEST(S) FAILED" % failures)
	quit(failures)


func _check(cond: bool, label: String) -> int:
	if not cond:
		print("FAIL: " + label)
		return 1
	return 0
