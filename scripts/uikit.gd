class_name UiKit
extends RefCounted

## The western chrome kit: one place for the game's UI vocabulary.
## Round 2 ships painted 9-slice textures (assets/art/r2/ui +
## ui_index.json manifest); when they are present every helper here
## hands out StyleBoxTexture chrome, and when they are not the old
## flat leather-and-brass styleboxes still work. Static-only (no
## scene access), safe to load headless.

# Brand palette (PokerPop kit): Coal 15100C · Saloon Oak 3A2618 ·
# Worn Felt 1C2E25 · Bone E6D5B0 · Tarnished Brass B08A4A · Oxblood 7C1F16.
const PANEL_BG := Color("241910")        # dark saloon oak
const PANEL_EDGE := Color("b08a4a")      # tarnished brass (gold = hover/active)
const PANEL_BG_HOVER := Color("38281a")
const PANEL_BG_PRESSED := Color("4a3524")
const PANEL_BG_DISABLED := Color("1b130c")
const POSTER_PAPER := Color("d8cba8")    # wanted-poster stock
const POSTER_INK := Color("3a3126")
const POSTER_EDGE := Color("5a4a2e")
const DIM := Color("8a836e")
const BRASS_HI := Color("d9b572")        # screen titles (gold = live numbers)
const DISABLED_TEXT := Color("6f6a62")

const ART_DIR := "res://assets/art/r2/"

static var _knob_cache := {}
static var _items := {}       # ui_index.json "items"
static var _tex_cache := {}
static var _box_cache := {}


## Parses the round-2 UI manifest. Call once at startup, before any
## chrome is built; without the manifest everything falls back flat.
static func setup() -> void:
	_items = {}
	_tex_cache = {}
	_box_cache = {}
	var path := ART_DIR + "ui_index.json"
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) == TYPE_DICTIONARY:
		_items = parsed.get("items", {})


static func has_art() -> bool:
	return not _items.is_empty()


## One texture from the kit, by manifest item name. Null if missing.
static func tex(item_name: String) -> Texture2D:
	if _tex_cache.has(item_name):
		return _tex_cache[item_name]
	var t: Texture2D = null
	if _items.has(item_name):
		var p: String = ART_DIR + String(_items[item_name].get("file", ""))
		if ResourceLoader.exists(p):
			t = load(p)
	_tex_cache[item_name] = t
	return t


## One 9-slice stylebox from the kit, by manifest item name — texture
## margins and content margins straight from the manifest. Cached and
## shared; null when the art is missing.
static func box(item_name: String) -> StyleBoxTexture:
	if _box_cache.has(item_name):
		return _box_cache[item_name]
	var sb: StyleBoxTexture = null
	var t := tex(item_name)
	if t != null:
		var item: Dictionary = _items[item_name]
		sb = StyleBoxTexture.new()
		sb.texture = t
		var m: Array = item.get("margins", [])
		if m.size() == 4:
			sb.texture_margin_left = float(m[0])
			sb.texture_margin_top = float(m[1])
			sb.texture_margin_right = float(m[2])
			sb.texture_margin_bottom = float(m[3])
		var cm: Array = item.get("content_margins", [])
		if cm.size() == 4:
			sb.content_margin_left = float(cm[0])
			sb.content_margin_top = float(cm[1])
			sb.content_margin_right = float(cm[2])
			sb.content_margin_bottom = float(cm[3])
	_box_cache[item_name] = sb
	return sb


## The flat stylebox factory: warm fill, brass border, soft drop
## shadow. Still the fallback whenever a kit texture is absent.
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


## The tooltip chrome (art or flat).
static func tooltip_box() -> StyleBox:
	var sb: StyleBox = box("tooltip")
	if sb != null:
		return sb
	return panel_box(PANEL_BG, PANEL_EDGE, 4, 2, 6)


## Wanted-poster paper for the tutor popup (art bakes the nails in).
static func poster_box() -> StyleBox:
	var sb: StyleBox = box("poster_paper")
	if sb != null:
		return sb
	return panel_box(POSTER_PAPER, POSTER_EDGE, 2, 4, 14)


## Recessed well (YOUR HAND, kit icon boxes, slots, deck viewer).
static func inset_box() -> StyleBox:
	var sb: StyleBox = box("panel_inset")
	if sb != null:
		return sb
	var flat := panel_box(Color("0f0a07"), Color("3a2618"), 4, 2, 0)
	return flat


## Progress-bar chrome: "track", "gold", "red", "green".
static func bar_box(which: String) -> StyleBox:
	var sb: StyleBox = box("bar_track" if which == "track" else "bar_fill_" + which)
	if sb != null:
		return sb
	var flat := StyleBoxFlat.new()
	match which:
		"track":
			flat.bg_color = Color("2a2a2a")
		"gold":
			flat.bg_color = Color("e8c547")
		"red":
			flat.bg_color = Color("b8402c")
		"green":
			flat.bg_color = Color("7fae6a")
	return flat


## A decorative HUD plate: painted leather panel with brass rim and
## rivets when the kit is in, flat leather otherwise. Purely visual —
## ignores the mouse.
static func plate(parent: Control, rect: Rect2, kind := "plate") -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_name := "panel_plate"
	match kind:
		"plain":
			art_name = "panel_plate_plain"
		"inset":
			art_name = "panel_inset"
	var art: StyleBoxTexture = box(art_name)
	if art != null:
		# Shadow and painted face ride INSIDE the returned panel, so a
		# caller hiding the plate hides all of it.
		p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var sh: StyleBoxTexture = box("panel_shadow")
		if sh != null and kind != "inset":
			var shadow := Panel.new()
			shadow.position = Vector2(-14, -8)
			shadow.size = rect.size + Vector2(28, 28)
			shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shadow.add_theme_stylebox_override("panel", sh)
			p.add_child(shadow)
		var face := Panel.new()
		face.size = rect.size
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_theme_stylebox_override("panel", art)
		p.add_child(face)
		parent.add_child(p)
		return p
	var bg := PANEL_BG
	bg.a = 0.92
	p.add_theme_stylebox_override("panel", panel_box(bg, PANEL_EDGE, 8, 2, 8))
	var rivets := Rivets.new()
	rivets.plate_size = rect.size
	p.add_child(rivets)
	parent.add_child(p)
	return p


## Brass corner rivets for a flat plate (the painted plates bake
## their own; the tutor poster still uses these as nail heads).
class Rivets extends Node2D:
	var plate_size := Vector2.ZERO

	func _draw() -> void:
		for corner in [Vector2(10, 10), Vector2(plate_size.x - 10, 10),
				Vector2(10, plate_size.y - 10),
				Vector2(plate_size.x - 10, plate_size.y - 10)]:
			draw_circle(corner, 3.0, PANEL_EDGE)
			draw_circle(corner + Vector2(-0.8, -0.8), 1.2,
					Color(0.62, 0.55, 0.38))


## A thin horizontal divider — the kit's brass rule with diamond
## end-caps when available, a dim hairline otherwise.
static func hrule(parent: Control, pos: Vector2, w: float) -> Control:
	var art: StyleBoxTexture = box("divider")
	if art != null:
		var p := Panel.new()
		p.position = Vector2(pos.x, pos.y - 7.0)
		p.size = Vector2(w, 16)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_theme_stylebox_override("panel", art)
		parent.add_child(p)
		return p
	var r := ColorRect.new()
	r.position = pos
	r.size = Vector2(w, 2)
	r.color = Color(DIM.r, DIM.g, DIM.b, 0.45)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## House button chrome, art or flat. Primary (oxblood) is for the
## big calls to action: PLAY HAND, THE TRAIL, BUY.
static func style_button(b: Button, primary := false) -> void:
	var prefix := "button_primary_" if primary else "button_"
	var normal: StyleBoxTexture = box(prefix + "normal")
	if normal != null:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var sb: StyleBoxTexture = box(prefix + state).duplicate()
			# Buttons place text by explicit size, not content minimums;
			# flatten the vertical margins so labels stay centered —
			# except pressed, which sits the label 2px down.
			sb.content_margin_left = 20
			sb.content_margin_right = 20
			sb.content_margin_top = 4.0 if state == "pressed" else 0.0
			sb.content_margin_bottom = 0.0
			b.add_theme_stylebox_override(state, sb)
		b.add_theme_color_override("font_color", Color("e6d5b0"))
		b.add_theme_color_override("font_focus_color", Color("e6d5b0"))
		b.add_theme_color_override("font_hover_color", BRASS_HI)
		b.add_theme_color_override("font_pressed_color", BRASS_HI)
		b.add_theme_color_override("font_disabled_color", DISABLED_TEXT)
		return
	var sb := panel_box(PANEL_BG, PANEL_EDGE, 4, 2, 4)
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	b.add_theme_stylebox_override("normal", sb)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.bg_color = PANEL_BG_HOVER
	hover.border_color = Color("e8c547")
	b.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = hover.duplicate()
	pressed.bg_color = PANEL_BG_PRESSED
	pressed.shadow_size = 0
	b.add_theme_stylebox_override("pressed", pressed)
	var disabled: StyleBoxFlat = sb.duplicate()
	disabled.bg_color = PANEL_BG_DISABLED
	disabled.border_color = Color(DIM.r, DIM.g, DIM.b, 0.4)
	disabled.shadow_size = 0
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", Color("e6d5b0"))
	b.add_theme_color_override("font_focus_color", Color("e6d5b0"))
	b.add_theme_color_override("font_hover_color", Color("e8c547"))
	b.add_theme_color_override("font_pressed_color", Color("e8c547"))
	b.add_theme_color_override("font_disabled_color", DIM)


## Shelf-slot chrome for shop and pick holders: item well on top,
## price row in the bottom 48px. Leaves the flat button chrome alone
## when the kit is absent.
static func style_shop_slot(b: Button) -> void:
	if box("shop_slot_normal") == null:
		return
	b.add_theme_stylebox_override("normal", box("shop_slot_normal"))
	b.add_theme_stylebox_override("hover", box("shop_slot_hover"))
	b.add_theme_stylebox_override("pressed", box("shop_slot_selected"))
	b.add_theme_stylebox_override("disabled", box("shop_slot_disabled"))


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


## Dresses a stock HSlider in the house style: the kit's brass groove
## and ringed grabber when available, flat leather otherwise.
static func style_slider(s: HSlider) -> void:
	var track_art: StyleBoxTexture = box("slider_track")
	if track_art != null:
		s.add_theme_stylebox_override("slider", track_art)
		var fill_art: StyleBoxTexture = box("slider_fill")
		if fill_art != null:
			s.add_theme_stylebox_override("grabber_area", fill_art)
			s.add_theme_stylebox_override("grabber_area_highlight", fill_art)
		if tex("slider_grabber") != null:
			s.add_theme_icon_override("grabber", tex("slider_grabber"))
			s.add_theme_icon_override("grabber_highlight",
					tex("slider_grabber_hover") if tex("slider_grabber_hover") != null
					else tex("slider_grabber"))
		return
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
