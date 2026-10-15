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
	failures += _check(res.score == 100 and not res.has("cash_earned"),
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

	# Cash cards pay trail cash without touching the score.
	b.selected.assign([cards[3], cards[4]])
	res = {"score": 60}
	b._apply_card_mods(res)
	failures += _check(res.score == 60 and res.cash_earned == Board.CHIP_BONUS * 2,
			"two Cash cards pay $1 each, score unchanged")

	# Mixed hand: both effects apply.
	b.selected.assign([cards[1], cards[3]])
	res = {"score": 100}
	b._apply_card_mods(res)
	failures += _check(res.score == 150 and res.cash_earned == Board.CHIP_BONUS,
			"mult and Cash in one hand both apply")
	cards[3].chip_level = 2
	b.selected.assign([cards[3]])
	res = {"score": 60}
	b._apply_card_mods(res)
	failures += _check(res.cash_earned == 3, "a Cash card that has scored twice pays $3")
	cards[3].chip_level = 0

	# Gold cards pay trail cash: $3 apiece.
	var cash1 := PlayingCard.new()
	cash1.mod = "gold"
	var cash2 := PlayingCard.new()
	cash2.mod = "gold"
	b.selected.assign([cash1, cash2])
	res = {"score": 40}
	b._apply_card_mods(res)
	failures += _check(res.score == 40 and res.cash_earned == 6,
			"two gold cards earn $6, score unchanged")

	# HOLO: a flat +50 before the multipliers, which then multiply it.
	var holo := PlayingCard.new()
	holo.finish = "holo"
	b.selected.assign([cards[0], holo])
	res = {"score": 100}
	b._apply_card_mods(res)
	failures += _check(res.score == 150 and res.holo_bonus == 50,
			"a Holo card adds a flat +50 to the hand")
	b.selected.assign([holo, cards[1]])
	res = {"score": 100}
	b._apply_card_mods(res)
	failures += _check(res.score == 225, "a Mult card multiplies the Holo bump too: (100 + 50) × 1.5")
	# NEGATIVE: flagged for the trail to hand the hand back.
	var neg := PlayingCard.new()
	neg.finish = "negative"
	b.selected.assign([neg, cards[0]])
	res = {"score": 100}
	b._apply_card_mods(res)
	failures += _check(res.score == 100 and res.negatives == 1,
			"a Negative card leaves the score alone and is counted")
	holo.free()
	neg.free()

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

	# Bosses ride the shove — off the edge like anyone else (the caller
	# turns that into a lost life); the Cobra stays anchored.
	b = Board.new()
	var bossc := PlayingCard.new()
	bossc.boss = "jack"
	bossc.boss_hp = 3
	bossc.grid_pos = Vector2i(4, 0)
	b.grid[Vector2i(4, 0)] = bossc
	var bmoves: Array = b._apply_bump(Vector2i(3, 0), Vector2i.RIGHT)
	failures += _check(bmoves.size() == 1 and bmoves[0].off,
			"a jack boss is shoved off the edge by a bumper")
	bossc.free()
	var cobra := PlayingCard.new()
	cobra.boss = "cobra"
	cobra.grid_pos = Vector2i(4, 0)
	b.grid[Vector2i(4, 0)] = cobra
	bmoves = b._apply_bump(Vector2i(3, 0), Vector2i.RIGHT)
	failures += _check(bmoves.is_empty() and b.grid.has(Vector2i(4, 0)),
			"the cobra is anchored — his coils block the push")
	cobra.free()
	b.free()

	# --- THE JOKER: one step above the Ace, wild for good, x2 ----------
	b = Board.new()
	var ace := PlayingCard.new()
	ace.rank = 14
	failures += _check(b.boost_card(ace, "plus") == "joker"
			and ace.joker and ace.rank == 14 and ace.mod == "wild",
			"a Plus on an Ace lifts it into a wild Joker")
	failures += _check(ace.rank_text() == "JKR", "the Joker reads JKR")
	failures += _check(b.boost_card(ace, "plus") == "none" and ace.joker,
			"nothing ranks above the Joker")
	var other := PlayingCard.new()
	other.rank = 9
	b.selected.assign([ace, other])
	res = {"score": 100}
	b._apply_card_mods(res)
	failures += _check(res.score == 200, "the Joker doubles the hand")
	var mult := PlayingCard.new()
	mult.mod = "mult"
	b.selected.assign([ace, mult])
	res = {"score": 100}
	b._apply_card_mods(res)
	failures += _check(res.score == 300, "Joker x2 stacks with a mult's x1.5")
	failures += _check(b.get_selected_data()[0].get("wild", false),
			"the Joker plays wild")
	b.selected.clear()
	b.grid[Vector2i(0, 0)] = ace
	b._tick_fire_and_bombs()
	failures += _check(ace.joker and ace.mod == "wild",
			"the Joker holds wild through the hand tick")
	b.grid.clear()
	failures += _check(b.boost_card(ace, "minus") == "lowered"
			and not ace.joker and ace.mod == "" and ace.rank == 14,
			"a Minus knocks the Joker down to a plain Ace")
	ace.joker = true
	ace.rank = 7
	failures += _check(not ace.joker, "leaving the Ace's rank drops the Joker")
	var deuce := PlayingCard.new()
	deuce.rank = 2
	failures += _check(b.boost_card(deuce, "minus") == "destroy",
			"a Minus on a 2 still destroys it")
	for c in [ace, other, mult, deuce]:
		c.free()
	b.free()

	# --- Finishes: the Prism, and saves from the Explosive days -------
	failures += _check(PlayingCard.finish_of({"finish": "prism"}) == "prism"
			and PlayingCard.finish_of({"boom": true}) == "prism"
			and PlayingCard.finish_of({"mod": "chipsplode"}) == "prism"
			and PlayingCard.finish_of({"mod": "chip"}) == ""
			and PlayingCard.finish_of({"finish": "nonsense"}) == "",
			"old Explosive saves load as Prism; unknown finishes drop")
	var shiny := PlayingCard.new()
	shiny.finish = "foil?"
	failures += _check(shiny.finish == "", "a card refuses an unknown finish")
	shiny.finish = "prism"
	failures += _check(shiny.finish == "prism" and shiny.is_processing(),
			"a Prism card keeps animating its shimmer")
	shiny.free()

	# --- METAL wears through on its fifth scoring play -----------------
	var steel := PlayingCard.new()
	steel.finish = "metal"
	var stays := 0
	for i in PlayingCard.METAL_PLAYS:
		if i == PlayingCard.METAL_PINS:
			failures += _check(not steel.metal_covered() and not steel.hazard_proof(),
					"after the last pin the cover is off and hazards can reach it")
		elif i < PlayingCard.METAL_PINS:
			failures += _check(steel.metal_covered() and steel.hazard_proof(),
					"pinned steel keeps its cover and its immunity")
		if steel.wear_metal():
			stays += 1
	failures += _check(stays == PlayingCard.METAL_PLAYS - 1
			and steel.metal_plays_left() == 0,
			"metal stays for four plays and clears on the fifth")
	steel.free()

	# --- Ability cards on a poker hand ------------------------------------
	var ab := Board.new()
	var plain_cards: Array = []
	for r in [14, 14, 8, 8]:
		var pc := PlayingCard.new()
		pc.rank = r
		plain_cards.append(pc)
	var mult_card := PlayingCard.new()
	mult_card.mod = "mult"
	mult_card.rank = 9
	ab.selected.assign([plain_cards[0], mult_card])
	ab.ability_loadout = {"Pair": ["spurs"]}
	res = {"name": "Pair", "score": 100}
	ab._apply_card_mods(res)
	failures += _check(res.score == int((100 + 20) * Board.MULT_FACTOR) and res.abilities == ["Spurs"],
			"Spurs adds 20 before the Mult card multiplies (%d)" % res.score)
	ab.ability_loadout = {"Flush": ["big_iron"]}
	res = {"name": "Pair", "score": 100}
	ab._apply_card_mods(res)
	failures += _check(not res.has("abilities"), "an ability only fires on the hand it's equipped to")
	ab.selected.assign(plain_cards)
	ab.ability_loadout = {"Two Pair": ["dead_mans_hand", "side_bet"]}
	res = {"name": "Two Pair", "score": 100}
	ab._apply_card_mods(res)
	failures += _check(res.score == 400 and res.cash_earned == 1,
			"Dead Man's Hand gives ×4 on Aces and Eights, and Side Bet pays $1")
	plain_cards[3].rank = 9
	plain_cards[2].rank = 9
	res = {"name": "Two Pair", "score": 100}
	ab._apply_card_mods(res)
	failures += _check(res.score == 150, "and ×1.5 on any other Two Pair")
	failures += _check(Abilities.fits("big_iron", "Flush") and not Abilities.fits("big_iron", "Pair")
			and Abilities.misfit_reason("big_iron", "Pair").contains("five-card"),
			"Big Iron fits a Flush but not a Pair, and says why")
	failures += _check(not Abilities.fits("scattergun", "Pair") and Abilities.fits("scattergun", "Three of a Kind"),
			"a 3-slot ability won't fit a 2-slot Pair")
	failures += _check(Abilities.smallest_fit("matched_pair") == "Pair"
			and Abilities.smallest_fit("house_money") == "Full House", "the smallest hand an ability fits")
	# The next plain card off the shoe takes the enhancement.
	ab.deck = [{"rank": 5, "suit": 0}, {"rank": 6, "suit": 1, "cursed": true},
			{"rank": 7, "suit": 2, "mod": "chip"}]
	failures += _check(ab.enhance_next_draw("plus") and ab.deck[0].get("mod", "") == "plus"
			and ab.deck[2].mod == "chip" and not ab.deck[1].has("mod"),
			"Hot Brand skips cursed and enhanced cards and marks the next plain one")
	ab.deck = []
	failures += _check(ab.enhance_next_draw("mult") and not ab.deck.is_empty(),
			"an empty shoe is refilled before the enhancement lands")
	# --- The sides: posse counts and the ride-aware abilities ----------------
	var pc3 := Abilities.posse_counts(["keep_the_peace", "no_name", "side_bet", "spurs"])
	failures += _check(int(pc3.sheriff) == 2 and int(pc3.outlaw) == 2 and int(pc3.bounty) == 1
			and int(pc3.sides) == 3, "No Name rides with every side; drifters with none")
	var ctx := {"posse": {"sheriff": 3, "outlaw": 0, "bounty": 0, "sides": 1}}
	ab.ability_ctx = func() -> Dictionary: return ctx
	ab.selected.assign([plain_cards[0], plain_cards[1]])
	ab.ability_loadout = {"Pair": ["keep_the_peace"]}
	res = {"name": "Pair", "score": 100}
	ab._apply_card_mods(res)
	failures += _check(res.score == 145, "Keep the Peace adds 15 for each of three Sheriffs (%d)" % res.score)
	ab.ability_loadout = {"Pair": ["keep_the_peace", "keep_the_peace"]}
	res = {"name": "Pair", "score": 100}
	ab._apply_card_mods(res)
	failures += _check(res.score == 190, "two copies on one hand both fire (%d)" % res.score)
	ab.ability_loadout = {"Pair": ["law_and_order", "powder_keg"]}
	res = {"name": "Pair", "score": 100}
	ab._apply_card_mods(res)
	failures += _check(res.score == 150, "a table without hazards: Law and Order ×1.5, Powder Keg nothing")
	var fire := PlayingCard.new()
	fire.hazard = "fire"
	ab.grid[Vector2i(4, 4)] = fire
	res = {"name": "Pair", "score": 100}
	ab._apply_card_mods(res)
	failures += _check(res.score == 125, "one hazard: Powder Keg +25, Law and Order nothing")
	ab.grid.erase(Vector2i(4, 4))
	fire.free()
	ctx.clear()
	ctx.merge({"trail_cash": 3, "posse": {}})
	ab.ability_loadout = {"Pair": ["desperado", "desperado"]}
	res = {"name": "Pair", "score": 100}
	ab._apply_card_mods(res)
	failures += _check(res.score == 300 and int(res.cash_spent) == 2,
			"with $3 on you, only one Desperado can pay his $2 (%d)" % res.score)
	ctx.clear()
	ctx.merge({"posse": {"sides": 3}, "hand_plays": {"Pair": 4}, "last_hand": true})
	ab.ability_loadout = {"Pair": ["notches", "high_noon"]}
	res = {"name": "Pair", "score": 100}
	ab._apply_card_mods(res)
	failures += _check(res.score == 240, "Notches +5 for four plays, then High Noon doubles the last hand")
	ab.ability_loadout = {"Flush": ["good_bad_ugly"]}
	res = {"name": "Flush", "score": 100}
	ab._apply_card_mods(res)
	failures += _check(res.score == 250, "the Good, the Bad and the Ugly: ×2.5 with all three sides")
	ab.next_hand_flat = 100
	ab.ability_loadout = {}
	res = {"name": "Pair", "score": 50}
	ab._apply_card_mods(res)
	failures += _check(res.score == 150 and int(res.next_flat) == 100, "Huckleberry's promise lands on the next hand")
	ab.next_hand_flat = 0
	var cashc := PlayingCard.new()
	cashc.mod = "chip"
	ab.selected.assign([plain_cards[0], cashc])
	ab.ability_loadout = {"Pair": ["fistful_of_dollars"]}
	res = {"name": "Pair", "score": 50}
	ab._apply_card_mods(res)
	failures += _check(int(res.cash_earned) == Board.CHIP_BONUS + 2,
			"A Fistful of Dollars: $1, plus $1 for the Cash card in the hand")
	cashc.free()
	# --- Levels: combined copies grow -------------------------------------
	ab.ability_ctx = Callable()
	ab.selected.assign([plain_cards[0], plain_cards[1]])
	ab.ability_loadout = {"Pair": ["spurs@2"]}
	res = {"name": "Pair", "score": 100}
	ab._apply_card_mods(res)
	failures += _check(res.score == 140, "Spurs II adds 40 (%d)" % res.score)
	ab.ability_loadout = {"Pair": ["matched_pair@3"]}
	res = {"name": "Pair", "score": 100}
	ab._apply_card_mods(res)
	failures += _check(res.score == 250, "Matched Pair III scores 2.5 times as much (%d)" % res.score)
	failures += _check(Abilities.rarity("spurs@2") == 1 and Abilities.rarity("spurs@3") == 2
			and Abilities.rarity("house_money@2") == 3, "each level lifts the rarity, up to Legendary")
	failures += _check(is_equal_approx(float(Abilities.fx("lookout@3").refill_hazard_mult), 0.125)
			and int(Abilities.fx("borrowed_time@3").hand_every) == 2
			and int(Abilities.fx("posse_up@3").posse_hands) == 1
			and int(Abilities.fx("hot_brand@2").enhance_n) == 2,
			"steps and counts scale the right way")
	failures += _check(Abilities.combined("spurs") == "spurs@2" and Abilities.combined("spurs@2") == "spurs@3"
			and Abilities.combined("spurs@3") == "" and Abilities.display_name("spurs@3") == "Spurs III",
			"two copies make the next level, up to III")
	failures += _check(int(Abilities.posse_counts(["keep_the_peace@2", "keep_the_peace"]).sheriff) == 3,
			"a level II copy counts twice in its posse")
	failures += _check(Abilities.describe("spurs") == String(Abilities.DEFS.spurs.desc).format({"flat": "20"})
			and Abilities.describe("rain_barrel@2").contains("up to four fires")
			and Abilities.describe("matched_pair@2") == "Your Pairs score double.",
			"descriptions carry each level's own numbers")
	ab.selected.clear()
	for pc in plain_cards:
		pc.free()
	mult_card.free()
	ab.free()
	# Every ability definition is sound.
	for id in Abilities.DEFS:
		var d: Dictionary = Abilities.DEFS[id]
		var fits_one := false
		for hand in Abilities.HAND_ORDER:
			if Abilities.fits(id, hand):
				fits_one = true
		var desc := String(d.desc)
		failures += _check(String(d.get("side", "")) in ["sheriff", "outlaw", "bounty", "drifter", "any"],
				"ability %s rides with a side" % id)
		failures += _check(fits_one and int(d.slots) >= 1 and int(d.slots) <= 5
				and desc.ends_with(".") and desc.length() > 20 and not desc.contains(" — ")
				and int(d.rarity) >= 0 and int(d.rarity) <= 3,
				"ability %s is well formed" % id)
		for h in d.hands:
			failures += _check(Abilities.HAND_SLOTS.has(h), "ability %s names a real hand (%s)" % [id, h])
		for lv in range(1, Abilities.MAX_LEVEL + 1):
			var text := Abilities.describe(Abilities.key_at(String(id), lv))
			failures += _check(not text.contains("{") and not text.contains("}") and text.ends_with("."),
					"ability %s reads cleanly at level %d: %s" % [id, lv, text])

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
