class_name CardArt
extends RefCounted

## The layered card-art kit: loads layers_index.json once and serves
## textures by group/name. Pure resource lookups (no scene access), so
## headless tests stay green — PlayingCard._draw asks `available()`
## and falls back to its vector face when the kit is absent.
##
## Stack order (from the kit's how_to_stack): base → center (skip when
## modded) → mod_wash → mod_frame → mod_emblem → rank → suit_corner →
## hazard → special → rider; bosses are boss/<name>_card + boss_frame.
## Every card layer is a 500×700 PNG on one canvas, drawn at the full
## card rect (the game card is the same 5:7 aspect).

const ROOT := "res://assets/art/cards/"
const INDEX := ROOT + "layers_index.json"

const SUIT_KEYS := ["spades", "hearts", "diamonds", "clubs"]
const RANK_KEYS := {11: "J", 12: "Q", 13: "K", 14: "A"}

static var _paths := {}       # group -> name -> relative path
static var _tex := {}         # "group/name" -> Texture2D (lazy)
static var _ready := false
static var _ok := false


static func _ensure() -> void:
	if _ready:
		return
	_ready = true
	if not FileAccess.file_exists(INDEX):
		return
	var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(INDEX))
	if parsed is Dictionary and parsed.has("layers"):
		_paths = parsed.layers
		_ok = true


static func available() -> bool:
	_ensure()
	return _ok


## A texture by group and name, or null when the kit lacks it.
static func tex(group: String, name: String) -> Texture2D:
	_ensure()
	var key := group + "/" + name
	if _tex.has(key):
		return _tex[key]
	var t: Texture2D = null
	if _ok and _paths.has(group) and (_paths[group] as Dictionary).has(name):
		var path: String = ROOT + String(_paths[group][name])
		if ResourceLoader.exists(path):
			t = load(path)
	_tex[key] = t  # cache misses too, so bad keys don't re-hit the disk
	return t


static func rank_name(rank: int) -> String:
	return String(RANK_KEYS.get(rank, str(rank)))


static func suit_name(suit: int) -> String:
	return SUIT_KEYS[clampi(suit, 0, 3)]


## Fire severity 1..4 from the burning card's rank (the kit's ladder:
## A–J burn low, 3–2 are all but consumed).
static func fire_level(rank: int) -> int:
	if rank >= 11:
		return 1
	if rank >= 7:
		return 2
	if rank >= 4:
		return 3
	return 4


## Facing rotation for *_arrow_up layers: radians to turn an up-arrow
## to the given grid direction.
static func arrow_rotation(dir: Vector2i) -> float:
	match dir:
		Vector2i.UP:
			return 0.0
		Vector2i.RIGHT:
			return PI / 2.0
		Vector2i.DOWN:
			return PI
		Vector2i.LEFT:
			return -PI / 2.0
	return 0.0


# Game ids whose art files spell the name differently.
const PROVISION_ART := {"dynamite": "dynamite_stick", "razor": "barbers_razor",
		"tonic": "rattlesnake_tonic"}


static func provision_icon(id: String) -> Texture2D:
	return tex("provision_framed", PROVISION_ART.get(id, id))


## Startup validation: prints every index entry whose file is missing.
static func validate() -> int:
	_ensure()
	var missing := 0
	for group in _paths:
		for name in _paths[group]:
			if not ResourceLoader.exists(ROOT + String(_paths[group][name])):
				push_warning("CardArt: missing %s/%s -> %s"
						% [group, name, _paths[group][name]])
				missing += 1
	return missing
