class_name CharacterKit
extends RefCounted

## The outlaw character kit: layered 512x512 portrait slots, tint
## palettes, eight named presets, and the wanted-poster templates
## (characters_index.json). Builds any named outlaw — or a seeded
## random gang member who looks the same every time their name comes
## up. Static-only, safe headless.

const DIR := "res://assets/art/characters/"

## Western name pools for generated gang members.
const FIRST := ["BLACK JACK", "RATTLER", "DOC", "BUCK", "SADIE", "RUSTY",
		"COLE", "ETTA", "HOLLIS", "JUNE", "CASSIDY", "WILEY", "MOSS",
		"PEARL", "GRIM", "AMOS", "DELLA", "SHAD"]
const LAST := ["DALTON", "MCGREW", "HOLLOWAY", "QUICK", "TATUM", "CROW",
		"BARLOW", "SLOCUM", "VANCE", "KETCHUM", "REED", "GRAVES",
		"BISHOP", "LACKEY"]

static var _index := {}
static var _index_loaded := false
static var _tex_cache := {}


static func _idx() -> Dictionary:
	if not _index_loaded:
		_index_loaded = true
		var path := DIR + "characters_index.json"
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if typeof(parsed) == TYPE_DICTIONARY:
				_index = parsed
	return _index


static func available() -> bool:
	return not _idx().is_empty()


## A kit texture by path relative to the kit folder. Null if missing.
static func tex(rel: String) -> Texture2D:
	if _tex_cache.has(rel):
		return _tex_cache[rel]
	var t: Texture2D = null
	var p := DIR + rel
	if rel != "" and ResourceLoader.exists(p):
		t = load(p)
	_tex_cache[rel] = t
	return t


## A palette tint resolved to a Color: palette key or raw hex.
static func tint_color(group: String, key: String) -> Color:
	if key.begins_with("#"):
		return Color(key)
	var pal: Dictionary = _idx().get("palettes", {}).get(group, {})
	if pal.has(key):
		return Color(String(pal[key]))
	return Color.WHITE


## One preset, deep-copied so callers can tweak it freely.
static func preset(id: String) -> Dictionary:
	var p: Dictionary = _idx().get("presets", {}).get(id, {})
	if p.is_empty():
		return {}
	var spec: Dictionary = p.duplicate(true)
	spec["id"] = id
	if not spec.has("sub"):
		spec["sub"] = ""
	return spec


static func preset_ids() -> Array:
	return _idx().get("presets", {}).keys()


## A seeded random outlaw: same seed, same face, forever. Follows the
## kit's rules — a bandana hides the mouth and beard, bare hair means
## no hat, an eyepatch already owns the brow.
static func random_spec(seed_val: int, sub := "") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var layers := {}
	var tints := {}
	layers["background"] = _pick(rng, ["plain", "hatched", "dark"])
	var has_hat := rng.randf() < 0.8
	layers["body"] = _pick(rng, ["duster", "vest", "poncho", "sheepskin"])
	if rng.randf() < 0.6:
		layers["chest"] = _pick(rng, ["bandolier", "suspenders", "bolo"])
	layers["head"] = _pick(rng, ["oval", "square", "gaunt", "round"])
	if rng.randf() < 0.5:
		layers["mask"] = _pick(rng, ["bandana", "neck_scarf"])
	if layers.get("mask", "") != "bandana":
		layers["mouth"] = _pick(rng, ["neutral", "grimace", "smirk"])
		if rng.randf() < 0.55:
			layers["facial_hair"] = _pick(rng,
					["stubble", "mustache", "full_beard", "goatee"])
	layers["eyes"] = _pick(rng, ["narrow", "wide", "squint", "eyepatch"])
	layers["brows"] = _pick(rng, ["heavy", "thin", "arched"])
	if rng.randf() < 0.35:
		layers["scar"] = _pick(rng, ["cheek", "x"] \
				if layers["eyes"] == "eyepatch" else ["brow", "cheek", "x"])
	layers["hair_front"] = _pick(rng, ["short", "long", "shaggy"]) \
			if has_hat else _pick(rng, ["short", "long", "shaggy", "bare"])
	if rng.randf() < 0.3:
		layers["hair_back"] = _pick(rng, ["long", "braid"])
	if has_hat:
		layers["hat"] = _pick(rng, ["wide_brim", "derby", "flat_gambler", "sombrero"])
	var pals: Dictionary = _idx().get("palettes", {})
	for group in ["skin", "hair", "coat"]:
		tints[group] = _pick(rng, pals.get(group, {"plain": "#ffffff"}).keys())
	if layers.has("mask"):
		tints["mask"] = _pick(rng, pals.get("mask", {}).keys())
	if layers.has("hat"):
		tints["hat"] = _pick(rng, pals.get("hat", {}).keys())
	var who := "%s %s" % [_pick(rng, FIRST), _pick(rng, LAST)]
	return {"id": "", "name": who, "sub": sub, "layers": layers, "tints": tints}


static func _pick(rng: RandomNumberGenerator, from: Array) -> Variant:
	return from[rng.randi() % from.size()]


## The spec flattened to ordered draw passes: [{tex, color}, ...],
## under -> tinted file -> detail per slot, with the frame on top.
static func layer_draws(spec: Dictionary) -> Array:
	var out: Array = []
	var idx := _idx()
	var slots: Dictionary = idx.get("slots", {})
	var layers: Dictionary = spec.get("layers", {})
	var tints: Dictionary = spec.get("tints", {})
	for slot_name in idx.get("order", []):
		if not layers.has(slot_name) or not slots.has(slot_name):
			continue
		var slot: Dictionary = slots[slot_name]
		var variant: Dictionary = slot.get("variants", {}).get(
				String(layers[slot_name]), {})
		if variant.is_empty():
			continue
		var tint := Color.WHITE
		var group: Variant = slot.get("tint")
		if group != null and tints.has(String(group)):
			tint = tint_color(String(group), String(tints[String(group)]))
		for pass_key in ["under", "file", "detail"]:
			if variant.has(pass_key):
				var t := tex(String(variant[pass_key]))
				if t != null:
					out.append({"tex": t,
							"color": tint if pass_key == "file" else Color.WHITE})
	var frame := tex(String(idx.get("frame", "")))
	if frame != null:
		out.append({"tex": frame, "color": Color.WHITE})
	return out


## Stacks the portrait as TextureRects inside a Control (for posters
## and other UI); returns the holder.
static func add_portrait(parent: Control, spec: Dictionary, rect: Rect2) -> Control:
	var holder := Control.new()
	holder.position = rect.position
	holder.size = rect.size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for d in layer_draws(spec):
		var tr := TextureRect.new()
		tr.texture = d.tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.size = rect.size
		tr.modulate = d.color
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tr)
	parent.add_child(holder)
	return holder


## Poster template info (card_template / banner_template / topbar_template).
static func poster_info(which: String) -> Dictionary:
	return _idx().get("posters", {}).get(which, {})
