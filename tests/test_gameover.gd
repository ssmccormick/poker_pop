extends SceneTree

## Headless tests for the trail's last page: every ending builds, a
## click lands the intro on its final frame (map lit to the end table,
## tallies drawn, buttons up), the buttons speak, and the small text
## helpers hold.
## Run: godot --headless --path . --script res://tests/test_gameover.gd


class FakeHost:
	extends Node
	var board = null

	func _button(parent: Control, text: String, pos: Vector2, btn_size: Vector2,
			_primary := false) -> Button:
		var b := Button.new()
		b.text = text
		b.position = pos
		b.size = btn_size
		parent.add_child(b)
		return b


var _rode := 0
var _menued := 0
var _ran := false


## Runs on the first frame, once the root is inside the tree (focus
## and accept_event need it).
func _process(_delta: float) -> bool:
	if not _ran:
		_ran = true
		_run()
	return false


func _run() -> void:
	var failures := 0
	var host := FakeHost.new()
	root.add_child(host)

	# --- text helpers --------------------------------------------------------
	failures += _check(TrailMode._title_case("BLACK JACK MCGREW") == "Black Jack McGrew",
			"outlaw names read in title case, Mc kept")
	failures += _check(GameOverScene._commas(41300) == "41,300"
			and GameOverScene._commas(999) == "999"
			and GameOverScene._commas(1000000) == "1,000,000",
			"ledger numbers take thousands commas")

	var stops := ["table", "table", "outlaw", "camp", "table", "shop", "boss",
			"table", "outlaw", "table"]
	for kind in ["laid_low", "busted_out", "blinded_out", "trail_complete"]:
		var complete: bool = kind == "trail_complete"
		var reached := 21 if complete else 10
		var scene := GameOverScene.new()
		scene.host = host
		root.add_child(scene)
		scene.ride_again.connect(func() -> void: _rode += 1)
		scene.to_menu.connect(func() -> void: _menued += 1)
		var shown := scene.show_ending({
			"kind": kind, "title": "TITLE", "epitaph": "Epitaph.", "cause": "A cause.",
			"rider": "the_doctor", "score": 41300, "best_name": "Full House",
			"best_score": 840, "outlaws": 7, "reached": reached, "total": 21,
			"cash": 88, "stake": "Penny Ante", "relics": ["horseshoe", "rabbits_foot"],
			"stops": stops, "bosses": TrailMode.BOSS_ROOMS, "region_size": 7,
			"camp_slot": 3})
		failures += _check(shown, "%s: the painted page builds" % kind)
		if not shown:
			scene.free()
			continue
		var btn: Button = scene._buttons[0]
		failures += _check(btn.modulate.a < 0.01, "%s: buttons wait for the intro" % kind)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		scene._gui_input(click)
		failures += _check(is_equal_approx(scene._it, scene._intro_end),
				"%s: a click jumps to the last frame" % kind)
		failures += _check(btn.modulate.a > 0.99, "%s: buttons are up after the skip" % kind)
		var lit := 0
		for n in scene._nodes:
			if bool(n.on):
				lit += 1
		failures += _check(lit == reached, "%s: map lights exactly %d stops (got %d)"
				% [kind, reached, lit])
		var outlaw_node: Dictionary = scene._nodes[2]
		failures += _check(String(outlaw_node.lit.resource_path).ends_with("marker_outlaw.png"),
				"%s: the outlaw stop wears the outlaw marker" % kind)
		var gate: TextureRect = scene._tally_groups[0]
		var tail: TextureRect = scene._tally_groups[1]
		failures += _check(scene._tally_groups.size() == 2
				and String(gate.texture.resource_path).ends_with("tally_5.png")
				and String(tail.texture.resource_path).ends_with("tally_2.png"),
				"%s: seven outlaws = one slashed gate and two marks" % kind)
		failures += _check((scene._flag == null) == complete
				and (scene._star != null) == complete,
				"%s: flag for a fall, star for the finish" % kind)
		scene._buttons[1].pressed.emit()
		scene._buttons[0].pressed.emit()
		scene.free()
	failures += _check(_rode == 4 and _menued == 4,
			"RIDE AGAIN and BACK TO MENU each answer once per page")

	# --- A ride that climbs levels: the EXP bar fills, the banner lands --
	var lv_scene := GameOverScene.new()
	lv_scene.host = host
	root.add_child(lv_scene)
	var e0 := Progression.exp_at_level(10) - 60
	var gain := 513
	var lv_shown := lv_scene.show_ending({
		"kind": "laid_low", "title": "LAID LOW", "epitaph": "Epitaph.", "cause": "",
		"rider": "the_gambler", "score": 41300, "best_name": "Full House",
		"best_score": 840, "outlaws": 3, "reached": 10, "total": 21,
		"cash": 88, "stake": "Penny Ante", "relics": [], "stops": stops,
		"bosses": TrailMode.BOSS_ROOMS, "region_size": 7, "camp_slot": 3,
		"exp_gain": gain, "exp_rows": [["SCORE", 413], ["TABLES REACHED", 100]],
		"exp_before": e0, "exp_after": e0 + gain,
		"level_before": Progression.level_for_exp(e0),
		"level_after": Progression.level_for_exp(e0 + gain),
		"unlocks": Progression.unlocks_between(9, 11), "purse": 105,
		"contracts": ["Road Worn"]})
	failures += _check(lv_shown and lv_scene._exp_box != null and lv_scene._banner != null,
			"a level-up page builds its EXP bar and banner")
	if lv_shown:
		failures += _check(lv_scene._banner.modulate.a < 0.01
				and lv_scene._exp_gain.text == "+0 EXP", "both wait for the map to light")
		var click2 := InputEventMouseButton.new()
		click2.button_index = MOUSE_BUTTON_LEFT
		click2.pressed = true
		lv_scene._gui_input(click2)
		var lv_end := Progression.level_for_exp(e0 + gain)
		failures += _check(lv_scene._exp_level.text == "LEVEL %d" % lv_end
				and lv_scene._exp_gain.text == "+513 EXP",
				"skipped to the end, the bar shows the new level and the EXP earned")
		var into := e0 + gain - Progression.exp_at_level(lv_end)
		failures += _check(is_equal_approx(lv_scene._exp_fill.size.x,
				lv_scene._exp_track_w * float(into) / Progression.exp_to_next(lv_end)),
				"the bar ends where the EXP leaves it")
		failures += _check(lv_scene._banner.modulate.a > 0.99
				and lv_scene._contracts_l != null and lv_scene._contracts_l.modulate.a > 0.99,
				"the level-up banner and the contracts line are up")
	lv_scene.free()
	host.free()

	if failures == 0:
		print("ALL GAMEOVER TESTS PASSED")
	else:
		print("%d GAMEOVER TEST(S) FAILED" % failures)
	quit(failures)


func _check(cond: bool, label: String) -> int:
	if not cond:
		print("FAIL: " + label)
		return 1
	return 0
