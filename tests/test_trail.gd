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
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	main.profile = TEST_PROFILE
	trail = main.trail
	main._dismiss_splash()

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
		failures += _check(trail._aiming_sleight and not trail.sleight_used,
				"the first pick waits for its neighbor")
		await trail._on_provision_target(b)
		await _settle()
		failures += _check(trail.sleight_used and not trail._aiming_sleight,
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
	trail.sleight_used = false
	trail._save_run()
	trail.gambler_ability = "sleight"
	trail._load_run()
	failures += _check(trail.gambler_ability == "sleeve",
			"the run save carries the Gambler's trick")

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

	_cleanup()
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
