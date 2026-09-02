class_name Themes
extends RefCounted

## Visual themes: a palette plus an optional card pattern material.
## Pattern textures come from the UltimateToon shader pack (its 3D toon
## shader itself doesn't apply to 2D — see shaders/card_pattern.gdshader
## for the 2D adaptation).

const LIST := [
	{
		"name": "Classic",
		"bg": Color("1a1a1a"),
		"face": Color("e8e0c8"),
		"edge": Color("a89c7d"),
		"red": Color("c23b3b"),
		"black": Color("1a1a1a"),
		"pattern": "",
		"strength": 0.0,
		"tile_px": 200.0,
		"suit_style": "vector",
		"face_texture": "",
	},
	{
		"name": "Felt Table",
		"bg": Color("1d3326"),
		"face": Color("ece4cd"),
		"edge": Color("94a086"),
		"red": Color("b93a35"),
		"black": Color("20242a"),
		"pattern": "res://assets/patterns/dither_01.png",
		"strength": 0.14,
		"tile_px": 48.0,
		"suit_style": "vector",
		"face_texture": "",
	},
	{
		"name": "Sketchbook",
		"bg": Color("2b2723"),
		"face": Color("f1ead6"),
		"edge": Color("8f8672"),
		"red": Color("b0524a"),
		"black": Color("3a3631"),
		"pattern": "res://assets/patterns/hatching_01.png",
		"strength": 0.26,
		"tile_px": 300.0,
		"suit_style": "pixel",
		"face_texture": "",
	},
	{
		"name": "Crosshatch Noir",
		"bg": Color("121014"),
		"face": Color("d9d2bb"),
		"edge": Color("6e6858"),
		"red": Color("cf4438"),
		"black": Color("17151a"),
		"pattern": "res://assets/patterns/cross_03.png",
		"strength": 0.26,
		"tile_px": 200.0,
		"suit_style": "pixel",
		"face_texture": "",
	},
]

# Cached optional face textures (drop art into assets/cards/ and point
# a theme's face_texture at it to reskin card bases).
static var _face_textures := {}


static func face_texture() -> Texture2D:
	var path: String = current().get("face_texture", "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	if not _face_textures.has(path):
		_face_textures[path] = load(path)
	return _face_textures[path]

static var index := 0
static var _materials := {}


static func current() -> Dictionary:
	return LIST[index]


static func cycle() -> Dictionary:
	index = (index + 1) % LIST.size()
	return current()


## Shared ShaderMaterial for the current theme's card pattern, or null for
## pattern-free themes.
static func current_material() -> ShaderMaterial:
	var t := current()
	if t.pattern == "":
		return null
	if not _materials.has(t.name):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/card_pattern.gdshader")
		mat.set_shader_parameter("pattern_tex", load(t.pattern))
		mat.set_shader_parameter("pattern_strength", t.strength)
		mat.set_shader_parameter("tile_px", t.tile_px)
		_materials[t.name] = mat
	return _materials[t.name]
