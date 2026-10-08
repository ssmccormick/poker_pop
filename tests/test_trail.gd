extends SceneTree

## Integration tests for trail rules that need the whole game running:
## Second Wind's free life (HP and chips), Tin Star's scaling pay, and
## the Gambler's Sleight of Hand. Boots the real main scene, then moves
## to a throwaway profile so no real save is touched.
## Run: godot --headless --path . --script res://tests/test_trail.gd

const TEST_PROFILE := 97

var main: Node
var trail: Node
var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	# Boot straight onto the throwaway profile so the real one is never
	# loaded (or saved) by the test.
	OS.set_environment("POKERPOP_PROFILE", str(TEST_PROFILE))
	_cleanup()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	main.profile = TEST_PROFILE
	trail = main.trail
	# A clean slate on the throwaway profile: no stats, level 1.
	_cleanup()
	main._stats_load()
	trail._load_meta()
	# No first-time popups over the tables under test.
	for k in main.TUTOR:
		main.tutor_seen[k] = true
	main.tutor_seen["core"] = true
	main._dismiss_splash()
	failures += _check(trail.progress.level() == 1 and not trail.progress.grandfathered,
			"a fresh profile starts at level 1")
	# Most checks ride every rider and trick; the gates get their own
	# section at the end.
	trail.progress.unlock_all = true

	# --- Tin Star pays a blind that climbs with the trail ---------------
	failures += _check(trail._blind_for(0) == 25 and trail._blind_for(7) > 25 * 6,
			"Tin Star's blind starts at 25 and grows past the Jack")

	# --- Second Wind: a lethal blow leaves the rider standing once -------
	await _enter_room("the_machine")
	trail.relics.append("second_wind")
	trail.hp = 3
	var alive: bool = trail.take_damage(5, "", "Test blow.")
	failures += _check(alive and trail.hp == 5 and trail.run_active and trail.in_room,
			"Second Wind turns a killing blow into 5 HP, mid-table")
	failures += _check(trail._second_wind_used and not trail.second_wind_ready(),
			"the free life is spent after one use")
	alive = trail.take_damage(99, "", "Test blow.")
	failures += _check(not alive and not trail.run_active,
			"with the wind spent, the next killing blow ends the ride")

	# --- Second Wind: short on chips buys the seat once -----------------
	await _enter_room("the_machine")
	trail.relics.append("second_wind")
	trail.in_room = false
	trail.chips = 7
	var ended: bool = trail._short_stacked(120)
	failures += _check(not ended and trail.chips == 120 and trail.run_active,
			"Second Wind covers the seat when the stack falls short")
	failures += _check(trail.hp >= 5, "and leaves the rider at least 5 HP")
	trail.chips = 0
	ended = trail._short_stacked(120)
	failures += _check(ended and not trail.run_active,
			"spent, a short stack busts out as before")

	# --- The Gambler's choice is remembered -----------------------------
	trail._pick_gambler_ability("sleight")
	failures += _check(trail.gambler_ability == "sleight"
			and trail.character == "the_gambler",
			"picking SLEIGHT saddles the Gambler with it")
	trail.gambler_ability = "sleeve"
	trail._load_meta()
	failures += _check(trail.gambler_ability == "sleight",
			"the pick survives a reload of the profile")

	# --- Sleight of Hand swaps two neighbors, once per table ------------
	await _enter_room("the_gambler", "sleight")
	main._update_kit()
	failures += _check(main._sleeve_btn.text == "SLEIGHT OF HAND"
			and not main._sleeve_btn.disabled, "the kit offers SLEIGHT OF HAND")
	var pair := _plain_neighbors()
	if pair.is_empty():
		failures += _check(false, "found two plain neighboring cards to swap")
	else:
		var a: PlayingCard = pair[0]
		var b: PlayingCard = pair[1]
		var a_pos: Vector2i = a.grid_pos
		var b_pos: Vector2i = b.grid_pos
		trail.use_signature()
		failures += _check(trail._aiming_sleight
				and main.board.pending_provision == "sleight",
				"pressing the ability arms the trick")
		trail._on_provision_target(a)
		failures += _check(trail._aiming_sleight and trail.sleight_uses_left == 1,
				"the first pick waits for its neighbor")
		await trail._on_provision_target(b)
		await _settle()
		failures += _check(trail.sleight_uses_left == 0 and not trail._aiming_sleight,
				"the second pick plays the trick")
		failures += _check(main.board.grid.get(a_pos) == b and main.board.grid.get(b_pos) == a,
				"the two cards traded places")
		main._update_kit()
		failures += _check(main._sleeve_btn.disabled
				and main._sleeve_btn.text == "SLEIGHT — PLAYED",
				"the kit button shows the trick as played")
		trail.use_signature()
		failures += _check(not trail._aiming_sleight, "a second trick at the same table is refused")
	trail.gambler_ability = "sleeve"
	trail._save_run()
	trail.gambler_ability = "sleight"
	trail._load_run()
	failures += _check(trail.gambler_ability == "sleeve",
			"the run save carries the Gambler's trick")

	# --- An upgraded Sleight of Hand palms two tricks per table ----------
	trail.sleight_level = 1
	await _enter_room("the_gambler", "sleight")
	failures += _check(trail.sleight_uses_left == 2,
			"one Outfitter level gives two tricks per table")
	var pair3 := _plain_neighbors()
	if not pair3.is_empty():
		trail.use_signature()
		trail._on_provision_target(pair3[0])
		await trail._on_provision_target(pair3[1])
		await _settle()
		trail.use_signature()
		failures += _check(trail.sleight_uses_left == 1 and trail._aiming_sleight,
				"after one trick the second is still ready to arm")
		trail.use_signature()  # pocket it again
	trail.sleight_level = 0

	# --- NEGATIVE gives the hand (or the seconds) back --------------------
	await _enter_room("the_machine")
	trail.room_limit = "hands"
	var neg_pair := _plain_neighbors()
	if neg_pair.is_empty():
		failures += _check(false, "found two plain neighbors for the Negative test")
	else:
		var hands_before: int = trail.room_hands_left
		(neg_pair[0] as PlayingCard).finish = "negative"
		await _play_pair_of(neg_pair)
		failures += _check(trail.room_hands_left == hands_before or not trail.in_room,
				"a hand with a Negative card costs no hand (%d -> %d)"
				% [hands_before, trail.room_hands_left])
	await _enter_room("the_machine")
	trail.room_limit = "time"
	trail.room_time_left = 100.0
	var clock_pair := _plain_neighbors()
	if not clock_pair.is_empty():
		(clock_pair[0] as PlayingCard).finish = "negative"
		await _play_pair_of(clock_pair)
		# (the clock keeps ticking through the play, so allow it a few)
		failures += _check(trail.room_time_left >= 104.0 or not trail.in_room,
				"on a clock table it adds 10 seconds (%.1f)" % trail.room_time_left)
	trail.room_limit = "hands"

	# --- METAL scores but stays on the table -----------------------------
	await _enter_room("the_machine")
	var pair2 := _plain_neighbors()
	if pair2.is_empty():
		failures += _check(false, "found two plain neighbors for the metal test")
	else:
		var steel: PlayingCard = pair2[0]
		var mate: PlayingCard = pair2[1]
		mate.rank = steel.rank
		mate.mod = ""
		steel.mod = ""
		steel.finish = "metal"
		var steel_pos: Vector2i = steel.grid_pos
		var mate_pos: Vector2i = mate.grid_pos
		var score_before: int = main.score
		main.board.selected.assign([steel, mate])
		steel.selected = true
		mate.selected = true
		main.board._update_hand_validity()
		await main.board.play_hand()
		await _settle()
		failures += _check(main.score > score_before, "the pair with a metal card scored")
		failures += _check(main.board.grid.get(steel_pos) == steel and is_instance_valid(steel),
				"the metal card stays in its cell after scoring")
		failures += _check(main.board.grid.get(mate_pos) != mate,
				"its plain partner cleared as usual")
		failures += _check(steel.metal_wear == 1 and steel.metal_plays_left() == 4,
				"one play spends one of its five")

	# --- A Prism finish rides through the run save ---------------------
	trail.deck[0]["mod"] = "chip"
	trail.deck[0]["finish"] = "prism"
	trail.deck[1]["finish"] = ""
	trail._save_run()
	trail.deck[0]["finish"] = ""
	trail._load_run()
	failures += _check(String(trail.deck[0].get("finish", "")) == "prism"
			and String(trail.deck[1].get("finish", "")) == "",
			"a Prism deck card keeps its finish across a save")

	# --- With a ride saved, THE TRAIL puts RESUME first ------------------
	trail._save_run()
	main.tutor_seen["core"] = true
	trail._hide_all()
	trail.open_trail()
	await _wait(0.5)
	var resume: Button = trail._buyin_resume_btn
	var first_tier: Button = trail._buyin_saddle_btn
	failures += _check(trail.buyin_layer.visible and not trail.select_layer.visible,
			"THE TRAIL skips rider select when a ride is saved")
	failures += _check(resume.visible and resume.position.y < first_tier.position.y,
			"RESUME YOUR RIDE is the first choice")

	# --- A busy card's tooltip stays a few short lines -------------------
	var busy_card := PlayingCard.new()
	busy_card.rank = 9
	busy_card.suit = 1
	busy_card.mod = "plus"
	busy_card.finish = "prism"
	busy_card.hazard = "fire"
	busy_card.honey = true
	busy_card.objective = "hisbullet"
	var tip: String = main._card_tooltip_text(busy_card)
	print("TOOLTIP SAMPLE:\n" + tip)
	var tip_lines := tip.split("\n")
	var longest := 0
	for ln in tip_lines:
		longest = maxi(longest, ln.length())
	failures += _check(tip_lines.size() <= 6 and longest <= 50,
			"a busy card's tooltip is a few short lines (longest %d)" % longest)
	busy_card.free()

	# --- The ride's score rides in the save -----------------------------
	await _enter_room("the_machine")
	main.score = 4321
	trail._save_run()
	main.score = 0
	trail._load_run()
	failures += _check(main.score == 4321, "the run score survives a save and resume")

	# --- The pocket watch turns the run score back too ------------------
	await _enter_room("the_doctor")
	var before_hand: int = main.score
	if await _play_pair():
		failures += _check(main.score > before_hand, "the Doctor's pair scored")
		trail.use_watch()
		failures += _check(main.score == before_hand,
				"the watch winds the run score back with the hand")
	else:
		failures += _check(false, "found a pair for the watch test")

	# --- A ride is paid its EXP exactly once ----------------------------
	await _enter_room("the_machine")
	main.score = 50000
	var exp0: int = trail.progress.exp_total
	var cash0: int = trail.cash
	trail._end_run("LAID LOW", "Test.", 0, "Test.")
	var gained: int = trail.progress.exp_total - exp0
	failures += _check(gained > 500 and int(trail._last_grant.exp_gain) == gained,
			"the ride's end pays its EXP (%d)" % gained)
	failures += _check(trail.progress.level() > 1 and trail.cash > cash0,
			"the climb pays the level purse")
	trail._end_run("LAID LOW", "Test.", 0, "Test.")
	failures += _check(trail.progress.exp_total == exp0 + gained,
			"ending the same ride twice pays once")
	failures += _check(trail._ending_data("LAID LOW", 0, "").has("exp_gain"),
			"the last page hears about the EXP")
	var reloaded := Progression.new()
	var mcf := ConfigFile.new()
	mcf.load(main.profile_path("trail_meta.cfg"))
	reloaded.read(mcf, {})
	failures += _check(reloaded.exp_total == trail.progress.exp_total,
			"the EXP is saved with the profile")

	# --- A ride ridden over is still paid --------------------------------
	await _enter_room("the_machine")
	trail.room_index = 3
	main.score = 9000
	trail._save_run()
	var exp1: int = trail.progress.exp_total
	trail._start_run(0)
	await _wait(0.5)
	failures += _check(trail.progress.exp_total > exp1,
			"starting over a saved ride credits the one left behind")
	var exp2: int = trail.progress.exp_total
	trail._start_run(0)
	await _wait(0.5)
	failures += _check(trail.progress.exp_total == exp2,
			"re-saddling a fresh ride earns nothing")

	# --- The gates: a fresh level-1 rider ---------------------------------
	trail._hide_all()
	trail.progress.unlock_all = false
	trail.progress.read(ConfigFile.new(), {})
	trail.character = "the_gambler"
	trail.gambler_ability = "sleeve"
	trail._pick_character("the_machine")
	failures += _check(trail.character == "the_gambler",
			"without a Gambler win the Machine can't be saddled")
	trail._pick_gambler_ability("sleight")
	failures += _check(trail.gambler_ability == "sleeve",
			"nor can the Gambler pull Sleight of Hand")
	trail.cash = 2000
	var uid_before: String = trail.run_uid
	trail._start_run(1)
	failures += _check(trail.run_uid == uid_before and trail.ascension_open() == 0,
			"Ascension 1 stays shut until the trail is beaten")
	trail.laser_level = 0
	trail._buy_upgrade("laser")
	failures += _check(trail.laser_level == 0 and trail.cash == 2000,
			"the Laser's upgrades wait on the Machine")
	trail.room_index = 5
	var goals := {}
	var only_peddler := true
	var clocks := 0
	for i in 400:
		var o: Dictionary = trail._make_one_offer(true)
		if o.kind == "shop":
			if int(o.merchant) != 0:
				only_peddler = false
		else:
			goals[String(o.get("goal", ""))] = true
			if String(o.get("limit", "")) == "time":
				clocks += 1
	failures += _check(goals.size() >= 8 and clocks > 0,
			"a level-1 rider meets every kind of table (%d kinds, %d on the clock)" % [goals.size(), clocks])
	failures += _check(only_peddler, "merchants are still unlocked one by one: only the Peddler at level 1")
	var starters := ["horseshoe", "card_sleeve", "snake_oil", "tin_star", "bomb_badge", "chisel"]
	trail.relics.clear()
	var shelf: Array = trail._relic_shelf(10)
	failures += _check(shelf.size() == starters.size()
			and shelf.all(func(id): return starters.has(id)),
			"a merchant shelf holds only relics on the trail")
	var kit: Array = trail._provision_shelf(9)
	failures += _check(kit.size() == 4 and not kit.has("tonic"),
			"and only provisions on the trail")
	var mods_ok := true
	for i in 300:
		if not trail._random_mod() in ["mult", "chip", "gold"]:
			mods_ok = false
	failures += _check(mods_ok, "only Mult, Chip and Gold cards are dealt at level 1")

	# --- Level up, then buy ------------------------------------------------
	trail.progress.exp_total = Progression.exp_at_level(3)
	failures += _check(not trail._avail("relic", "rabbits_foot"),
			"reaching level 3 unlocks the Rabbit's Foot but doesn't hand it over")
	trail._buy_catalog("relic", "rabbits_foot")
	failures += _check(trail.cash == 1940 and trail._avail("relic", "rabbits_foot"),
			"buying it costs $60 and puts it on the trail")
	trail._buy_catalog("relic", "rabbits_foot")
	failures += _check(trail.cash == 1940, "it can't be bought twice")
	trail._buy_find("relic", "horseshoe")
	failures += _check(trail.progress.find_level("relic", "horseshoe") == 1 and trail.cash == 1900,
			"FIND on a starter relic costs $40")
	trail._load_meta()
	failures += _check(trail.progress.owns("relic", "rabbits_foot")
			and trail.progress.find_level("relic", "horseshoe") == 1 and trail.cash == 1900,
			"purchases are saved with the profile")

	# --- Riders are won ----------------------------------------------------
	trail.cash = 1900
	main.stats["trail_wins_the_gambler"] = 1
	failures += _check(trail._avail("rider", "the_machine") and not trail._avail("rider", "the_doctor"),
			"a full ride won as the Gambler frees the Machine — and only him")
	trail._pick_character("the_machine")
	failures += _check(trail.character == "the_machine" and trail.cash == 1900,
			"he saddles up free")
	trail.character = "the_gambler"
	main.stats.erase("trail_wins_the_gambler")
	trail._up_tab = "riders"
	trail._refresh_upgrades()
	failures += _check(trail._up_list.get_child_count() == 5,
			"the RIDERS shelf lists three riders and both tricks")
	trail._up_tab = "gear"

	# --- POWER upgrades reach the table ---------------------------------
	trail.cash = 5000
	trail._buy_power("mod", "mult")
	trail._buy_power("mod", "mult")
	failures += _check(trail.progress.power_level("mod", "mult") == 2 and trail.cash == 5000 - 80 - 160,
			"Mult's two POWER levels cost $80 then $160")
	trail._buy_power("relic", "horseshoe")
	trail._buy_power("relic", "horseshoe")
	trail._buy_power("provision", "pocket_flask")
	trail._load_meta()
	trail.progress.unlock_all = true
	await _enter_room("the_gambler")
	failures += _check(is_equal_approx(main.board.mult_factor, 1.75),
			"a POWER 2 Mult card multiplies ×1.75 (%.2f)" % main.board.mult_factor)
	trail.relics.append("horseshoe")
	trail.relics.append("mirror_shades")
	trail._apply_relic_effects()
	failures += _check(is_equal_approx(main.board.mult_factor, 2.25),
			"Mirror Shades still add their +0.5 on top")
	var hands_before: int = trail.room_hands_left
	trail.room_limit = "hands"
	trail._apply_instant_provision("pocket_flask")
	failures += _check(trail.room_hands_left == hands_before + 3,
			"a POWER 1 Pocket Flask pours three hands")
	trail.progress.unlock_all = false

	# --- Ascension: the ladder, per rider ---------------------------------
	trail.progress.unlock_all = false
	trail.character = "the_gambler"
	trail.progress.ascension_max = {}
	await _enter_room("the_gambler")
	trail.room_index = TrailMode.ROOMS_TOTAL
	trail._trail_complete()
	failures += _check(trail.progress.asc_max("the_gambler") == 1
			and trail.progress.asc_max("the_machine") == 0,
			"beating the trail at Ascension 0 opens Ascension 1 for that rider only")
	failures += _check(int(main.stats.get("trail_wins_the_gambler", 0)) >= 1,
			"the win is counted for the Gambler")
	trail._hide_all()
	trail.progress.open_ascension("the_gambler", 18)
	trail.character = "the_gambler"
	var uid0: String = trail.run_uid
	trail._start_run(19)
	failures += _check(trail.run_uid == uid0, "the buy-in refuses an Ascension above the rider's highest")
	await _enter_room_at("the_gambler", 0)
	var base_hands: int = trail.room_hands_left
	var base_hp: int = trail.hp
	await _enter_room_at("the_gambler", 18)
	failures += _check(trail.ascension == 18 and trail.hp == 8 and trail.max_hp() == 8 and base_hp == 10,
			"Ascension 18 starts the rider at 8 HP")
	failures += _check(trail.room_limit == "time" or trail.room_hands_left <= base_hands,
			"higher Ascensions deal fewer hands")
	var cursed: Array = trail.deck.filter(func(d): return bool(d.get("cursed", false)))
	failures += _check(cursed.size() >= 1, "Ascension 16+ rides with a cursed card")
	failures += _check(trail._target_for(3, TrailMode.RISKS[0]) > int((TrailMode.BASE_TARGET + TrailMode.TARGET_STEP * 3) * 0.85),
			"higher Ascensions ask for more score")
	trail.progress.ascension_max = {}

	# --- Contracts: done, claimed once, remembered ------------------------
	var cash_c: int = trail.cash
	main.stats["tables_cleared"] = 10
	var talk := Contracts.find("table_talk")
	failures += _check(Contracts.state(talk, main.stats, main.stats_hands, trail.progress) == "ready",
			"clearing 10 tables makes Table Talk claimable")
	failures += _check(trail.claim_contract("table_talk") == 40 and trail.cash == cash_c + 40,
			"CLAIM pays the reward")
	failures += _check(trail.claim_contract("table_talk") == 0 and trail.cash == cash_c + 40,
			"a second claim is refused")
	failures += _check(trail.claim_contract("road_worn") == 0, "an unfinished one can't be claimed")
	trail._load_meta()
	failures += _check(trail.progress.contracts_claimed.has("table_talk") and trail.cash == cash_c + 40,
			"the claim survives a save and load")
	failures += _check(Contracts.state(Contracts.find("card_counter"), main.stats,
			main.stats_hands, trail.progress) != "locked",
			"Card Counter is open from the start, like every table")
	failures += _check(Contracts.state(Contracts.find("time_keeper"), main.stats,
			main.stats_hands, trail.progress) == "locked",
			"Time Keeper is greyed until the Doctor is won")
	main._refresh_contracts()
	await process_frame
	failures += _check(main._contracts_list.get_child_count() == Contracts.LIST.size(),
			"the CONTRACTS page lists every contract")
	trail.progress.contracts_seen.erase("road_worn")
	main.stats["tables_cleared"] = 100
	trail._ride_contracts = []
	trail._check_contracts(false)
	failures += _check(trail._ride_contracts.has("Road Worn")
			and trail.progress.contracts_seen.has("road_worn"),
			"a contract finished on the ride is noted once")
	trail._check_contracts(false)
	failures += _check(trail._ride_contracts.count("Road Worn") == 1, "and only once")

	_cleanup()
	OS.unset_environment("POKERPOP_PROFILE")
	if failures == 0:
		print("ALL TRAIL TESTS PASSED")
	else:
		print("%d TRAIL TEST(S) FAILED" % failures)
	quit(failures)


## A fresh run seated at its first play table, board dealt and idle.
func _enter_room(rider: String, trick := "sleeve") -> void:
	trail.character = rider
	trail.gambler_ability = trick
	trail.cash = maxi(trail.cash, 0)
	trail._start_run(0)
	# Screen swaps ride a short fade; let each land before the next.
	await _wait(0.5)
	for offer in trail._offers:
		if offer.kind == "play":
			trail._choose_offer(offer, false)
			break
	await _wait(0.5)
	trail._confirm_bet()
	await _wait(0.5)
	await _settle()


## Like _enter_room, at a chosen Ascension, on a plain hand table.
func _enter_room_at(rider: String, asc: int) -> void:
	trail.character = rider
	trail.gambler_ability = "sleeve"
	trail._start_run(asc)
	await _wait(0.5)
	var pick: Dictionary = {}
	for offer in trail._offers:
		if offer.kind != "play":
			continue
		if pick.is_empty() or (String(offer.get("goal", "")) == ""
				and String(offer.get("limit", "")) == "hands"):
			pick = offer
	if not pick.is_empty():
		trail._choose_offer(pick, false)
	await _wait(0.5)
	trail._confirm_bet()
	await _wait(0.5)
	await _settle()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


## Waits (in real time — headless frames run unthrottled) for the deal
## countdown and any animation to finish.
func _settle() -> void:
	var waited := 0.0
	while (main.board.busy or main.board.locked) and waited < 8.0:
		await create_timer(0.1).timeout
		waited += 0.1
	await process_frame


## Plays a pair of two plain neighbors; false if none could be made.
func _play_pair() -> bool:
	var pair := _plain_neighbors()
	if pair.is_empty():
		return false
	await _play_pair_of(pair, true)
	return true


## Makes the two cards a pair (keeping a finish only if `wipe` is off)
## and plays them.
func _play_pair_of(pair: Array, wipe := false) -> void:
	var a: PlayingCard = pair[0]
	var b: PlayingCard = pair[1]
	b.rank = a.rank
	a.mod = ""
	b.mod = ""
	b.finish = ""
	if wipe:
		a.finish = ""
	main.board.selected.assign([a, b])
	a.selected = true
	b.selected = true
	main.board._update_hand_validity()
	await main.board.play_hand()
	await _settle()


## Two side-by-side cards Sleight of Hand may shuffle.
func _plain_neighbors() -> Array:
	var g: Dictionary = main.board.grid
	for p in g:
		var c: PlayingCard = g[p]
		var n: Vector2i = p + Vector2i.RIGHT
		if not g.has(n):
			continue
		var d: PlayingCard = g[n]
		if trail._provision_refusal("shell_game", c) == "" \
				and trail._provision_refusal("shell_game", d) == "":
			return [c, d]
	return []


func _cleanup() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	for f in dir.get_files():
		if f.begins_with("p%d_" % TEST_PROFILE):
			dir.remove(f)


func _check(cond: bool, label: String) -> int:
	if not cond:
		print("FAIL: " + label)
		return 1
	return 0
