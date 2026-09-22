class_name TableSurface
extends Node2D

## The card table drawn under the board: a beveled wood rim, a felt
## top with a soft inset vignette, and a shallow slot per cell so
## empty cells read as dealt-out places at the table. Pure drawing —
## no tree, audio, or particle access, so it is safe on the detached
## boards the headless tests build.

const RIM_W := 22.0
const FELT_PAD := 8.0

var cols := 5
var rows := 5
var felt := Color("25201a")
var rim := Color("3a2a1c")


func _init() -> void:
	z_index = -1


func setup(new_cols: int, new_rows: int) -> void:
	cols = new_cols
	rows = new_rows
	queue_redraw()


func retheme() -> void:
	var t := Themes.current()
	felt = Color(String(t.get("felt", "25201a")))
	rim = Color(String(t.get("rim", "3a2a1c")))
	queue_redraw()


func _draw() -> void:
	var px := Vector2(cols * Board.CELL_W - Board.GAP, rows * Board.CELL_H - Board.GAP)
	# Wood rim with a three-tone bevel.
	var rim_rect := Rect2(Vector2(-RIM_W - FELT_PAD, -RIM_W - FELT_PAD),
			px + Vector2.ONE * (RIM_W + FELT_PAD) * 2.0)
	_rounded(rim_rect, rim, 16.0)
	draw_rect(Rect2(rim_rect.position + Vector2(6, 3),
			Vector2(rim_rect.size.x - 12, 3)), rim.lightened(0.28))
	draw_rect(Rect2(Vector2(rim_rect.position.x + 6, rim_rect.end.y - 6),
			Vector2(rim_rect.size.x - 12, 3)), rim.darkened(0.35))
	# The felt.
	var felt_rect := Rect2(Vector2(-FELT_PAD, -FELT_PAD),
			px + Vector2.ONE * FELT_PAD * 2.0)
	_rounded(felt_rect, felt, 10.0)
	# Soft inset vignette: stacked whisper-thin frames.
	for i in 3:
		draw_rect(felt_rect.grow(-2.0 - i * 3.0),
				Color(0, 0, 0, 0.10 - i * 0.03), false, 3.0)
	# One shallow slot per cell.
	var slot := felt.darkened(0.18)
	var slot_edge := felt.lightened(0.10)
	for y in rows:
		for x in cols:
			var c := Vector2(x * Board.CELL_W + PlayingCard.W / 2.0,
					y * Board.CELL_H + PlayingCard.H / 2.0)
			var r := Rect2(c - Vector2(PlayingCard.W / 2.0 + 3.0,
					PlayingCard.H / 2.0 + 3.0),
					Vector2(PlayingCard.W + 6.0, PlayingCard.H + 6.0))
			_rounded(r, slot, 8.0)
			draw_line(Vector2(r.position.x + 4.0, r.end.y),
					Vector2(r.end.x - 4.0, r.end.y), slot_edge, 1.5)


## A rounded rect out of one rect and four corner circles — cheap and
## clean at these radii.
func _rounded(r: Rect2, col: Color, radius: float) -> void:
	draw_rect(Rect2(r.position + Vector2(radius, 0),
			Vector2(r.size.x - radius * 2.0, r.size.y)), col)
	draw_rect(Rect2(r.position + Vector2(0, radius),
			Vector2(r.size.x, r.size.y - radius * 2.0)), col)
	for corner in [r.position + Vector2(radius, radius),
			Vector2(r.end.x - radius, r.position.y + radius),
			Vector2(r.position.x + radius, r.end.y - radius),
			r.end - Vector2(radius, radius)]:
		draw_circle(corner, radius, col)
