class_name SeedRng
extends RefCounted

## SEEDS: every game deals from a seed, so a seed replays the same
## game. Gameplay never touches Godot's global RNG (sounds, particles
## and other cosmetics share that, at unpredictable moments); it draws
## from named streams instead, each derived from the seed plus a
## purpose and an index ("wall" at room 4, "board" at room 4 attempt
## 1...). A stream for the same key always yields the same numbers.

const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # no I, O, 0, 1
const LENGTH := 8


## A fresh seed for a game nobody chose one for.
static func random_seed() -> String:
	var out := ""
	for i in LENGTH:
		out += ALPHABET[randi() % ALPHABET.length()]
	return out


## Seed text as typed: uppercased, spaces and dashes gone, the look-alike
## letters mapped onto the alphabet, anything else dropped. Daily seeds
## ("D" + date) pass through.
static func normalize(text: String) -> String:
	var t := text.strip_edges().to_upper().replace("-", "").replace(" ", "")
	if is_daily(t):
		return t
	t = t.replace("O", "0").replace("I", "1")
	t = t.replace("0", "Q").replace("1", "L")  # the alphabet has neither
	var out := ""
	for ch in t:
		if ALPHABET.contains(ch):
			out += ch
	return out.substr(0, LENGTH)


static func is_valid(text: String) -> bool:
	return is_daily(text) or (text.length() == LENGTH and normalize(text) == text)


## "K7QX2M9P" -> "K7QX-2M9P"; daily seeds read "DAILY 2026-10-12".
static func pretty(text: String) -> String:
	if is_daily(text):
		return "DAILY %s-%s-%s" % [text.substr(1, 4), text.substr(5, 2), text.substr(7, 2)]
	if text.length() != LENGTH:
		return text
	return text.substr(0, 4) + "-" + text.substr(4)


## Today's daily seed, by the UTC date (everyone shares it).
static func daily_seed(date: Dictionary = {}) -> String:
	var d := date if not date.is_empty() else Time.get_date_dict_from_system(true)
	return "D%04d%02d%02d" % [int(d.year), int(d.month), int(d.day)]


static func is_daily(text: String) -> bool:
	return text.length() == 9 and text.begins_with("D") and text.substr(1).is_valid_int()


## A stable 64-bit hash of `text` (two 32-bit FNV-1a passes — no
## overflow, the same on every platform).
static func hash64(text: String) -> int:
	var a := 2166136261
	var b := 2166136261 ^ 0x5bd1e995
	for byte in text.to_utf8_buffer():
		a = ((a ^ byte) * 16777619) & 0xFFFFFFFF
		b = ((b ^ ((byte * 31 + 7) & 0xFF)) * 16777619) & 0xFFFFFFFF
	return (a << 32) | b


## The stream for (seed, purpose, a, b).
static func stream(seed_text: String, purpose: String, a := 0, b := 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash64("%s|%s|%d|%d" % [seed_text, purpose, a, b])
	return rng


# --- Array helpers (Array.pick_random / shuffle always use the global RNG) ---

static func pick(rng: RandomNumberGenerator, arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[rng.randi_range(0, arr.size() - 1)]


## Fisher–Yates, in place.
static func shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


static func chance(rng: RandomNumberGenerator, p: float) -> bool:
	return rng.randf() < p
