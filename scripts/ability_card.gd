class_name AbilityCard
extends Node2D

## One ability card face: no rank or suit. The kit's tooled-leather frame
## (rarity in the rim and the emblem ring), the ability's glyph in the
## emblem, its name on the parchment plaque, one pip per slot it takes,
## and the hands it's limited to. Drawn around its center, W × H; scale it
## to fit. Falls back to plain shapes when the art kit isn't there.
##
## `face_down` shows the card back; `reveal(delay)` flips it face up with
## the kit's rays and glow behind it, tinted by rarity.

const W := 150.0
const H := 210.0
const INK := Color("2a2016")
const DIM := Color("6a5a44")
const PAPER := Color("e9dfc6")
const FOOTER := Color("cdb88b")
const RARITY_COLORS := [Color("cdbf9e"), Color("5d9ad6"), Color("a970d8"), Color("e8c547")]
# Live zones on the kit's 500×700 card (see the pack README).
const GLYPH_BOX := Rect2(140, 90, 220, 220)
const NAME_BAND := Rect2(36, 366, 428, 88)
const SLOT_ROW := Rect2(80, 482, 340, 76)
const FOOTER_BAND := Rect2(60, 588, 380, 62)

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
var face_down := false:
	set(value):
		face_down = value
		queue_redraw()
var _fx_mat: ShaderMaterial
var _fx_t := randf() * 10.0
var _reveal_a := 0.0     # rays and glow strength, 0 = none
var _reveal_spin := 0.0


func _update_shine() -> void:
	# Epic and Legendary abilities wear the foil shimmer, like relics.
	if Abilities.rarity(ability_id) < 2:
		material = null
		set_process(_reveal_a > 0.0)
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
	if _reveal_a > 0.0:
		_reveal_spin += deg_to_rad(20.0) * delta
		queue_redraw()


## The reward flip: the back narrows to nothing, the face widens back in,
## then the rays and glow come up behind it.
func reveal(delay := 0.0) -> void:
	face_down = true
	var sx := scale.x
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(self, "scale:x", 0.0, 0.12)
	tw.tween_callback(func() -> void: face_down = false)
	tw.tween_property(self, "scale:x", sx, 0.12)
	tw.tween_callback(func() -> void: set_process(true))
	tw.tween_method(func(v: float) -> void:
		_reveal_a = v
		queue_redraw(), 0.0, 0.8, 0.35)


func _draw() -> void:
	var d := Abilities.def(ability_id)
	if d.is_empty():
		return
	var rect := Rect2(-W / 2, -H / 2, W, H)
	var r := clampi(int(d.rarity), 0, 3)
	var tint: Color = RARITY_COLORS[r]
	var k := W / 500.0
	if _reveal_a > 0.0 and not face_down:
		_draw_reveal(rect, k, tint)
	if face_down:
		var back := CardArt.tex("ability_frame", "back")
		if back != null:
			draw_texture_rect(back, rect, false)
		else:
			draw_rect(rect, Color("2a2016"))
			draw_rect(rect, tint, false, 3.0)
		return
	var frame := CardArt.tex("ability_frame", Abilities.RARITY_IDS[r])
	if frame != null:
		_draw_kit_face(d, rect, k, r)
	else:
		_draw_plain_face(d, rect, r, tint)


## The rarity-tinted rays (slowly turning) and the pulsing glow, on the
## kit's 700×900 canvas with the card at (100, 100).
func _draw_reveal(rect: Rect2, k: float, tint: Color) -> void:
	var canvas := Rect2(rect.position - Vector2(100, 100) * k, Vector2(700, 900) * k)
	var glow := CardArt.tex("fx", "ability_reveal_glow")
	if glow != null:
		var pulse := 0.6 + 0.4 * (0.5 + 0.5 * sin(_fx_t * 3.0))
		draw_texture_rect(glow, canvas, false, Color(tint.r, tint.g, tint.b, _reveal_a * pulse))
	var rays := CardArt.tex("fx", "ability_reveal_rays")
	if rays != null:
		draw_set_transform(Vector2.ZERO, _reveal_spin, Vector2.ONE)
		draw_texture_rect(rays, Rect2(-canvas.size / 2.0, canvas.size), false,
				Color(tint.r, tint.g, tint.b, _reveal_a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _zone(z: Rect2, rect: Rect2, k: float) -> Rect2:
	return Rect2(rect.position + z.position * k, z.size * k)


func _draw_kit_face(d: Dictionary, rect: Rect2, k: float, r: int) -> void:
	draw_texture_rect(CardArt.tex("ability_frame", Abilities.RARITY_IDS[r]), rect, false)
	var glyph := CardArt.tex("ability_glyph", ability_id)
	if glyph != null:
		draw_texture_rect(glyph, _zone(GLYPH_BOX, rect, k), false)
	var display: Font = FontLib.display if FontLib.display != null else ThemeDB.fallback_font
	var label: Font = FontLib.label if FontLib.label != null else ThemeDB.fallback_font
	# The name on the plaque, one or two lines, centered in the band.
	var band := _zone(NAME_BAND, rect, k)
	var name_text := String(d.name).to_upper()
	var size := int(round((40.0 if name_text.length() <= 10 else 32.0) * k * 1.0))
	var lines := 1 if display.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= band.size.x - 8 else 2
	var line_h := size * 1.05
	var top := band.position.y + (band.size.y - lines * line_h) / 2.0 + size * 0.82
	draw_multiline_string(display, Vector2(band.position.x + 4, top), name_text,
			HORIZONTAL_ALIGNMENT_CENTER, band.size.x - 8, size, 2, INK)
	# One pip per slot, centered in the dark well.
	var row := _zone(SLOT_ROW, rect, k)
	var n := int(d.slots)
	var pip := 44.0 * k
	var gap := 8.0 * k
	var x0 := row.get_center().x - (n * pip + (n - 1) * gap) / 2.0
	var pip_tex := CardArt.tex("ability_pip", Abilities.RARITY_IDS[r])
	for i in n:
		var pr := Rect2(x0 + i * (pip + gap), row.get_center().y - pip / 2.0, pip, pip)
		if pip_tex != null:
			draw_texture_rect(pip_tex, pr, false)
		else:
			draw_circle(pr.get_center(), pip / 2.0, RARITY_COLORS[r])
	# The restriction line in the footer.
	var limit := Abilities.restriction_line(ability_id)
	if limit != "":
		var fb := _zone(FOOTER_BAND, rect, k)
		var fs := maxi(6, int(round(26.0 * k)))
		draw_string(label, Vector2(fb.position.x, fb.get_center().y + fs * 0.36), limit.to_upper(),
				HORIZONTAL_ALIGNMENT_CENTER, fb.size.x, fs, FOOTER)


## No kit: a parchment card with a rarity band, a disc and the name.
func _draw_plain_face(d: Dictionary, rect: Rect2, r: int, tint: Color) -> void:
	draw_rect(rect, PAPER)
	draw_rect(rect, INK, false, 2.0)
	draw_rect(Rect2(rect.position.x + 8, rect.position.y + 8, W - 16, 6), tint)
	var c := Vector2(0, -H / 2 + 58)
	draw_circle(c, 36, Color("241c12"))
	draw_arc(c, 34, 0, TAU, 40, tint, 3.0)
	var font: Font = FontLib.display if FontLib.display != null else ThemeDB.fallback_font
	var body: Font = FontLib.label if FontLib.label != null else ThemeDB.fallback_font
	var name_text := String(d.name).to_upper()
	draw_multiline_string(font, Vector2(-W / 2 + 8, 22), name_text,
			HORIZONTAL_ALIGNMENT_CENTER, W - 16, 17 if name_text.length() <= 12 else 14, 2, INK)
	var n := int(d.slots)
	var x0 := -(n * 12.0 + (n - 1) * 5.0) / 2.0
	for i in n:
		draw_rect(Rect2(x0 + i * 17.0, 58, 12, 12), tint)
	var limit := Abilities.restriction_line(ability_id)
	if limit != "":
		draw_multiline_string(body, Vector2(-W / 2 + 8, 100), limit,
				HORIZONTAL_ALIGNMENT_CENTER, W - 16, 11, 2, Color("8a3a30"))
