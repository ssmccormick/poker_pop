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

	# --- The seed book ---------------------------------------------------------
	var path := "user://test_seedbook.cfg"
	DirAccess.remove_absolute(path)
	var book := SeedBook.new()
	book.load_file(path)
	var k := SeedBook.key("trail", "K7QX2M9P", SeedBook.trail_variant("the_gambler", 3))
	_check(k == "trail|K7QX2M9P|the_gambler-a3", "a board key is mode, seed and variant")
	_check(book.record(k, 500, {"tables": 12}), "a first score is a best")
	_check(not book.record(k, 300), "a lower one isn't")
	_check(book.record(k, 900, {"tables": 20}) and book.best(k) == 900, "a higher one is")
	_check(int(book.boards[k].attempts) == 3 and int(book.boards[k].tables) == 20,
			"attempts count, and the best ride's summary is kept")
	book.record(SeedBook.key("single", "ABCDEFGH"), 50)
	_check(book.recent(1).size() == 1 and book.recent(8).size() == 2, "recent seeds list the boards played")
	_check(not book.daily_used("D20261012"), "the day's daily starts unspent")
	book.mark_daily("D20261012")
	var again := SeedBook.new()
	again.load_file(path)
	_check(again.best(k) == 900 and again.daily_used("D20261012"), "the book survives a save and load")
	_check(again.player_id == "" and again.display_name().begins_with("Stranger ")
			and again.player_id.length() == 32, "a nameless player posts as a Stranger, with a made id")
	var pid := again.player_id
	again.player_name = SeedBook.clean_name("  Doc|Holliday The Great ")
	again.save()
	var third := SeedBook.new()
	third.load_file(path)
	_check(third.player_id == pid and third.display_name() == "DocHolliday",
			"the player's id and name are kept (%s)" % third.display_name())
	DirAccess.remove_absolute(path)

	# --- The online boards, with no keys --------------------------------------
	_check(not Leaderboard.configured(), "with the keys unpasted the online boards stay off")
	_check(Leaderboard._count_from(PackedStringArray(["Content-Type: x", "Content-Range: 0-0/42"])) == 42
			and Leaderboard._count_from(PackedStringArray(["content-range: */0"])) == 0,
			"a board's count reads from Content-Range")

	if failures == 0:
		print("ALL SEED TESTS PASSED")
	else:
		print("%d SEED TEST(S) FAILED" % failures)
	quit(failures)


func _check(cond: bool, label: String) -> void:
	if not cond:
		print("FAIL: " + label)
		failures += 1
