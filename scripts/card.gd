class_name PlayingCard
extends Node2D

## A single card on the board. Draws itself (no textures) centered on its
## origin so scale/rotation tweens pivot from the middle.

const W := 80
const H := 112

const FACE_COLOR := Color("e8e0c8")
const EDGE_COLOR := Color("a89c7d")
const RED := Color("c23b3b")
const BLACK := Color("1a1a1a")
const GOLD := Color("e8c547")

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
static var _shadow_box: StyleBoxFlat

var rank := 2
var suit := 0
var grid_pos := Vector2i.ZERO
var selected := false:
	set(value):
		selected = value
		queue_redraw()


static func _make_boxes() -> void:
	_face_box = StyleBoxFlat.new()
	_face_box.bg_color = FACE_COLOR
	_face_box.set_corner_radius_all(6)
	_face_box.border_color = EDGE_COLOR
	_face_box.set_border_width_all(2)

	_selected_box = _face_box.duplicate()
	_selected_box.border_color = GOLD
	_selected_box.set_border_width_all(4)

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
	return RED if suit == 1 or suit == 2 else BLACK


func _draw() -> void:
	if _face_box == null:
		_make_boxes()
	if selected:
		# Lift the whole card slightly while selected.
		draw_set_transform(Vector2(0, -8))

	var rect := Rect2(-W / 2.0, -H / 2.0, W, H)
	_shadow_box.draw(get_canvas_item(), rect.grow_individual(-2, -2, 4, 6))
	if selected:
		_selected_box.draw(get_canvas_item(), rect)
	else:
		_face_box.draw(get_canvas_item(), rect)

	var col := suit_color()
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-W / 2.0 + 8, -H / 2.0 + 27), rank_text(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)
	_draw_suit(Vector2(-W / 2.0 + 16, -H / 2.0 + 40), 2.0)
	_draw_suit(Vector2(0, 6), 5.0)


## Draws the suit pixel map centered on `center`, one pixel = `px`.
func _draw_suit(center: Vector2, px: float) -> void:
	var map: Array = SUIT_PIXELS[suit]
	var origin := center - Vector2(map[0].length() * px / 2.0, map.size() * px / 2.0)
	var col := suit_color()
	for y in map.size():
		var row: String = map[y]
		for x in row.length():
			if row[x] == "1":
				draw_rect(Rect2(origin + Vector2(x * px, y * px), Vector2(px, px)), col)
