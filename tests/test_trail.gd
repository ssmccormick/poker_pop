extends SceneTree

## Integration tests for trail rules that need the whole game running:
## Second Wind's free life, the cash economy (table pay, the bet, selling), and
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

	# --- Tables pay trail cash: more for higher odds and deeper regions ----
	failures += _check(trail._table_pay({"odds": 1.0}, 0) == 3
			and trail._table_pay({"odds": 2.0}, 0) == 6
			and trail._table_pay({"odds": 1.0}, TrailMode.QUEEN_ROOM + 1)
					> trail._table_pay({"odds": 1.0}, TrailMode.JACK_ROOM + 1),
			"a first table pays $3, doubled odds double it, and the regions climb")

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

	# --- The bet and brought cash come out of the bank at the start ------
	trail.cash = 500
	trail.buyin_bring = 30
	trail.buyin_target = "queen"
	trail.buyin_stake = 20
	trail.character = "the_machine"
	trail._start_run(0)
	await _wait(0.3)
	var free_cash: int = TrailMode.BANKROLL_CASH * trail.ride_lv("bankroll")
	failures += _check(trail.cash == 450 and trail.trail_cash == 30 + free_cash
			and trail.cash_brought == 30 and int(trail.bet.stake) == 20
			and is_equal_approx(float(trail.bet.odds), 3.0),
			"saddling up takes the stake and the brought cash out of the bank")
	failures += _check(trail.hud_cash_line().contains("BET: QUEEN"),
			"the HUD shows the bet")
	trail._settle_bet(TrailMode.JACK_ROOM)
	failures += _check(trail.cash == 450 and not bool(trail.bet.paid),
			"a Queen bet doesn't pay at the Jack")
	trail._settle_bet(TrailMode.QUEEN_ROOM)
	failures += _check(trail.cash == 530 and bool(trail.bet.paid),
			"beating the Queen banks the stake plus 3:1 right away")
	trail._settle_bet(TrailMode.QUEEN_ROOM)
	failures += _check(trail.cash == 530, "and it only pays once")
	# Selling a provision pays half its price here.
	trail.provisions = ["canteen"]
	var before: int = trail.trail_cash
	var sale: int = trail.sell_price("canteen")
	trail.sell_provision(0)
	failures += _check(trail.provisions.is_empty() and trail.trail_cash == before + sale
			and sale >= 1 and sale <= trail._price(int(TrailMode.PROVISIONS.canteen.price)),
			"selling a provision frees the slot and pays half its price")
	# Dying loses the trail cash; the bank keeps what the bet paid.
	trail.take_damage(99, "", "Test blow.")
	await _wait(0.3)
	failures += _check(not trail.run_active and trail.cash == 530,
			"a lost ride takes the trail cash with it, and the bank keeps the bet")
	# A bet with nothing staked is no bet; a free ride costs nothing.
	trail.buyin_bring = 0
	trail.buyin_target = ""
	trail.buyin_stake = 0
	trail._start_run(0)
	await _wait(0.3)
	failures += _check(trail.cash == 530 and trail.bet.is_empty() and trail.cash_brought == 0,
			"a free ride takes nothing from the bank")

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

	# --- A fresh profile is asked about the tutorial, once --------------
	main.tutor_seen.erase("core")
	trail._hide_all()
	trail.open_trail()
	await _wait(0.3)
	failures += _check(main.help_open(main._offer_layer) and not trail.select_layer.visible
			and main.mode_kind != "tutorial",
			"THE TRAIL on a fresh profile asks about the tutorial before anything starts")
	failures += _check(main._offer_layer.modulate.a < 0.5, "the question fades in")
	await _wait(2.0)
	failures += _check(is_equal_approx(main._offer_layer.modulate.a, 1.0),
			"over two seconds")
	main._offer_skip_tutorial()
	await _wait(0.6)
	failures += _check(not main.help_open(main._offer_layer) and main.tutor_seen.get("core", false)
			and main.mode_kind != "tutorial"
			and (trail.select_layer.visible or trail.buyin_layer.visible),
			"SKIP IT turns the tutorial off and rides straight on")
	failures += _check(main._offer_layer.visible and main._offer_layer.modulate.a < 1.0,
			"the question fades out rather than vanishing")
	await _wait(1.8)
	failures += _check(not main._offer_layer.visible, "and is gone once its 2-second fade ends")
	trail.open_trail()
	await _wait(0.6)
	failures += _check(not main.help_open(main._offer_layer), "and it never asks again")
	trail._hide_all()

	# --- A hazard dealt in for the first time gets a poster beside it ----
	await _enter_room("the_machine")
	main.tutor_seen.erase("hazard_water")
	var wet: PlayingCard = main.board.grid.values()[7]
	wet.hazard = "water"
	main.board.card_dealt.emit(wet)
	await _wait(0.4)
	failures += _check(main.help_open(main._callout_layer) and wet.tut_order == -1
			and main._callout_title.text == "WATER CARD",
			"a first water card dealt in is explained by a poster beside it")
	failures += _check(main.help_blocking(), "and the table waits while it's up")
	var px: float = main._callout_panel.position.x
	var card_x: float = (main.board.get_global_transform_with_canvas() * main.board.cell_center(wet.grid_pos)).x
	failures += _check(absf(px - card_x) < 420.0 or absf(px + main._callout_panel.size.x - card_x) < 420.0,
			"the poster sits next to the card")
	main._dismiss_callout()
	failures += _check(not main.help_open(main._callout_layer) and wet.tut_order == 0,
			"GOT IT dismisses it and drops the glow")
	main.board.card_dealt.emit(wet)
	await _wait(0.3)
	failures += _check(main._callout_queue.is_empty() and not main.help_open(main._callout_layer),
			"the same hazard is only ever explained once")
	main.table_banner("TABLE CLEARED")
	await _wait(0.8)
	failures += _check(main._plaque.visible and main._plaque.position.y > 0.0
			and main._plaque.position.y < 60.0 and main._plaque_label.text == "TABLE CLEARED",
			"a finished table is announced on a plaque at the top of the screen")
	trail._hide_all()

	# --- Seeds: the same seed deals the same ride -------------------------
	var rec1: Dictionary = await _seeded_probe("K7QX2M9P")
	for n in randi_range(50, 400):
		randf()  # churn the global RNG: gameplay must not care
	main.board.confetti()
	var rec2: Dictionary = await _seeded_probe("K7QX2M9P")
	failures += _check(rec1.wall == rec2.wall and not rec1.wall.is_empty(),
			"the same seed deals the same first wall")
	failures += _check(rec1.deal == rec2.deal and not rec1.deal.is_empty(),
			"and the same opening table")
	failures += _check(rec1.hands == rec2.hands and rec1.hands.size() == 3,
			"and the same refills after the same three hands")
	failures += _check(rec1.score == rec2.score, "for the same score (%d)" % rec1.score)
	failures += _check(rec1.wall2 == rec2.wall2, "and the same second wall")
	failures += _check(rec1.shop == rec2.shop and not rec1.shop.is_empty(),
			"and the same merchant's shelves")
	failures += _check(rec1.abilities == rec2.abilities, "and the same first ability offer")
	var rec3: Dictionary = await _seeded_probe("ABCDEFGH")
	failures += _check(rec3.deal != rec1.deal, "a different seed deals a different table")
	# The other modes deal from seeds too.
	trail._hide_all()
	var time_deals: Array = []
	for n in 2:
		main.next_mode_seed = "QWERTY23"
		await main._start_mode_now("time", 60.0)
		await _settle()
		for k in randi_range(5, 90):
			randf()
		time_deals.append(_grid_sig())
		failures += _check(main.mode_seed == "QWERTY23", "a chosen seed sticks to the mode")
	failures += _check(time_deals[0] == time_deals[1] and not time_deals[0].is_empty(),
			"a Time Trial on the same seed deals the same table")
	await main._start_mode_now("time", 60.0)
	await _settle()
	failures += _check(SeedRng.is_valid(main.mode_seed) and main.mode_seed != "QWERTY23"
			and main.mode_label_text.contains("Seed"), "an unchosen game gets a random seed, on the HUD")
	main.mode_kind = ""
	main.game_started = false
	# The pocket watch: the same hand after a rewind refills the same way.
	await _enter_room("the_doctor")
	var pair_a := _plain_neighbors()
	if not pair_a.is_empty():
		var cells := [pair_a[0].grid_pos, pair_a[1].grid_pos]
		await _play_pair_of(pair_a, true)
		var after1 := _grid_sig()
		trail.use_watch()
		await _settle()
		for n in 37:
			randf()
		await _play_pair_of([main.board.grid[cells[0]], main.board.grid[cells[1]]], true)
		failures += _check(_grid_sig() == after1,
				"the watch rewinds the seed too: the same hand refills the same way")

	# --- Seeded rides: the standard loadout, the seed's board, the daily --
	trail._hide_all()
	var std1: Dictionary = await _seeded_probe("STANDRD2", true)
	failures += _check(trail.standard_loadout and trail.progress.standard,
			"a seeded ride rides on the standard loadout")
	# Max out the profile: a seeded ride mustn't notice.
	var keep_lv := [trail.sleeve_rank, trail.laser_level, trail.meta_bankroll, trail.meta_provisions,
			trail.watch_level, trail.sleight_level]
	var keep_find: Dictionary = trail.progress.find.duplicate()
	var keep_power: Dictionary = trail.progress.power.duplicate()
	trail.sleeve_rank = 12
	trail.laser_level = 3
	trail.meta_bankroll = 5
	trail.meta_provisions = 3
	trail.watch_level = 2
	trail.sleight_level = 2
	for k in ["finish:holo", "finish:negative", "finish:prism", "relic:horseshoe", "mod:bomb"]:
		trail.progress.find[k] = 5
		trail.progress.power[k] = 3
	var std2: Dictionary = await _seeded_probe("STANDRD2", true)
	failures += _check(std1.kit == std2.kit and std1.kit[1] == 2 and std1.kit[2] == 0,
			"the standard loadout ignores the Outfitter (%s vs %s)" % [str(std1.kit), str(std2.kit)])
	failures += _check(std1.wall == std2.wall and std1.deal == std2.deal and std1.shop == std2.shop
			and std1.abilities == std2.abilities and std1.abilities.size() == 3,
			"so a maxed profile and a fresh one get the very same seeded ride")
	var own: Dictionary = await _seeded_probe("STANDRD2", false)
	failures += _check(own.kit != std1.kit and not trail.standard_loadout and not trail.progress.standard,
			"the same seed on your own loadout plays your own gear")
	trail.sleeve_rank = keep_lv[0]
	trail.laser_level = keep_lv[1]
	trail.meta_bankroll = keep_lv[2]
	trail.meta_provisions = keep_lv[3]
	trail.watch_level = keep_lv[4]
	trail.sleight_level = keep_lv[5]
	trail.progress.find = keep_find
	trail.progress.power = keep_power
	failures += _check(trail.seed_line().contains("SEEDED RIDE"),
			"an own-loadout ride's last page offers the seeded replay")
	# A seeded ride's score goes on the seed's board, and banks no cash.
	await _seeded_probe("BARDSK23", true)
	trail.ascension = 0
	main.score = 4321
	var cash_s: int = trail.cash
	var asc_s: int = trail.progress.asc_max("the_gambler")
	var wins_s := int(main.stats.get("trail_wins_the_gambler", 0))
	trail.run_active = true
	trail._trail_complete()
	var bkey := SeedBook.key("trail", "BARDSK23", "the_gambler-a0")
	failures += _check(main.seed_book.best(bkey) == 4321, "a seeded ride's score lands on its board")
	failures += _check(trail.cash == cash_s + int(trail._last_grant.get("purse", 0))
			and trail.progress.asc_max("the_gambler") == asc_s,
			"a seeded ride banks no cash (beyond a level purse) and opens no Ascension")
	failures += _check(int(main.stats.get("trail_wins_the_gambler", 0)) == wins_s,
			"and its win doesn't count toward the next rider")
	failures += _check(not trail.progress.standard, "the ride's end lifts the standard loadout")
	failures += _check(trail.seed_line() == "NEW BEST ON THIS SEED!"
			and trail._ending_data("TRAIL COMPLETE", 0, "").get("seeded", false),
			"the last page calls it a new best on the seed")
	trail._end_run("TRAIL COMPLETE", "Again.", 0)
	failures += _check(int(main.seed_book.boards[bkey].attempts) == 1,
			"ending the same ride twice logs one attempt")
	var book2 := SeedBook.new()
	book2.load_file(main.profile_path("seeds.cfg"))
	failures += _check(book2.best(bkey) == 4321, "the seed book is saved with the profile")
	# The daily: one scored ride a day, practice after that.
	main.seed_book.dailies = {}
	trail._hide_all()
	trail.character = "the_machine"
	trail.next_standard = true
	trail.next_daily = true
	trail._start_run(5)
	await _wait(0.5)
	failures += _check(trail.run_seed == SeedRng.daily_seed() and trail.ascension == 0
			and trail.run_daily and not trail.run_practice,
			"the daily ride is today's seed at Ascension 0, scored")
	failures += _check(main.seed_book.daily_used(SeedRng.daily_seed()), "and spends the day's scored ride")
	trail._hide_all()
	trail.next_standard = true
	trail.next_daily = true
	trail._start_run(0)
	await _wait(0.5)
	main.score = 999999
	trail._end_run("LAID LOW", "Test.", 0, "Test.")
	failures += _check(trail.run_practice and trail.seed_line().begins_with("Practice")
			and main.seed_book.best(SeedBook.key("daily", SeedRng.daily_seed(), "the_machine")) == 0,
			"a second daily ride the same day is practice, off the board")
	trail.character = "the_gambler"
	trail._hide_all()
	# The other modes keep their seed's best, once a game.
	main.next_mode_seed = "MADES234"
	await main._start_mode_now("time", 180.0)
	await _settle()
	main.score = 777
	failures += _check(main._record_mode_score() == "NEW SEED BEST!"
			and main.seed_book.best(SeedBook.key("time", "MADES234", "180")) == 777,
			"a Time Trial's score goes on its seed's board, by length")
	failures += _check(main._record_mode_score() == "", "and only once a game")
	main.mode_kind = ""
	main.game_started = false
	main.open_seeds("trail", "BARDSK23", "the_gambler", 0)
	await _wait(0.5)
	failures += _check(main.seeds_layer.visible and main._seed_best.text.contains("4321")
			and main._seed_recent_box.get_child_count() >= 2,
			"SEEDED PLAY shows the seed's best and the recent seeds")
	main._seed_mode = "time180"
	main._seed_edit.text = "MADES234"
	main._refresh_seeds()
	failures += _check(main._seed_best.text.contains("777") and not main._seed_trail_box.visible,
			"and each mode's own board")
	main._seed_edit.text = "NOPE"
	main._refresh_seeds()
	failures += _check(main._seed_start.disabled, "a broken seed can't be started")
	main._seed_edit.text = "MADES234"
	main._refresh_seeds()
	await process_frame
	var board_kids: Array = main._seed_board_box.get_children().filter(func(c): return not c.is_queued_for_deletion())
	failures += _check(board_kids.size() == 2 and String(board_kids[1].text).to_lower().contains("offline"),
			"with no keys the online board says it's offline")
	main._on_board_fetched(main._shown_board_key, [
			{"player_id": "someone-else", "player_name": "Calamity", "score": 900},
			{"player_id": main.seed_book.ensure_player(), "player_name": "Me", "score": 777}])
	await process_frame
	board_kids = main._seed_board_box.get_children().filter(func(c): return not c.is_queued_for_deletion())
	failures += _check(board_kids.size() == 3, "an online answer lists the top ten under its heading")
	main._on_board_fetched("time|OTHER234|180", [])
	await process_frame
	failures += _check(main._seed_board_box.get_children().filter(
			func(c): return not c.is_queued_for_deletion()).size() == 3,
			"a late answer for another board is ignored")
	main.seeds_layer.visible = false
	await _enter_room("the_gambler")  # an ordinary ride again for what follows

	# --- Ability cards: equipping, effects, the reward, saving -----------
	trail.abilities = ["matched_pair", "scattergun", "big_iron", "spurs", "spurs", "hot_brand",
			"push_broom", "on_the_house", "double_down", "borrowed_time"]
	trail.loadout = {}
	failures += _check(trail.equip(0, "Pair") and trail.used_slots("Pair") == 2,
			"Matched Pair fills a Pair's two slots")
	failures += _check(not trail.equip(1, "Pair") and trail.can_equip(1, "Pair").contains("slots"),
			"a 3-slot ability won't go on a Pair, and says why")
	failures += _check(not trail.equip(3, "Pair") and trail.can_equip(3, "Pair").contains("room"),
			"a full hand takes nothing more")
	failures += _check(trail.equip(2, "Flush") and not trail.equip(2, "Pair"),
			"Big Iron goes on a Flush, and only fits five-card hands")
	failures += _check(trail.equip(3, "Straight") and not trail.equip(4, "Straight")
			and trail.can_equip(4, "Straight").contains("already"),
			"a hand never holds two copies of the same ability")
	failures += _check(trail.equip(3, "Three of a Kind") and trail.hand_of(3) == "Three of a Kind"
			and trail.used_slots("Straight") == 0, "equipping a copy elsewhere moves it")
	failures += _check(main.board.ability_loadout.get("Flush", []) == ["big_iron"],
			"the board sees the loadout as ability ids")
	trail.unequip(0)
	failures += _check(trail.hand_of(0) == "" and not trail.loadout.has("Pair"),
			"taking an ability off frees its slots")
	# What fires when a hand is played.
	trail.room_limit = "hands"
	trail.equip(5, "Pair")       # Hot Brand
	trail.equip(7, "Full House") # On the House
	trail.equip(8, "Two Pair")   # Double Down
	trail.equip(9, "Flush")      # Borrowed Time beside Big Iron? (1 + 5 > 5: refused)
	failures += _check(trail.hand_of(9) == "", "Borrowed Time can't squeeze in beside Big Iron")
	trail.equip(9, "Straight")
	var plus_before := 0
	for d in main.board.deck:
		if String(d.get("mod", "")) == "plus":
			plus_before += 1
	trail._fire_play_abilities({"name": "Pair", "cleared_cells": []})
	var plus_after := 0
	for d in main.board.deck:
		if String(d.get("mod", "")) == "plus":
			plus_after += 1
	failures += _check(plus_after == plus_before + 1, "Hot Brand puts a Plus on the next plain card")
	var hands0: int = trail.room_hands_left
	trail._fire_play_abilities({"name": "Full House", "cleared_cells": []})
	failures += _check(trail.room_hands_left == hands0 + 1, "On the House hands the hand back")
	main.board.next_hand_mult = 1.0
	trail._fire_play_abilities({"name": "Two Pair", "cleared_cells": []})
	failures += _check(main.board.next_hand_mult == 2.0, "Double Down doubles the next hand")
	main.board.next_hand_mult = 1.0
	var hands1: int = trail.room_hands_left
	for n in 4:
		trail._fire_play_abilities({"name": "Straight", "cleared_cells": []})
	failures += _check(trail.room_hands_left == hands1 + 1,
			"Borrowed Time gives a hand back on the fourth play")
	# Push Broom clears a hazard but never a stone.
	trail.unequip(5)
	trail.equip(6, "Pair")
	var hz_cards: Array = []
	for pp in main.board.grid:
		var hc: PlayingCard = main.board.grid[pp]
		if hc.hazard == "" and hc.boss == "" and not hc.is_safe and not hc.cursed:
			hz_cards.append(hc)
		if hz_cards.size() == 2:
			break
	for pp in main.board.grid:
		var other: PlayingCard = main.board.grid[pp]
		if other.hazard != "" and not hz_cards.has(other):
			main.board.provision_clean(other)
			other.hazard = ""
	failures += _check(hz_cards.size() == 2, "the Push Broom test found two cards to use")
	if hz_cards.size() == 2:
		main.board._init_hazard(hz_cards[0], "stone")
		main.board._init_hazard(hz_cards[1], "fire")
		trail._fire_play_abilities({"name": "Pair", "cleared_cells": []})
		failures += _check(hz_cards[0].hazard == "stone" and hz_cards[1].hazard == "",
				"Push Broom puts out the fire and leaves the stone alone")
		main.board.break_stone(hz_cards[0])
	# The board's own snapshot keeps the next-hand multiplier.
	main.board.next_hand_mult = 2.0
	var bsnap: Dictionary = main.board.build_state_snapshot()
	main.board.next_hand_mult = 1.0
	failures += _check(not bsnap.is_empty(), "the board could be photographed")
	if not bsnap.is_empty():
		main.board.undo_state = bsnap
		main.board.restore_state()
		failures += _check(main.board.next_hand_mult == 2.0,
				"a snapshot brings back a pending double (the Tonic or Double Down)")
	main.board.next_hand_mult = 1.0
	# The reward: ability cards, never a card for the deck.
	var keep_all: bool = trail.progress.unlock_all
	trail.progress.unlock_all = true
	var offer3: Array = trail._roll_ability_offer(4, 0, "table")
	failures += _check(offer3.size() == 3, "a cleared table offers three ability cards")
	var boss_offer: Array = trail._roll_ability_offer(9, 0, "boss")
	var boss_ok := true
	for bid in boss_offer:
		if Abilities.rarity(String(bid)) < 2:
			boss_ok = false
	failures += _check(boss_ok and boss_offer.size() == 3, "a boss offers only Epic and Legendary abilities")
	failures += _check(trail._roll_ability_offer(4, 0, "table") == offer3,
			"the same table and round always offer the same cards")
	trail.relics.append("card_sleeve")
	failures += _check(trail._roll_ability_offer(4, 0, "table").size() == 4,
			"Card Sleeve adds a fourth ability to choose from")
	trail.relics.erase("card_sleeve")
	trail.progress.unlock_all = keep_all
	var deck_n: int = trail.deck.size()
	var held: int = trail.abilities.size()
	trail._take_ability("spurs")
	failures += _check(trail.deck.size() == deck_n and trail.abilities.size() == held + 1,
			"taking an ability doesn't touch the deck")
	# The collection, the loadout and a pending offer ride in the save.
	trail.pending_reward = {"room": 4, "source": "table", "round": 0, "offers": ["lookout", "spurs", "cool_head"],
			"chest_rounds": 1, "relic": "", "ledger": []}
	var lo_before: Dictionary = trail.loadout.duplicate(true)
	var ab_before: Array = trail.abilities.duplicate()
	trail._save_run()
	trail.abilities = []
	trail.loadout = {}
	trail.pending_reward = {}
	trail._load_run()
	failures += _check(trail.abilities == ab_before and trail.loadout == lo_before
			and trail.pending_reward.get("offers", []) == ["lookout", "spurs", "cool_head"],
			"abilities, the loadout and an unfinished reward come back from the save")
	trail.pending_reward = {}
	trail.abilities = []
	trail.loadout = {}
	trail._push_loadout()

	# --- Twists at the table: wild ranks, hand rules, hazard top-ups ----
	main.board.wild_rank = 5
	var fives: Array = []
	for pp in main.board.grid:
		if main.board.grid[pp].rank == 5:
			fives.append(main.board.grid[pp])
	if not fives.is_empty():
		main.board.selected.assign([fives[0]])
		failures += _check(main.board.get_selected_data()[0].get("wild", false),
				"with Wild 5s, a 5 plays as wild")
		main.board.selected.clear()
	main.board.wild_rank = 0
	main.board.play_only = PackedStringArray(["Pair", "Flush"])
	failures += _check(main.board.hand_allowed("Pair") and not main.board.hand_allowed("Straight"),
			"House Rules lets only the listed hands play")
	main.board.play_only = PackedStringArray()
	main.board.score_only = PackedStringArray(["Flush"])
	var picky := {"name": "Pair", "score": 100}
	main.board.selected.clear()
	main.board._apply_card_mods(picky)
	failures += _check(int(picky.score) == 0 and picky.get("unscored", false),
			"a Picky Crowd lets an off-list hand play for no score")
	main.board.score_only = PackedStringArray()
	var keep_offer: Dictionary = trail.current_offer
	trail.current_offer = {"kind": "play", "twists": [{"id": "hz_bomb"}]}
	for pp in main.board.grid:
		if main.board.grid[pp].hazard == "bomb":
			main.board.provision_clean(main.board.grid[pp])
	main.board._pending_refill_hazards.clear()
	trail._hazard_twist_upkeep()
	failures += _check(main.board._pending_refill_hazards.has("bomb"),
			"Lit Fuses tops the bombs back up with the next deal")
	main.board._pending_refill_hazards.clear()
	trail.current_offer = keep_offer

	# --- Stones cover cards: a hand next to one breaks it off ------------
	var spair := _plain_neighbors()
	var rock: PlayingCard = null
	if not spair.is_empty():
		for d in Board.HAZARD_DIRS:
			var q: Vector2i = spair[0].grid_pos + d
			var n: PlayingCard = main.board.grid.get(q)
			if n != null and n != spair[1] and n.hazard == "" and n.mod == "" \
					and not n.cursed and n.boss == "" and not n.is_safe:
				rock = n
				break
	failures += _check(rock != null, "the stone test found a card beside a playable pair")
	if rock != null:
		main.board.gold_find_chance = 1.0
		main.board._init_hazard(rock, "stone")
		rock.stone_hits = 1
		var rock_rank := rock.rank
		await _play_pair_of(spair, true)
		await _settle()
		failures += _check(is_instance_valid(rock) and main.board.grid.values().has(rock)
				and rock.hazard == "" and rock.rank == rock_rank,
				"a stone chipped to nothing breaks off, and its card stays on the table")
		failures += _check(is_instance_valid(rock) and rock.mod == "gold",
				"the card under a gold-veined stone comes out GOLD")
	# Dynamite blasts the stone off rather than the card.
	var blast: PlayingCard = null
	for p in main.board.grid:
		var bc: PlayingCard = main.board.grid[p]
		if bc.hazard == "" and bc.boss == "" and not bc.is_safe and not bc.cursed:
			blast = bc
			break
	failures += _check(blast != null, "the dynamite test found a card to bury")
	if blast != null:
		main.board._init_hazard(blast, "stone")
		await trail._apply_target_provision("dynamite", blast)
		await _settle()
		failures += _check(is_instance_valid(blast) and main.board.grid.values().has(blast)
				and blast.hazard == "", "dynamite on a stone blasts the stone off and leaves the card")
	main.board.gold_find_chance = Board.GOLD_FIND_CHANCE

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
	trail.next_seed = "HANDS234"  # a fixed plain table, so the check never rides on luck
	await _enter_room_at("the_doctor", 0)
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
	trail.tables_played = []
	var goals := {}
	var only_peddler := true
	var clocks := 0
	var twists_ok := true
	var twist_kinds := {}
	var max_twists := 0
	for i in 400:
		var o: Dictionary = trail._make_one_offer(true)
		goals[String(o.get("goal", ""))] = true
		if String(o.get("limit", "")) == "time":
			clocks += 1
			if not TableMods.has_twist(o, "clock"):
				twists_ok = false  # a clock table shows its clock as a twist
		if trail._random_merchant_index() != 0:
			only_peddler = false
		# One objective, and twists that belong on it.
		if not o.has("objective") or not o.has("twists"):
			twists_ok = false
		var rolled := 0
		var seen := {}
		for tw in o.get("twists", []):
			var tid := String(tw.id)
			if seen.has(tid) or not TableMods.TWISTS.has(tid):
				twists_ok = false
			seen[tid] = true
			twist_kinds[tid] = true
			if tid in TableMods.ROLLABLE:
				rolled += 1
			if tid == "play_only" and not (tw.hands as Array).has("Pair"):
				twists_ok = false  # House Rules always lets a Pair play
			if tid == "wild" and (int(tw.rank) < 2 or int(tw.rank) > 14):
				twists_ok = false
			if (tid == "hz_stone" and o.get("goal", "") == "mine") \
					or (tid.begins_with("hz_") and o.get("goal", "") == "purge"
					and tid.substr(3) == String(o.get("purge_kind", ""))):
				twists_ok = false
		max_twists = maxi(max_twists, rolled)
		if o.get("goal", "") == "crazy8":
			twists_ok = false  # Crazy 8s is a twist now
	failures += _check(twists_ok and max_twists <= TableMods.MAX_TWISTS and max_twists >= 1,
			"every table has one objective and twists that fit it (up to %d)" % max_twists)
	failures += _check(twist_kinds.has("wild") and twist_kinds.has("hz_fire")
			and twist_kinds.has("play_only") and twist_kinds.has("score_only"),
			"wild ranks, hazards and hand rules all turn up (%s)" % str(twist_kinds.keys()))
	trail.room_index = 0
	var first_twists := 0
	for i in 30:
		for tw in trail._make_one_offer(true).get("twists", []):
			if String(tw.id) in TableMods.ROLLABLE:
				first_twists += 1
	failures += _check(first_twists == 0, "the first table never has twists")
	trail.room_index = 5
	# Old saved tables move onto twists.
	var old8: Dictionary = trail._migrate_offer({"kind": "play", "goal": "crazy8", "target": 900,
			"limit": "hands", "tarot": "CRAZY 8s", "odds": 1.5, "hands": 10})
	failures += _check(String(old8.goal) == "" and TableMods.wild_rank(old8) == 8
			and TrailMode.table_type(old8) == "plain", "an old Crazy 8s table becomes a plain table with wild 8s")
	var old_noon: Dictionary = trail._migrate_offer({"kind": "play", "goal": "timed", "target": 900,
			"limit": "hands", "odds": 1.0, "hands": 10, "minutes": 3})
	failures += _check(String(old_noon.goal) == "" and old_noon.limit == "time"
			and TableMods.has_twist(old_noon, "clock"), "an old HIGH NOON table keeps its clock")
	failures += _check(TableMods.twist_name({"id": "wild", "rank": 5}) == "Wild 5s"
			and TableMods.twist_desc({"id": "play_only", "hands": ["Pair", "Straight"]})
			== "You can only play Pairs and Straights at this table.",
			"twists read in plain words")
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

	# --- The road: 30 stops, merchants and campfires fixed between tables
	failures += _check(TrailMode.ROOMS_TOTAL == 30 and TrailMode.BOSS_ROOMS.keys() == [9, 19, 29],
			"30 stops, a boss closing each 10-stop region")
	var kinds: Array = []
	for i in TrailMode.ROOMS_TOTAL:
		kinds.append(TrailMode.stop_kind(i))
	failures += _check(kinds.count("table") + kinds.count("boss") == 21
			and kinds.count("shop") == 6 and kinds.count("camp") == 3,
			"21 tables, 6 merchants and 3 campfires")
	failures += _check(TrailMode.table_depth(9) == 6 and TrailMode.table_depth(19) == 13
			and TrailMode.table_depth(29) == 20 and TrailMode.table_depth(2) == 2
			and TrailMode.table_depth(3) == 2, "difficulty climbs per table, not per stop")
	failures += _check(TrailMode.next_table(2) == 3 and TrailMode.next_table(8) == 9,
			"a stop knows the next table")
	failures += _check(TrailMode.migrate_room(6) == 9 and TrailMode.migrate_room(7) == 10
			and TrailMode.migrate_room(20) == 29, "old 21-stop rides re-seat at the same table")
	var walls_clean := true
	for n in 50:
		for o in trail._make_offers():
			if o.get("kind", "") != "play":
				walls_clean = false
		if trail._make_one_offer(true).get("kind", "") != "play":
			walls_clean = false
	failures += _check(walls_clean, "the wall and the Fool only ever deal tables")
	await _enter_room("the_machine")
	trail.in_room = false
	trail.trail_cash = 5000  # flush enough to buy anything on the probe
	trail.room_index = 2
	trail._show_tarot_now()
	failures += _check(trail.shop_layer.visible and not trail.tarot_layer.visible
			and trail.trail_log[2] == "shop", "stop 3 goes straight to the merchant")
	trail._hide_all()
	trail.room_index = 5
	trail._show_tarot_now()
	failures += _check(trail.camp_layer.visible and not trail.tarot_layer.visible,
			"stop 6 goes straight to the campfire")
	trail._hide_all()

	# --- Table rotation: no repeats until every type has been played -----
	trail.room_index = 3
	trail.tables_played = []
	var all_distinct := true
	for n in 100:
		var wall: Array = trail._wall_types(trail._make_offers())
		var seen := {}
		for t in wall:
			if seen.has(t):
				all_distinct = false
			seen[t] = true
	failures += _check(all_distinct, "a wall never deals the same table type twice")
	var types: Array = TrailMode.ROOM_TABLE.keys()
	trail.tables_played = types.filter(func(t): return not t in ["safe", "mine"])
	var only_left := true
	var sizes := {}
	for n in 100:
		var wall: Array = trail._wall_types(trail._make_offers())
		sizes[wall.size()] = true
		for t in wall:
			if not t in ["safe", "mine"]:
				only_left = false
	failures += _check(only_left and sizes.keys().all(func(k): return int(k) <= 2 and int(k) >= 1),
			"with two types unplayed, the wall deals just those two (fewer cards)")
	trail.tables_played = types.filter(func(t): return t != "safe")
	var lone: Array = trail._wall_types(trail._make_offers())
	failures += _check(lone == ["safe"], "with one type left, the wall deals only it (%s)" % str(lone))
	trail._save_run()
	trail.tables_played = []
	trail._load_run()
	failures += _check(trail.tables_played.size() == types.size() - 1,
			"the rotation is saved with the ride")
	trail._mark_table_played({"kind": "play", "goal": "safe"})
	failures += _check(trail.tables_played.is_empty(),
			"playing the last unplayed type starts the rotation over")
	trail._mark_table_played({"kind": "play", "tarot": "EASY MONEY"})
	failures += _check(trail.tables_played == ["plain"], "plain tables count in the rotation too")
	trail.tables_played = []

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
	# The same seed both times, so both rides sit at the same table.
	trail.next_seed = "HANDS234"
	await _enter_room_at("the_gambler", 0)
	var base_hands: int = trail.room_hands_left
	var base_hp: int = trail.hp
	trail.next_seed = "HANDS234"
	await _enter_room_at("the_gambler", 18)
	failures += _check(trail.ascension == 18 and trail.hp == 8 and trail.max_hp() == 8 and base_hp == 10,
			"Ascension 18 starts the rider at 8 HP")
	failures += _check(trail.room_limit == "time" or trail.room_hands_left == base_hands - 2,
			"Ascension 18 deals two fewer hands at the same table (%d vs %d)" % [trail.room_hands_left, base_hands])
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


## One seeded ride's fingerprint: the first wall, the opening table,
## three hands of refills, the second wall and the first merchant.
func _seeded_probe(seed_text: String, standard := false) -> Dictionary:
	var rec := {}
	trail._hide_all()
	trail.character = "the_gambler"
	trail.gambler_ability = "sleeve"
	trail.next_seed = seed_text
	trail.next_standard = standard
	trail._start_run(0)
	await _wait(0.5)
	rec["kit"] = [trail.trail_cash, trail.sleeve_card.rank, trail.provisions.size(),
			trail.ride_lv("laser")]
	rec["abilities"] = trail._roll_ability_offer(0, 0, "table")
	rec["wall"] = _wall_sig(trail._offers) + [_offer_sig(trail._fate_offer)]
	trail._choose_offer(trail._offers[0], false)
	await _wait(0.5)
	trail._confirm_bet()
	await _wait(0.5)
	await _settle()
	rec["deal"] = _grid_sig()
	rec["kit"].append(trail.watch_uses_left)
	var hands: Array = []
	for h in 3:
		for n in randi_range(1, 40):
			randf()
		var pair := _plain_neighbors()
		if pair.is_empty():
			break
		await _play_pair_of(pair, true)
		hands.append(_grid_sig())
	rec["hands"] = hands
	rec["score"] = main.score
	# The next stops, by the seed alone.
	trail.in_room = false
	main.board.locked = true
	trail.trail_cash = 5000
	trail.room_index = 1
	trail._offers_room = -1
	trail._show_tarot_now()
	rec["wall2"] = _wall_sig(trail._offers)
	trail._hide_all()
	trail.room_index = 2
	trail._offers_room = -1
	trail._shop_stock_room = -1
	trail._show_tarot_now()
	var shop: Array = []
	for o in trail._shop_stock:
		shop.append([o.data.rank, o.data.suit, o.data.get("mod", "")])
	for o in trail._shop_stock_relics:
		shop.append(o.id)
	for o in trail._shop_stock_provisions:
		shop.append(o.id)
	for o in trail._shop_stock_abilities:
		shop.append(o.id)
	rec["shop"] = shop
	trail._hide_all()
	return rec


func _grid_sig() -> Array:
	var out: Array = []
	for y in 5:
		for x in 5:
			var c: PlayingCard = main.board.grid.get(Vector2i(x, y))
			out.append([c.rank, c.suit, c.hazard, c.mod, c.finish] if c != null else [])
	return out


func _offer_sig(o: Dictionary) -> Array:
	return [String(o.get("kind", "")), String(o.get("tarot", "")), String(o.get("goal", "")),
			int(o.get("target", 0)), String(o.get("limit", "")), int(o.get("merchant", -1))]


func _wall_sig(offers: Array) -> Array:
	var out: Array = []
	for o in offers:
		out.append(_offer_sig(o))
	return out


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
