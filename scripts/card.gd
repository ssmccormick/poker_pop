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

	var font := ThemeDB.fallback_font
	if washed:
		# The splash hides everything — you'd better remember this card.
		draw_rect(rect.grow(-3), Color(WATER_BLUE.r, WATER_BLUE.g, WATER_BLUE.b, 0.16))
		_draw_pixel_map(DROP_PX, Vector2(0, 2), 5.0, WATER_BLUE)
		_draw_pixel_map(DROP_PX, Vector2(-W / 2.0 + 14, -H / 2.0 + 22), 2.0, WATER_BLUE)
		_draw_pixel_map(DROP_PX, Vector2(W / 2.0 - 16, H / 2.0 - 24), 2.0, WATER_BLUE)
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
	_draw_pixel_map(SUIT_PIXELS[suit], center, px, suit_color())


func _draw_pixel_map(map: Array, center: Vector2, px: float, col: Color) -> void:
	var origin := center - Vector2(map[0].length() * px / 2.0, map.size() * px / 2.0)
	for y in map.size():
		var row: String = map[y]
		for x in row.length():
			if row[x] == "1":
				draw_rect(Rect2(origin + Vector2(x * px, y * px), Vector2(px, px)), col)
