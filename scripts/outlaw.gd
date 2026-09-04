class_name OutlawPortrait
extends Node2D

## The Showdown's villain: a code-drawn silhouette gunslinger who
## sways while he waits, flinches when shot, leans in with a muzzle
## flash when he fires, and folds over when he's done.

const DARK := Color("17120e")
const HAT := Color("241b13")
const BANDANA := Color("6e2620")
const EYE := Color("e05252")
const FLASH := Color("ffdf8a")
const HP_RED := Color("c23b3b")
const HP_BACK := Color("2a2a2a")

var hp := 5
var max_hp := 5
var dying := false
var _flash := 0.0:
	set(value):
		_flash = value
		queue_redraw()
var _idle_tween: Tween


func _ready() -> void:
	_start_idle()


func _start_idle() -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	rotation = 0.0
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(self, "rotation", 0.035, 1.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(self, "rotation", -0.035, 1.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func appear(new_max: int) -> void:
	max_hp = new_max
	hp = new_max
	dying = false
	modulate = Color(1, 1, 1, 1)
	position.y = 0.0
	scale = Vector2.ONE
	_start_idle()
	queue_redraw()


func set_hp(new_hp: int) -> void:
	hp = maxi(new_hp, 0)
	queue_redraw()


## He takes a bullet: a sharp sideways jolt and a red blink.
func flinch() -> void:
	if dying:
		return
	var tw := create_tween()
	tw.tween_property(self, "position:x", 14.0, 0.05).as_relative()
	tw.parallel().tween_property(self, "modulate", Color(1.6, 0.6, 0.6), 0.08)
	tw.tween_property(self, "position:x", -14.0, 0.09).as_relative()
	tw.tween_property(self, "modulate", Color(1, 1, 1), 0.25)


## He fires: a lean toward the table and a muzzle flash.
func shoot() -> void:
	if dying:
		return
	var tw := create_tween()
	tw.tween_property(self, "_flash", 1.0, 0.03)
	tw.parallel().tween_property(self, "rotation", 0.14, 0.08) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_flash", 0.0, 0.3)


## Gunned down: he crumples out of frame.
func die() -> void:
	dying = true
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	var tw := create_tween()
	tw.tween_property(self, "rotation", 1.35, 0.55) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "position:y", 90.0, 0.55).as_relative()
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.7)
	tw.tween_callback(func() -> void:
		dying = false)


func _draw() -> void:
	# Shoulders / poncho.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-78, 96), Vector2(-52, 8), Vector2(52, 8), Vector2(78, 96)]), DARK)
	# Head.
	draw_circle(Vector2(0, -26), 34, DARK)
	# Bandana over the face.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-32, -22), Vector2(32, -22), Vector2(0, 24)]), BANDANA)
	# Hat: brim and crown.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-52, -44), Vector2(52, -44), Vector2(44, -54), Vector2(-44, -54)]), HAT)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-30, -52), Vector2(-24, -88), Vector2(26, -84), Vector2(32, -52)]), HAT)
	# Eyes under the brim.
	draw_rect(Rect2(-20, -40, 12, 4), EYE)
	draw_rect(Rect2(8, -40, 12, 4), EYE)
	# Gun arm, raised across the chest.
	draw_colored_polygon(PackedVector2Array([
		Vector2(20, 30), Vector2(72, 6), Vector2(78, 18), Vector2(28, 44)]), DARK)
	draw_rect(Rect2(70, -2, 26, 10), DARK)   # the iron
	draw_rect(Rect2(88, 8, 8, 14), DARK)
	if _flash > 0.02:
		# Muzzle flash off the barrel tip.
		var m := Vector2(104, 2)
		var c := FLASH
		c.a = _flash
		for k in 6:
			var ray := Vector2.RIGHT.rotated(TAU * k / 6.0 + 0.3)
			draw_line(m + ray * 4.0, m + ray * (12.0 + 10.0 * _flash), c, 3.0)
		draw_circle(m, 6.0 * _flash + 2.0, c)
	# Health bar under the portrait.
	draw_rect(Rect2(-70, 112, 140, 10), HP_BACK)
	if max_hp > 0 and hp > 0:
		draw_rect(Rect2(-68, 114, 136.0 * hp / max_hp, 6), HP_RED)
