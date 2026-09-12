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
const BOMB_BLACK := Color("141414")

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
# CRAZY 8s room: every 8 on the board is wild (drawn with a W badge).
static var eights_wild := false

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
		_update_ambient()
		queue_redraw()
var fuse := 0:  # bomb: hands until detonation
	set(value):
		fuse = value
		_fuse_max = maxi(_fuse_max, value)
		if _ambient != null and hazard == "bomb":
			_ambient.position = _fuse_tip()
		queue_redraw()
var _fuse_max := 0  # longest this fuse has been; burn length scales off it
var stone_hits := 0:  # stone: scoring uses left
	set(value):
		if value < stone_hits and hazard == "stone" and is_inside_tree():
			_crumble_burst()
		stone_hits = value
		_stone_max = maxi(_stone_max, value)
		queue_redraw()
var _stone_max := 0  # heaviest the rock has been; cracks scale off it
var wind_dir := Vector2i.RIGHT:
	set(value):
		wind_dir = value
		if _ambient != null and hazard == "wind":
			_ambient.direction = Vector2(wind_dir)
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

# Ambient particles that live on the card while it's hazarded.
var _ambient: CPUParticles2D
# Animation clock for the full-card hazard treatments; _phase keeps
# every card's flames/waves/swirls out of step with its neighbours.
var _t := 0.0
var _phase := randf() * TAU


func _process(delta: float) -> void:
	if hazard == "":
		set_process(false)
		return
	_t += delta
	queue_redraw()


## Every hazard smoulders, drips, sparks, or swirls constantly.
func _update_ambient() -> void:
	set_process(hazard != "")
	if _ambient != null:
		_ambient.queue_free()
		_ambient = null
	if hazard == "":
		return
	var p := CPUParticles2D.new()
	p.emitting = true
	p.z_index = 3
	p.explosiveness = 0.0
	match hazard:
		"fire":
			p.position = Vector2(0, -6)
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(22, 12)
			p.amount = 7
			p.lifetime = 1.0
			p.direction = Vector2.UP
			p.spread = 25.0
			p.gravity = Vector2(0, -150)
			p.initial_velocity_min = 15.0
			p.initial_velocity_max = 45.0
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.0
			p.color = Color("e07830")
		"bomb":
			p.position = _fuse_tip()
			p.amount = 5
			p.lifetime = 0.45
			p.direction = Vector2.UP
			p.spread = 60.0
			p.gravity = Vector2(0, 200)
			p.initial_velocity_min = 30.0
			p.initial_velocity_max = 70.0
			p.scale_amount_min = 1.5
			p.scale_amount_max = 2.5
			p.color = Color("ffdf8a")
		"water":
			p.position = Vector2(0, H / 2.0 - 6)
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(24, 2)
			p.amount = 3
			p.lifetime = 0.8
			p.direction = Vector2.DOWN
			p.spread = 8.0
			p.gravity = Vector2(0, 320)
			p.initial_velocity_min = 5.0
			p.initial_velocity_max = 20.0
			p.scale_amount_min = 2.0
			p.scale_amount_max = 3.0
			p.color = Color("6fa8c9")
		"wind":
			p.position = Vector2.ZERO
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(20, 26)
			p.amount = 5
			p.lifetime = 0.55
			p.direction = Vector2(wind_dir)
			p.spread = 12.0
			p.gravity = Vector2.ZERO
			p.initial_velocity_min = 60.0
			p.initial_velocity_max = 110.0
			p.scale_amount_min = 1.5
			p.scale_amount_max = 3.0
			p.color = Color(0.7, 0.8, 0.85, 0.6)
		"stone":
			p.position = Vector2(0, H / 2.0 - 10)
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(22, 4)
			p.amount = 2
			p.lifetime = 0.9
			p.direction = Vector2.DOWN
			p.spread = 15.0
			p.gravity = Vector2(0, 260)
			p.initial_velocity_min = 5.0
			p.initial_velocity_max = 15.0
			p.scale_amount_min = 1.5
			p.scale_amount_max = 2.5
			p.color = Color(0.5, 0.5, 0.55, 0.7)
	_ambient = p
	add_child(p)


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
			# The fuse rope, one notch shorter every hand.
			var burn := float(fuse) / maxi(_fuse_max, 1)
			var rope := PackedVector2Array()
			var steps := maxi(ceili(burn * 8.0), 1)
			for i in steps + 1:
				rope.append(_fuse_point(burn * i / steps))
			if rope.size() >= 2:
				draw_polyline(rope, Color("8a6a42"), 3.0)
			# The burning end: a flickering spark.
			var tip := _fuse_point(burn)
			var pulse := 0.5 + 0.5 * sin(_t * 16.0 + _phase)
			for k in 4:
				var ray := Vector2.RIGHT.rotated(_t * 7.0 + k * TAU / 4.0)
				draw_line(tip + ray * 2.0, tip + ray * (5.0 + 3.0 * pulse),
						Color("ffdf8a"), 2.0)
			draw_circle(tip, 2.6 + 1.2 * pulse, Color(1.0, 0.95, 0.8))
			draw_circle(c, 12, BOMB_BLACK)
			draw_string(font, c + Vector2(-10, 5), str(fuse),
					HORIZONTAL_ALIGNMENT_CENTER, 20, 14, Color.WHITE)
		"fire":
			_draw_fire(rect)
		"wind":
			_draw_wind_swirl()
			# The direction arrow — the part that matters for planning.
			var base := Vector2(W / 2.0 - 18, H / 2.0 - 17)
			var v := Vector2(wind_dir) * 11.0
			var perp := Vector2(-v.y, v.x).normalized() * 6.0
			draw_line(base - v, base + v, WIND_BLUE, 4.0)
			draw_colored_polygon(PackedVector2Array([
				base + v * 1.5, base + v * 0.5 + perp, base + v * 0.5 - perp]), WIND_BLUE)
		"stone":
			_draw_rock(rect)
			for i in stone_hits:
				draw_rect(Rect2(-13.0 + i * 10.0, H / 2.0 - 16.0, 7, 7), Color("3a3a40"))
		"water":
			_draw_water(rect)

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
	if eights_wild and rank == 8 and mod == "" and not washed:
		# Crazy 8s: every 8 is wild tonight.
		draw_string(font, Vector2(W / 2.0 - 24, -H / 2.0 + 45), "W",
				HORIZONTAL_ALIGNMENT_CENTER, 22, 24, WILD_PURPLE)
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
		"redeal":
			var rc := Vector2(W / 2.0 - 16, H / 2.0 - 16)
			draw_arc(rc, 9.0, 0.7, TAU - 0.4, 14, WIND_BLUE, 3.0)
			var tip := rc + Vector2.RIGHT.rotated(0.7) * 9.0
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(4, -4), tip + Vector2(-4, -4), tip + Vector2(0, 5)]),
				WIND_BLUE)
		"bullet":
			_draw_bullet(GOLD)
		"hisbullet":
			_draw_bullet(ERROR_RED)

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
## Duel ammunition: a little cartridge, gold for yours, red for his.
func _draw_bullet(col: Color) -> void:
	var base := Vector2(W / 2.0 - 20, H / 2.0 - 24)
	draw_rect(Rect2(base, Vector2(9, 14)), col)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(0, 0), base + Vector2(9, 0), base + Vector2(4.5, -8)]), col)


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


## The card is ablaze: a flickering heat tint over the whole face and
## three layers of tongues climbing from the bottom — deep red at the
## back, orange, then a bright core. Translucent so the rank survives.
func _draw_fire(rect: Rect2) -> void:
	var flicker := 0.05 * sin(_t * 9.0 + _phase)
	draw_rect(rect.grow(-2), Color(0.95, 0.45, 0.1, 0.16 + flicker))
	_draw_flame_layer(rect, rect.size.y * 0.72, 4, 5.1, Color(0.72, 0.16, 0.05, 0.75))
	_draw_flame_layer(rect, rect.size.y * 0.5, 5, 6.3, Color(0.9, 0.46, 0.16, 0.8))
	_draw_flame_layer(rect, rect.size.y * 0.3, 6, 7.9, Color(1.0, 0.85, 0.5, 0.8))


## One strip of flame tongues along the bottom edge; peaks breathe
## with the clock so the fire visibly dances.
func _draw_flame_layer(rect: Rect2, max_h: float, tongues: int, speed: float,
		col: Color) -> void:
	var left := rect.position.x + 2.0
	var width := rect.size.x - 4.0
	var floor_y := rect.end.y - 2.0
	var pts := PackedVector2Array()
	pts.append(Vector2(left, floor_y))
	var n := tongues * 2
	for i in n + 1:
		var x := left + width * i / n
		var wave := 0.6 + 0.4 * sin(_t * speed + i * 2.1 + _phase)
		var h := max_h * wave if i % 2 == 1 else max_h * wave * 0.3
		pts.append(Vector2(x, floor_y - h))
	pts.append(Vector2(left + width, floor_y))
	draw_colored_polygon(pts, col)


## Half-swamped: water fills the lower half behind a rolling waveline,
## with the odd bubble working its way up to the surface.
func _draw_water(rect: Rect2) -> void:
	var level := rect.position.y + rect.size.y * 0.52
	var surface := PackedVector2Array()
	var n := 10
	for i in n + 1:
		var x := rect.position.x + 2.0 + (rect.size.x - 4.0) * i / n
		surface.append(Vector2(x, level + 3.0 * sin(x * 0.16 + _t * 2.6 + _phase)))
	var fill := surface.duplicate()
	fill.append(Vector2(rect.end.x - 2.0, rect.end.y - 2.0))
	fill.append(Vector2(rect.position.x + 2.0, rect.end.y - 2.0))
	draw_colored_polygon(fill, Color(WATER_BLUE.r, WATER_BLUE.g, WATER_BLUE.b, 0.42))
	draw_polyline(surface, Color(0.82, 0.93, 1.0, 0.8), 2.0)
	for b in 3:
		var cycle := fposmod(_t * (0.45 + b * 0.17) + b * 0.37 + _phase, 1.0)
		var bx := rect.position.x + rect.size.x * (0.25 + 0.25 * b) \
				+ 4.0 * sin(cycle * 9.0 + b)
		var by := lerpf(rect.end.y - 8.0, level + 6.0, cycle)
		draw_circle(Vector2(bx, by), 2.2,
				Color(0.85, 0.95, 1.0, 0.55 * (1.0 - cycle * 0.5)))


## Caught in a twister: translucent streaks orbiting the whole card,
## front and back, so it reads as wrapped in moving air.
func _draw_wind_swirl() -> void:
	for k in 3:
		var lead := _t * 2.6 + _phase + k * TAU / 3.0
		var pts := PackedVector2Array()
		for s in 9:
			var a := lead - s * 0.11
			pts.append(Vector2(cos(a) * W * 0.62, sin(a) * H * 0.42))
		draw_polyline(pts, Color(0.75, 0.85, 0.9, 0.5), 3.0)


## Solid rock over the face: a slab of jittered facets that lose
## chunks (revealing the card) and gain cracks as scorings chip at it.
func _draw_rock(rect: Rect2) -> void:
	var total := maxi(_stone_max, 1)
	var dmg := 1.0 - float(stone_hits) / total
	var inner := rect.grow(-3)
	var cols := 3
	var rows := 4
	var cw := inner.size.x / cols
	var ch := inner.size.y / rows
	var gone := int(floor(dmg * (cols * rows - 3)))
	for i in cols * rows:
		# Chunks fall off in a scattered (but stable) order.
		if (i * 5 + 2) % (cols * rows) < gone:
			continue
		var cx := i % cols
		var cy := i / cols
		var o := Vector2(inner.position.x + cx * cw, inner.position.y + cy * ch)
		var corners := PackedVector2Array([
			o, o + Vector2(cw, 0), o + Vector2(cw, ch), o + Vector2(0, ch)])
		for j in 4:
			corners[j] += Vector2(sin(_phase * 3.0 + i * 1.7 + j * 2.3),
					cos(_phase * 2.0 + i * 2.9 + j * 1.1)) * 3.0
		var shade := 0.4 + 0.07 * float((i * 7 + int(_phase * 10.0)) % 3)
		draw_colored_polygon(corners, Color(shade, shade, shade + 0.04, 0.55))
	# Facet seams give it depth even when whole.
	for cx in range(1, cols):
		var x := inner.position.x + cx * cw
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y),
				Color(0.2, 0.2, 0.24, 0.35), 1.5)
	for cy in range(1, rows):
		var y := inner.position.y + cy * ch
		draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y),
				Color(0.2, 0.2, 0.24, 0.35), 1.5)
	# Cracks spread from the middle as the rock weakens.
	var cracks := ceili(dmg * 3.0)
	for c in cracks:
		var ang := _phase + c * 2.4
		var p := Vector2(sin(ang) * 8.0, cos(ang) * 10.0)
		var step := Vector2.RIGHT.rotated(ang) * 11.0
		var pts := PackedVector2Array([p])
		for s in 4:
			p += step + Vector2(sin(_phase + c * 3.1 + s * 1.9) * 5.0,
					cos(_phase + c * 1.3 + s * 2.7) * 5.0)
			pts.append(p)
		draw_polyline(pts, Color(0.12, 0.12, 0.15, 0.8), 2.0)


## Where the burning end of the fuse currently sits.
func _fuse_tip() -> Vector2:
	return _fuse_point(float(fuse) / maxi(_fuse_max, 1))


## A point along the fuse rope: s = 0 at the bomb, 1 = the full,
## freshly-lit length. Curls up and to the right with a wiggle.
func _fuse_point(s: float) -> Vector2:
	var base := Vector2(-W / 2.0 + 16, H / 2.0 - 17) + Vector2(3, -11)
	return base + Vector2(9.0 * s + 4.0 * sin(s * 6.5), -27.0 * s)


## A scoring landed on the rock: grey shards break loose and fall.
func _crumble_burst() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = 10
	p.lifetime = 0.7
	p.z_index = 4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(W * 0.35, H * 0.35)
	p.direction = Vector2.DOWN
	p.spread = 40.0
	p.gravity = Vector2(0, 500)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(0.5, 0.5, 0.55)
	add_child(p)
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)
