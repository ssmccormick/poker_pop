extends SceneTree

## Pure tests for meta progression: the catalog, the EXP curve, ride
## EXP, grandfathering, gates, weighted picks and the save round-trip.
## Run: godot --headless --path . --script res://tests/test_progression.gd

const MODS := ["mult", "chip", "gold", "plus", "minus", "bumper", "wild"]

var failures := 0


func _initialize() -> void:
	_catalog()
	_curve()
	_ride_exp()
	_grandfather()
	_gates()
	_picks()
	_odds()
	_round_trip()
	_contracts()
	_power()
	if failures == 0:
		print("ALL PROGRESSION TESTS PASSED")
	else:
		print("%d PROGRESSION TEST(S) FAILED" % failures)
	quit(failures)


func _catalog() -> void:
	var counts := {}
	for r in Progression.CATALOG:
		var k := Progression.key(String(r.kind), String(r.id))
		counts[k] = int(counts.get(k, 0)) + 1
	var dupes := counts.keys().filter(func(k): return int(counts[k]) > 1)
	_check(dupes.is_empty(), "no item appears twice in the catalog %s" % str(dupes))
	var want: Array = []
	for id in TrailMode.RELICS:
		want.append(Progression.key("relic", id))
	for id in TrailMode.PROVISIONS:
		want.append(Progression.key("provision", id))
	for id in MODS:
		want.append(Progression.key("mod", id))
	for id in PlayingCard.FINISHES:
		want.append(Progression.key("finish", id))
	for id in TrailMode.CHARACTERS:
		want.append(Progression.key("rider", id))
	for id in TrailMode.GAMBLER_ABILITIES:
		want.append(Progression.key("trick", id))
	for m in TrailMode.MERCHANTS:
		want.append(Progression.key("merchant", String(m.id)))
	var missing := want.filter(func(k): return not counts.has(k))
	_check(missing.is_empty(), "every relic, provision, card, rider and merchant is in the catalog %s" % str(missing))
	var gated_tables := Progression.CATALOG.filter(func(r): return String(r.kind) in ["room", "stake"])
	_check(gated_tables.is_empty(), "no table type or stake is gated — they're all on the trail")

	# The starter set, exactly.
	var starters: Array = []
	for r in Progression.CATALOG:
		if int(r.level) == 1:
			starters.append(Progression.key(String(r.kind), String(r.id)))
	starters.sort()
	var expect := ["rider:the_gambler", "trick:sleeve", "gear:bankroll",
			"merchant:peddler", "mod:mult", "mod:chip", "mod:gold",
			"relic:horseshoe", "relic:card_sleeve", "relic:snake_oil", "relic:tin_star",
			"relic:bomb_badge", "relic:chisel", "provision:canteen",
			"provision:dynamite", "provision:pocket_flask", "provision:gold_pan"]
	expect.sort()
	_check(starters == expect, "the starter set is exactly the small kit")

	# One unlock on every level 2..29, nothing past it.
	var per_level := {}
	for r in Progression.CATALOG:
		if not r.has("after_win"):
			per_level[int(r.level)] = int(per_level.get(int(r.level), 0)) + 1
	var bad: Array = []
	for lv in range(2, Progression.LAST_UNLOCK + 1):
		if int(per_level.get(lv, 0)) != 1:
			bad.append(lv)
	_check(bad.is_empty() and Progression.LAST_UNLOCK == 29,
			"exactly one unlock on each level 2-29 %s" % str(bad))
	var past := per_level.keys().filter(func(lv): return int(lv) > Progression.LAST_UNLOCK)
	_check(past.is_empty(), "no unlocks past level 29")
	# Riders are won, not levelled.
	var p := Progression.new()
	p.exp_total = Progression.exp_at_level(60)
	_check(not p.is_available("rider", "the_machine") and not p.is_available("rider", "the_doctor"),
			"even at level 60 the Machine and the Doctor wait for a win")
	p.stats = {"trail_wins_the_gambler": 1}
	_check(p.is_available("rider", "the_machine") and not p.is_available("rider", "the_doctor"),
			"a Gambler win frees the Machine (no price), not yet the Doctor")
	p.stats["trail_wins_the_machine"] = 1
	_check(p.is_available("rider", "the_doctor"), "a Machine win frees the Doctor")
	_check(Progression.unlocks_between(0, 99).all(func(r): return not r.has("after_win")),
			"riders never show up as level-up unlocks")


func _curve() -> void:
	var ok := true
	for lv in range(1, 60):
		if Progression.exp_at_level(lv + 1) <= Progression.exp_at_level(lv):
			ok = false
		if Progression.level_for_exp(Progression.exp_at_level(lv)) != lv:
			ok = false
		if Progression.level_for_exp(Progression.exp_at_level(lv + 1) - 1) != lv:
			ok = false
	_check(ok, "the curve climbs and level_for_exp inverts it")
	_check(Progression.exp_at_level(2) == 80, "level 2 at 80 EXP")
	_check(Progression.exp_at_level(29) == 9800, "every unlock is in hand by 9,800 EXP (level 29)")
	_check(Progression.purse_between(1, 3) == 25, "levels 2 and 3 pay $10 + $15")


func _ride_exp() -> void:
	# Three cleared tables (~1,000-1,500 a table), busted at the fourth.
	var bust := Progression.run_exp(4500, 4, 0, 0, false)
	_check(int(bust.total) >= 80, "an early bust still reaches level 2 (%d EXP)" % int(bust.total))
	var deep := Progression.run_exp(41000, 10, 1, 0, false)
	_check(absi(int(deep.total) - 560) <= 20, "a death at table 10 with 41k ≈ 560 EXP (%d)" % int(deep.total))
	var win := Progression.run_exp(100000, 21, 3, 0, true)
	_check(absi(int(win.total) - 1610) <= 20, "a Penny Ante win ≈ 1,600 EXP (%d)" % int(win.total))
	var high := Progression.run_exp(100000, 21, 3, 20, true)
	_check(int(high.total) == int(win.total) * 2, "an Ascension 20 win pays double EXP")
	var sum := 0
	for r in high.rows:
		sum += int(r[1])
	_check(sum == int(high.total), "the breakdown rows add up to the total")
	var huge := Progression.run_exp(10000000, 21, 3, 0, true)
	_check(int(huge.rows[0][1]) == 2500, "score EXP is soft-capped at 2,500")


func _grandfather() -> void:
	_check(Progression.grandfather_exp({}) == 0, "no stats, no head start")
	var vet := {"trail_runs": 30, "tables_cleared": 200, "bosses_beaten": 12,
			"trail_wins": 2, "deepest_table": 21}
	var p := Progression.new()
	var cf := ConfigFile.new()
	var built := p.read(cf, vet, {"character": "the_doctor", "watch": 1})
	_check(built and p.grandfathered, "a veteran profile with no progress is grandfathered")
	_check(p.level() >= 25, "a trail winner starts at level 25 or more (L%d)" % p.level())
	_check(p.is_available("relic", "rabbits_foot") and p.is_available("rider", "the_doctor"),
			"everything at or below the level, and the rider they rode, is theirs")
	_check(p.asc_max("the_doctor") == 1 and p.asc_max("the_gambler") == 0,
			"a past winner has Ascension 1 open for the rider they rode")
	# A version-1 save from before the repack: owns the old layout only.
	var old := Progression.new()
	old.read(ConfigFile.new(), vet, {"character": "the_gambler"})
	old.owned.erase(Progression.key("relic", "mirror_shades"))
	old.catalog_version = 1
	var ocf := ConfigFile.new()
	old.write(ocf)
	var moved := Progression.new()
	var resave := moved.read(ocf, vet)
	_check(resave and moved.owns("relic", "mirror_shades") and moved.catalog_version == 2,
			"the repack hands a grandfathered profile everything at its level")
	var fresh := Progression.new()
	_check(not fresh.read(ConfigFile.new(), {"hands_played": 50}),
			"a profile that never rode the trail starts fresh")
	_check(fresh.level() == 1, "fresh is level 1")
	var floor_only := Progression.new()
	floor_only.read(ConfigFile.new(), {"trail_runs": 1, "deepest_table": 8})
	_check(floor_only.level() >= 10, "reaching table 7 floors the level at 10")


func _gates() -> void:
	var p := Progression.new()
	_check(p.is_available("relic", "horseshoe"), "starters are available at level 1")
	_check(not p.is_available("relic", "rabbits_foot"), "a level-3 relic is locked at level 1")
	_check(p.is_available("room", "clock") and p.is_available("room", "blackjack"),
			"every table type is open at level 1")
	_check(p.is_available("relic", "not_in_catalog"), "unknown ids are never gated")
	var gain := p.add_exp(Progression.exp_at_level(3))
	_check(int(gain.to) == 3 and gain.unlocks.size() == 2 and int(gain.purse) == 25,
			"climbing to 3 unlocks two things and pays the purse")
	p.add_exp(Progression.exp_at_level(5) - p.exp_total)
	_check(p.is_available("gear", "provisions"), "a free unlock (Packed Kit) is ready on the spot")
	_check(p.is_unlocked("relic", "rabbits_foot") and not p.is_available("relic", "rabbits_foot"),
			"a priced unlock waits to be bought")
	_check(p.buy_cost("relic", "rabbits_foot") == 60, "it costs its price")
	p.mark_owned("relic", "rabbits_foot")
	_check(p.is_available("relic", "rabbits_foot") and p.buy_cost("relic", "rabbits_foot") == 0,
			"bought, it's on the trail")
	_check(p.find_cost("relic", "horseshoe") == 40 and p.find_cost("relic", "rabbits_foot") == 30,
			"FIND 1 costs half the buy price, at least $30")
	p.raise_find("relic", "horseshoe")
	p.raise_find("relic", "horseshoe")
	_check(p.find_level("relic", "horseshoe") == 2 and p.find_cost("relic", "horseshoe") == 0,
			"FIND tops out at 2")
	_check(p.find_cost("rider", "the_gambler") == 0, "riders have no FIND level")
	_check(p.asc_max("the_gambler") == 0 and p.open_ascension("the_gambler", 1)
			and not p.open_ascension("the_gambler", 1) and p.asc_max("the_gambler") == 1,
			"a win opens the next Ascension once")
	p.open_ascension("the_gambler", 99)
	_check(p.asc_max("the_gambler") == Ascension.MAX and p.asc_max("the_machine") == 0,
			"Ascension caps at 20 and is kept per rider")


func _picks() -> void:
	var p := Progression.new()
	var weights := {"horseshoe": 1.0, "rabbits_foot": 1.0, "lucky_chip": 1.0}
	var leaked := false
	for i in 500:
		if p.pick("relic", weights) != "horseshoe":
			leaked = true
	_check(not leaked, "pick never returns a locked id")
	_check(p.pick("relic", weights, ["horseshoe"]) == "", "nothing available picks \"\"")
	p.unlock_all = true
	p.find[Progression.key("relic", "horseshoe")] = 2
	var n := {}
	for i in 20000:
		var id := p.pick("relic", {"horseshoe": 1.0, "chisel": 1.0})
		n[id] = int(n.get(id, 0)) + 1
	var ratio := float(n.get("horseshoe", 0)) / maxf(1.0, float(n.get("chisel", 0)))
	_check(absf(ratio - 2.0) < 0.15, "FIND 2 doubles how often it turns up (%.2f×)" % ratio)


## Fully unlocked, the weighted tables deal exactly the old odds.
func _odds() -> void:
	var p := Progression.new()
	p.unlock_all = true
	# The old cumulative chain, goal by goal.
	var old_rooms := {"safe": 0.06, "chest": 0.06, "mine": 0.024, "purge": 0.096,
			"hands": 0.10, "holdem": 0.08, "crazy8": 0.07, "blackjack": 0.08,
			"outlaw": 0.08, "collect": 0.08, "landrush": 0.07, "plain": 0.20}
	_check(_odds_match(p, "room", TrailMode.ROOM_TABLE, old_rooms),
			"table odds match the old draw within 1.5%")
	var old_mods := {"mult": 0.26, "chip": 0.26, "plus": 0.14, "minus": 0.10,
			"bumper": 0.11, "gold": 0.10, "wild": 0.03}
	_check(_odds_match(p, "mod", TrailMode.MOD_WEIGHTS, old_mods),
			"enhancement odds match the old roll within 1.5%")
	var fresh := Progression.new()
	_check(_odds_match(fresh, "room", TrailMode.ROOM_TABLE, old_rooms),
			"at level 1 every table type deals at its full odds")
	var mods_ok := true
	for i in 2000:
		if not fresh.pick("mod", TrailMode.MOD_WEIGHTS) in ["mult", "chip", "gold"]:
			mods_ok = false
	_check(mods_ok, "at level 1 only Mult, Chip and Gold turn up")


func _odds_match(p: Progression, kind: String, weights: Dictionary, want: Dictionary) -> bool:
	var n := {}
	var draws := 20000
	for i in draws:
		var id := p.pick(kind, weights)
		n[id] = int(n.get(id, 0)) + 1
	var ok := true
	for id in want:
		var got := float(n.get(id, 0)) / draws
		if absf(got - float(want[id])) > 0.015:
			print("  %s %s: %.3f vs %.3f" % [kind, id, got, float(want[id])])
			ok = false
	return ok


func _round_trip() -> void:
	var p := Progression.new()
	p.add_exp(1234)
	p.mark_owned("relic", "rabbits_foot")
	p.raise_find("mod", "mult")
	p.power[Progression.key("relic", "horseshoe")] = 1
	p.seen_level = 5
	p.last_run_uid = "abc"
	p.contracts_claimed["first_ride"] = true
	p.contracts_seen["first_ride"] = true
	p.open_ascension("the_machine", 7)
	var cf := ConfigFile.new()
	p.write(cf)
	var text := cf.encode_to_text()
	var cf2 := ConfigFile.new()
	cf2.parse(text)
	var q := Progression.new()
	q.read(cf2, {"trail_runs": 99})
	_check(q.exp_total == 1234 and q.owns("relic", "rabbits_foot")
			and q.find_level("mod", "mult") == 1
			and q.power_level("relic", "horseshoe") == 1
			and q.seen_level == 5 and q.last_run_uid == "abc"
			and q.contracts_claimed.has("first_ride") and q.contracts_seen.has("first_ride")
			and q.asc_max("the_machine") == 7
			and not q.grandfathered,
			"progress survives a save and load (and isn't re-grandfathered)")


func _contracts() -> void:
	var ids := {}
	var bad_req: Array = []
	for c in Contracts.LIST:
		ids[String(c.id)] = true
		var req: Array = c.requires
		if not req.is_empty() and Progression.row(String(req[0]), String(req[1])).is_empty():
			bad_req.append(String(c.id))
	_check(ids.size() == Contracts.LIST.size(), "every contract id is unique")
	_check(bad_req.is_empty(), "every contract's requirement is a catalog item %s" % str(bad_req))
	var p := Progression.new()
	var stats := {"rides_ended": 1, "tables_cleared": 4, "duels_won": 9}
	var hands := {"Royal Flush": 1}
	var first := Contracts.find("first_ride")
	var talk := Contracts.find("table_talk")
	var wanted := Contracts.find("wanted")
	var royal := Contracts.find("royal_treatment")
	var safe := Contracts.find("climbing")
	_check(Contracts.state(first, stats, hands, p) == "ready", "a met target is ready to claim")
	_check(Contracts.progress_of(talk, stats, hands) == 4
			and Contracts.state(talk, stats, hands, p) == "open", "a part-way one shows its progress")
	_check(Contracts.state(royal, stats, hands, p) == "ready", "hand contracts read the hand tally")
	_check(Contracts.state(Contracts.find("sharpshooter"), stats, hands, p) == "locked",
			"one that needs a rider not yet won is greyed out")
	_check(Contracts.state(Contracts.find("safecracker"), stats, hands, p) == "open",
			"table contracts are open from the start")
	_check(Contracts.progress_of(safe, {"ascension_best": 3}, hands) == 3
			and Contracts.state(safe, {"ascension_best": 5}, hands, p) == "ready",
			"the Ascension contracts read the best Ascension beaten")
	_check(Contracts.state(wanted, stats, hands, p) == "ready",
			"a finished one is claimable even before its content is unlocked")
	p.contracts_claimed["first_ride"] = true
	_check(Contracts.state(first, stats, hands, p) == "claimed", "claimed stays claimed")
	var order: Array = []
	for r in Contracts.sorted(stats, hands, p):
		order.append(Contracts.ORDER[r.state])
	var sorted_ok := true
	for i in range(1, order.size()):
		if int(order[i]) < int(order[i - 1]):
			sorted_ok = false
	_check(sorted_ok and int(order[0]) == 0 and int(order[-1]) == 3,
			"the page reads ready, in progress, greyed, then claimed")
	_check(Contracts.lock_text(Contracts.find("sharpshooter"), p) != "",
			"a greyed row says what it waits on")


func _power() -> void:
	var bad: Array = []
	for k in Progression.POWER:
		var parts := String(k).split(":")
		if Progression.row(parts[0], parts[1]).is_empty():
			bad.append(k)
		var n := (Progression.POWER[k].pdesc as Array).size()
		for vk in Progression.POWER[k].vals:
			if (Progression.POWER[k].vals[vk] as Array).size() != n:
				bad.append("%s.%s" % [k, vk])
	_check(bad.is_empty(), "every POWER row is a catalog item with a value per level %s" % str(bad))
	_check(Progression.power_max("relic", "horseshoe") == 2
			and Progression.power_max("mod", "gold") == 1
			and Progression.power_max("relic", "swimming_goggles") == 0,
			"POWER tops out per item (Goggles have none)")
	var p := Progression.new()
	_check(int(p.val("relic", "horseshoe", "hands")) == 1, "POWER 0 is today's Horseshoe")
	_check(p.power_cost("relic", "horseshoe") == 80, "POWER 1 on a starter relic costs $80")
	_check(p.power_cost("relic", "rabbits_foot") == 0, "a relic not bought has no POWER for sale")
	p.raise_power("relic", "horseshoe")
	_check(p.power_cost("relic", "horseshoe") == 160 and int(p.val("relic", "horseshoe", "secs")) == 15,
			"POWER 1 adds the clock seconds, and POWER 2 costs double")
	p.raise_power("relic", "horseshoe")
	p.raise_power("relic", "horseshoe")
	_check(p.power_level("relic", "horseshoe") == 2 and int(p.val("relic", "horseshoe", "hands")) == 2
			and p.power_cost("relic", "horseshoe") == 0, "POWER caps at its top level")
	_check(p.pdesc("relic", "horseshoe").begins_with("+2 hands"), "the description follows the level")
	_check(float(p.val("provision", "dynamite", "keep")) == 0.0
			and float(p.val("relic", "nope", "x", 1.5)) == 1.5, "missing values fall back")


func _check(cond: bool, label: String) -> void:
	if not cond:
		print("FAIL: " + label)
		failures += 1
