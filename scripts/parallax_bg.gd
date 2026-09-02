class_name ParallaxScene
extends Node2D

## Full-bleed procedural parallax backdrop. Every scene is a static
## sky (gradient bands drawn by this node) plus silhouette layers that
## drift left at different speeds, wrapping over a TILE_W-wide strip.
## Scoring a hand calls lurch() — a decaying speed boost that surges
## the near layers hardest, like the wagon rolling forward.

const TILE_W := 2400.0
const VIEW := Vector2(1920, 1080)
const BASE_NEAR_SPEED := 32.0   # the speed a full lurch is scaled against
const LURCH_DECAY := 3.0        # boost halves ~every 0.23s
const DIM_ALPHA := 0.22         # darkening over the play area
const GUTTER_COLOR := Color(0.1, 0.1, 0.1, 0.88)

var kind := ""
var variant := -1
var _boost := 0.0
var _layers: Array = []
var _sky_bands: Array = []  # {rect: Rect2, color: Color}
var _rng := RandomNumberGenerator.new()


## One drifting silhouette strip. Polygons are laid out across TILE_W
## and drawn twice, so sliding the node's x wraps seamlessly.
class Layer extends Node2D:
	var speed := 10.0
	var tint := Color.WHITE
	var polys: Array = []
	var offset := 0.0

	func _draw() -> void:
		for pass_x in [0.0, ParallaxScene.TILE_W]:
			draw_set_transform(Vector2(pass_x, 0.0), 0.0, Vector2.ONE)
			for p in polys:
				draw_colored_polygon(p, tint)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Gutter panels + play-area dim sit ABOVE every layer, added last
	# in set_scene — built once here as reusable rects.
	z_index = -10


func _process(delta: float) -> void:
	_boost = maxf(0.0, _boost - _boost * LURCH_DECAY * delta)
	for l: Layer in _layers:
		l.offset += (l.speed + _boost * l.speed / BASE_NEAR_SPEED) * delta
		l.position.x = -fposmod(l.offset, TILE_W)


## The wagon rolls forward: a burst of speed that decays away.
func lurch(strength := 1.0) -> void:
	_boost = minf(_boost + 150.0 * strength, 600.0)


func _draw() -> void:
	for band in _sky_bands:
		draw_rect(band.rect, band.color)


# --- Scene construction ---------------------------------------------------

func set_scene(new_kind: String, new_variant := 0) -> void:
	if new_kind == kind and new_variant == variant:
		return
	kind = new_kind
	variant = new_variant
	_rng.seed = hash(kind) * 31 + variant
	for c in get_children():
		c.queue_free()
	_layers.clear()
	_sky_bands.clear()
	match kind:
		"trail_day":
			_sky([Color("6d5a3a"), Color("8a6c42"), Color("a5804e")])
			_add_layer(5, Color("4a3a4a"), _mesas(5, 640, 190))
			_add_layer(12, Color("3c3226"), _ground(700, 26, 2.0) + _cacti(7, 700))
			_add_layer(30, Color("241c12"), _ground(870, 34, 3.0) + _posts(430, 870))
		"trail_dusk":
			_sky([Color("5a2f3a"), Color("87432f"), Color("a05c33")])
			_add_layer(5, Color("39283e"), _mesas(5, 640, 200))
			_add_layer(12, Color("2c2220"), _ground(700, 26, 2.0) + _cacti(6, 700))
			_add_layer(30, Color("17110d"), _ground(870, 34, 3.0) + _posts(460, 870))
		"trail_night":
			_sky([Color("10142a"), Color("161c36"), Color("1c2440")])
			_add_layer(2, Color(0.85, 0.88, 1.0, 0.8), _stars(70, 560))
			_add_layer(5, Color("181430"), _mesas(5, 650, 190))
			_add_layer(12, Color("100e20"), _ground(710, 24, 2.0) + _cacti(5, 710))
			_add_layer(30, Color("07060f"), _ground(880, 30, 3.0) + _posts(500, 880))
		"storm":
			_sky([Color("14181a"), Color("1c2422"), Color("242e28")])
			_add_layer(6, Color("101617"), _spires(7, 660, 260))
			_add_layer(14, Color("0b0f10"), _ground(760, 40, 4.0))
			_add_layer(32, Color("050707"), _ground(890, 40, 5.0) + _dead_trees(5, 890))
		"canyon":
			_sky([Color("8a7040"), Color("a58448"), Color("bf9a54")])
			_add_layer(5, Color("6e3a2a"), _mesas(4, 600, 300))
			_add_layer(13, Color("53291d"), _spires(6, 720, 200))
			_add_layer(30, Color("2f1710"), _ground(880, 36, 3.0) + _boulders(6, 880))
		"plains":
			var hue := fposmod(0.28 + variant * 0.06, 1.0)
			_sky([Color.from_hsv(hue, 0.32, 0.42), Color.from_hsv(hue, 0.36, 0.5),
					Color.from_hsv(hue, 0.4, 0.58)])
			_add_layer(5, Color.from_hsv(hue, 0.42, 0.2), _ground(660, 70, 1.2))
			_add_layer(13, Color.from_hsv(hue, 0.46, 0.14), _ground(770, 60, 1.6))
			_add_layer(30, Color.from_hsv(hue, 0.5, 0.08), _ground(890, 48, 2.2))
		"homestead":
			_sky([Color("4a3050"), Color("74424a"), Color("945840")])
			_add_layer(5, Color("2c2036"), _ground(680, 40, 1.4) + _windmills(2, 680) + _barns(2, 680))
			_add_layer(13, Color("221826"), _ground(790, 30, 2.0))
			_add_layer(30, Color("120d16"), _ground(890, 26, 2.5) + _wheat(880))
		"stars", _:
			_sky([Color("0b0e1e"), Color("101430"), Color("141a3a")])
			_add_layer(1.5, Color(0.9, 0.9, 1.0, 0.75), _stars(90, 700))
			_add_layer(4, Color("0e1024"), _ground(780, 60, 0.8))
			_add_layer(10, Color("070812"), _ground(900, 40, 1.2))
	queue_redraw()
	_add_overlays()


func _sky(colors: Array) -> void:
	var band_h := VIEW.y / colors.size()
	for i in colors.size():
		_sky_bands.append({"rect": Rect2(0, i * band_h, VIEW.x, band_h + 1),
				"color": colors[i]})


func _add_layer(speed: float, tint: Color, polys: Array) -> void:
	var l := Layer.new()
	l.speed = speed
	l.tint = tint
	l.polys = polys
	add_child(l)
	_layers.append(l)


## HUD gutters + play-area dim, above every silhouette.
func _add_overlays() -> void:
	for gutter: Rect2 in [Rect2(0, 0, 370, VIEW.y), Rect2(1550, 0, 370, VIEW.y)]:
		var g := ColorRect.new()
		g.color = GUTTER_COLOR
		g.position = gutter.position
		g.size = gutter.size
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(g)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, DIM_ALPHA)
	dim.position = Vector2(370, 0)
	dim.size = Vector2(1180, VIEW.y)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)


# --- Silhouette generators (all span 0..TILE_W, seam-safe) ----------------

## A rolling ground strip from base_y down to the bottom of the view.
## The first and last ridge points match so the tile wraps cleanly.
func _ground(base_y: float, amp: float, rough: float) -> Array:
	var pts := PackedVector2Array()
	var steps := 40
	var jitter: Array[float] = []
	for i in steps + 1:
		jitter.append(_rng.randf_range(-amp * 0.4, amp * 0.4) * rough * 0.3)
	jitter[steps] = jitter[0]
	for i in steps + 1:
		var x := TILE_W * i / steps
		var y := base_y + sin(TAU * 2.0 * i / steps) * amp * 0.5 \
				+ sin(TAU * 5.0 * i / steps) * amp * 0.25 + jitter[i]
		pts.append(Vector2(x, y))
	pts.append(Vector2(TILE_W, VIEW.y + 4))
	pts.append(Vector2(0, VIEW.y + 4))
	return [pts]


## Flat-topped mesa trapezoids resting a little below base_y.
func _mesas(count: int, base_y: float, h: float) -> Array:
	var out: Array = []
	for i in count:
		var cx := TILE_W * (i + _rng.randf_range(0.15, 0.85)) / count
		var w := _rng.randf_range(160, 340)
		var top := base_y - _rng.randf_range(h * 0.55, h)
		out.append(PackedVector2Array([
			Vector2(cx - w * 0.5, base_y + 60), Vector2(cx - w * 0.32, top),
			Vector2(cx + w * 0.3, top), Vector2(cx + w * 0.5, base_y + 60)]))
	return out


## Saguaro cacti: trunk plus two arms.
func _cacti(count: int, base_y: float) -> Array:
	var out: Array = []
	for i in count:
		var x := TILE_W * (i + _rng.randf_range(0.1, 0.9)) / count
		var h := _rng.randf_range(50, 95)
		out.append(PackedVector2Array([
			Vector2(x - 7, base_y + 20), Vector2(x - 7, base_y - h),
			Vector2(x + 7, base_y - h), Vector2(x + 7, base_y + 20)]))
		out.append(PackedVector2Array([
			Vector2(x - 26, base_y - h * 0.45), Vector2(x - 26, base_y - h * 0.8),
			Vector2(x - 16, base_y - h * 0.8), Vector2(x - 16, base_y - h * 0.45)]))
		out.append(PackedVector2Array([
			Vector2(x + 16, base_y - h * 0.35), Vector2(x + 16, base_y - h * 0.7),
			Vector2(x + 26, base_y - h * 0.7), Vector2(x + 26, base_y - h * 0.35)]))
	return out


## Fence posts with a sagging rail between neighbors.
func _posts(spacing: float, base_y: float) -> Array:
	var out: Array = []
	var x := _rng.randf_range(0, spacing * 0.5)
	while x < TILE_W:
		out.append(PackedVector2Array([
			Vector2(x - 5, base_y + 40), Vector2(x - 5, base_y - 70),
			Vector2(x + 5, base_y - 70), Vector2(x + 5, base_y + 40)]))
		out.append(PackedVector2Array([
			Vector2(x, base_y - 52), Vector2(x + spacing, base_y - 44),
			Vector2(x + spacing, base_y - 36), Vector2(x, base_y - 44)]))
		x += spacing
	return out


## Jagged storm peaks.
func _spires(count: int, base_y: float, h: float) -> Array:
	var out: Array = []
	for i in count:
		var cx := TILE_W * (i + _rng.randf_range(0.2, 0.8)) / count
		var w := _rng.randf_range(120, 260)
		out.append(PackedVector2Array([
			Vector2(cx - w * 0.5, base_y + 60),
			Vector2(cx - w * 0.1, base_y - _rng.randf_range(h * 0.6, h)),
			Vector2(cx + w * 0.15, base_y - h * 0.35),
			Vector2(cx + w * 0.5, base_y + 60)]))
	return out


## Tiny star squares scattered above y_max.
func _stars(count: int, y_max: float) -> Array:
	var out: Array = []
	for i in count:
		var p := Vector2(_rng.randf_range(0, TILE_W), _rng.randf_range(20, y_max))
		var s := _rng.randf_range(2.0, 4.0)
		out.append(PackedVector2Array([
			p, p + Vector2(s, 0), p + Vector2(s, s), p + Vector2(0, s)]))
	return out


## Round-ish boulders (hexagons).
func _boulders(count: int, base_y: float) -> Array:
	var out: Array = []
	for i in count:
		var cx := TILE_W * (i + _rng.randf_range(0.1, 0.9)) / count
		var r := _rng.randf_range(24, 60)
		var poly := PackedVector2Array()
		for k in 6:
			poly.append(Vector2(cx, base_y) + Vector2.RIGHT.rotated(TAU * k / 6.0) * r \
					* Vector2(1.0, 0.7))
		out.append(poly)
	return out


## Bare, forked dead trees.
func _dead_trees(count: int, base_y: float) -> Array:
	var out: Array = []
	for i in count:
		var x := TILE_W * (i + _rng.randf_range(0.15, 0.85)) / count
		var h := _rng.randf_range(80, 140)
		out.append(PackedVector2Array([
			Vector2(x - 6, base_y + 30), Vector2(x - 3, base_y - h),
			Vector2(x + 3, base_y - h), Vector2(x + 6, base_y + 30)]))
		out.append(PackedVector2Array([
			Vector2(x, base_y - h * 0.55), Vector2(x + h * 0.35, base_y - h * 0.9),
			Vector2(x + h * 0.38, base_y - h * 0.82), Vector2(x + 4, base_y - h * 0.48)]))
		out.append(PackedVector2Array([
			Vector2(x, base_y - h * 0.4), Vector2(x - h * 0.3, base_y - h * 0.68),
			Vector2(x - h * 0.33, base_y - h * 0.6), Vector2(x - 4, base_y - h * 0.34)]))
	return out


## Windmill towers with a cross of blades.
func _windmills(count: int, base_y: float) -> Array:
	var out: Array = []
	for i in count:
		var x := TILE_W * (i + _rng.randf_range(0.25, 0.75)) / count
		var h := _rng.randf_range(150, 210)
		out.append(PackedVector2Array([
			Vector2(x - 26, base_y + 30), Vector2(x - 6, base_y - h),
			Vector2(x + 6, base_y - h), Vector2(x + 26, base_y + 30)]))
		for k in 4:
			var dir := Vector2.RIGHT.rotated(TAU * k / 4.0 + 0.5)
			var tip := Vector2(x, base_y - h) + dir * 52.0
			var perp := Vector2(-dir.y, dir.x) * 7.0
			out.append(PackedVector2Array([
				Vector2(x, base_y - h) + perp, tip + perp * 0.4,
				tip - perp * 0.4, Vector2(x, base_y - h) - perp]))
	return out


## Low barns with peaked roofs.
func _barns(count: int, base_y: float) -> Array:
	var out: Array = []
	for i in count:
		var x := TILE_W * (i + _rng.randf_range(0.2, 0.8)) / count + 500.0
		x = fmod(x, TILE_W)
		var w := _rng.randf_range(110, 170)
		var h := _rng.randf_range(60, 90)
		out.append(PackedVector2Array([
			Vector2(x - w * 0.5, base_y + 30), Vector2(x - w * 0.5, base_y - h * 0.55),
			Vector2(x, base_y - h), Vector2(x + w * 0.5, base_y - h * 0.55),
			Vector2(x + w * 0.5, base_y + 30)]))
	return out


## A row of wheat-stalk triangles along the near ridge.
func _wheat(base_y: float) -> Array:
	var out: Array = []
	var x := 0.0
	while x < TILE_W:
		var h := _rng.randf_range(26, 52)
		out.append(PackedVector2Array([
			Vector2(x - 4, base_y + 10), Vector2(x + _rng.randf_range(-4, 4), base_y - h),
			Vector2(x + 4, base_y + 10)]))
		x += _rng.randf_range(26, 48)
	return out
