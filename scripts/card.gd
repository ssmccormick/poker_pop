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

# Swimming Goggles relic: soaked cards still reveal their suit.
static var washed_show_suit := false
# Weathervane relic: hazards telegraph the card they strike next.
# Always on since the Weathervane relic retired: wind arrows and
# next-victim telegraphs are free information now.
static var show_hazard_intent := true
# What one chip level pays â€” mirrors board.chip_bonus (Gold Tooth
# doubles it), pushed by trail's relic effects.
static var chip_pay_base := 8
# CRAZY 8s room: every 8 on the board is wild (drawn with a W badge).
static var eights_wild := false

static var _face_box: StyleBoxFlat
static var _selected_box: StyleBoxFlat
static var _valid_box: StyleBoxFlat
static var _error_box: StyleBoxFlat
static var _shadow_far: StyleBoxFlat
static var _shadow_near: StyleBoxFlat
static var _hover_ring: StyleBoxFlat
static var _hover_glow: StyleBoxFlat

var rank := 2:
	set(value):
		rank = value
		if rank != 14:
			joker = false
		queue_redraw()
# THE JOKER: a PLUS boost past the Ace. He sits one step above the
# Ace (stored on the Ace's rank), always plays WILD and doubles any
# hand he scores in.
var joker := false:
	set(value):
		joker = value
		queue_redraw()
var suit := 0
var grid_pos := Vector2i.ZERO
var selected := false:
	set(value):
		if value and not selected and hazard == "stone" and is_inside_tree():
			_stone_dust()
		var changed := value != selected
		selected = value
		if changed and is_inside_tree():
			# A little pick-up: the card grows in the hand.
			if _sel_tween != null and _sel_tween.is_valid():
				_sel_tween.kill()
			_sel_tween = create_tween()
			_sel_tween.tween_property(self, "scale",
					Vector2(1.06, 1.06) if selected else Vector2.ONE, 0.12) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		queue_redraw()
var _sel_tween: Tween
# Under the mouse (set by main's hover tracking): a quiet gold ring.
var hovered := false:
	set(value):
		hovered = value
		_update_processing()
		queue_redraw()
# The hover TILT: the card turns in 3D toward the cursor, projected
# with real perspective by the card shader. Only the drawing tilts
# (never the node), so board tweens and hit areas are untouched.
const TILT_MAX := 0.35         # radians at the card's edge
var _tilt := Vector2.ZERO      # -1..1 toward the cursor, eased
var _hover_amt := 0.0          # 0..1, eased hover lift
# While tilting, the card wears its own copy of the theme material
# (the tilt is per card); flat, it hands the shared one back.
static var _card_shader: Shader
var _tilt_mat: ShaderMaterial
var _theme_mat: Material
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
# Blackjack tables: the card sits face-down until revealed â€” chaining
# it is a blind hit. Hazards always burn through the card back.
var face_down := false:
	set(value):
		face_down = value
		queue_redraw()
# Deal presentation: 0 = back-up on the deck, 1 = fully face-up.
# Tweened over the flight so each card flips off the stack.
var deal_flip := 1.0:
	set(value):
		deal_flip = value
		queue_redraw()
# Set when the hazard lands; a fresh hazard sits out its first tick
# (no spread, soak, or fuse burn the round it arrived).
var hazard_fresh := false
# Trail hazards: "", "bomb", "fire", "wind", "stone", "water".
var hazard := "":
	set(value):
		hazard = value
		if hazard != "":
			face_down = false
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
# Fire/water: the neighbor this hazard strikes next (re-rolled each
# tick by the board). Only ever shown through the Weathervane.
var next_dir := Vector2i.RIGHT:
	set(value):
		next_dir = value
		queue_redraw()
# Weathervane: the hazard about to strike THIS card ("", fire, water)
# â€” drawn as a faint preview of the effect creeping in at the bottom.
var incoming := "":
	set(value):
		incoming = value
		_update_processing()
		queue_redraw()
var washed := false:  # drowned: rank/suit hidden under the waterline
	set(value):
		washed = value
		_update_processing()
		queue_redraw()
# The flood: 0 = dry, rises one step per hand, WATER_FULL_LEVEL = at
# the brim (the face drowns and the card pours into its neighbors).
const WATER_FULL_LEVEL := 4
var water_level := 0:
	set(value):
		water_level = value
		_update_processing()
		queue_redraw()
# Deck enhancement (trail): "", "chip" (bonus chips when played),
# "mult" (multiplies the hand it's in), "gold" ($1 real cash when
# played), "plus"/"minus" (clearing it raises/lowers the card the
# arrow points at by one rank), "wild" (counts as any rank and suit).
var mod := "":
	set(value):
		mod = value
		queue_redraw()
# FINISHES ride over a card's whole face, like Balatro's editions:
# a shimmer you can read at a glance, separate from the enhancement.
# "" is none. Each finish also changes how the card plays.
const FINISHES := {
	"prism": {"name": "PRISM",
			"desc": "Clearing it spreads its enhancement to every neighbor."},
	"metal": {"name": "METAL",
			"desc": "Pinned under steel: it stays on the table when scored and no hazard can touch it. Each play pops a pin; with the last one the cover comes off and it plays as a normal card."},
}
## Scoring plays a METAL card survives at one table; the last one
## clears it like any card.
const METAL_PLAYS := 5
## Corner pins holding the steel cover on: one pops per scoring play,
## and with the last one the cover comes off. The order they go in,
## as card corners (0 = left/top, 1 = right/bottom).
const METAL_PINS := 4
const PIN_ORDER := [Vector2(1, 0), Vector2(0, 1), Vector2(0, 0), Vector2(1, 1)]
var finish := "":
	set(value):
		finish = value if FINISHES.has(value) else ""
		_update_processing()
		queue_redraw()
# Scoring plays a METAL card has taken at this table.
var metal_wear := 0:
	set(value):
		metal_wear = value
		queue_redraw()
# Chip cards SEASON with use: +1 every time this deck card scores,
# and the payout grows a full base step per level.
var chip_level := 0:
	set(value):
		chip_level = value
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
# Legacy fuse counter (the Outlaw's bullets no longer tick).
var bullet_timer := 0:
	set(value):
		bullet_timer = value
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
var honey := false:  # Queen Bee's trail: one card may follow it in a chain
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
	var tilting := _ease_tilt(delta)
	if hazard == "" and incoming == "" and finish == "" and not tilting:
		set_process(false)
		return
	_t += delta
	queue_redraw()


## Eases the tilt toward the cursor while hovered, and back to flat
## after. True while there is still tilt to show.
func _ease_tilt(delta: float) -> bool:
	var target := Vector2.ZERO
	if hovered and is_inside_tree() and deal_flip >= 1.0:
		var m := get_local_mouse_position()
		target = Vector2(clampf(m.x / (W / 2.0), -1.0, 1.0),
				clampf(m.y / (H / 2.0), -1.0, 1.0))
	var k := 1.0 - exp(-delta * 14.0)
	_tilt = _tilt.lerp(target, k)
	_hover_amt = lerpf(_hover_amt, 1.0 if hovered else 0.0, k)
	if not hovered and _tilt.length() < 0.01 and _hover_amt < 0.01:
		_tilt = Vector2.ZERO
		_hover_amt = 0.0
		_release_tilt_material()
		return false
	_hold_tilt_material()
	_tilt_mat.set_shader_parameter("tilt", _tilt * TILT_MAX)
	return true


## Puts this card in its own copy of the theme material. Re-adopts the
## theme if someone (a theme switch) swapped the material meanwhile.
func _hold_tilt_material() -> void:
	if _tilt_mat != null and material == _tilt_mat:
		return
	_theme_mat = material
	if _theme_mat is ShaderMaterial:
		_tilt_mat = (_theme_mat as ShaderMaterial).duplicate()
	else:
		if _card_shader == null:
			_card_shader = load("res://shaders/card_pattern.gdshader")
		_tilt_mat = ShaderMaterial.new()
		_tilt_mat.shader = _card_shader
		_tilt_mat.set_shader_parameter("pattern_strength", 0.0)
	material = _tilt_mat


func _release_tilt_material() -> void:
	if _tilt_mat != null and material == _tilt_mat:
		material = _theme_mat
	_tilt_mat = null


## Where the face is drawn: the selection lift and a slight hover swell
## (the 3D turn itself happens in the card shader).
func _face_xform() -> Transform2D:
	var lift := Vector2(0, -8) if selected else Vector2.ZERO
	var swell := 1.0 + 0.03 * _hover_amt
	return Transform2D(Vector2(swell, 0.0), Vector2(0.0, swell), lift)


## A soft light band across the face that slides with the cursor, so
## the lean reads as a real surface catching the light.
func _draw_tilt_sheen(rect: Rect2) -> void:
	if _hover_amt <= 0.01:
		return
	var glare := CardArt.tex("fx", "card_glare")
	if glare != null:
		# The kit's soft highlight rides with the cursor.
		_draw_clipped(glare, rect, _tilt * rect.size * 0.5, Color(1, 1, 1, 0.5 * _hover_amt))
		return
	var r := rect.grow(-2.0)
	var card_poly := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y),
			r.end, Vector2(r.position.x, r.end.y)])
	var cx := r.get_center().x + _tilt.x * r.size.x * 0.45
	var lean := r.size.y * 0.3
	var widths := [26.0, 14.0, 6.0]
	var alphas := [0.05, 0.06, 0.07]
	for i in widths.size():
		var w: float = widths[i]
		var band := PackedVector2Array([Vector2(cx - w + lean / 2.0, r.position.y),
				Vector2(cx + w + lean / 2.0, r.position.y),
				Vector2(cx + w - lean / 2.0, r.end.y), Vector2(cx - w - lean / 2.0, r.end.y)])
		var col := Color(1, 1, 1, float(alphas[i]) * _hover_amt)
		for piece in Geometry2D.intersect_polygons(band, card_poly):
			draw_colored_polygon(piece, col)


## Animate only while something on this card moves: a live hazard
## (stone sits still) or an incoming-strike preview.
func _update_processing() -> void:
	set_process((hazard != "" and hazard != "stone") or incoming != ""
			or water_level > 0 or washed or finish != ""
			or hovered or _tilt != Vector2.ZERO or _hover_amt > 0.0)


## Fire, bombs, water and wind smoulder, spark, drip, or swirl
## constantly. Stone sits solid and silent â€” it only sheds dust when
## touched (see _stone_dust / _crumble_burst).
func _update_ambient() -> void:
	_update_processing()
	if _ambient != null:
		_ambient.queue_free()
		_ambient = null
	if hazard == "" or hazard == "stone":
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
			p.amount = 9
			p.lifetime = 0.55
			p.direction = Vector2(wind_dir)
			p.spread = 10.0
			p.gravity = Vector2.ZERO
			p.initial_velocity_min = 70.0
			p.initial_velocity_max = 120.0
			p.scale_amount_min = 1.5
			p.scale_amount_max = 3.0
			p.color = Color(0.7, 0.8, 0.85, 0.75)
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

	_shadow_far = StyleBoxFlat.new()
	_shadow_far.bg_color = Color(0, 0, 0, 0.13)
	_shadow_far.set_corner_radius_all(11)
	_shadow_near = StyleBoxFlat.new()
	_shadow_near.bg_color = Color(0, 0, 0, 0.24)
	_shadow_near.set_corner_radius_all(7)

	# Hover ring + glow: rounded to match the card corners.
	_hover_ring = StyleBoxFlat.new()
	_hover_ring.draw_center = false
	_hover_ring.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.95)
	_hover_ring.set_border_width_all(3)
	_hover_ring.set_corner_radius_all(7)
	_hover_glow = StyleBoxFlat.new()
	_hover_glow.draw_center = false
	_hover_glow.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.35)
	_hover_glow.set_border_width_all(4)
	_hover_glow.set_corner_radius_all(9)


## A deck entry's finish, reading saves from before finishes existed
## (the old Explosive flag and its even older "chipsplode" mod).
static func finish_of(d: Dictionary) -> String:
	var f := String(d.get("finish", ""))
	if FINISHES.has(f):
		return f
	if bool(d.get("boom", false)) or String(d.get("mod", "")) == "chipsplode":
		return "prism"
	return ""


## METAL shrugs off every hazard: no fire, flood, wind, bomb or stone
## can land on it, and no job piece rides it.
func hazard_proof() -> bool:
	return metal_covered()


## The steel cover is still pinned on (it comes off with the last pin).
func metal_covered() -> bool:
	return finish == "metal" and metal_wear < METAL_PINS


## Scoring plays left before a METAL card wears through.
func metal_plays_left() -> int:
	return maxi(METAL_PLAYS - metal_wear, 0)


## Counts one scoring play on a METAL card. True while it still stays
## on the table; false on the play that wears it through.
func wear_metal() -> bool:
	metal_wear += 1
	if is_inside_tree():
		if metal_wear <= METAL_PINS:
			_pop_pin(metal_wear - 1)
		if metal_wear == METAL_PINS:
			_pop_cover()
	return metal_wear < METAL_PLAYS


## A pin's centre: the kit puts them 38 px in from each corner of the
## 500×700 canvas.
func _pin_pos(corner: Vector2) -> Vector2:
	var inset := Vector2(38.0 / 500.0 * W, 38.0 / 700.0 * H)
	var r := Rect2(-W / 2.0, -H / 2.0, W, H).grow_individual(-inset.x, -inset.y,
			-inset.x, -inset.y)
	return r.position + r.size * corner


## One pin springs out of its corner, spinning off and fading.
func _pop_pin(i: int) -> void:
	var corner: Vector2 = PIN_ORDER[i % PIN_ORDER.size()]
	var at := _pin_pos(corner)
	var pin: Node2D
	var pin_tex := CardArt.tex("finish", "metal_pin")
	if pin_tex != null:
		var spr := Sprite2D.new()
		spr.texture = pin_tex
		spr.scale = Vector2.ONE * (W / 500.0)
		pin = spr
	else:
		var poly := Polygon2D.new()
		var pts := PackedVector2Array()
		for k in 10:
			pts.append(Vector2.RIGHT.rotated(TAU * k / 10.0) * 3.6)
		poly.polygon = pts
		poly.color = Color(0.88, 0.91, 0.95)
		pin = poly
	pin.position = at
	pin.z_index = 5
	add_child(pin)
	var out := Vector2(-1.0 if corner.x < 0.5 else 1.0, -1.0 if corner.y < 0.5 else 1.0)
	var tw := pin.create_tween().set_parallel(true)
	tw.tween_property(pin, "position", at + out * Vector2(28, 16) + Vector2(0, 10), 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(pin, "rotation", out.x * randf_range(5.0, 8.0), 0.45)
	tw.tween_property(pin, "modulate:a", 0.0, 0.3).set_delay(0.15)
	tw.chain().tween_callback(pin.queue_free)


## The last pin is out: the steel plate lifts off and tumbles away,
## leaving the plain card underneath.
func _pop_cover() -> void:
	var lift_1 := CardArt.tex("finish", "metal_lift_1")
	if lift_1 != null:
		# The kit's three lift frames (700×900, card centred), 60 ms
		# apiece, then the plate drops away.
		var spr := Sprite2D.new()
		spr.texture = lift_1
		spr.scale = Vector2.ONE * (W / 500.0)
		spr.z_index = 6
		add_child(spr)
		var tw := spr.create_tween()
		for f in [2, 3]:
			tw.tween_interval(0.06)
			var frame := CardArt.tex("finish", "metal_lift_%d" % f)
			tw.tween_callback(func() -> void:
				if frame != null:
					spr.texture = frame)
		tw.tween_interval(0.06)
		tw.set_parallel(true)
		tw.tween_property(spr, "position", Vector2(0, -24), 0.18) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(spr, "modulate:a", 0.0, 0.18)
		tw.chain().tween_callback(spr.queue_free)
		return
	var r := Rect2(-W / 2.0, -H / 2.0, W, H).grow(-3.0)
	var cover := Polygon2D.new()
	cover.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y),
			r.end, Vector2(r.position.x, r.end.y)])
	var top := Color(0.86, 0.9, 0.95, 0.8)
	var foot := Color(0.42, 0.47, 0.54, 0.8)
	cover.vertex_colors = PackedColorArray([top, top, foot, foot])
	cover.z_index = 6
	add_child(cover)
	var lean := -1.0 if randf() < 0.5 else 1.0
	var tw := cover.create_tween().set_parallel(true)
	tw.tween_property(cover, "position", Vector2(lean * 14.0, -50.0), 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(cover, "rotation", lean * 0.4, 0.5)
	tw.tween_property(cover, "scale", Vector2.ONE * 1.08, 0.5)
	tw.tween_property(cover, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(cover.queue_free)


## The finish layer over the whole face. One branch per finish.
func _draw_finish(rect: Rect2) -> void:
	match finish:
		"prism":
			if CardArt.tex("finish", "prism_foil") != null:
				_draw_prism_art(rect)
			else:
				_draw_prism(rect)
		"metal":
			if not metal_covered():
				return
			if CardArt.tex("finish", "metal_plate") != null:
				_draw_metal_art(rect)
			else:
				_draw_metal(rect)


## Draws `t` as if laid over the card at `off` (card units), clipped
## to the card rect: the kit's sliding bands stay on the card.
func _draw_clipped(t: Texture2D, rect: Rect2, off: Vector2, tint: Color) -> void:
	var placed := Rect2(rect.position + off, rect.size)
	var inter := placed.intersection(rect)
	if inter.size.x <= 0.5 or inter.size.y <= 0.5:
		return
	var px := Vector2(t.get_size()) / rect.size
	draw_texture_rect_region(t, inter,
			Rect2((inter.position - placed.position) * px, inter.size * px), tint)


## PRISM from the kit: the static foil, the rainbow sheen sliding down
## the diagonal (1.8 s, then a 1.2 s rest), and two star glints that
## pop up at fresh spots, swell and fade over 0.6 s.
func _draw_prism_art(rect: Rect2) -> void:
	_art(rect, "finish", "prism_foil")
	var sheen := CardArt.tex("finish", "prism_sheen")
	var cycle := fposmod(_t + _phase, 3.0)
	if sheen != null and cycle < 1.8:
		var f := cycle / 1.8
		_draw_clipped(sheen, rect, Vector2(lerpf(-1.0, 1.0, f), lerpf(-1.0, 1.0, f)) * rect.size,
				Color(1, 1, 1, 0.6))
	var glint := CardArt.tex("finish", "prism_glint")
	if glint == null:
		return
	for k in 2:
		var span := fposmod(_t * 0.8 + _phase + k * 0.5, 1.0) * 1.25
		if span > 0.6:
			continue  # resting between twinkles
		var n := floorf(_t * 0.8 + _phase + k * 0.5) * 2.0 + k
		var spot := Vector2(fposmod(sin(n * 12.9898) * 43758.5453, 1.0),
				fposmod(sin(n * 78.233) * 12543.1, 1.0))
		var at := rect.position + rect.size * (Vector2(0.18, 0.15) + spot * Vector2(0.64, 0.7))
		var size := (64.0 / 500.0) * rect.size.x * sin(span / 0.6 * PI)
		draw_set_transform_matrix(_face_xform() * Transform2D(PI / 4.0, at))
		draw_texture_rect(glint, Rect2(-Vector2.ONE * size / 2.0, Vector2.ONE * size), false)
	draw_set_transform_matrix(_face_xform())


## METAL from the kit: the windowed steel plate, a pin or an empty
## socket at each corner, and the glint band sliding slowly across.
func _draw_metal_art(rect: Rect2) -> void:
	_art(rect, "finish", "metal_plate")
	var pin := CardArt.tex("finish", "metal_pin")
	var hole := CardArt.tex("finish", "metal_pin_hole")
	var pin_size := Vector2.ONE * (48.0 / 500.0) * rect.size.x
	for i in METAL_PINS:
		var t: Texture2D = pin if i >= metal_wear else hole
		if t != null:
			draw_texture_rect(t, Rect2(_pin_pos(PIN_ORDER[i]) - pin_size / 2.0, pin_size), false)
	var glint := CardArt.tex("finish", "metal_glint")
	var cycle := fposmod(_t / 3.6 + _phase / TAU, 1.0)
	if glint != null and cycle < 0.4:
		var f := cycle / 0.4
		_draw_clipped(glint, rect, Vector2(lerpf(-1.0, 1.0, f) * rect.size.x, 0.0),
				Color(1, 1, 1, sin(f * PI)))


## METAL: brushed steel. A cool steel tint darkening toward the foot,
## fine brushed grain, a beveled plate edge, and a slow white glint
## that slides across now and then.
func _draw_metal(rect: Rect2) -> void:
	var r := rect.grow(-3.0)
	var card_poly := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y),
			r.end, Vector2(r.position.x, r.end.y)])
	var top := Color(0.86, 0.9, 0.95, 0.34)
	var foot := Color(0.42, 0.47, 0.54, 0.34)
	draw_polygon(card_poly, PackedColorArray([top, top, foot, foot]))
	# Brushed grain: hairlines, alternately light and dark.
	var y := r.position.y + 2.0
	var k := 0
	while y < r.end.y:
		var grain := Color(1, 1, 1, 0.07) if k % 2 == 0 else Color(0, 0, 0, 0.05)
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), grain, 1.0)
		y += 3.0
		k += 1
	# Beveled plate: lit top-left edge, shadowed bottom-right edge.
	var b := r.grow(-1.0)
	var lit := Color(1, 1, 1, 0.45)
	var shade := Color(0.1, 0.12, 0.15, 0.45)
	draw_line(b.position, Vector2(b.end.x, b.position.y), lit, 2.0)
	draw_line(b.position, Vector2(b.position.x, b.end.y), lit, 2.0)
	draw_line(Vector2(b.position.x, b.end.y), b.end, shade, 2.0)
	draw_line(Vector2(b.end.x, b.position.y), b.end, shade, 2.0)
	# The corner pins still holding the cover on: domed steel rivets.
	for i in range(metal_wear, METAL_PINS):
		var at := _pin_pos(PIN_ORDER[i])
		draw_circle(at + Vector2(0.6, 0.9), 3.8, Color(0.08, 0.09, 0.11, 0.6))
		draw_circle(at, 3.6, Color(0.62, 0.67, 0.74))
		draw_circle(at, 2.6, Color(0.86, 0.9, 0.95))
		draw_circle(at - Vector2(1.0, 1.0), 1.0, Color(1, 1, 1, 0.95))
	# The glint: travels for 40% of a slow cycle, then rests.
	var cycle := fposmod(_t / 3.6 + _phase / TAU, 1.0)
	if cycle < 0.4:
		var travel := cycle / 0.4
		var lean := r.size.y * 0.35
		var stripes := 5
		var sw := 3.0
		var x0 := lerpf(r.position.x - stripes * sw, r.end.x + lean, travel)
		for i in stripes:
			var x := x0 + i * sw
			var band := PackedVector2Array([Vector2(x, r.position.y),
					Vector2(x + sw, r.position.y), Vector2(x + sw - lean, r.end.y),
					Vector2(x - lean, r.end.y)])
			var shine := Color(1, 1, 1, 0.5 * sin(travel * PI) * sin(PI * (i + 0.5) / stripes))
			for piece in Geometry2D.intersect_polygons(band, card_poly):
				draw_colored_polygon(piece, shine)


## PRISM: a foil sheen. A faint iridescent wash whose hues drift
## across the card, a rainbow band that sweeps corner to corner and
## rests, and two glints that twinkle in turn.
func _draw_prism(rect: Rect2) -> void:
	var r := rect.grow(-3.0)
	var card_poly := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y),
			r.end, Vector2(r.position.x, r.end.y)])
	var hue := fposmod(_t * 0.12 + _phase / TAU, 1.0)
	var wash := PackedColorArray()
	for k in 4:
		wash.append(Color.from_hsv(fposmod(hue + k * 0.22, 1.0), 0.6, 1.0, 0.2))
	draw_polygon(card_poly, wash)
	# The sweep travels for the first 75% of its cycle, then rests.
	var cycle := fposmod(_t / 2.4 + _phase / TAU, 1.0)
	if cycle < 0.75:
		var travel := cycle / 0.75
		var lean := r.size.y * 0.5
		var stripes := 9
		var sw := 3.5
		var start := r.position.x - stripes * sw
		var x0 := lerpf(start, r.end.x + lean, travel)
		var fade := sin(travel * PI)
		for k in stripes:
			var x := x0 + k * sw
			var band := PackedVector2Array([Vector2(x, r.position.y),
					Vector2(x + sw, r.position.y), Vector2(x + sw - lean, r.end.y),
					Vector2(x - lean, r.end.y)])
			# Soft edges: the middle of the band shines brightest.
			var edge := sin(PI * (k + 0.5) / stripes)
			var col := Color.from_hsv(fposmod(float(k) / stripes + hue, 1.0),
					0.5, 1.0, 0.42 * fade * edge)
			for piece in Geometry2D.intersect_polygons(band, card_poly):
				draw_colored_polygon(piece, col)
	for k in 2:
		var tw := sin(fposmod(_t * 0.7 + _phase + k * 0.5, 1.0) * PI)
		if tw <= 0.05:
			continue
		var at := r.position + r.size * (Vector2(0.78, 0.2) if k == 0 else Vector2(0.22, 0.62))
		var arm := 5.0 * tw
		var glint := Color(1, 1, 1, 0.85 * tw)
		draw_line(at - Vector2(arm, 0), at + Vector2(arm, 0), glint, 1.5)
		draw_line(at - Vector2(0, arm * 1.4), at + Vector2(0, arm * 1.4), glint, 1.5)


func rank_text() -> String:
	if joker:
		return "JKR"
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
	var rect := Rect2(-W / 2.0, -H / 2.0, W, H)
	if deal_flip < 1.0:
		# Mid-flip off the deck: squash horizontally through the turn,
		# back showing on the first half, face on the second.
		var sx := maxf(absf(cos(deal_flip * PI)), 0.04)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, 1.0))
		if deal_flip < 0.5:
			if CardArt.available():
				draw_texture_rect(CardArt.tex("base", "card_back"), rect, false)
				return
			# The cream card base under the back, so the flying card
			# wears the same white border as the ones in the stack.
			_face_box.draw(get_canvas_item(), rect)
			_draw_card_back(rect)
			return
	# Shadows stay on the felt while the face lifts â€” wider when the
	# card is raised, so selection reads as real height.
	var far_off := Vector2(5, 10) if selected else Vector2(3, 6)
	var near_off := Vector2(4, 7) if selected else Vector2(2, 4)
	far_off -= _tilt * Vector2(4, 3)
	near_off -= _tilt * Vector2(2, 1.5)
	var soft := CardArt.tex("fx", "card_shadow_soft")
	if soft != null:
		# The kit's soft shadow: 600×800 with the card at (50, 50).
		var k := rect.size.x / 500.0
		draw_texture_rect(soft, Rect2(rect.position - Vector2(50, 50) * k + far_off,
				Vector2(600, 800) * k), false)
	else:
		_shadow_far.draw(get_canvas_item(),
				Rect2(rect.position + far_off, rect.size).grow(2))
		_shadow_near.draw(get_canvas_item(),
				Rect2(rect.position + near_off, rect.size))
	# The face rides the selection lift and the hover lean.
	draw_set_transform_matrix(_face_xform())
	if CardArt.available():
		# The layered art kit draws the whole face; interaction rings
		# and badges ride on top. Game logic untouched.
		_draw_art(rect)
		_draw_tilt_sheen(rect)
		return
	if selected:
		var box := _selected_box
		if error_flash:
			box = _error_box
		elif hand_valid:
			box = _valid_box
		box.draw(get_canvas_item(), rect)
	else:
		_face_box.draw(get_canvas_item(), rect)
		if hovered:
			# A clear gold ring under the cursor, with a soft outer glow.
			_hover_glow.draw(get_canvas_item(), rect.grow(3))
			_hover_ring.draw(get_canvas_item(), rect)
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
	if face_down:
		# A blind hit waiting to happen: the card back, nothing more.
		_draw_card_back(rect)
		if selected and chain_index > 0:
			var fd_badge := GOLD if not error_flash else ERROR_RED
			var fd_center := Vector2(W / 2.0 - 13, -H / 2.0 + 13)
			draw_circle(fd_center, 10, fd_badge)
			draw_string(font, fd_center + Vector2(-10, 5.5), str(chain_index),
					HORIZONTAL_ALIGNMENT_CENTER, 20, 15, BLACK)
		return
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
		# Drowned: water to the brim â€” whatever this card was is down
		# there somewhere, and the face is unreadable.
		_draw_flood(rect, 1.0)
		draw_circle(Vector2(-8, 6), 9.0, Color(0.19, 0.33, 0.46))
		draw_circle(Vector2(10, -14), 6.0, Color(0.19, 0.33, 0.46))
		draw_circle(Vector2(6, 26), 7.0, Color(0.19, 0.33, 0.46))
		if washed_show_suit:  # Swimming Goggles
			_draw_suit(Vector2(-W / 2.0 + 16, -H / 2.0 + 40), 2.0)
	else:
		if hazard == "stone":
			# A slab of rock: no rank, no suit â€” just a blocker. Clear
			# cards beside it to chip it away.
			_draw_rock(rect)
			for i in stone_hits:
				draw_rect(Rect2(-13.0 + i * 10.0, H / 2.0 - 16.0, 7, 7),
						Color("3a3a40"))
			return
		_draw_mod_face(rect)
		if joker:
			# The trickster announces itself.
			draw_rect(rect.grow(-5), Color(BOOST_GREEN.r, BOOST_GREEN.g,
					BOOST_GREEN.b, 0.55), false, 2.5)
		var col := suit_color()
		draw_string(font, Vector2(-W / 2.0 + 8, -H / 2.0 + 27), rank_text(),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)
		if not joker:
			_draw_suit(Vector2(-W / 2.0 + 16, -H / 2.0 + 40), 2.0)
		if mod != "":
			# Enhanced cards wear their power as the center art.
			_draw_mod_art(font)
			if eights_wild and rank == 8:
				# Still an 8 under the mod's face â€” still WILD.
				draw_string(font, Vector2(W / 2.0 - 44, -H / 2.0 + 32), "W",
						HORIZONTAL_ALIGNMENT_CENTER, 36, 28, WILD_PURPLE)
		elif eights_wild and rank == 8:
			draw_string(font, Vector2(-24, 22), "W",
					HORIZONTAL_ALIGNMENT_CENTER, 48, 46, WILD_PURPLE)
		else:
			_draw_suit(Vector2(0, 6), 5.0)
		_draw_finish(rect)

	match hazard:
		"bomb":
			# DYNAMITE, impossible to miss: a red alert ring pulsing
			# around the whole card, a bound bundle of three sticks,
			# and the fuse hissing shorter above it.
			var alert := 0.5 + 0.5 * sin(_t * 6.0 + _phase)
			draw_rect(rect.grow(-2), Color(0.88, 0.2, 0.12, 0.3 + 0.4 * alert),
					false, 4.0)
			var bb := Vector2(-W / 2.0 + 21, H / 2.0 - 20)
			for k in 3:
				var sx := bb.x - 9.0 + k * 9.0
				var sy := bb.y + (0.0 if k == 1 else 2.0)
				var stick := Rect2(Vector2(sx - 3.5, sy - 15.0), Vector2(7, 26))
				draw_rect(stick, Color("b8382a"))
				draw_rect(Rect2(stick.position, Vector2(7, 4)), Color("d9d0b8"))
				draw_rect(stick, Color("7e2018"), false, 1.5)
			# The binding strap.
			draw_rect(Rect2(bb + Vector2(-14, -3), Vector2(28, 5)), Color("6a4a28"))
			# The fuse rope, one notch shorter every hand.
			var burn := float(fuse) / maxi(_fuse_max, 1)
			var rope := PackedVector2Array()
			var steps := maxi(ceili(burn * 8.0), 1)
			for i in steps + 1:
				rope.append(_fuse_point(burn * i / steps))
			if rope.size() >= 2:
				draw_polyline(rope, Color("8a6a42"), 3.0)
			# The burning end: a big, flickering spark.
			var tip := _fuse_point(burn)
			var pulse := 0.5 + 0.5 * sin(_t * 16.0 + _phase)
			for k in 4:
				var ray := Vector2.RIGHT.rotated(_t * 7.0 + k * TAU / 4.0)
				draw_line(tip + ray * 2.0, tip + ray * (7.0 + 4.0 * pulse),
						Color("ffdf8a"), 2.4)
			draw_circle(tip, 3.2 + 1.6 * pulse, Color(1.0, 0.95, 0.8))
			# Hands left, stamped beside the bundle.
			var c := bb + Vector2(26, -8)
			draw_circle(c, 11, BOMB_BLACK)
			draw_string(font, c + Vector2(-10, 5), str(fuse),
					HORIZONTAL_ALIGNMENT_CENTER, 20, 14, Color.WHITE)
		"fire":
			_draw_fire(rect)
		"wind":
			# The swirl is the body; the streaming chevrons carry the
			# direction the gust takes.
			_draw_wind_swirl()
			_draw_wind_stream(rect)
		"water":
			if not washed:
				# The washed branch already drew the full tank.
				_draw_water(rect)

	if incoming != "" and hazard == "":
		# Always on show: where the fire or water strikes next.
		_draw_incoming(rect)

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
			# A waiting slug â€” no fuse, no countdown. Clear the card
			# it rides and he shoots you for it. Step around it.
			_draw_bullet(ERROR_RED)

	if honey:
		draw_rect(rect.grow(-2), HONEY_AMBER)
		_draw_pixel_map(DROP_PX, Vector2(W / 2.0 - 14, H / 2.0 - 15), 2.5, Color("c98a1e"))

	match boss:
		"jack":
			_draw_pixel_map(CROWN_PX, Vector2(0, -H / 2.0 + 8), 3.0, GOLD)
			# Score left to deal him, in thousands â€” the badge can't fit
			# five digits, and the banner bar carries the exact count.
			var bc := Vector2(-W / 2.0 + 16, H / 2.0 - 17)
			draw_circle(bc, 12, ERROR_RED)
			draw_string(font, bc + Vector2(-11, 5),
					"%dK" % ceili(boss_hp / 1000.0),
					HORIZONTAL_ALIGNMENT_CENTER, 22, 12, Color.WHITE)
		"queen":
			_draw_pixel_map(CROWN_PX, Vector2(0, -H / 2.0 + 8), 3.0, GOLD)
			# Her score pool, worn as an amber chip like the Jack's.
			var qc := Vector2(-W / 2.0 + 16, H / 2.0 - 17)
			draw_circle(qc, 12, Color(0.92, 0.68, 0.18))
			draw_string(font, qc + Vector2(-11, 5),
					"%dK" % ceili(boss_hp / 1000.0),
					HORIZONTAL_ALIGNMENT_CENTER, 22, 12, BLACK)
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


# --- Layered art-kit rendering (visual only; logic lives elsewhere) -------

static var _art_ring_cache := {}


## One layer from the kit, drawn over the full card rect. Rotation is
## around the card center (for the *_arrow_up facings), re-applying
## the selection lift so the arrow rides the raised card.
func _art(rect: Rect2, group: String, name: String, tint := Color.WHITE,
		rot := 0.0) -> void:
	var t := CardArt.tex(group, name)
	if t == null:
		return
	if rot != 0.0:
		draw_set_transform_matrix(_face_xform() * Transform2D(rot, Vector2.ZERO))
		draw_texture_rect(t, rect, false, tint)
		draw_set_transform_matrix(_face_xform())
	else:
		draw_texture_rect(t, rect, false, tint)


## One kit layer drawn as a corner BADGE: the layer's canvas center
## lands on `anchor` (normalized card coords) at `scale_f` of the
## card size, so markers ride the free top-right / bottom-left
## corners instead of covering the face. Rotation spins around the
## badge center, selection lift re-applied as in _art.
func _art_badge(rect: Rect2, group: String, name: String, anchor: Vector2,
		scale_f: float, tint := Color.WHITE, rot := 0.0) -> void:
	var t := CardArt.tex(group, name)
	if t == null:
		return
	var sub_size := rect.size * scale_f
	var center := rect.position + rect.size * anchor
	if rot != 0.0:
		draw_set_transform_matrix(_face_xform() * Transform2D(rot, center))
		draw_texture_rect(t, Rect2(-sub_size / 2.0, sub_size), false, tint)
		draw_set_transform_matrix(_face_xform())
	else:
		draw_texture_rect(t, Rect2(center - sub_size / 2.0, sub_size),
				false, tint)


## Border-only selection ring for art cards (a filled stylebox would
## paint over the artwork).
func _art_ring(col: Color) -> StyleBoxFlat:
	var key := col.to_html()
	if not _art_ring_cache.has(key):
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.set_corner_radius_all(8)
		sb.border_color = col
		sb.set_border_width_all(3)
		_art_ring_cache[key] = sb
	return _art_ring_cache[key]


func _draw_art_rings(rect: Rect2) -> void:
	if selected:
		var col := GOLD
		if error_flash:
			col = ERROR_RED
		elif hand_valid:
			col = GREEN
		draw_style_box(_art_ring(col), rect.grow(-1))
	elif hovered:
		_hover_glow.draw(get_canvas_item(), rect.grow(3))
		_hover_ring.draw(get_canvas_item(), rect)


func _draw_art_chain_badge(font: Font) -> void:
	if not (selected and chain_index > 0):
		return
	var badge_color := GOLD
	if error_flash:
		badge_color = ERROR_RED
	elif hand_valid:
		badge_color = GREEN
	var c := Vector2(W / 2.0 - 13, -H / 2.0 + 13)
	draw_circle(c, 10, badge_color)
	draw_string(font, c + Vector2(-10, 5.5), str(chain_index),
			HORIZONTAL_ALIGNMENT_CENTER, 20, 15, BLACK)


func _draw_art_rank_suit(rect: Rect2) -> void:
	if joker:
		# Wild has no suit: just the JKR mark in the rank corner.
		var jf: Font = FontLib.card if FontLib.card != null else ThemeDB.fallback_font
		draw_string(jf, Vector2(rect.position.x + rect.size.x * 0.09,
				rect.position.y + rect.size.y * 0.18), "JKR",
				HORIZONTAL_ALIGNMENT_LEFT, rect.size.x * 0.5, 15, Color("2a4a2a"))
		return
	var ink := "red" if suit == 1 or suit == 2 else "black"
	_art(rect, "rank", "%s_%s" % [CardArt.rank_name(rank), ink])
	_art(rect, "suit_corner", CardArt.suit_name(suit))


## The Ace wears a big letter like the Jack, Queen and King â€” the
## kit's own ornate corner letter (ink, halo and all), cropped out of
## the rank layer and scaled up to center stage, so the style matches
## the painted faces exactly.
func _draw_art_ace(rect: Rect2) -> void:
	var ink := "red" if suit == 1 or suit == 2 else "black"
	var t := CardArt.tex("rank", "A_" + ink)
	if t == null:
		var font: Font = FontLib.card if FontLib.card != null else ThemeDB.fallback_font
		var col := Color("a73a2a") if ink == "red" else Color("292117")
		draw_string(font, Vector2(rect.position.x,
				rect.position.y + rect.size.y * 0.5 + 24.0), "A",
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 66, col)
		return
	var ts := t.get_size()
	# The top-left corner letter's home in the layer canvas.
	var region := Rect2(ts.x * 0.030, ts.y * 0.064, ts.x * 0.220, ts.y * 0.165)
	var dst_h := rect.size.y * 0.44
	var dst := Vector2(dst_h * region.size.x / region.size.y, dst_h)
	draw_texture_rect_region(t,
			Rect2(rect.position + rect.size / 2.0 - dst / 2.0, dst), region)


## The full kit stack for this card's state, plus the interaction
## overlays. Mirrors the vector path branch-for-branch.
func _draw_art(rect: Rect2) -> void:
	var font: Font = FontLib.card if FontLib.card != null else ThemeDB.fallback_font
	if face_down:
		_art(rect, "base", "card_back")
		_draw_art_chain_badge(font)
		_draw_art_rings(rect)
		return
	if snake_tail:
		_art(rect, "base", "cobra_tail")
		_draw_art_rings(rect)
		return
	if is_safe:
		_art(rect, "base", "safe")
		# Combo digits in the four windows (the kit leaves them empty).
		var dfont: Font = FontLib.numbers if FontLib.numbers != null else font
		for i in combo.size():
			var digit_col := GREEN if i < combo_progress else Color("e6d5b0")
			draw_string(dfont, Vector2(-28.0 + i * 14.6, H / 2.0 - 21.0),
					str(combo[i]), HORIZONTAL_ALIGNMENT_CENTER, 15, 15, digit_col)
		_draw_art_rings(rect)
		return
	if boss != "":
		_art(rect, "boss", boss + "_card")
		_draw_art_rank_suit(rect)
		_art(rect, "boss", "boss_frame")
		match boss:
			"jack":
				var bc := Vector2(-W / 2.0 + 16, H / 2.0 - 17)
				draw_circle(bc, 12, ERROR_RED)
				draw_string(font, bc + Vector2(-11, 5),
						"%dK" % ceili(boss_hp / 1000.0),
						HORIZONTAL_ALIGNMENT_CENTER, 22, 12, Color.WHITE)
			"queen":
				var qc := Vector2(-W / 2.0 + 16, H / 2.0 - 17)
				draw_circle(qc, 12, Color(0.92, 0.68, 0.18))
				draw_string(font, qc + Vector2(-11, 5),
						"%dK" % ceili(boss_hp / 1000.0),
						HORIZONTAL_ALIGNMENT_CENTER, 22, 12, BLACK)
			"cobra":
				if stunned:
					draw_string(font, Vector2(-W / 2.0, -H / 2.0 - 4), "zzz",
							HORIZONTAL_ALIGNMENT_CENTER, W, 18, WIND_BLUE)
		_draw_art_chain_badge(font)
		_draw_art_rings(rect)
		return
	if hazard == "stone":
		_art(rect, "base", "stone")
		if stone_hits <= 1:
			_art(rect, "hazard", "stone_cracks_2")
			_art(rect, "hazard", "stone_gold_vein")
		elif stone_hits == 2:
			_art(rect, "hazard", "stone_cracks_1")
		_draw_art_rings(rect)
		return

	# A playing card: base, identity (or mod regalia), then trouble.
	_art(rect, "base", "card_blank")
	if washed:
		# FILLED: water to the brim hides everything.
		_art(rect, "hazard", "water_4")
		if washed_show_suit:  # Swimming Goggles
			_art(rect, "suit_corner", CardArt.suit_name(suit))
		_draw_art_chain_badge(font)
		_draw_art_rings(rect)
		return
	if joker and CardArt.tex("center", "face_joker") != null:
		# THE JOKER's own stack: harlequin skin, the jester, his JKR
		# index (no suit), any finish, then the ×2 badge on top.
		_art(rect, "mod_wash", "joker")
		_art(rect, "center", "face_joker")
		_art(rect, "mod_frame", "joker")
		_art(rect, "rank", "JKR")
		_draw_finish(rect)
		_art(rect, "rider", "joker_x2")
	else:
		var mod_key := mod
		# THE JOKER wears the lucky wash and frame as his own suit, with
		# whatever enhancement he's holding THIS hand as his badge.
		var skin := "lucky" if joker else mod_key
		if skin != "":
			_art(rect, "mod_wash", skin)
			_art(rect, "mod_frame", skin)
		# The card's own face ALWAYS shows — pip or letter — so the suit
		# reads clearly even enhanced; the emblem rides the free
		# bottom-left corner as a badge on every card.
		if joker:
			# No suit and no letter: the Wild emblem holds center stage.
			_art_badge(rect, "mod_emblem", "wild", Vector2(0.5, 0.47), 1.0)
		elif rank == 14:
			_draw_art_ace(rect)
		elif rank >= 11:
			_art(rect, "center", "face_%s_%s" % [CardArt.rank_name(rank),
					CardArt.suit_name(suit)])
		else:
			_art(rect, "center", "pip_" + CardArt.suit_name(suit))
		if mod_key != "" and not joker:
			var emb_anchor := Vector2(0.24, 0.78)
			var emb_scale := 0.52
			if metal_covered() and CardArt.tex("finish", "metal_plate") != null:
				# Under the steel plate the badge sits in the plate's round
				# window (centre 92,612, radius 38 on the 500×700 canvas).
				emb_anchor = Vector2(92.0 / 500.0, 612.0 / 700.0)
				emb_scale = 0.4
			if mod_key in ["plus", "minus", "bumper"]:
				_art_badge(rect, "mod_emblem", mod_key + "_arrow_up", emb_anchor,
						emb_scale, Color.WHITE, CardArt.arrow_rotation(boost_dir))
			else:
				_art_badge(rect, "mod_emblem", mod_key, emb_anchor, emb_scale)
		if joker:
			# A small nameplate, kept right of the corner badge.
			var jfont: Font = FontLib.numbers if FontLib.numbers != null \
					else ThemeDB.fallback_font
			draw_string(jfont, Vector2(rect.position.x + rect.size.x * 0.36,
					rect.end.y - 14.0), "JOKER  ×2",
					HORIZONTAL_ALIGNMENT_CENTER, rect.size.x * 0.56, 11,
					Color("2a4a2a"))
		elif mod == "chip" and chip_level > 0:
			# A seasoned chip wears its grown payout beside its badge.
			var cfont: Font = FontLib.numbers if FontLib.numbers != null \
					else ThemeDB.fallback_font
			draw_string(cfont, Vector2(rect.position.x + rect.size.x * 0.36,
					rect.end.y - 14.0),
					"+%d" % (chip_pay_base * (1 + chip_level)),
					HORIZONTAL_ALIGNMENT_CENTER, rect.size.x * 0.56, 12, GOLD)
		_draw_art_rank_suit(rect)
		_draw_finish(rect)

	# Hazards ride over the face; the code's motion rides over the art.
	match hazard:
		"fire":
			# No still art here â€” the painted flames fought the live
			# ones; the fire is all motion now.
			_draw_fire(rect)
		"water":
			_art(rect, "hazard", "water_%d" % clampi(water_level, 1, 4))
		"wind":
			# No medallion, no arrow: the living swirl is the body and
			# the streaming chevrons carry the direction.
			_draw_wind_swirl()
			_draw_wind_stream(rect)
		"bomb":
			# The dynamite rides the free top-right corner â€” center
			# stage belongs to the card's own face.
			var alert := 0.55 + 0.45 * sin(_t * 6.0 + _phase)
			var bomb_at := Vector2(0.76, 0.21)
			_art_badge(rect, "hazard", "bomb", bomb_at, 0.55)
			# The alert ring stays card-sized â€” a whole-card pulse
			# reads from across the board.
			_art(rect, "hazard", "bomb_alert_ring", Color(1, 1, 1, alert))
			# The fuse counter tucks against the medallion's lower-left
			# rim, clear of the card edge.
			_art_badge(rect, "hazard", "bomb_fuse_badge_%d" % fuse
					if fuse >= 1 and fuse <= 5 else "bomb_fuse_badge_blank",
					Vector2(0.60, 0.115), 0.55)

	# The in-the-path tells for the NEXT victim.
	match incoming:
		"fire":
			# Small live flames licking the bottom edge â€” the still
			# spark art never read as motion.
			_draw_flame_layer(rect, 11.0, 5, 6.0, Color(0.9, 0.46, 0.16, 0.6))
			_draw_flame_layer(rect, 6.5, 6, 7.6, Color(1.0, 0.85, 0.5, 0.65))
		"water":
			_art(rect, "hazard", "water_telegraph_seep")
		"wind":
			for k in 3:
				var wy := rect.end.y - 14.0 + k * 4.0
				var sweep := 8.0 * sin(_t * 3.2 + _phase + k * 1.4)
				draw_line(Vector2(rect.position.x + 10.0 + sweep, wy),
						Vector2(rect.position.x + 34.0 + sweep, wy),
						Color(WIND_BLUE.r, WIND_BLUE.g, WIND_BLUE.b, 0.7), 2.0)

	# Job pieces, curses, and the Queen's honey.
	match objective:
		"key":
			_art(rect, "special", "key")
		"chest":
			_art(rect, "special", "chest")
		"bullet":
			_art(rect, "special", "bullet_yours")
		"hisbullet":
			_art(rect, "special", "bullet_his")
		"redeal":
			var rc := Vector2(W / 2.0 - 16, H / 2.0 - 16)
			draw_arc(rc, 9.0, 0.7, TAU - 0.4, 14, WIND_BLUE, 3.0)
			var tip := rc + Vector2.RIGHT.rotated(0.7) * 9.0
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(4, -4), tip + Vector2(-4, -4), tip + Vector2(0, 5)]),
				WIND_BLUE)
	if honey:
		_art(rect, "special", "honey")
	if eights_wild and rank == 8:
		_art(rect, "rider", "wild8_badge")
	if cursed:
		_art(rect, "special", "cursed")
	_draw_art_chain_badge(font)
	_draw_art_rings(rect)


## The card back: a plain deep-red field with a lighter border.
func _draw_card_back(rect: Rect2) -> void:
	var inner := rect.grow(-5)
	draw_rect(inner, Color("6e2620"))
	draw_rect(inner.grow(-3), Color("8a3a30"), false, 2.0)


## Full-face identity for enhanced cards: gold cards go solid gold;
## everything else gets a wash of its color and an inner frame so the
## power reads at a glance.
func _draw_mod_face(rect: Rect2) -> void:
	if mod == "":
		return
	var inner := rect.grow(-3)
	if mod == "gold":
		# Solid gold through and through, with a top shine.
		draw_rect(inner, Color("d9b83f"))
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, 9)),
				Color(1.0, 0.95, 0.72, 0.5))
		draw_rect(inner.grow(-2), Color("8a6a1e"), false, 2.0)
		return
	var tint := _mod_color()
	tint.a = 0.13
	draw_rect(inner, tint)
	var frame := _mod_color()
	frame.a = 0.55
	draw_rect(inner.grow(-2), frame, false, 3.0)


func _mod_color() -> Color:
	match mod:
		"chip": return GOLD
		"mult": return ERROR_RED
		"wild": return WILD_PURPLE
		"plus": return BOOST_GREEN
		"minus": return ERROR_RED
		"bumper": return WIND_BLUE
	return GOLD


## The big center emblem that replaces the suit pip on enhanced
## cards: the card IS its power now.
func _draw_mod_art(font: Font) -> void:
	var c := Vector2(0, 6)
	match mod:
		"chip":
			# A fat poker chip.
			draw_circle(c, 24, GOLD)
			for k in 8:
				var mid := Vector2.RIGHT.rotated(TAU * k / 8.0) * 21.0
				draw_line(c + mid * 0.86, c + mid * 1.12, Color("faf3dc"), 6.0)
			draw_circle(c, 14, Color("a8842c"))
			draw_circle(c, 6, GOLD)
		"mult":
			draw_string(font, c + Vector2(-24, 18), "Ã—",
					HORIZONTAL_ALIGNMENT_CENTER, 48, 54, ERROR_RED)
		"gold":
			# A hefty nugget with a glint on the gold face.
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-20, 8), c + Vector2(-13, -15), c + Vector2(5, -20),
				c + Vector2(20, -5), c + Vector2(15, 15), c + Vector2(-8, 20)]),
				Color("b8901f"))
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-14, 5), c + Vector2(-9, -10), c + Vector2(4, -13),
				c + Vector2(13, -2), c + Vector2(9, 10), c + Vector2(-5, 13)]),
				Color("f5d76e"))
			draw_rect(Rect2(c + Vector2(-4, -8), Vector2(6, 6)),
					Color(1.0, 0.98, 0.85))
		"wild":
			draw_string(font, c + Vector2(-24, 17), "W",
					HORIZONTAL_ALIGNMENT_CENTER, 48, 46, WILD_PURPLE)
		"plus", "minus":
			var col := BOOST_GREEN if mod == "plus" else ERROR_RED
			# The big sign...
			draw_rect(Rect2(c + Vector2(-13, -4), Vector2(26, 8)), col)
			if mod == "plus":
				draw_rect(Rect2(c + Vector2(-4, -13), Vector2(8, 26)), col)
			# ...and the aim arrow, sweeping a quarter-turn each hand.
			var v := Vector2(boost_dir) * 22.0
			var perp := Vector2(-v.y, v.x).normalized() * 7.0
			var tip := c + v * 1.4
			draw_line(c + v * 0.8, tip, col, 5.0)
			draw_colored_polygon(PackedVector2Array([
				tip + v * 0.32, tip - v * 0.2 + perp, tip - v * 0.2 - perp]), col)
		"bumper":
			# The pad and the big shove arrow.
			var bv := Vector2(boost_dir) * 20.0
			var bperp := Vector2(-bv.y, bv.x).normalized()
			draw_line(c - bv * 0.5 + bperp * 18.0, c - bv * 0.5 - bperp * 18.0,
					WIND_BLUE, 8.0)
			var btip := c + bv * 1.35
			draw_line(c - bv * 0.1, btip, WIND_BLUE, 5.0)
			draw_colored_polygon(PackedVector2Array([
				btip + bv * 0.35, btip - bv * 0.2 + bperp * 8.0,
				btip - bv * 0.2 - bperp * 8.0]), WIND_BLUE)


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
		0:  # spades â€” one tall sharp point over small low lobes
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
		3:  # clubs â€” a clearly separated trefoil and a stem
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


## The card is ablaze, and the fire GROWS as the rank burns down: on
## an Ace the tongues barely clear the bottom edge; by rank 2 the card
## is all but consumed. All live paint, no still art: a pulsing heat
## glow, three smooth flame bodies back-to-front (ember red, orange,
## bright core), and embers breaking off the tips.
func _draw_fire(rect: Rect2) -> void:
	var burn := clampf(1.0 - (float(rank) - 2.0) / 12.0, 0.0, 1.0)
	var flicker := 0.04 * sin(_t * 9.0 + _phase)
	var glow := rect.grow(-2)
	draw_rect(glow, Color(0.95, 0.45, 0.1, 0.05 + 0.09 * burn + flicker))
	# The heat pools low on the card.
	draw_rect(Rect2(glow.position + Vector2(0, glow.size.y * 0.58),
			Vector2(glow.size.x, glow.size.y * 0.42)),
			Color(1.0, 0.55, 0.15, 0.08 + 0.12 * burn + flicker))
	# Four bodies back-to-front, each breathing on its own clock â€”
	# alpha and height swell and fade out of step, so the colors mix
	# and swirl through each other instead of sitting in fixed bands.
	var bodies := [
		[lerpf(0.30, 1.02, burn), 0.0, 0.9, Color(0.62, 0.13, 0.05, 0.80), 1.3, 0.0],
		[lerpf(0.22, 0.82, burn), 2.6, 1.25, Color(0.93, 0.44, 0.12, 0.78), 1.9, 2.1],
		[lerpf(0.16, 0.62, burn), 7.9, 1.5, Color(0.99, 0.62, 0.20, 0.66), 2.6, 4.0],
		[lerpf(0.12, 0.50, burn), 5.2, 1.8, Color(1.0, 0.87, 0.48, 0.80), 3.4, 1.1],
	]
	for b in bodies:
		var h_frac: float = b[0]
		var seed_off: float = b[1]
		var speed_mul: float = b[2]
		var col: Color = b[3]
		var rate: float = b[4]
		var off: float = b[5]
		var breathe := 0.5 + 0.5 * sin(_t * rate + _phase + off)
		col.a *= 0.55 + 0.45 * breathe
		_draw_flame_body(rect, rect.size.y * h_frac * (0.88 + 0.16 * breathe),
				seed_off, speed_mul, col)
	_draw_embers(rect, burn)


## One smooth flame body rising from the bottom edge. Two drifting
## waves multiplied (plus a fast shimmer) make tongues that split,
## merge and lick upward instead of marching in step; the power curve
## sharpens the peaks while the valleys stay low and round.
func _draw_flame_body(rect: Rect2, max_h: float, seed_off: float,
		speed_mul: float, col: Color) -> void:
	var left := rect.position.x + 2.0
	var width := rect.size.x - 4.0
	var floor_y := rect.end.y - 2.0
	var pts := PackedVector2Array()
	pts.append(Vector2(left, floor_y))
	# Dense sampling keeps the tongue tips ROUNDED â€” the sine fields
	# are smooth, so more points means soft licks, not spikes.
	var n := 36
	for i in n + 1:
		var u := float(i) / n
		var a := 0.5 + 0.5 * sin(u * 9.4 + _t * 4.2 * speed_mul + _phase + seed_off)
		var b := 0.5 + 0.5 * sin(u * 15.7 - _t * 6.1 * speed_mul
				+ _phase * 1.7 + seed_off * 2.3)
		var c := 0.5 + 0.5 * sin(u * 23.0 + _t * 9.5 * speed_mul + seed_off * 3.1)
		var h := max_h * (0.16 + 0.84 * pow(0.30 + 0.56 * a * b + 0.14 * c, 1.6))
		# The blaze roots a little lower at the card's edges.
		h *= 0.72 + 0.28 * sin(u * PI)
		pts.append(Vector2(left + width * u, floor_y - h))
	pts.append(Vector2(left + width, floor_y))
	draw_colored_polygon(pts, col)


## Sparks lifting off the fire: born at the flame line, swaying as
## they rise, winking out near the top of their arc.
func _draw_embers(rect: Rect2, burn: float) -> void:
	var count := 3 + int(burn * 3.0)
	var flame_top := rect.end.y - 4.0 - rect.size.y * lerpf(0.10, 0.55, burn)
	for k in count:
		var cycle := fposmod(_t * (0.55 + 0.17 * k) + k * 0.37 + _phase, 1.0)
		var u := fposmod(0.13 + 0.31 * k + 0.05 * sin(_t + k), 1.0)
		var x := rect.position.x + 4.0 + (rect.size.x - 8.0) * u \
				+ 5.0 * sin(cycle * 7.0 + k * 2.0)
		var y := lerpf(rect.end.y - 8.0, flame_top - 26.0, cycle)
		var fade := (1.0 - cycle) * (0.55 + 0.45 * sin(_t * 11.0 + k * 3.0))
		if fade <= 0.05:
			continue
		draw_circle(Vector2(x, maxf(y, rect.position.y + 4.0)),
				1.6 + 0.8 * (1.0 - cycle), Color(1.0, 0.72, 0.3, 0.75 * fade))


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


## The leaky SOURCE card: solid water at its current level â€” as it
## rises, the face slips out of sight rank-corner last.
func _draw_water(rect: Rect2) -> void:
	_draw_flood(rect, lerpf(0.16, 0.94,
			water_level / float(WATER_FULL_LEVEL)))


## The flood at height `frac` (0..1): an OPAQUE water body rising from
## the bottom behind a rolling, animated surface line, with bubbles
## working their way up. Whatever it covers, you can't read.
func _draw_flood(rect: Rect2, frac: float) -> void:
	var body := rect.grow(-3)
	var level := body.end.y - body.size.y * clampf(frac, 0.08, 1.0)
	var surface := PackedVector2Array()
	for i in 11:
		var x := body.position.x + body.size.x * i / 10.0
		surface.append(Vector2(x, level + 2.6 * sin(x * 0.18 + _t * 2.5 + _phase)))
	var fill := surface.duplicate()
	fill.append(Vector2(body.end.x, body.end.y))
	fill.append(Vector2(body.position.x, body.end.y))
	draw_colored_polygon(fill, Color(0.22, 0.38, 0.52))
	draw_polyline(surface, Color(0.82, 0.93, 1.0, 0.9), 2.0)
	# Bubbles need a little depth to rise through.
	if body.end.y - level > 16.0:
		for k in 3:
			var cycle := fposmod(_t * (0.4 + k * 0.15) + k * 0.41 + _phase, 1.0)
			var bx := body.position.x + body.size.x * (0.25 + 0.25 * k) \
					+ 4.0 * sin(cycle * 8.0 + k)
			var by := lerpf(body.end.y - 6.0, level + 6.0, cycle)
			draw_circle(Vector2(bx, by), 2.0, Color(0.85, 0.95, 1.0,
					0.7 * (1.0 - cycle * 0.4)))


## The gust's DIRECTION, worn on the card: little chevron streaks
## sliding across the face the way the wind blows, fading in and out
## as they travel.
func _draw_wind_stream(rect: Rect2) -> void:
	var dir := Vector2(wind_dir)
	var perp := Vector2(-dir.y, dir.x)
	var reach := minf(rect.size.x, rect.size.y) * 0.5
	for k in 3:
		var slide := fposmod(_t * 0.9 + k * 0.33 + _phase, 1.0)
		var center := dir * lerpf(-0.8, 0.8, slide) * reach \
				+ perp * (k - 1) * 14.0
		var a := 0.8 * sin(slide * PI)
		var col := Color(0.84, 0.92, 0.96, a)
		draw_line(center - dir * 11.0, center + dir * 11.0, col, 2.5)
		draw_line(center + dir * 11.0, center + dir * 6.0 + perp * 4.0, col, 2.0)
		draw_line(center + dir * 11.0, center + dir * 6.0 - perp * 4.0, col, 2.0)


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
	# Solid base â€” there's no card face under the rock any more.
	draw_rect(inner, Color(0.30, 0.30, 0.34))
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
		draw_colored_polygon(corners, Color(shade, shade, shade + 0.04, 0.9))
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


## The Weathervane tell on the TARGET: a whisper of the hazard that
## strikes here next â€” flames barely licking the bottom edge, or a
## thin line of water seeping in.
func _draw_incoming(rect: Rect2) -> void:
	match incoming:
		"fire":
			# Small flames barely licking the bottom edge â€” the fire
			# hasn't caught yet, but it's about to.
			_draw_flame_layer(rect, 11.0, 5, 6.0, Color(0.9, 0.46, 0.16, 0.6))
			_draw_flame_layer(rect, 6.5, 6, 7.6, Color(1.0, 0.85, 0.5, 0.65))
		"water":
			var level := rect.end.y - 9.0
			var pts := PackedVector2Array()
			for i in 11:
				var x := rect.position.x + 2.0 + (rect.size.x - 4.0) * i / 10.0
				pts.append(Vector2(x, level + 2.0 * sin(x * 0.2 + _t * 2.6 + _phase)))
			var fill := pts.duplicate()
			fill.append(Vector2(rect.end.x - 2.0, rect.end.y - 2.0))
			fill.append(Vector2(rect.position.x + 2.0, rect.end.y - 2.0))
			draw_colored_polygon(fill,
					Color(WATER_BLUE.r, WATER_BLUE.g, WATER_BLUE.b, 0.3))
			draw_polyline(pts, Color(0.82, 0.93, 1.0, 0.5), 1.5)
		"wind":
			# The Weathervane's warning: the gust takes THIS card next.
			for k in 3:
				var wy := rect.end.y - 14.0 + k * 4.0
				var sweep := 8.0 * sin(_t * 3.2 + _phase + k * 1.4)
				draw_line(Vector2(rect.position.x + 10.0 + sweep, wy),
						Vector2(rect.position.x + 34.0 + sweep, wy),
						Color(WIND_BLUE.r, WIND_BLUE.g, WIND_BLUE.b, 0.7), 2.0)


## Where the burning end of the fuse currently sits.
func _fuse_tip() -> Vector2:
	if CardArt.available():
		# The fuse ball baked into the corner medallion (anchored at
		# 0.76 / 0.21, drawn at 0.55 scale) â€” the spark sits on it.
		return Vector2(23.7, -39.9)
	return _fuse_point(float(fuse) / maxi(_fuse_max, 1))


## A point along the fuse rope: s = 0 at the bomb, 1 = the full,
## freshly-lit length. Curls up and to the right with a wiggle.
func _fuse_point(s: float) -> Vector2:
	# Rises from the middle stick of the dynamite bundle.
	var base := Vector2(-W / 2.0 + 21, H / 2.0 - 35)
	return base + Vector2(9.0 * s + 4.0 * sin(s * 6.5), -27.0 * s)


## Picking the rock up: a soft puff of dust off the surface.
func _stone_dust() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = 7
	p.lifetime = 0.55
	p.z_index = 4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(W * 0.4, H * 0.4)
	p.direction = Vector2.UP
	p.spread = 80.0
	p.gravity = Vector2(0, 60)
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 30.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5
	p.color = Color(0.62, 0.6, 0.54, 0.7)
	add_child(p)
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


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
