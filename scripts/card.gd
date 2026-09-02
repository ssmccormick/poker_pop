class_name PlayingCard
extends Node2D

## A single card on the board. Draws itself (no textures) centered on its
## origin so scale/rotation tweens pivot from the middle.

const W := 80
const H := 112

const GOLD := Color("e8c547")
const GREEN := Color("90e07c")
const ERROR_RED := Color("e05252")
const BLACK := Color("1a1a1a")
const FIRE_ORANGE := Color("e07830")
const WATER_BLUE := Color("6fa8c9")
const WIND_BLUE := Color("9ec9d8")
const BOOST_GREEN := Color("52d67e")
const WILD_PURPLE := Color("b06fd8")
const STONE_GRAY := Color(0.42, 0.42, 0.48, 0.4)
const BOMB_BLACK := Color("141414")

const FLAME_PX := [
	"0001000",
	"0011000",
	"0011100",
	"0111110",
	"1111111",
	"1110111",
	"0111110",
	"0011100",
]
const DROP_PX := [
	"00100",
	"00100",
	"01110",
	"11111",
	"11111",
	"01110",
]
const KEY_PX := [
	"0111000000",
	"1101000000",
	"1101111111",
	"1101000101",
	"0111000101",
]
const CHEST_PX := [
	"01111110",
	"11111111",
	"10111101",
	"11111111",
	"10100101",
	"10111101",
	"11111111",
]
const SAFE_STEEL := Color("6e737c")
const SAFE_DARK := Color("4a4e56")
const CROWN_PX := [
	"101010101",
	"111111111",
	"011111110",
	"011111110",
]
const HONEY_AMBER := Color(0.92, 0.68, 0.18, 0.4)
const SNAKE_GREEN := Color("3f7d4e")
const SNAKE_DARK := Color("24462c")

# suit ids: 0 = spades, 1 = hearts, 2 = diamonds, 3 = clubs
const SUIT_NAMES := ["Spades", "Hearts", "Diamonds", "Clubs"]

const SPADE_PX := [
	"0001000",
	"0011100",
	"0111110",
	"1111111",
	"1111111",
	"0110110",
	"0001000",
	"0011100",
]
const HEART_PX := [
	"0110110",
	"1111111",
	"1111111",
	"1111111",
	"0111110",
	"0011100",
	"0001000",
]
const DIAMOND_PX := [
	"0001000",
	"0011100",
	"0111110",
	"1111111",
	"0111110",
	"0011100",
	"0001000",
]
const CLUB_PX := [
	"000111000",
	"001111100",
	"000111000",
	"110111011",
	"111111111",
	"110111011",
	"000010000",
	"001111100",
]
const SUIT_PIXELS := [SPADE_PX, HEART_PX, DIAMOND_PX, CLUB_PX]

# Magnifying Glass relic: soaked cards still reveal their suit.
static var washed_show_suit := false

static var _face_box: StyleBoxFlat
static var _selected_box: StyleBoxFlat
static var _valid_box: StyleBoxFlat
static var _error_box: StyleBoxFlat
static var _shadow_box: StyleBoxFlat

var rank := 2:
	set(value):
		rank = value
		queue_redraw()
var suit := 0
var grid_pos := Vector2i.ZERO
var selected := false:
	set(value):
		selected = value
		queue_redraw()
var chain_index := 0:
	set(value):
		chain_index = value
		queue_redraw()
var hand_valid := false:  # selection currently forms a playable hand
	set(value):
		hand_valid = value
		queue_redraw()
var cursed := false:  # trail-mode dead weight: unselectable, blocks chains
	set(value):
		cursed = value
		queue_redraw()
# Trail hazards: "", "bomb", "fire", "wind", "stone", "water".
var hazard := "":
	set(value):
		hazard = value
		queue_redraw()
var fuse := 0:  # bomb: hands until detonation
	set(value):
		fuse = value
		queue_redraw()
var stone_hits := 0:  # stone: scoring uses left
	set(value):
		stone_hits = value
		queue_redraw()
var wind_dir := Vector2i.RIGHT:
	set(value):
		wind_dir = value
		queue_redraw()
var washed := false:  # splashed: rank/suit hidden from the player
	set(value):
		washed = value
		queue_redraw()
# Deck enhancement (trail): "", "chip" (bonus chips when played),
# "mult" (multiplies the hand it's in), "gold" ($1 real cash when
# played), "plus"/"minus" (clearing it raises/lowers the card the
# arrow points at by one rank), "wild" (counts as any rank and suit).
var mod := "":
	set(value):
		mod = value
		queue_redraw()
# The EXPLOSION rider: clearing this card spreads its mod to every
# adjacent card. Rides on top of any mod (chip, gold, plus...).
var boom := false:
	set(value):
		boom = value
		queue_redraw()
var boost_dir := Vector2i.RIGHT:  # plus/minus: the arrow, turning each hand
	set(value):
		boost_dir = value
		queue_redraw()
# Objectives (trail): "", "key", "chest".
var objective := "":
	set(value):
		objective = value
		queue_redraw()
# The locked safe (trail heists): shows a 4-digit combination.
var is_safe := false:
	set(value):
		is_safe = value
		queue_redraw()
var combo: Array = []
var combo_progress := 0:  # matched prefix digits, lit up green
	set(value):
		combo_progress = value
		queue_redraw()
# Bosses (trail): "", "jack", "queen", "cobra".
var boss := "":
	set(value):
		boss = value
		queue_redraw()
var boss_hp := 0:
	set(value):
		boss_hp = value
		queue_redraw()
var honey := false:  # Queen Bee's spread: only 2-3 card hands clear it
	set(value):
		honey = value
		queue_redraw()
var snake_tail := false:  # King Cobra body segment: a wall
	set(value):
		snake_tail = value
		queue_redraw()
var cobra_body: Array = []   # head only: segment cards, closest-first
var cobra_stack: Array = []  # head only: identities to revert through
var stunned := false:
	set(value):
		stunned = value
		queue_redraw()
var error_flash := false:  # brief red border after an invalid submit
	set(value):
		error_flash = value
		queue_redraw()


## Invalidates the cached styleboxes; call after a theme change.
static func rebuild_theme() -> void:
	_face_box = null


static func _make_boxes() -> void:
	var t := Themes.current()
	_face_box = StyleBoxFlat.new()
	_face_box.bg_color = t.face
	_face_box.set_corner_radius_all(6)
	_face_box.border_color = t.edge
	_face_box.set_border_width_all(2)

	_selected_box = _face_box.duplicate()
	_selected_box.border_color = GOLD
	_selected_box.set_border_width_all(4)

	_valid_box = _selected_box.duplicate()
	_valid_box.border_color = GREEN

	_error_box = _selected_box.duplicate()
	_error_box.border_color = ERROR_RED

	_shadow_box = StyleBoxFlat.new()
	_shadow_box.bg_color = Color(0, 0, 0, 0.35)
	_shadow_box.set_corner_radius_all(6)


func rank_text() -> String:
	match rank:
		11: return "J"
		12: return "Q"
		13: return "K"
		14: return "A"
		_: return str(rank)


func suit_color() -> Color:
	var t := Themes.current()
	return t.red if suit == 1 or suit == 2 else t.black


func _draw() -> void:
	if _face_box == null:
		_make_boxes()
	if selected:
		# Lift the whole card slightly while selected.
		draw_set_transform(Vector2(0, -8))

	var rect := Rect2(-W / 2.0, -H / 2.0, W, H)
	_shadow_box.draw(get_canvas_item(), rect.grow_individual(-2, -2, 4, 6))
	if selected:
		var box := _selected_box
		if error_flash:
			box = _error_box
		elif hand_valid:
			box = _valid_box
		box.draw(get_canvas_item(), rect)
	else:
		_face_box.draw(get_canvas_item(), rect)
	# Optional per-theme card-base art (drop into assets/cards/).
	var face_tex := Themes.face_texture()
	if face_tex != null:
		draw_texture_rect(face_tex, rect.grow(-3), false)
	else:
		# Subtle two-tone inner edge so flat faces read less flat.
		draw_rect(Rect2(rect.position + Vector2(3, 3), Vector2(rect.size.x - 6, 2)),
				Color(1, 1, 1, 0.28))
		draw_rect(Rect2(rect.position + Vector2(3, 3), Vector2(2, rect.size.y - 6)),
				Color(1, 1, 1, 0.18))
		draw_rect(Rect2(Vector2(rect.position.x + 3, rect.end.y - 5),
				Vector2(rect.size.x - 6, 2)), Color(0, 0, 0, 0.13))
		draw_rect(Rect2(Vector2(rect.end.x - 5, rect.position.y + 3),
				Vector2(2, rect.size.y - 6)), Color(0, 0, 0, 0.10))

	var font: Font = FontLib.card if FontLib.card != null else ThemeDB.fallback_font
	if snake_tail:
		# Cobra body: a scaled green wall.
		draw_rect(rect.grow(-3), SNAKE_GREEN)
		for i in 5:
			var y := -H / 2.0 + 12 + i * 20.0
			draw_line(Vector2(-W / 2.0 + 6, y), Vector2(W / 2.0 - 6, y + 10), SNAKE_DARK, 3.0)
		if selected and chain_index > 0:
			pass
		return
	if is_safe:
		# The locked safe: steel face, dial, and the combination on show.
		draw_rect(rect.grow(-3), SAFE_STEEL)
		draw_circle(Vector2(0, 12), 16, SAFE_DARK)
		draw_circle(Vector2(0, 12), 6, SAFE_STEEL)
		draw_line(Vector2(0, 12), Vector2(0, -2), Color("2c2f35"), 3.0)
		for i in combo.size():
			var digit_col := GREEN if i < combo_progress else Color("e8e0c8")
			draw_string(font, Vector2(-W / 2.0 + 4 + i * 18, -H / 2.0 + 28),
					str(combo[i]), HORIZONTAL_ALIGNMENT_CENTER, 16, 17, digit_col)
		if selected:
			pass  # border/badge drawn below as usual
	elif washed:
		# The splash hides everything — you'd better remember this card.
		draw_rect(rect.grow(-3), Color(WATER_BLUE.r, WATER_BLUE.g, WATER_BLUE.b, 0.16))
		_draw_pixel_map(DROP_PX, Vector2(0, 2), 5.0, WATER_BLUE)
		_draw_pixel_map(DROP_PX, Vector2(-W / 2.0 + 14, -H / 2.0 + 22), 2.0, WATER_BLUE)
		_draw_pixel_map(DROP_PX, Vector2(W / 2.0 - 16, H / 2.0 - 24), 2.0, WATER_BLUE)
		if washed_show_suit:  # Magnifying Glass
			_draw_suit(Vector2(-W / 2.0 + 16, -H / 2.0 + 40), 2.0)
	else:
		var col := suit_color()
		draw_string(font, Vector2(-W / 2.0 + 8, -H / 2.0 + 27), rank_text(),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)
		_draw_suit(Vector2(-W / 2.0 + 16, -H / 2.0 + 40), 2.0)
		_draw_suit(Vector2(0, 6), 5.0)

	match hazard:
		"bomb":
			var c := Vector2(-W / 2.0 + 16, H / 2.0 - 17)
			draw_circle(c, 12, BOMB_BLACK)
			draw_rect(Rect2(c + Vector2(6, -14), Vector2(4, 4)), ERROR_RED)
			draw_string(font, c + Vector2(-10, 5), str(fuse),
					HORIZONTAL_ALIGNMENT_CENTER, 20, 14, Color.WHITE)
		"fire":
			_draw_pixel_map(FLAME_PX, Vector2(W / 2.0 - 14, H / 2.0 - 15), 3.0, FIRE_ORANGE)
		"wind":
			var base := Vector2(W / 2.0 - 18, H / 2.0 - 17)
			var v := Vector2(wind_dir) * 11.0
			var perp := Vector2(-v.y, v.x).normalized() * 6.0
			draw_line(base - v, base + v, WIND_BLUE, 4.0)
			draw_colored_polygon(PackedVector2Array([
				base + v * 1.5, base + v * 0.5 + perp, base + v * 0.5 - perp]), WIND_BLUE)
		"stone":
			draw_rect(rect.grow(-2), STONE_GRAY)
			for i in stone_hits:
				draw_rect(Rect2(-13.0 + i * 10.0, H / 2.0 - 16.0, 7, 7), Color("3a3a40"))
		"water":
			_draw_pixel_map(DROP_PX, Vector2(W / 2.0 - 14, H / 2.0 - 15), 3.0, WATER_BLUE)

	var mod_anchor := Vector2(W / 2.0 - 13, -H / 2.0 + 36)
	match mod:
		"chip":
			draw_circle(mod_anchor, 9, GOLD)
			draw_circle(mod_anchor, 5, Color("a8842c"))
		"mult":
			draw_string(font, Vector2(W / 2.0 - 24, -H / 2.0 + 45), "×",
					HORIZONTAL_ALIGNMENT_CENTER, 22, 24, ERROR_RED)
		"gold":
			# A nugget: rough gold lump with a glint.
			draw_colored_polygon(PackedVector2Array([
				mod_anchor + Vector2(-8, 3), mod_anchor + Vector2(-5, -6),
				mod_anchor + Vector2(2, -8), mod_anchor + Vector2(8, -2),
				mod_anchor + Vector2(6, 6), mod_anchor + Vector2(-3, 8)]), GOLD)
			draw_rect(Rect2(mod_anchor + Vector2(-2, -4), Vector2(3, 3)),
					Color(1.0, 0.95, 0.7))
		"wild":
			draw_string(font, Vector2(W / 2.0 - 24, -H / 2.0 + 45), "W",
					HORIZONTAL_ALIGNMENT_CENTER, 22, 24, WILD_PURPLE)
		"bumper":
			var bb := Vector2(W / 2.0 - 15, -H / 2.0 + 38)
			var bv := Vector2(boost_dir) * 9.0
			var bperp := Vector2(-bv.y, bv.x).normalized()
			# The pad, then the shove arrow.
			draw_line(bb - bv * 0.6 + bperp * 8.0, bb - bv * 0.6 - bperp * 8.0,
					WIND_BLUE, 5.0)
			var btip := bb + bv * 1.4
			draw_line(bb - bv * 0.2, btip, WIND_BLUE, 3.0)
			draw_colored_polygon(PackedVector2Array([
				btip + bv * 0.35, btip - bv * 0.25 + bperp * 4.0,
				btip - bv * 0.25 - bperp * 4.0]), WIND_BLUE)
		"plus", "minus":
			var base := Vector2(W / 2.0 - 15, -H / 2.0 + 38)
			var col := BOOST_GREEN if mod == "plus" else ERROR_RED
			# The sign...
			draw_rect(Rect2(base + Vector2(-7, -2), Vector2(10, 4)), col)
			if mod == "plus":
				draw_rect(Rect2(base + Vector2(-4, -5), Vector2(4, 10)), col)
			# ...and the aim arrow, turning each hand.
			var v := Vector2(boost_dir) * 9.0
			var perp := Vector2(-v.y, v.x).normalized() * 4.0
			var tip := base + v * 1.6
			draw_line(base + v * 0.8, tip, col, 3.0)
			draw_colored_polygon(PackedVector2Array([
				tip + v * 0.4, tip - v * 0.3 + perp, tip - v * 0.3 - perp]), col)
	if boom and mod != "":
		# Explosion rider: rays around whatever the mod glyph is.
		for k in 8:
			var ray := Vector2.RIGHT.rotated(k * PI / 4.0 + PI / 8.0)
			draw_line(mod_anchor + ray * 11.0, mod_anchor + ray * 15.0,
					FIRE_ORANGE, 2.5)

	match objective:
		"key":
			_draw_pixel_map(KEY_PX, Vector2(W / 2.0 - 22, H / 2.0 - 14), 3.0, GOLD)
		"chest":
			_draw_pixel_map(CHEST_PX, Vector2(W / 2.0 - 16, H / 2.0 - 15), 3.0, Color("b07f3e"))

	if honey:
		draw_rect(rect.grow(-2), HONEY_AMBER)
		_draw_pixel_map(DROP_PX, Vector2(W / 2.0 - 14, H / 2.0 - 15), 2.5, Color("c98a1e"))

	match boss:
		"jack":
			_draw_pixel_map(CROWN_PX, Vector2(0, -H / 2.0 + 8), 3.0, GOLD)
			var bc := Vector2(-W / 2.0 + 16, H / 2.0 - 17)
			draw_circle(bc, 12, ERROR_RED)
			draw_string(font, bc + Vector2(-10, 5), str(boss_hp),
					HORIZONTAL_ALIGNMENT_CENTER, 20, 14, Color.WHITE)
		"queen":
			_draw_pixel_map(CROWN_PX, Vector2(0, -H / 2.0 + 8), 3.0, GOLD)
			for i in boss_hp:
				draw_rect(Rect2(-21.0 + i * 15.0, H / 2.0 - 16.0, 12, 8),
						Color(0.92, 0.68, 0.18))
		"cobra":
			draw_rect(rect.grow(-2), SNAKE_GREEN, false, 5.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-14, H / 2.0 - 20), Vector2(-8, H / 2.0 - 8), Vector2(-2, H / 2.0 - 20)]), SNAKE_DARK)
			draw_colored_polygon(PackedVector2Array([
				Vector2(2, H / 2.0 - 20), Vector2(8, H / 2.0 - 8), Vector2(14, H / 2.0 - 20)]), SNAKE_DARK)
			if stunned:
				draw_string(font, Vector2(-W / 2.0, -H / 2.0 - 4), "zzz",
						HORIZONTAL_ALIGNMENT_CENTER, W, 18, WIND_BLUE)

	if cursed:
		# Darken the face and slash it out.
		draw_rect(rect.grow(-2), Color(0.05, 0.05, 0.08, 0.62))
		var a := rect.position + Vector2(14, 18)
		var b := rect.end - Vector2(14, 18)
		draw_line(a, b, ERROR_RED, 5.0)
		draw_line(Vector2(b.x, a.y), Vector2(a.x, b.y), ERROR_RED, 5.0)

	if selected and chain_index > 0:
		# Chain-order badge, tinted to match the border state.
		var badge_color := GOLD
		if error_flash:
			badge_color = ERROR_RED
		elif hand_valid:
			badge_color = GREEN
		var badge_center := Vector2(W / 2.0 - 13, -H / 2.0 + 13)
		draw_circle(badge_center, 10, badge_color)
		draw_string(font, badge_center + Vector2(-10, 5.5), str(chain_index),
				HORIZONTAL_ALIGNMENT_CENTER, 20, 15, BLACK)


## Draws the suit pixel map centered on `center`, one pixel = `px`.
func _draw_suit(center: Vector2, px: float) -> void:
	if Themes.current().get("suit_style", "pixel") == "vector":
		_draw_suit_vector(center, px)
	else:
		_draw_pixel_map(SUIT_PIXELS[suit], center, px, suit_color())


## Smooth polygon suits for "vector" themes. Sized to match the pixel
## maps (~7px wide at scale 1).
func _draw_suit_vector(c: Vector2, px: float) -> void:
	var col := suit_color()
	var r := 3.6 * px
	match suit:
		0:  # spades — one tall sharp point over small low lobes
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -r * 1.05), c + Vector2(r * 0.8, r * 0.38),
				c + Vector2(-r * 0.8, r * 0.38)]), col)
			draw_circle(c + Vector2(-r * 0.42, r * 0.28), r * 0.42, col)
			draw_circle(c + Vector2(r * 0.42, r * 0.28), r * 0.42, col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.28, r), c + Vector2(r * 0.28, r),
				c + Vector2(0, r * 0.3)]), col)
		1:  # hearts
			draw_circle(c + Vector2(-r * 0.45, -r * 0.3), r * 0.52, col)
			draw_circle(c + Vector2(r * 0.45, -r * 0.3), r * 0.52, col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.93, -r * 0.08), c + Vector2(r * 0.93, -r * 0.08),
				c + Vector2(0, r)]), col)
		2:  # diamonds
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r * 0.72, 0),
				c + Vector2(0, r), c + Vector2(-r * 0.72, 0)]), col)
		3:  # clubs — a clearly separated trefoil and a stem
			draw_circle(c + Vector2(0, -r * 0.55), r * 0.4, col)
			draw_circle(c + Vector2(-r * 0.52, r * 0.22), r * 0.4, col)
			draw_circle(c + Vector2(r * 0.52, r * 0.22), r * 0.4, col)
			draw_circle(c + Vector2(0, r * 0.02), r * 0.2, col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.24, r), c + Vector2(r * 0.24, r),
				c + Vector2(0, r * 0.1)]), col)


func _draw_pixel_map(map: Array, center: Vector2, px: float, col: Color) -> void:
	var origin := center - Vector2(map[0].length() * px / 2.0, map.size() * px / 2.0)
	for y in map.size():
		var row: String = map[y]
		for x in row.length():
			if row[x] == "1":
				draw_rect(Rect2(origin + Vector2(x * px, y * px), Vector2(px, px)), col)
