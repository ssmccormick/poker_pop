class_name RelicIcon
extends Node2D

## A small code-drawn emblem for one relic, on a dark leather disc.
## Used on merchant shelves; ~34 px radius.

const DISC := Color("241c12")
const RIM := Color("6e5a3a")
const GOLD := Color("e8c547")
const OFFWHITE := Color("e8e0c8")
const RED := Color("c23b3b")
const STEEL := Color("9aa0ad")
const WOOD := Color("8a6a42")
const CANVAS := Color("cbb68f")
const WIND := Color("9ec9d8")

var relic_id := "":
	set(value):
		relic_id = value
		queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 34, DISC)
	draw_arc(Vector2.ZERO, 32, 0, TAU, 40, RIM, 2.5)
	match relic_id:
		"horseshoe":
			# Open end down, lucky side up.
			draw_arc(Vector2(0, 2), 15, 0.8 * PI, 2.2 * PI, 24, GOLD, 7.0)
			draw_rect(Rect2(-17, 6, 6, 5), GOLD)
			draw_rect(Rect2(11, 6, 6, 5), GOLD)
		"card_sleeve":
			draw_rect(Rect2(-18, -16, 20, 28), Color(0.75, 0.72, 0.62))
			draw_rect(Rect2(-4, -12, 20, 28), OFFWHITE)
			draw_circle(Vector2(6, 2), 4, RED)
		"snake_oil":
			draw_rect(Rect2(-8, -6, 16, 22), Color(0.35, 0.5, 0.35))
			draw_rect(Rect2(-4, -14, 8, 8), Color(0.35, 0.5, 0.35))
			draw_rect(Rect2(-4, -18, 8, 4), GOLD)
			draw_rect(Rect2(-6, 0, 12, 8), OFFWHITE)
		"tin_star":
			var pts := PackedVector2Array()
			for k in 10:
				var r := 18.0 if k % 2 == 0 else 7.5
				pts.append(Vector2.UP.rotated(TAU * k / 10.0) * r)
			draw_colored_polygon(pts, STEEL)
			draw_circle(Vector2.ZERO, 3, Color(0.55, 0.58, 0.64))
		"rabbits_foot":
			draw_circle(Vector2(0, -8), 7, CANVAS)
			draw_circle(Vector2(0, 8), 9, CANVAS)
			draw_rect(Rect2(-7, -8, 14, 16), CANVAS)
			for k in 3:
				draw_circle(Vector2(-6 + k * 6, 16), 3, CANVAS)
			draw_arc(Vector2(0, -18), 5, 0, TAU, 12, GOLD, 2.0)
		"bomb_badge":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-15, -14), Vector2(15, -14), Vector2(13, 6),
				Vector2(0, 18), Vector2(-13, 6)]), STEEL)
			draw_circle(Vector2(0, -1), 7, Color("141414"))
			draw_line(Vector2(4, -6), Vector2(9, -11), WOOD, 2.5)
		"chisel":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-4, -18), Vector2(4, -18), Vector2(4, 2),
				Vector2(0, 8), Vector2(-4, 2)]), STEEL)
			draw_rect(Rect2(-5, -18, 10, -1), STEEL)
			draw_rect(Rect2(-6, 8, 12, 12), WOOD)
		"fire_blanket":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-4, -18), Vector2(4, -14), Vector2(0, -8)]), Color("e07830"))
			draw_rect(Rect2(-16, -8, 32, 22), Color(0.55, 0.35, 0.3))
			draw_rect(Rect2(-16, 0, 32, 4), OFFWHITE)
		"weathervane":
			draw_line(Vector2(0, -4), Vector2(0, 16), STEEL, 3.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-8, 16), Vector2(8, 16), Vector2(0, 10)]), STEEL)
			draw_line(Vector2(-14, -6), Vector2(10, -6), GOLD, 3.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(16, -6), Vector2(8, -11), Vector2(8, -1)]), GOLD)
			draw_rect(Rect2(-16, -10, 4, 8), GOLD)
		"magnifying_glass":
			draw_arc(Vector2(-4, -6), 11, 0, TAU, 24, GOLD, 3.5)
			draw_line(Vector2(4, 2), Vector2(14, 14), WOOD, 5.0)
		"gold_tooth":
			draw_circle(Vector2(-5, -6), 6, GOLD)
			draw_circle(Vector2(5, -6), 6, GOLD)
			draw_rect(Rect2(-11, -6, 22, 8), GOLD)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-10, 2), Vector2(-2, 2), Vector2(-7, 14)]), GOLD)
			draw_colored_polygon(PackedVector2Array([
				Vector2(2, 2), Vector2(10, 2), Vector2(7, 14)]), GOLD)
		"mirror_shades":
			draw_circle(Vector2(-9, 0), 8, Color(0.16, 0.18, 0.22))
			draw_circle(Vector2(9, 0), 8, Color(0.16, 0.18, 0.22))
			draw_arc(Vector2(-9, 0), 8, 0, TAU, 20, STEEL, 2.0)
			draw_arc(Vector2(9, 0), 8, 0, TAU, 20, STEEL, 2.0)
			draw_line(Vector2(-2, -2), Vector2(2, -2), STEEL, 2.0)
			draw_line(Vector2(-16, -3), Vector2(-20, -8), STEEL, 2.0)
			draw_line(Vector2(16, -3), Vector2(20, -8), STEEL, 2.0)
		"second_wind":
			draw_arc(Vector2(-2, -6), 10, PI * 0.2, PI * 1.3, 16, WIND, 3.5)
			draw_arc(Vector2(2, 6), 8, PI * 1.2, PI * 2.3, 16, WIND, 3.5)
			draw_circle(Vector2(7, -13), 2.5, WIND)
			draw_circle(Vector2(-5, 12), 2.0, WIND)
		"bankroll_clip":
			draw_rect(Rect2(-15, -10, 30, 9), Color(0.45, 0.6, 0.42))
			draw_rect(Rect2(-13, -3, 30, 9), Color(0.5, 0.66, 0.46))
			draw_rect(Rect2(-11, 4, 30, 9), Color(0.55, 0.72, 0.5))
			draw_rect(Rect2(-4, -13, 10, 30), GOLD)
			draw_rect(Rect2(-1, -10, 4, 24), Color(0.7, 0.58, 0.2))
		"dowsing_rod":
			draw_line(Vector2(0, 16), Vector2(0, 0), WOOD, 4.0)
			draw_line(Vector2(0, 0), Vector2(-11, -14), WOOD, 4.0)
			draw_line(Vector2(0, 0), Vector2(11, -14), WOOD, 4.0)
		"saddlebags":
			# Two leather pouches draped over the saddle line.
			draw_line(Vector2(-19, -9), Vector2(19, -9), WOOD, 3.5)
			draw_rect(Rect2(-17, -9, 14, 20), Color(0.45, 0.32, 0.2))
			draw_rect(Rect2(3, -9, 14, 20), Color(0.45, 0.32, 0.2))
			draw_rect(Rect2(-17, -2, 14, 4), WOOD)
			draw_rect(Rect2(3, -2, 14, 4), WOOD)
			draw_circle(Vector2(-10, 6), 2.2, GOLD)
			draw_circle(Vector2(10, 6), 2.2, GOLD)
		"lucky_chip":
			draw_circle(Vector2.ZERO, 16, RED)
			for k in 6:
				var a := TAU * k / 6.0
				var mid := Vector2.RIGHT.rotated(a) * 14.0
				draw_line(mid * 0.82, mid * 1.14, OFFWHITE, 5.0)
			draw_circle(Vector2.ZERO, 9, Color(0.85, 0.32, 0.32))
			draw_circle(Vector2.ZERO, 3.5, OFFWHITE)
		_:
			var font: Font = ThemeDB.fallback_font
			draw_string(font, Vector2(-8, 9), "?", HORIZONTAL_ALIGNMENT_CENTER,
					16, 26, GOLD)
