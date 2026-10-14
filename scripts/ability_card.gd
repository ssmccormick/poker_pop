class_name AbilityCard
extends Node2D

## One ability card face: no rank or suit. A card blank, the rarity frame
## with the ability's glyph, its name, one pip per slot it takes, and the
## hands it's limited to. Drawn around its center, W × H; scale it to fit.
## Falls back to plain shapes when the art kit isn't there.

const W := 150.0
const H := 210.0
const INK := Color("2a2016")
const DIM := Color("6a5a44")
const PAPER := Color("e9dfc6")
const RARITY_COLORS := [Color("8a7a5a"), Color("4f7fb0"), Color("9a5fc0"), Color("d4a52c")]

var ability_id := "":
	set(value):
		ability_id = value
		_update_shine()
		queue_redraw()
## Dims the card (an equipped copy in the collection grid).
var faded := false:
	set(value):
		faded = value
		modulate = Color(1, 1, 1, 0.45) if value else Color.WHITE
var _fx_mat: ShaderMaterial
var _fx_t := randf() * 10.0


func _update_shine() -> void:
	# Epic and Legendary abilities wear the foil shimmer, like relics.
	if Abilities.rarity(ability_id) < 2:
		material = null
		set_process(false)
		return
	if _fx_mat == null:
		_fx_mat = ShaderMaterial.new()
		_fx_mat.shader = load("res://shaders/card_pattern.gdshader")
		_fx_mat.set_shader_parameter("pattern_strength", 0.0)
		_fx_mat.set_shader_parameter("fx_rect", Vector4(-W / 2, -H / 2, W / 2, H / 2))
	_fx_mat.set_shader_parameter("fx_mode", 3)
	material = _fx_mat
	set_process(true)


func _process(delta: float) -> void:
	_fx_t += delta
	if _fx_mat != null:
		_fx_mat.set_shader_parameter("fx_time", _fx_t)


func _draw() -> void:
	var d := Abilities.def(ability_id)
	if d.is_empty():
		return
	var rect := Rect2(-W / 2, -H / 2, W, H)
	var r := clampi(int(d.rarity), 0, 3)
	var tint: Color = RARITY_COLORS[r]
	var blank := CardArt.tex("base", "card_blank")
	if blank != null:
		draw_texture_rect(blank, rect, false)
	else:
		draw_rect(rect, PAPER)
		draw_rect(rect, INK, false, 2.0)
	# A rarity band across the top.
	draw_rect(Rect2(rect.position.x + 8, rect.position.y + 8, W - 16, 6), tint)
	# The emblem: the rarity frame with a glyph inside.
	var icon := Rect2(-38, -H / 2 + 20, 76, 76)
	var frame := CardArt.tex("relic_frame", Abilities.RARITY_IDS[r])
	if frame != null:
		draw_texture_rect(frame, icon, false)
	else:
		draw_circle(icon.get_center(), 36, Color("241c12"))
		draw_arc(icon.get_center(), 34, 0, TAU, 40, tint, 3.0)
	var g: Array = d.get("glyph", [])
	var glyph: Texture2D = null
	if g.size() == 2 and String(g[0]) != "draw":
		glyph = CardArt.tex(String(g[0]), String(g[1]))
	if glyph != null:
		draw_texture_rect(glyph, icon.grow(-12), false)
	elif g.size() == 2 and String(g[1]) == "bullet":
		_draw_bullet(icon.get_center())
	else:
		draw_circle(icon.get_center(), 14, tint)
	var font: Font = FontLib.display if FontLib.display != null else ThemeDB.fallback_font
	var body: Font = FontLib.label if FontLib.label != null else ThemeDB.fallback_font
	# The name, wrapped to two lines when it needs them.
	var name_text := String(d.name).to_upper()
	var size := 17 if name_text.length() <= 12 else 14
	draw_multiline_string(font, Vector2(-W / 2 + 8, 22), name_text,
			HORIZONTAL_ALIGNMENT_CENTER, W - 16, size, 2, INK)
	# One pip per slot it takes.
	var n := int(d.slots)
	var pip_w := 12.0
	var gap := 5.0
	var x0 := -(n * pip_w + (n - 1) * gap) / 2.0
	for i in n:
		draw_rect(Rect2(x0 + i * (pip_w + gap), 58, pip_w, 12), tint)
	draw_string(body, Vector2(-W / 2, 86), "%d SLOT%s" % [n, "" if n == 1 else "S"],
			HORIZONTAL_ALIGNMENT_CENTER, W, 12, DIM)
	var limit := Abilities.restriction_line(ability_id)
	_draw_limit(body, limit)


func _draw_limit(body: Font, limit: String) -> void:
	if limit != "":
		draw_multiline_string(body, Vector2(-W / 2 + 8, 100), limit,
				HORIZONTAL_ALIGNMENT_CENTER, W - 16, 11, 2, Color("8a3a30"))


## A brass cartridge, for the gunslinging abilities.
func _draw_bullet(c: Vector2) -> void:
	var brass := Color("c9a24a")
	var lead := Color("8d8f96")
	draw_rect(Rect2(c.x - 8, c.y - 2, 16, 20), brass)
	draw_rect(Rect2(c.x - 9, c.y + 16, 18, 4), brass.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(c.x - 8, c.y - 2),
			Vector2(c.x - 6, c.y - 12), Vector2(c.x, c.y - 18), Vector2(c.x + 6, c.y - 12),
			Vector2(c.x + 8, c.y - 2)]), lead)
	draw_line(Vector2(c.x - 4, c.y + 2), Vector2(c.x - 4, c.y + 14), brass.lightened(0.35), 2.0)
