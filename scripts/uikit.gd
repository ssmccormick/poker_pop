class_name UiKit
extends RefCounted

## The western chrome kit: one place for the game's UI vocabulary —
## leather panel plates with brass edges and corner rivets, the
## shared stylebox factory, dividers, and slider styling. Static-only
## (no scene access), safe to load headless.

const PANEL_BG := Color("262019")        # dark leather
const PANEL_EDGE := Color("6e5f3a")      # dimmed brass (gold = hover/active)
const PANEL_BG_HOVER := Color("3d3a2c")
const PANEL_BG_PRESSED := Color("55503a")
const PANEL_BG_DISABLED := Color("1f1c17")
const POSTER_PAPER := Color("d8cba8")    # wanted-poster stock
const POSTER_INK := Color("3a3126")
const POSTER_EDGE := Color("5a4a2e")
const DIM := Color("8a836e")

static var _knob_cache := {}


## The one stylebox factory: warm fill, brass border, soft drop shadow.
static func panel_box(bg: Color, edge: Color, radius := 6, border := 2,
		shadow := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = edge
	sb.set_border_width_all(border)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = shadow
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


## A decorative HUD plate: leather panel with brass corner rivets.
## Purely visual — ignores the mouse.
static func plate(parent: Control, rect: Rect2) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := PANEL_BG
	bg.a = 0.92
	p.add_theme_stylebox_override("panel", panel_box(bg, PANEL_EDGE, 8, 2, 8))
	var rivets := Rivets.new()
	rivets.plate_size = rect.size
	p.add_child(rivets)
	parent.add_child(p)
	return p


## Brass corner rivets for a plate.
class Rivets extends Node2D:
	var plate_size := Vector2.ZERO

	func _draw() -> void:
		for corner in [Vector2(10, 10), Vector2(plate_size.x - 10, 10),
				Vector2(10, plate_size.y - 10),
				Vector2(plate_size.x - 10, plate_size.y - 10)]:
			draw_circle(corner, 3.0, PANEL_EDGE)
			draw_circle(corner + Vector2(-0.8, -0.8), 1.2,
					Color(0.62, 0.55, 0.38))


## A thin horizontal divider.
static func hrule(parent: Control, pos: Vector2, w: float) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = Vector2(w, 2)
	r.color = Color(DIM.r, DIM.g, DIM.b, 0.45)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## A round slider knob drawn to a texture (cached per radius+color).
static func knob_texture(radius: int, col: Color) -> ImageTexture:
	var key := "%d_%s" % [radius, col.to_html()]
	if _knob_cache.has(key):
		return _knob_cache[key]
	var d := radius * 2 + 2
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(d / 2.0, d / 2.0)
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if dist <= radius - 2.0:
				img.set_pixel(x, y, col)
			elif dist <= radius:
				img.set_pixel(x, y, col.darkened(0.45))
	var tex := ImageTexture.create_from_image(img)
	_knob_cache[key] = tex
	return tex


## Dresses a stock HSlider in the house style: dark leather track,
## gold fill, brass-ringed gold knob.
static func style_slider(s: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = PANEL_BG
	track.border_color = PANEL_EDGE
	track.set_border_width_all(1)
	track.set_corner_radius_all(4)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	s.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("e8c547")
	fill.set_corner_radius_all(4)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	s.add_theme_icon_override("grabber", knob_texture(9, Color("e8c547")))
	s.add_theme_icon_override("grabber_highlight",
			knob_texture(10, Color("f5da6e")))
