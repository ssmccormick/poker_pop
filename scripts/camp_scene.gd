class_name CampScene
extends Node2D

## The campfire's living backdrop: night sky, the camp off the
## trail, the CHOSEN RIDER on the log, and a fire that actually
## burns — pulsing glow, three flame frames at ~8 fps, sparks
## drifting up, smoke crawling into the dark. Layer stack and
## positions from campfire_index.json; hidden when the kit is absent.

const DIR := "res://assets/art/campfire/scene/"

var _glow: Sprite2D
var _rider: Sprite2D
var _flames: Array = []
var _sparks: Array = []
var _smoke: Sprite2D
var _t := 0.0


## Builds (or rebuilds) the stack. Returns false when the kit's art
## is missing, so the caller can keep its plain backdrop.
func setup(rider_id: String) -> bool:
	for c in get_children():
		c.queue_free()
	_flames.clear()
	_sparks.clear()
	if not ResourceLoader.exists(DIR + "sky.png"):
		visible = false
		return false
	visible = true
	_layer("sky.png")
	_layer("land.png")
	_glow = _layer("glow.png")
	_rider = _layer("rider_%s.png" % rider_id)
	for i in 3:
		_flames.append(_layer("flames_%d.png" % (i + 1)))
	for i in 3:
		_sparks.append(_layer("sparks_%d.png" % (i + 1)))
	_smoke = _layer("smoke.png")
	if _smoke != null:
		_smoke.modulate.a = 0.25
	return true


func _layer(file: String) -> Sprite2D:
	var p := DIR + file
	if not ResourceLoader.exists(p):
		return null
	var s := Sprite2D.new()
	s.texture = load(p)
	s.centered = false
	add_child(s)
	return s


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# Firelight breathes.
	if _glow != null:
		_glow.modulate.a = 0.9 + 0.1 * sin(_t * 5.0)
	# The flames flicker through their three frames.
	var frame := int(_t * 8.0) % 3
	for i in _flames.size():
		if _flames[i] != null:
			_flames[i].visible = i == frame
	# Sparks rise on staggered loops, fading as they climb.
	for i in _sparks.size():
		var sp: Sprite2D = _sparks[i]
		if sp == null:
			continue
		var cycle := fposmod(_t * 0.45 + i / 3.0, 1.0)
		sp.position.y = -70.0 * cycle
		sp.modulate.a = 0.9 * (1.0 - cycle)
	# Smoke crawls upward and thins out at the top of its drift.
	if _smoke != null:
		var sc := fposmod(_t * 0.08, 1.0)
		_smoke.position.y = -50.0 * sc
		_smoke.modulate.a = 0.25 * (1.0 - 0.5 * sc)
