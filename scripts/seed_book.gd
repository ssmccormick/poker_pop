class_name SeedBook
extends RefCounted

## Local highscores per seed, per profile (pN_seeds.cfg): the best score
## on each board, how often it was tried, and the recent seeds played.
## A board is a mode, a seed and a variant — a Trail board splits by
## rider and Ascension, a Time Trial by its length — so two scores on
## one board were played on exactly the same game.

var path := ""
var boards := {}        # key -> {mode, seed, variant, best, attempts, last, outcome, tables}
var dailies := {}       # daily seed -> true once its scored ride is spent
var player_id := ""     # this profile's id on the online boards (made once)
var player_name := ""   # the name it posts under (Options / SEEDED PLAY)

const NAME_MAX := 12


## Bumped whenever the rules change what a seed deals (r2: ability cards
## replace the card pick; r3: tables carry twists; r4: trail cash
## replaces chips; r5: the three sides join the ability pool), so old and new
## scores never share a board.
const RULESET := "r5"


static func key(mode: String, seed_text: String, variant := "") -> String:
	return "%s|%s|%s|%s" % [mode, seed_text, variant, RULESET]


## The board variant for a trail ride: rider and Ascension.
static func trail_variant(rider: String, asc: int) -> String:
	return "%s-a%d" % [rider, asc]


func load_file(p: String) -> void:
	path = p
	boards = {}
	dailies = {}
	player_id = ""
	player_name = ""
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return
	player_id = String(cf.get_value("player", "id", ""))
	player_name = String(cf.get_value("player", "name", ""))
	if cf.has_section("boards"):
		for k in cf.get_section_keys("boards"):
			var v = cf.get_value("boards", k, {})
			if v is Dictionary:
				boards[String(k)] = v
	if cf.has_section("daily"):
		for k in cf.get_section_keys("daily"):
			dailies[String(k)] = true


func save() -> void:
	if path == "" or OS.get_environment("POKERPOP_SHOT") != "":
		return
	var cf := ConfigFile.new()
	cf.set_value("player", "id", player_id)
	cf.set_value("player", "name", player_name)
	for k in boards:
		cf.set_value("boards", k, boards[k])
	for k in dailies:
		cf.set_value("daily", k, true)
	cf.save(path)


## Logs a finished game. True when it's a new best on that board.
func record(k: String, score: int, meta: Dictionary = {}) -> bool:
	var parts := k.split("|")
	var e: Dictionary = boards.get(k, {"mode": parts[0] if parts.size() > 0 else "",
			"seed": parts[1] if parts.size() > 1 else "",
			"variant": parts[2] if parts.size() > 2 else "",
			"best": 0, "attempts": 0})
	e["attempts"] = int(e.get("attempts", 0)) + 1
	e["last"] = int(Time.get_unix_time_from_system())
	var pb := score > int(e.get("best", 0))
	if pb:
		e["best"] = score
		for mk in meta:
			e[mk] = meta[mk]
	boards[k] = e
	save()
	return pb


func best(k: String) -> int:
	return int(boards.get(k, {}).get("best", 0))


## The most recently played boards, newest first.
func recent(n := 8) -> Array:
	var rows: Array = boards.values()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("last", 0)) > int(b.get("last", 0)))
	return rows.slice(0, n)


## This profile's id on the online boards, made the first time it's asked for.
func ensure_player() -> String:
	if player_id == "":
		player_id = "%08x%08x%08x%08x" % [randi(), randi(), randi(), randi()]
		save()
	return player_id


## The name a score posts under: the chosen one, or "Stranger" and a tag.
func display_name() -> String:
	if player_name.strip_edges() != "":
		return player_name.strip_edges().left(NAME_MAX)
	return "Stranger " + ensure_player().left(3).to_upper()


static func clean_name(text: String) -> String:
	var out := ""
	for ch in text.strip_edges():
		if ch.unicode_at(0) >= 32 and ch != "|":
			out += ch
	return out.left(NAME_MAX)


func daily_used(seed_text: String) -> bool:
	return dailies.has(seed_text)


func mark_daily(seed_text: String) -> void:
	dailies[seed_text] = true
	save()
