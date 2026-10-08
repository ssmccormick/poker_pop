extends SceneTree

## Pure tests for the Ascension ladder: 20 rules, every knob only ever
## gets harder (and every reward only richer) as the level climbs, and
## Ascension 0 is the eased base trail.
## Run: godot --headless --path . --script res://tests/test_ascension.gd

var failures := 0


func _initialize() -> void:
	_check(Ascension.LEVELS.size() == Ascension.MAX and Ascension.MAX == 20,
			"twenty rungs on the ladder")
	var named := true
	for row in Ascension.LEVELS:
		if String(row.get("name", "")) == "" or String(row.get("desc", "")) == "":
			named = false
	_check(named, "every rung has a name and a rule")

	# Ascension 0: the plain trail, nothing added.
	_check(is_equal_approx(Ascension.target_mult(0), 1.0)
			and is_equal_approx(Ascension.blind_mult(0), 1.0)
			and Ascension.hazard_bonus(0) == 0.0 and Ascension.hands_minus(0) == 0
			and Ascension.start_chips(0) == 180 and Ascension.max_hp(0) == 10
			and Ascension.lost_table_hp(0) == 1 and Ascension.camp_rest(0) == 5
			and Ascension.bomb_hp(0) == 2 and Ascension.cursed_start(0) == 0
			and is_equal_approx(Ascension.boss_mult(0), 1.0)
			and Ascension.cobra_tail(0, Board.COBRA_START_TAIL) == Board.COBRA_START_TAIL,
			"Ascension 0 adds nothing")
	_check(TrailMode.BASE_TARGET == 850 and TrailMode.TARGET_STEP == 140
			and is_equal_approx(TrailMode.HAZARD_BASE_CHANCE, 0.10)
			and Board.JACK_HP == 2000 and Board.QUEEN_HP == 2400,
			"the base trail runs on the eased numbers")

	# Every knob climbs one way.
	var harder := true
	var richer := true
	for a in range(0, Ascension.MAX):
		var b := a + 1
		if Ascension.target_mult(b) < Ascension.target_mult(a) \
				or Ascension.blind_mult(b) < Ascension.blind_mult(a) \
				or Ascension.hazard_bonus(b) < Ascension.hazard_bonus(a) \
				or Ascension.refill_mult(b) < Ascension.refill_mult(a) \
				or Ascension.boss_mult(b) < Ascension.boss_mult(a) \
				or Ascension.hands_minus(b) < Ascension.hands_minus(a) \
				or Ascension.start_chips(b) > Ascension.start_chips(a) \
				or Ascension.max_hp(b) > Ascension.max_hp(a) \
				or Ascension.camp_rest(b) > Ascension.camp_rest(a) \
				or Ascension.lost_table_hp(b) < Ascension.lost_table_hp(a) \
				or Ascension.bomb_hp(b) < Ascension.bomb_hp(a) \
				or Ascension.shop_mult(b) < Ascension.shop_mult(a) \
				or Ascension.extra_seed(b) < Ascension.extra_seed(a) \
				or Ascension.cursed_start(b) < Ascension.cursed_start(a) \
				or Ascension.outlaw_hp_plus(b) < Ascension.outlaw_hp_plus(a):
			harder = false
		if Ascension.exp_mult(b) <= Ascension.exp_mult(a) \
				or Ascension.rate_bonus(b) <= Ascension.rate_bonus(a) \
				or Ascension.purse_mult(b) <= Ascension.purse_mult(a):
			richer = false
	_check(harder, "every rule only gets harder going up")
	_check(richer, "every reward grows with every rung")

	# Each rung lands where its rule says.
	_check(Ascension.hands_minus(6) == 0 and Ascension.hands_minus(7) == 1
			and Ascension.hands_minus(17) == 2, "Short-Handed bites at 7 and again at 17")
	_check(Ascension.max_hp(17) == 10 and Ascension.max_hp(18) == 8, "Worn Out: max HP 8 from 18")
	_check(Ascension.cobra_tail(20, 2) == 4 and Ascension.cobra_tail(19, 2) == 2,
			"the Long Snake grows two segments at 20")
	_check(is_equal_approx(Ascension.target_mult(20), 1.35), "targets +35% by the top")
	_check(is_equal_approx(Ascension.exp_mult(20), 2.0)
			and is_equal_approx(1.0 + Ascension.rate_bonus(20), 2.5),
			"Ascension 20 pays double EXP and a 2.5× cash-out")
	var active := Ascension.active(3)
	_check(active.size() == 3 and int(active[0][0]) == 1 and int(active[2][0]) == 3,
			"Ascension 3 is the first three rules")
	_check(Ascension.active(0).is_empty() and Ascension.active(99).size() == 20,
			"the active list clamps to the ladder")

	if failures == 0:
		print("ALL ASCENSION TESTS PASSED")
	else:
		print("%d ASCENSION TEST(S) FAILED" % failures)
	quit(failures)


func _check(cond: bool, label: String) -> void:
	if not cond:
		print("FAIL: " + label)
		failures += 1
