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

	b.selected.clear()
	for c in cards:
		c.free()
	b.free()

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
