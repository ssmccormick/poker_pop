class_name Contracts
extends RefCounted

## CONTRACTS: achievement-style goals that pay a cash reward, claimed on
## the CONTRACTS page off the main menu. Progress is read live from the
## profile's lifetime stats ("hand:<name>" reads the poker-hand tally);
## only CLAIMED and SEEN (completion announced) are stored, in the
## [progress] section via Progression. A contract that needs content the
## rider hasn't unlocked yet is greyed out until they have it.

## {id, name, desc, stat, target, reward, requires: [kind, id] or []}
const LIST := [
	{"id": "first_ride", "name": "First Ride", "desc": "Finish a ride on the trail, any way it ends.", "stat": "rides_ended", "target": 1, "reward": 25, "requires": []},
	{"id": "table_talk", "name": "Table Talk", "desc": "Clear 10 tables.", "stat": "tables_cleared", "target": 10, "reward": 40, "requires": []},
	{"id": "road_worn", "name": "Road Worn", "desc": "Clear 100 tables.", "stat": "tables_cleared", "target": 100, "reward": 200, "requires": []},
	{"id": "jack_be_nimble", "name": "Jack Be Nimble", "desc": "Beat the Jack of All Trades.", "stat": "beat_jack", "target": 1, "reward": 75, "requires": []},
	{"id": "hive_mind", "name": "Hive Mind", "desc": "Beat the Queen Bee.", "stat": "beat_queen", "target": 1, "reward": 125, "requires": []},
	{"id": "snake_charmer", "name": "Snake Charmer", "desc": "Beat King Cobra.", "stat": "beat_cobra", "target": 1, "reward": 200, "requires": []},
	{"id": "end_of_the_line", "name": "End of the Line", "desc": "Complete the trail.", "stat": "trail_wins", "target": 1, "reward": 250, "requires": []},
	{"id": "big_stakes", "name": "Big Stakes", "desc": "Complete the trail at Table Stakes.", "stat": "trail_wins_tier1", "target": 1, "reward": 400, "requires": ["stake", "1"]},
	{"id": "high_roller", "name": "High Roller", "desc": "Complete the trail at High Roller.", "stat": "trail_wins_tier2", "target": 1, "reward": 750, "requires": ["stake", "2"]},
	{"id": "big_hand", "name": "Big Hand", "desc": "Score 2,000 or more with a single hand.", "stat": "best_hand", "target": 2000, "reward": 100, "requires": []},
	{"id": "score_keeper", "name": "Score Keeper", "desc": "Score 50,000 in a single ride.", "stat": "trail_score_best", "target": 50000, "reward": 150, "requires": []},
	{"id": "royal_treatment", "name": "Royal Treatment", "desc": "Play a Royal Flush.", "stat": "hand:Royal Flush", "target": 1, "reward": 150, "requires": []},
	{"id": "flushed_five", "name": "Flushed Five", "desc": "Play a Flushed Five: five of a kind, all one suit.", "stat": "hand:Flushed Five", "target": 1, "reward": 300, "requires": []},
	{"id": "safecracker", "name": "Safecracker", "desc": "Crack 5 Bank Jobs.", "stat": "cleared_safe", "target": 5, "reward": 80, "requires": ["room", "safe"]},
	{"id": "wanted", "name": "Wanted", "desc": "Win 5 bounties.", "stat": "duels_won", "target": 5, "reward": 100, "requires": ["room", "outlaw"]},
	{"id": "dealers_choice", "name": "Dealer's Choice", "desc": "Clear 5 Dealer's Calls.", "stat": "cleared_hands", "target": 5, "reward": 100, "requires": ["room", "hands"]},
	{"id": "stage_robber", "name": "Stage Robber", "desc": "Clear 3 Stagecoach Hauls.", "stat": "cleared_chest", "target": 3, "reward": 120, "requires": ["room", "chest"]},
	{"id": "prospector", "name": "Prospector", "desc": "Clear a Gold Mine.", "stat": "cleared_mine", "target": 1, "reward": 80, "requires": ["room", "mine"]},
	{"id": "exterminator", "name": "Exterminator", "desc": "Clear 5 purge jobs.", "stat": "cleared_purge", "target": 5, "reward": 100, "requires": ["room", "purge"]},
	{"id": "land_baron", "name": "Land Baron", "desc": "Clear a Land Rush.", "stat": "cleared_landrush", "target": 1, "reward": 80, "requires": ["room", "landrush"]},
	{"id": "crazy_eights", "name": "Crazy Eights", "desc": "Clear a Crazy 8s table.", "stat": "cleared_crazy8", "target": 1, "reward": 80, "requires": ["room", "crazy8"]},
	{"id": "card_counter", "name": "Card Counter", "desc": "Win 10 blackjack rounds.", "stat": "blackjack_rounds", "target": 10, "reward": 120, "requires": ["room", "blackjack"]},
	{"id": "river_rat", "name": "River Rat", "desc": "Clear a Texas Hold'em table.", "stat": "cleared_holdem", "target": 1, "reward": 100, "requires": ["room", "holdem"]},
	{"id": "up_the_sleeve", "name": "Up the Sleeve", "desc": "Swap 25 cards up the sleeve.", "stat": "sleeve_swaps", "target": 25, "reward": 60, "requires": []},
	{"id": "sleight_master", "name": "Sleight Master", "desc": "Pull 25 sleights of hand.", "stat": "sleights", "target": 25, "reward": 80, "requires": ["trick", "sleight"]},
	{"id": "sharpshooter", "name": "Sharpshooter", "desc": "Fire the Laser 25 times.", "stat": "laser_shots", "target": 25, "reward": 80, "requires": ["rider", "the_machine"]},
	{"id": "time_keeper", "name": "Time Keeper", "desc": "Turn back 25 hands with the pocket watch.", "stat": "hands_unwound", "target": 25, "reward": 80, "requires": ["rider", "the_doctor"]},
	{"id": "gamblers_luck", "name": "Gambler's Luck", "desc": "Complete the trail as the Gambler.", "stat": "trail_wins_the_gambler", "target": 1, "reward": 200, "requires": []},
	{"id": "machine_learning", "name": "Machine Learning", "desc": "Complete the trail as the Machine.", "stat": "trail_wins_the_machine", "target": 1, "reward": 300, "requires": ["rider", "the_machine"]},
	{"id": "doctors_orders", "name": "Doctor's Orders", "desc": "Complete the trail as the Doctor.", "stat": "trail_wins_the_doctor", "target": 1, "reward": 300, "requires": ["rider", "the_doctor"]},
	{"id": "campfire_stories", "name": "Campfire Stories", "desc": "Rest at 10 campfires.", "stat": "campfire_rests", "target": 10, "reward": 50, "requires": []},
	{"id": "well_supplied", "name": "Well Supplied", "desc": "Use 25 provisions.", "stat": "provisions_used", "target": 25, "reward": 60, "requires": []},
	{"id": "curator", "name": "Curator", "desc": "Find 10 relics.", "stat": "relics_found", "target": 10, "reward": 80, "requires": []},
]

const ORDER := {"ready": 0, "open": 1, "locked": 2, "claimed": 3}


static func find(id: String) -> Dictionary:
	for c in LIST:
		if String(c.id) == id:
			return c
	return {}


## How far along a contract is (capped at its target).
static func progress_of(c: Dictionary, stats: Dictionary, hands: Dictionary) -> int:
	var stat := String(c.stat)
	var v := int(hands.get(stat.substr(5), 0)) if stat.begins_with("hand:") \
			else int(stats.get(stat, 0))
	return mini(v, int(c.target))


static func is_complete(c: Dictionary, stats: Dictionary, hands: Dictionary) -> bool:
	return progress_of(c, stats, hands) >= int(c.target)


## "ready" (done, unclaimed) · "open" (in progress) · "locked" (needs
## content not on the trail yet) · "claimed".
static func state(c: Dictionary, stats: Dictionary, hands: Dictionary,
		prog: Progression) -> String:
	if prog.contracts_claimed.has(String(c.id)):
		return "claimed"
	if is_complete(c, stats, hands):
		return "ready"  # done is done — even before the content is bought
	var req: Array = c.requires
	if not req.is_empty() and not prog.is_available(String(req[0]), String(req[1])):
		return "locked"
	return "open"


## The page order: ready to claim, in progress, greyed out, claimed —
## LIST order within each. [{c, state}, ...]
static func sorted(stats: Dictionary, hands: Dictionary, prog: Progression) -> Array:
	var rows: Array = []
	for i in LIST.size():
		var c: Dictionary = LIST[i]
		rows.append({"c": c, "state": state(c, stats, hands, prog), "i": i})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var oa := int(ORDER[a.state])
		var ob := int(ORDER[b.state])
		return oa < ob if oa != ob else int(a.i) < int(b.i))
	return rows


static func ready_count(stats: Dictionary, hands: Dictionary, prog: Progression) -> int:
	var n := 0
	for c in LIST:
		if state(c, stats, hands, prog) == "ready":
			n += 1
	return n


## Why a greyed contract is greyed: what it needs and where to get it.
static func lock_text(c: Dictionary, prog: Progression) -> String:
	var req: Array = c.requires
	if req.is_empty():
		return ""
	var r := Progression.row(String(req[0]), String(req[1]))
	if r.is_empty():
		return ""
	if not prog.is_unlocked(String(req[0]), String(req[1])):
		return "Unlocks with %s · Level %d" % [String(r.name), int(r.level)]
	return "Needs %s · buy it at the Outfitter" % String(r.name)
