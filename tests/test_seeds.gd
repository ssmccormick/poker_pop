extends SceneTree

## Pure tests for seeds: the text format, the hash, the daily seed and
## the streams every gameplay roll draws from.
## Run: godot --headless --path . --script res://tests/test_seeds.gd

var failures := 0


func _initialize() -> void:
	# --- Seed text --------------------------------------------------------
	var s := SeedRng.random_seed()
	_check(s.length() == SeedRng.LENGTH and SeedRng.is_valid(s), "a random seed is 8 valid characters (%s)" % s)
	_check(SeedRng.normalize(" k7qx-2m9p ") == "K7QX2M9P", "typing is forgiving: case, spaces, dashes")
	_check(SeedRng.normalize("OOII2345") == "QQLL2345", "look-alike O and I map onto the alphabet")
	_check(SeedRng.pretty("K7QX2M9P") == "K7QX-2M9P", "seeds read in two halves")
	_check(not SeedRng.is_valid("SHORT") and not SeedRng.is_valid(""), "short seeds aren't seeds")

	# --- The daily seed ----------------------------------------------------
	var d := SeedRng.daily_seed({"year": 2026, "month": 10, "day": 12})
	_check(d == "D20261012" and SeedRng.is_daily(d) and SeedRng.is_valid(d), "the daily seed is the date")
	_check(SeedRng.pretty(d) == "DAILY 2026-10-12", "and reads as one")
	_check(SeedRng.normalize("d20261012") == "D20261012", "daily seeds survive normalizing")

	# --- The hash ------------------------------------------------------------
	_check(SeedRng.hash64("K7QX2M9P") == SeedRng.hash64("K7QX2M9P"), "the hash is stable")
	_check(SeedRng.hash64("K7QX2M9P") != SeedRng.hash64("K7QX2M9Q"), "one letter changes it")
	print("hash64(K7QX2M9P|wall|3|0) = %d" % SeedRng.hash64("K7QX2M9P|wall|3|0"))

	# --- Streams -------------------------------------------------------------
	var a := SeedRng.stream("K7QX2M9P", "wall", 3)
	var b := SeedRng.stream("K7QX2M9P", "wall", 3)
	var same := true
	for i in 200:
		randf()  # the global RNG churning between draws changes nothing
		if a.randi() != b.randi():
			same = false
	_check(same, "a stream for the same key gives the same numbers, whatever the global RNG does")
	var c := SeedRng.stream("K7QX2M9P", "wall", 4)
	var e := SeedRng.stream("K7QX2M9P", "shop", 3)
	var x := SeedRng.stream("K7QX2M9P", "wall", 3)
	var r0 := x.randi()
	_check(c.randi() != r0 and e.randi() != r0, "another stop or purpose gives a different stream")
	var arr := range(20)
	var arr2 := range(20)
	SeedRng.shuffle(SeedRng.stream("ABCDEFGH", "deal"), arr)
	SeedRng.shuffle(SeedRng.stream("ABCDEFGH", "deal"), arr2)
	var sorted := arr.duplicate()
	sorted.sort()
	_check(arr == arr2 and sorted == range(20) and arr != range(20),
			"a seeded shuffle is a real, repeatable permutation")
	_check(SeedRng.pick(SeedRng.stream("ABCDEFGH", "p"), []) == null, "picking from nothing is null")

	if failures == 0:
		print("ALL SEED TESTS PASSED")
	else:
		print("%d SEED TEST(S) FAILED" % failures)
	quit(failures)


func _check(cond: bool, label: String) -> void:
	if not cond:
		print("FAIL: " + label)
		failures += 1
