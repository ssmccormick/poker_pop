class_name ShopBackdrop
extends Control

## The traveling merchant's roadside camp, drawn behind the shelves:
## a covered wagon pulled off the trail, a rope of lanterns, crates,
## and packed dirt. Muted colors so the wares stay readable.

const DIRT := Color(0.14, 0.11, 0.08)
const DIRT_EDGE := Color(0.24, 0.185, 0.12)
const WOOD := Color(0.23, 0.17, 0.11)
const WOOD_DARK := Color(0.16, 0.12, 0.08)
const CANVAS := Color(0.32, 0.28, 0.21)
const ROPE := Color(0.3, 0.24, 0.16)
const LANTERN := Color(0.95, 0.78, 0.4)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1920, 1080)


func _draw() -> void:
	# Distant ridge along the top, behind the title.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 190), Vector2(0, 120), Vector2(420, 155), Vector2(900, 105),
		Vector2(1400, 150), Vector2(1920, 115), Vector2(1920, 190)]),
		Color(0.11, 0.09, 0.07))
	# Packed dirt where the wagon pulled off the trail.
	draw_rect(Rect2(0, 820, 1920, 260), DIRT)
	draw_line(Vector2(0, 821), Vector2(1920, 821), DIRT_EDGE, 3.0)
	# Wheel ruts curving off.
	draw_line(Vector2(300, 1080), Vector2(520, 830), Color(0.1, 0.08, 0.06), 9.0)
	draw_line(Vector2(430, 1080), Vector2(600, 832), Color(0.1, 0.08, 0.06), 9.0)

	# The wagon, parked in the left gutter.
	draw_colored_polygon(PackedVector2Array([
		Vector2(40, 700), Vector2(52, 585), Vector2(90, 545), Vector2(255, 545),
		Vector2(292, 585), Vector2(305, 700)]), CANVAS)
	for k in 4:
		var x := 78.0 + k * 48.0
		draw_line(Vector2(x, 552), Vector2(x - 8, 698), Color(0.24, 0.2, 0.15), 3.0)
	draw_rect(Rect2(36, 700, 274, 105), WOOD)
	draw_rect(Rect2(36, 700, 274, 12), WOOD_DARK)
	draw_rect(Rect2(36, 793, 274, 12), WOOD_DARK)
	_wheel(Vector2(110, 852))
	_wheel(Vector2(248, 852))
	# The hitch pole.
	draw_line(Vector2(305, 780), Vector2(400, 830), WOOD_DARK, 8.0)

	# Crate stack under the relic shelf.
	_crate(Rect2(1490, 940, 120, 90))
	_crate(Rect2(1625, 955, 100, 75))
	_crate(Rect2(1530, 862, 100, 74))

	# A sagging rope of lanterns strung across the camp.
	var a := Vector2(120, 132)
	var b := Vector2(1800, 132)
	var pts := PackedVector2Array()
	for i in 25:
		var t := i / 24.0
		var y := lerpf(a.y, b.y, t) + 30.0 * sin(t * PI)
		pts.append(Vector2(lerpf(a.x, b.x, t), y))
	draw_polyline(pts, ROPE, 3.0)
	for t in [0.14, 0.86]:
		var lx := lerpf(a.x, b.x, t)
		var ly := lerpf(a.y, b.y, t) + 46.0 * sin(t * PI) + 6.0
		var glow := LANTERN
		glow.a = 0.10
		draw_circle(Vector2(lx, ly + 14), 34, glow)
		glow.a = 0.2
		draw_circle(Vector2(lx, ly + 14), 18, glow)
		draw_rect(Rect2(lx - 6, ly, 12, 22), Color(0.2, 0.16, 0.1))
		draw_rect(Rect2(lx - 4, ly + 4, 8, 14), LANTERN)


func _wheel(c: Vector2) -> void:
	draw_circle(c, 48, WOOD_DARK)
	draw_circle(c, 40, DIRT)
	for k in 6:
		var d := Vector2.RIGHT.rotated(TAU * k / 6.0) * 40.0
		draw_line(c, c + d, WOOD_DARK, 5.0)
	draw_circle(c, 8, WOOD_DARK)


func _crate(r: Rect2) -> void:
	draw_rect(r, WOOD)
	draw_rect(r, WOOD_DARK, false, 3.0)
	draw_line(r.position, r.end, WOOD_DARK, 3.0)
	draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y),
			WOOD_DARK, 3.0)
