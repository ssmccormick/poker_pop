class_name GameOverScene
extends Control

## The trail's last page: a painted ending (cold dusk, the empty
## saloon, the pot slid away, or the golden ridge), the rider's
## portrait, the Trail Ledger, the relics carried and a map of the
## ride. Layers, layout and loop FX come from gameover_manifest.json.
## The intro is a pure function of one clock, so a click can jump it
## straight to its last frame.

signal ride_again
signal to_menu

const DIR := "res://assets/art/gameover/"
const MANIFEST := DIR + "gameover_manifest.json"
const VIEW := Vector2(1920, 1080)

const INK := Color("3a3126")
const INK_DIM := Color("8a7a5e")
const INK_RED := Color("a3322a")
const CAUSE_RED := Color("e07a5f")
const BONE := Color("f0e2c0")
const EPITAPH := Color("e6d5b0")
const GOLD := Color("e8c547")
const LABEL_LIT := Color("b9a98a")
const LABEL_AHEAD := Color("5f5644")
const SCRIM := Color("0c0806")

# Intro timeline (seconds), after the manifest's intro_anim.
const T_TITLE := 0.30
const TITLE_DUR := 0.18
const T_EPITAPH := 0.52
const T_PORTRAIT := 0.60
const T_LEDGER := 0.90
const LINE_STAGGER := 0.25
const MARK_STEP := 0.12
const T_RELICS := 2.40
const RELIC_STAGGER := 0.06
const T_STRIP := 2.70
const NODE_STEP := 0.04
const T_BUTTONS := 3.60
const T_HAND := T_TITLE + TITLE_DUR + 0.8

const ROMAN := ["I", "II", "III", "IV", "V"]

var host   # main (untyped): its _button() and board sounds

var _m: Dictionary = {}
var _data: Dictionary = {}
var _it := 0.0           # intro clock
var _intro_end := 4.0
var _t := 0.0            # loop clock
var _mute := false
var _fired := {}

var _scene: Control
var _ui: Control
var _title_box: Control
var _epitaph: RichTextLabel
var _portrait: Control
var _portrait_home := Vector2.ZERO
var _portrait_rot := 0.0
var _ledger: Control
var _ledger_home := Vector2.ZERO
var _lines: Array = []
var _outlaws := 0
var _tally_start := 0.0
var _tally_groups: Array = []
var _tally_tex: Array = []
var _marks_shown := -1
var _relic_slots: Array = []
var _nodes: Array = []
var _end_node := 0
var _rail_lit: NinePatchRect
var _rail_x0 := 0.0
var _node_dx := 75.0
var _flag: Control
var _flag_y := 0.0
var _star: Control
var _buttons: Array = []
var _ride_btn: Button

var _layers: Array = []
var _vultures: Array = []
var _vulture_frames: Array = []
var _vulture_fps := 5.0
var _dust: Array = []
var _dust_speed := -40.0
var _dust_tile := 2400.0
var _tumble: Sprite2D
var _tumble_cfg: Dictionary = {}
var _tumble_wait := 0.0
var _tumble_run := 0.0
var _glow: TextureRect
var _glow_alpha := Vector2(0.82, 1.0)
var _glow_hz := 7.0
var _flames: Array = []
var _flame_fps := 10.0
var _lantern_center := Vector2(1220, 740)
var _hand: TextureRect
var _hand_end := Vector2.ZERO
var _sun: TextureRect
var _sun_cfg: Dictionary = {}
var _glints: Array = []
var _glint_cfg: Dictionary = {}
var _glint_timer := 0.0


func _ready() -> void:
	size = VIEW
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


## Builds the page for one ending. Returns false (and stays hidden)
## when the art is missing, so the caller keeps its plain text page.
func show_ending(data: Dictionary) -> bool:
	visible = false
	if not FileAccess.file_exists(MANIFEST):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	_m = parsed
	var ending: Dictionary = _m.get("endings", {}).get(String(data.get("kind", "")), {})
	var layers: Array = ending.get("layers", [])
	if layers.is_empty() or _tex(String(layers[0].get("file", ""))) == null:
		return false
	_data = data
	_reset()
	_build_scene(ending)
	_build_ui()
	_it = 0.0
	_t = 0.0
	_apply_intro()
	visible = true
	return true


func _reset() -> void:
	for c in get_children():
		c.queue_free()
	_fired = {}
	_mute = false
	_lines.clear()
	_tally_groups.clear()
	_tally_tex.clear()
	_marks_shown = -1
	_relic_slots.clear()
	_nodes.clear()
	_buttons.clear()
	_layers.clear()
	_vultures.clear()
	_vulture_frames.clear()
	_dust.clear()
	_flames.clear()
	_glints.clear()
	_tumble = null
	_glow = null
	_hand = null
	_sun = null
	_flag = null
	_star = null
	_rail_lit = null


# --- Painted scene ---------------------------------------------------------

func _build_scene(ending: Dictionary) -> void:
	_scene = Control.new()
	_scene.size = VIEW
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scene)
	var fx: Dictionary = ending.get("fx", {})
	for layer in ending.get("layers", []):
		var tr := _full_rect(_tex(String(layer.get("file", ""))))
		_scene.add_child(tr)
		var drift := float(layer.get("parallax_drift_px", 0))
		if drift > 0.0:
			# Grown a hair so the sway never shows an edge.
			tr.pivot_offset = VIEW / 2.0
			tr.scale = Vector2.ONE * (VIEW.x + drift * 2.0) / VIEW.x
		_layers.append({"node": tr, "drift": drift, "phase": randf() * TAU})
		for id in fx:
			if String(fx[id].get("z_after", "")) == String(layer.get("id", "")):
				_build_fx(String(id), fx[id])
	for id in fx:
		if not fx[id].has("z_after"):
			_build_fx(String(id), fx[id])
	_build_scrims()


func _build_fx(id: String, f: Dictionary) -> void:
	match id:
		"vultures":
			for p in f.get("frames", []):
				_vulture_frames.append(_tex(String(p)))
			_vulture_fps = float(f.get("fps", 5))
			var orbit: Dictionary = f.get("orbit", {})
			var periods: Array = orbit.get("period_s", [14, 17, 21])
			var scales: Array = orbit.get("scale", [1.0, 0.7, 0.5])
			var alphas: Array = orbit.get("alpha", [0.9, 0.7, 0.55])
			var center := _vec(orbit.get("center", [1320, 300]))
			var radius := _vec(orbit.get("radius", [220, 70]))
			for i in int(f.get("count", 3)):
				var s := Sprite2D.new()
				s.texture = _vulture_frames[0] if not _vulture_frames.is_empty() else null
				s.scale = Vector2.ONE * float(scales[i % scales.size()])
				s.modulate.a = float(alphas[i % alphas.size()])
				_scene.add_child(s)
				_vultures.append({"sprite": s, "center": center, "radius": radius,
						"period": float(periods[i % periods.size()]),
						"phase": TAU * i / 3.0 + randf() * 0.6})
		"dust":
			_dust_speed = float(f.get("scroll_px_s", -40))
			_dust_tile = float(f.get("tile_x", 2400))
			var t := _tex(String(f.get("file", "")))
			for i in 2:
				var tr := TextureRect.new()
				tr.texture = t
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_SCALE
				tr.size = Vector2(_dust_tile, VIEW.y)
				tr.modulate.a = float(f.get("alpha", 0.55))
				tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_scene.add_child(tr)
				_dust.append(tr)
		"tumbleweed":
			_tumble_cfg = f
			_tumble = Sprite2D.new()
			_tumble.texture = _tex(String(f.get("file", "")))
			_tumble.visible = false
			_scene.add_child(_tumble)
			_tumble_wait = 1.2
		"lantern":
			_glow = _full_rect(_tex(String(f.get("glow", ""))))
			_scene.add_child(_glow)
			var flick: Dictionary = f.get("flicker", {})
			_glow_alpha = _vec(flick.get("alpha", [0.82, 1.0]))
			_glow_hz = float(flick.get("noise_hz", 7))
			_flame_fps = float(flick.get("flame_fps", 10))
			for p in f.get("flame_frames", []):
				var fl := _full_rect(_tex(String(p)))
				_scene.add_child(fl)
				_flames.append(fl)
			if not _flames.is_empty() and _flames[0].texture != null:
				var used: Rect2i = _flames[0].texture.get_image().get_used_rect()
				if used.size.x > 0:
					_lantern_center = Vector2(used.get_center())
		"dust_motes":
			_scene.add_child(_make_motes())
		"dealer_hand":
			_hand = TextureRect.new()
			_hand.texture = _tex(String(f.get("file", "")))
			_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_hand_end = _vec(f.get("pos_end", [1290, 586]))
			if _hand.texture != null:
				# The sleeve must run off the edge, never end in mid-air.
				_hand_end.x = maxf(_hand_end.x, VIEW.x - _hand.texture.get_width())
			_hand.position = _hand_end + Vector2(420, 0)
			_scene.add_child(_hand)
		"coin_glints":
			_glint_cfg = f
			for i in 5:
				var g := Sprite2D.new()
				g.texture = _tex(String(f.get("file", "")))
				g.visible = false
				_scene.add_child(g)
				_glints.append({"sprite": g, "age": -1.0})
		"sun_shimmer":
			_sun_cfg = f.get("pulse", {})
			_sun = _full_rect(_tex(String(f.get("file", ""))))
			_scene.add_child(_sun)
			if _sun.texture != null:
				var used: Rect2i = _sun.texture.get_image().get_used_rect()
				_sun.pivot_offset = Vector2(used.get_center()) if used.size.x > 0 \
						else VIEW / 2.0


## Lamp dust: warm motes drifting up through the lantern light.
func _make_motes() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = _lantern_center
	p.amount = 26
	p.lifetime = 5.5
	p.preprocess = 6.0
	p.texture = UiKit.knob_texture(3, Color.WHITE)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(150, 110)
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 14.0
	p.scale_amount_min = 0.33
	p.scale_amount_max = 0.83
	p.color = Color("e8c890")
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.25, Color(1, 1, 1, 0.8))
	ramp.add_point(0.7, Color(1, 1, 1, 0.6))
	p.color_ramp = ramp
	return p


## Shade behind the UI: heavy on the left, gone before the set piece,
## plus a band under the map and buttons.
func _build_scrims() -> void:
	var left := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(SCRIM, 0.78))
	g.set_color(1, Color(SCRIM, 0.0))
	g.add_point(1000.0 / VIEW.x, Color(SCRIM, 0.55))
	g.add_point(1250.0 / VIEW.x, Color(SCRIM, 0.0))
	left.gradient = g
	left.width = 256
	left.height = 4
	var lr := _full_rect(left)
	_scene.add_child(lr)
	var band := GradientTexture2D.new()
	var bg := Gradient.new()
	bg.set_color(0, Color(SCRIM, 0.0))
	bg.set_color(1, Color(SCRIM, 0.9))
	bg.add_point(0.35, Color(SCRIM, 0.85))
	band.gradient = bg
	band.fill_from = Vector2(0, 0)
	band.fill_to = Vector2(0, 1)
	band.width = 4
	band.height = 128
	var br := _full_rect(band)
	br.position = Vector2(0, VIEW.y - 290)
	br.size = Vector2(VIEW.x, 290)
	_scene.add_child(br)


# --- UI --------------------------------------------------------------------

func _build_ui() -> void:
	_ui = Control.new()
	_ui.size = VIEW
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	var complete := String(_data.get("kind", "")) == "trail_complete"
	_build_title(complete)
	_build_epitaph()
	_build_portrait(complete)
	_build_ledger()
	_build_relics()
	_build_strip(complete)
	_build_buttons()
	var strip_done := T_STRIP + _end_node * NODE_STEP + 0.4
	_intro_end = maxf(T_BUTTONS + 0.35, maxf(strip_done,
			_tally_start + _outlaws * MARK_STEP + 0.2))


func _build_title(complete: bool) -> void:
	var r := _layout_rect("title_plate", Rect2(120, 40, 980, 150))
	_title_box = Control.new()
	_title_box.position = r.position
	_title_box.size = r.size
	_title_box.pivot_offset = r.size / 2.0
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_title_box)
	var plate := _nine("title_plate_gilded" if complete else "title_plate")
	plate.size = r.size
	_title_box.add_child(plate)
	var tb := _layout_rect("title_text_box", Rect2(150, 58, 920, 112))
	var title := String(_data.get("title", ""))
	var font: Font = _font(FontLib.display)
	var fs := 96
	while fs > 48 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > tb.size.x - 90:
		fs -= 4
	var l := _label(_title_box, title, font, fs, GOLD if complete else BONE,
			Rect2(tb.position - r.position, tb.size), HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_color_override("font_outline_color", Color("2a1a0e"))
	l.add_theme_constant_override("outline_size", 6)


func _build_epitaph() -> void:
	var r := _layout_rect("epitaph", Rect2(130, 198, 960, 40))
	var text := String(_data.get("epitaph", ""))
	var cause := String(_data.get("cause", ""))
	var font: Font = _font(FontLib.card)
	var whole := text + ("   " + cause if cause != "" else "")
	var fs := 28
	while fs > 18 and font.get_string_size(whole, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x:
		fs -= 1
	_epitaph = RichTextLabel.new()
	_epitaph.bbcode_enabled = true
	_epitaph.scroll_active = false
	_epitaph.autowrap_mode = TextServer.AUTOWRAP_OFF
	_epitaph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_epitaph.position = r.position
	_epitaph.size = Vector2(r.size.x, r.size.y + 12)
	_epitaph.add_theme_font_override("normal_font", font)
	_epitaph.add_theme_font_size_override("normal_font_size", fs)
	_epitaph.add_theme_color_override("default_color", EPITAPH)
	var bb := "[center]%s" % _esc(text)
	if cause != "":
		bb += "   [color=#%s]%s[/color]" % [CAUSE_RED.to_html(false), _esc(cause)]
	_epitaph.text = bb + "[/center]"
	_ui.add_child(_epitaph)


func _build_portrait(complete: bool) -> void:
	var r := _layout_rect("portrait_frame", Rect2(120, 250, 340, 490))
	var kind := String(_data.get("kind", ""))
	var frame_kind := String(_m.get("endings", {}).get(kind, {}).get("portrait_frame",
			"gilded" if complete else "fallen"))
	var frame_info: Dictionary = _m.get("ui", {}).get("portrait_frame_" + frame_kind, {})
	var win := _rect(frame_info.get("window", [20, 20, 300, 450]), Rect2(20, 20, 300, 450))
	_portrait = Control.new()
	_portrait.position = r.position
	_portrait.size = r.size
	_portrait.pivot_offset = r.size / 2.0
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_portrait)
	_portrait_home = r.position
	_portrait_rot = -2.0 if frame_kind == "fallen" else 0.0
	var rider: Dictionary = _m.get("riders", {}).get(String(_data.get("rider", "")), {})
	var art := String(rider.get("fallen" if frame_kind == "fallen" else "art", ""))
	var face := TextureRect.new()
	face.texture = _tex(art)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.position = win.position
	face.size = win.size
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.add_child(face)
	var frame := TextureRect.new()
	frame.texture = _tex(String(frame_info.get("file", "ui/portrait_frame_%s.png" % frame_kind)))
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.size = r.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.add_child(frame)


func _build_ledger() -> void:
	var r := _layout_rect("ledger", Rect2(500, 250, 600, 490))
	_ledger = Control.new()
	_ledger.position = r.position
	_ledger.size = r.size
	_ledger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_ledger)
	_ledger_home = r.position
	var panel := _nine("ledger_panel")
	panel.size = r.size
	_ledger.add_child(panel)
	var start := _vec(_m.get("layout", {}).get("ledger_lines_start", [580, 312]))
	var left := start.x - r.position.x
	var right := r.size.x - 40.0
	var line_h := float(_m.get("layout", {}).get("ledger_line_h", 62))
	_label(_ledger, "Trail Ledger", _font(FontLib.display), 36, INK,
			Rect2(left, 16, 420, 50), HORIZONTAL_ALIGNMENT_LEFT)
	var underline := ColorRect.new()
	underline.color = Color(INK, 0.85)
	underline.position = Vector2(left, 64)
	underline.size = Vector2(right - left, 3)
	underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ledger.add_child(underline)
	var serif: Font = _font(FontLib.card)
	var top := start.y - r.position.y + 23.0
	var rows := ["Run score", "Best hand", "Outlaws caught", "Tables reached",
			"Cash banked", "Stake played"]
	for i in rows.size():
		var row := Control.new()
		row.position = Vector2(0, top + i * line_h)
		row.size = Vector2(r.size.x, line_h)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ledger.add_child(row)
		var name_l := _label(row, String(rows[i]), serif, 26, INK,
				Rect2(left, 0, 280, line_h - 8), HORIZONTAL_ALIGNMENT_LEFT)
		var rule := _tile("ledger_rule", Rect2(left - 8, line_h - 10, right - left + 16, 6))
		row.add_child(rule)
		var line := {"node": row, "start": T_LEDGER + 0.1 + LINE_STAGGER * i}
		var value_w := _build_value(row, i, line, serif, right, line_h - 8)
		var name_w := serif.get_string_size(name_l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var lead_from := left + name_w + 12.0
		var lead_to := right - value_w - 12.0
		if lead_to - lead_from > 16.0:
			row.add_child(_tile("ledger_leader_dots",
					Rect2(lead_from, (line_h - 8) / 2.0 + 6.0, lead_to - lead_from, 8)))
		_lines.append(line)


## One ledger value, right-aligned to `right`. Returns its width so
## the dot leader can stop short of it.
func _build_value(row: Control, i: int, line: Dictionary, serif: Font,
		right: float, h: float) -> float:
	match i:
		0:
			var score := int(_data.get("score", 0))
			var l := _label(row, _commas(score), serif, 32, INK,
					Rect2(right - 300, 0, 300, h), HORIZONTAL_ALIGNMENT_RIGHT)
			line["count"] = l
			line["value"] = score
			line["fmt"] = "%s"
			return serif.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
		1:
			var best := int(_data.get("best_score", 0))
			if best <= 0:
				_label(row, "—", serif, 26, INK_DIM, Rect2(right - 100, 0, 100, h),
						HORIZONTAL_ALIGNMENT_RIGHT)
				return 20.0
			var pts := " — %s" % _commas(best)
			var hand_name := String(_data.get("best_name", "")).to_upper()
			var pts_w := serif.get_string_size(pts, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			var name_w := serif.get_string_size(hand_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			_label(row, pts, serif, 26, INK_RED, Rect2(right - pts_w - 2, 0, pts_w + 4, h),
					HORIZONTAL_ALIGNMENT_RIGHT)
			_label(row, hand_name, serif, 26, INK,
					Rect2(right - pts_w - name_w - 4, 0, name_w + 4, h),
					HORIZONTAL_ALIGNMENT_RIGHT)
			return pts_w + name_w
		2:
			return _build_tallies(row, line, serif, right, h)
		3:
			var total := " / %d" % int(_data.get("total", 21))
			var tw := serif.get_string_size(total, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			_label(row, total, serif, 22, INK_DIM, Rect2(right - tw - 2, 2, tw + 4, h),
					HORIZONTAL_ALIGNMENT_RIGHT)
			var reached := str(int(_data.get("reached", 0)))
			var rw := serif.get_string_size(reached, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
			_label(row, reached, serif, 28, INK, Rect2(right - tw - rw - 4, 0, rw + 4, h),
					HORIZONTAL_ALIGNMENT_RIGHT)
			return tw + rw
		4:
			var cash := int(_data.get("cash", 0))
			var l := _label(row, "$" + _commas(cash), serif, 28, INK,
					Rect2(right - 300, 0, 300, h), HORIZONTAL_ALIGNMENT_RIGHT)
			line["count"] = l
			line["value"] = cash
			line["fmt"] = "$%s"
			return serif.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		_:
			var stake := String(_data.get("stake", ""))
			_label(row, stake, serif, 26, INK, Rect2(right - 300, 0, 300, h),
					HORIZONTAL_ALIGNMENT_RIGHT)
			return serif.get_string_size(stake, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x


## Outlaws as tally marks, five to a gate with the red slash. Past
## four gates the count turns into one stamp and a number.
func _build_tallies(row: Control, line: Dictionary, serif: Font, right: float,
		h: float) -> float:
	_outlaws = int(_data.get("outlaws", 0))
	_tally_start = float(line.start) + 0.1
	if _outlaws <= 0:
		_label(row, "none", serif, 24, INK_DIM, Rect2(right - 100, 0, 100, h),
				HORIZONTAL_ALIGNMENT_RIGHT)
		return 50.0
	var ui: Dictionary = _m.get("ui", {})
	if _outlaws > 20:
		var count := "× %d" % _outlaws
		var cw := serif.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		_label(row, count, serif, 26, INK, Rect2(right - cw - 2, 0, cw + 4, h),
				HORIZONTAL_ALIGNMENT_RIGHT)
		var stamp := TextureRect.new()
		stamp.texture = _tex(String(ui.get("outlaw_caught_stamp", "ui/outlaw_caught_stamp.png")))
		stamp.size = Vector2(48, 48)
		stamp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stamp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		stamp.position = Vector2(right - cw - 56, (h - 48) / 2.0)
		stamp.pivot_offset = Vector2(24, 24)
		stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(stamp)
		_tally_groups.append(stamp)
		_outlaws = 1  # one punch for the stamp
		return cw + 56.0
	var tally: Dictionary = ui.get("tally", {})
	for k in 5:
		_tally_tex.append(_tex(String(tally.get("tally_%d" % (k + 1),
				"ui/tally_%d.png" % (k + 1)))))
	var groups := int(ceil(_outlaws / 5.0))
	var gw := 64.0
	var gap := 6.0
	var total := groups * gw + (groups - 1) * gap
	for g in groups:
		var tr := TextureRect.new()
		tr.size = Vector2(gw, 52)
		tr.position = Vector2(right - total + g * (gw + gap), (h - 52) / 2.0)
		tr.pivot_offset = Vector2(gw, 52) / 2.0
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tr)
		_tally_groups.append(tr)
	return total


func _build_relics() -> void:
	var lp := _vec(_m.get("layout", {}).get("relics_label", [120, 776]))
	_label(_ui, "RELICS CARRIED", _spaced(FontLib.label, 4), 20, LABEL_LIT,
			Rect2(lp.x, lp.y, 360, 30), HORIZONTAL_ALIGNMENT_LEFT)
	var rowcfg: Array = _m.get("layout", {}).get("relics_row", [500, 748, 8, 72, 10])
	var x0 := float(rowcfg[0])
	var y0 := float(rowcfg[1])
	var count := int(rowcfg[2])
	var slot := float(rowcfg[3])
	var gap := float(rowcfg[4])
	var slot_cfg: Dictionary = _m.get("ui", {}).get("relic_slot", {})
	var box := _rect(slot_cfg.get("icon_box", [10, 10, 52, 52]), Rect2(10, 10, 52, 52))
	var relics: Array = _data.get("relics", [])
	for j in count:
		var holder := Control.new()
		holder.position = Vector2(x0 + j * (slot + gap), y0)
		holder.size = Vector2(slot, slot)
		holder.pivot_offset = Vector2(slot, slot) / 2.0
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.add_child(holder)
		var has := j < relics.size()
		var bg := TextureRect.new()
		bg.texture = _tex(String(slot_cfg.get("file" if has else "empty",
				"ui/relic_slot.png" if has else "ui/relic_slot_empty.png")))
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.size = holder.size
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(bg)
		if has:
			var id := String(relics[j])
			var glyph := CardArt.tex("relic_glyph", String(RelicIcon.ART_NAMES.get(id, id)))
			if glyph != null:
				var g := TextureRect.new()
				g.texture = glyph
				g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				g.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				g.position = box.position
				g.size = box.size
				g.mouse_filter = Control.MOUSE_FILTER_IGNORE
				holder.add_child(g)
			else:
				var icon := RelicIcon.new()
				icon.relic_id = id
				icon.position = holder.size / 2.0
				icon.scale = Vector2.ONE * (box.size.x / 72.0)
				holder.add_child(icon)
			var tip: Dictionary = TrailMode.RELICS.get(id, {})
			holder.tooltip_text = "%s — %s" % [tip.get("name", id), tip.get("desc", "")]
			holder.mouse_filter = Control.MOUSE_FILTER_PASS
		_relic_slots.append(holder)


## The map of the ride: every stop in order, bosses on their cards,
## the outlaw and campfire stops the rider actually took, and a flag
## (or the victory star) where it ended.
func _build_strip(complete: bool) -> void:
	var lay: Dictionary = _m.get("layout", {})
	var strip: Dictionary = _m.get("ui", {}).get("strip", {})
	var total := int(_data.get("total", 21))
	var reached := int(_data.get("reached", 1))
	var rsize := int(_data.get("region_size", 7))
	var camp_slot := int(_data.get("camp_slot", 3))
	var bosses: Dictionary = _data.get("bosses", {})
	var stops: Array = _data.get("stops", [])
	_rail_x0 = float(lay.get("strip_node_x0", 210))
	_node_dx = float(lay.get("strip_node_dx", 75))
	var ry := float(lay.get("strip_rail_y", 900))
	_end_node = reached
	var margins: Array = strip.get("rail_margins", [10, 0, 10, 0])
	var rail := _nine_file(String(strip.get("rail", "ui/strip_rail.png")), margins)
	rail.position = Vector2(_rail_x0 - 10, ry - 14)
	rail.size = Vector2((total - 1) * _node_dx + 20, 28)
	_ui.add_child(rail)
	_rail_lit = _nine_file(String(strip.get("rail_lit", "ui/strip_rail_lit.png")), margins)
	_rail_lit.position = rail.position
	_rail_lit.size = Vector2(20, 28)
	_rail_lit.visible = false
	_ui.add_child(_rail_lit)
	var regions := int(ceil(float(total) / rsize))
	var oswald := _spaced(FontLib.label, 5)
	# The end flag's footprint (pole ~3/8 across 48px art): a region
	# name that would sit under it steps aside within its region.
	var flag_l := _node_x(reached) - 22.0
	var flag_r := _node_x(reached) + 34.0
	for reg in regions:
		var first := reg * rsize + 1
		var last := mini(first + rsize - 1, total)
		var lit := reached >= first
		var text := "REGION %s" % ROMAN[reg % ROMAN.size()]
		var half := oswald.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x / 2.0 + 4.0
		var cx := (_node_x(first) + _node_x(last)) / 2.0
		if not complete and cx + half > flag_l and cx - half < flag_r:
			var right_cx := flag_r + half
			var left_cx := flag_l - half
			cx = right_cx if right_cx + half <= _node_x(last) + 20.0 \
					or absf(right_cx - cx) <= absf(left_cx - cx) else left_cx
		_label(_ui, text, oswald, 18, LABEL_LIT if lit else LABEL_AHEAD,
				Rect2(cx - 120, ry - 58, 240, 26), HORIZONTAL_ALIGNMENT_CENTER)
		if reg > 0:
			var post := TextureRect.new()
			post.texture = _tex(String(strip.get("region_divider", "ui/region_divider.png")))
			post.position = Vector2(_node_x(first) - _node_dx / 2.0 - 20, ry - 66)
			post.size = Vector2(40, 96)
			post.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_ui.add_child(post)
	var mono := _font(FontLib.label)
	for t in range(1, total + 1):
		var room := t - 1
		var lit_key := "table_passed"
		var ahead_key := "table_ahead"
		if bosses.has(room):
			lit_key = "boss_%s" % String(bosses[room])
			ahead_key = lit_key + "_ahead"
		else:
			var kind := String(stops[room]) if room < stops.size() else ""
			if room % rsize == camp_slot:
				ahead_key = "campfire_ahead"
			if kind == "camp":
				lit_key = "campfire"
			elif kind == "outlaw":
				lit_key = "outlaw"
			elif t == reached and not complete:
				lit_key = "table_current"
		var ahead_tex := _tex(String(strip.get(ahead_key, "ui/marker_%s.png" % ahead_key)))
		var lit_tex := _tex(String(strip.get(lit_key, "ui/marker_%s.png" % lit_key)))
		var tr := TextureRect.new()
		tr.texture = ahead_tex
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.add_child(tr)
		var n := {"rect": tr, "ahead": ahead_tex, "lit": lit_tex, "on": false,
				"center": Vector2(_node_x(t), ry), "t": t}
		_place_node(n)
		_nodes.append(n)
		_label(_ui, str(t), mono, 16, LABEL_LIT if t <= reached else LABEL_AHEAD,
				Rect2(_node_x(t) - 20, ry + 36, 40, 24), HORIZONTAL_ALIGNMENT_CENTER)
	var end_x := _node_x(reached)
	if complete:
		_star = TextureRect.new()
		_star.texture = _tex(String(strip.get("victory", "ui/marker_victory.png")))
		_star.size = Vector2(80, 80)
		_star.position = Vector2(end_x - 40, ry - 104)
		_star.pivot_offset = Vector2(40, 40)
		_star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.add_child(_star)
	else:
		var flag := TextureRect.new()
		flag.texture = _tex(String(strip.get("ended_here", "ui/marker_ended.png")))
		flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flag.size = Vector2(48, 63)
		flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The pole stands ~3/8 across the art; plant it on the node,
		# above a boss card when the ride ended at one.
		var foot := ry - (44.0 if bosses.has(reached - 1) else 12.0)
		_flag_y = foot - flag.size.y
		flag.position = Vector2(end_x - 18, _flag_y)
		_flag = flag
		_ui.add_child(flag)


func _place_node(n: Dictionary) -> void:
	var tr: TextureRect = n.rect
	var t: Texture2D = tr.texture
	var s := Vector2(t.get_size()) if t != null else Vector2(32, 32)
	tr.size = s
	tr.pivot_offset = s / 2.0
	tr.position = Vector2(n.center) - s / 2.0


func _build_buttons() -> void:
	var btns: Dictionary = _m.get("layout", {}).get("buttons", {})
	var back_r := _rect(btns.get("back_to_menu", [1110, 978, 310, 72]), Rect2(1110, 978, 310, 72))
	var ride_r := _rect(btns.get("ride_again", [1440, 978, 360, 72]), Rect2(1440, 978, 360, 72))
	var back: Button = host._button(_ui, "BACK TO MENU", back_r.position, back_r.size)
	var ride: Button = host._button(_ui, "RIDE AGAIN", ride_r.position, ride_r.size, true)
	for b in [back, ride]:
		if FontLib.display != null:
			b.add_theme_font_override("font", FontLib.display)
		b.add_theme_font_size_override("font_size", 30)
		_buttons.append(b)
	back.pressed.connect(func() -> void: to_menu.emit())
	ride.pressed.connect(func() -> void: ride_again.emit())
	_ride_btn = ride


# --- Intro (a pure function of _it) ----------------------------------------

func _apply_intro() -> void:
	var it := _it
	_scene.modulate.a = _c01(it / 0.5)
	# The title slams in, then the whole page jolts.
	var p := _c01((it - T_TITLE) / TITLE_DUR)
	_title_box.modulate.a = p
	_title_box.scale = Vector2.ONE * lerpf(1.6, 1.0, _ease_out_back(p))
	var sp := (it - T_TITLE - TITLE_DUR) / 0.16
	_ui.position = Vector2(sin(sp * TAU * 2.0) * 6.0 * (1.0 - sp), 0) \
			if sp > 0.0 and sp < 1.0 else Vector2.ZERO
	if it >= T_TITLE + TITLE_DUR:
		_once("slam", func() -> void:
			_sfx(Board.SFX_POPS.pick_random(), 0.45, -4.0)
			_sfx(Board.SFX_KNIVES.pick_random(), 0.7, -8.0))
	_epitaph.modulate.a = _c01((it - T_EPITAPH) / 0.4)
	# The frame drops and settles (crooked, for the fallen).
	p = _c01((it - T_PORTRAIT) / 0.4)
	var b := _bounce(p)
	_portrait.modulate.a = _c01(p * 4.0)
	_portrait.position = _portrait_home + Vector2(0, -30.0 * (1.0 - b))
	_portrait.rotation_degrees = lerpf(-4.0, _portrait_rot, b)
	# The ledger slides up; its lines tick in and count.
	p = _c01((it - T_LEDGER) / 0.25)
	_ledger.modulate.a = p
	_ledger.position = _ledger_home + Vector2(0, 40.0 * (1.0 - _ease_out(p)))
	for line in _lines:
		var s := float(line.start)
		var row: Control = line.node
		row.modulate.a = _c01((it - s) / 0.15)
		if line.has("count"):
			var q := _ease_out(_c01((it - s) / 0.4))
			var lbl: Label = line.count
			lbl.text = String(line.fmt) % _commas(int(round(int(line.value) * q)))
	_apply_tallies(it)
	for j in _relic_slots.size():
		var q := _c01((it - T_RELICS - RELIC_STAGGER * j) / 0.2)
		var slot: Control = _relic_slots[j]
		slot.scale = Vector2.ONE * maxf(0.001, _ease_out_back(q))
		slot.modulate.a = _c01(q * 3.0)
	_apply_strip(it)
	if _hand != null:
		var hp := _ease_in_out(_c01((it - T_HAND) / 1.6))
		_hand.position = _hand_end + Vector2(420.0 * (1.0 - hp), 0)
		if it >= T_HAND:
			_once("hand", func() -> void:
				_sfx(Board.SFX_COINS.pick_random(), 0.8, -10.0))
	var bp := _c01((it - T_BUTTONS) / 0.3)
	for btn in _buttons:
		var bt: Button = btn
		bt.modulate.a = bp
	if bp >= 1.0:
		var focus := func() -> void: _ride_btn.grab_focus()
		_once("focus", focus, false)


func _apply_tallies(it: float) -> void:
	if _tally_groups.is_empty():
		return
	var shown := 0
	if it >= _tally_start:
		shown = mini(_outlaws, int((it - _tally_start) / MARK_STEP) + 1)
	if shown != _marks_shown:
		if shown > maxi(_marks_shown, 0) and not _mute:
			_sfx(Board.SFX_KNIVES.pick_random(), 1.15, -12.0)
		_marks_shown = shown
		if _tally_tex.is_empty():
			var stamp: TextureRect = _tally_groups[0]
			stamp.visible = shown > 0
		else:
			for g in _tally_groups.size():
				var tr: TextureRect = _tally_groups[g]
				var marks := clampi(shown - g * 5, 0, 5)
				tr.texture = _tally_tex[marks - 1] if marks > 0 else null
	for g in _tally_groups.size():
		var tr: TextureRect = _tally_groups[g]
		tr.scale = Vector2.ONE
	if shown > 0:
		var age := it - (_tally_start + (shown - 1) * MARK_STEP)
		var latest: TextureRect = _tally_groups[mini((shown - 1) / 5, _tally_groups.size() - 1)]
		latest.scale = Vector2.ONE * lerpf(1.4, 1.0, _c01(age / MARK_STEP))


func _apply_strip(it: float) -> void:
	var lit := 0
	if it >= T_STRIP:
		lit = mini(_end_node, int((it - T_STRIP) / NODE_STEP) + 1)
	for k in _nodes.size():
		var n: Dictionary = _nodes[k]
		var on := k < lit
		var tr: TextureRect = n.rect
		if on != bool(n.on):
			n.on = on
			tr.texture = n.lit if on else n.ahead
			_place_node(n)
		var age := it - (T_STRIP + k * NODE_STEP)
		tr.scale = Vector2.ONE * (1.0 + 0.35 * (1.0 - _c01(age / 0.15))) \
				if on and age < 0.15 else Vector2.ONE
	_rail_lit.visible = lit > 0
	if lit > 0:
		_rail_lit.size.x = (lit - 1) * _node_dx + 20.0
	var done := T_STRIP + _end_node * NODE_STEP
	var p := _c01((it - done) / 0.35)
	if _flag != null:
		_flag.modulate.a = _c01(p * 3.0)
		_flag.position.y = _flag_y - 40.0 * (1.0 - _bounce(p))
		if it >= done:
			_once("flag", func() -> void:
				_sfx(Board.SFX_KNIVES.pick_random(), 0.85, -8.0))
	if _star != null:
		_star.modulate.a = _c01(p * 3.0)
		_star.scale = Vector2.ONE * maxf(0.001, _ease_out_back(p))
		_star.rotation = -0.6 * (1.0 - p)
		if it >= done:
			_once("star", func() -> void:
				_sfx(Board.SFX_BELL, 1.0, -8.0)
				_sfx(Board.SFX_COINS.pick_random(), 1.1, -8.0))


func _gui_input(event: InputEvent) -> void:
	# A click jumps the intro to its last frame.
	if event is InputEventMouseButton and event.pressed and _it < _intro_end:
		_mute = true
		_it = _intro_end
		_apply_intro()
		_mute = false
		accept_event()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if _it < _intro_end:
		_it = minf(_it + delta, _intro_end)
		_apply_intro()
	_t += delta
	for l in _layers:
		if float(l.drift) > 0.0:
			var node: TextureRect = l.node
			node.position.x = sin(_t * 0.18 + float(l.phase)) * float(l.drift)
	_loop_vultures()
	for i in _dust.size():
		var d: TextureRect = _dust[i]
		d.position.x = -fposmod(-_t * _dust_speed, _dust_tile) + i * _dust_tile
	_loop_tumbleweed(delta)
	if _glow != null:
		var n := 0.5 + 0.3 * sin(_t * _glow_hz * 0.9) + 0.2 * sin(_t * _glow_hz * 1.7 + 1.3)
		_glow.modulate.a = lerpf(_glow_alpha.x, _glow_alpha.y, clampf(n, 0.0, 1.0))
	if not _flames.is_empty():
		var frame := int(_t * _flame_fps) % _flames.size()
		for i in _flames.size():
			var fl: TextureRect = _flames[i]
			fl.visible = i == frame
	if _sun != null:
		var period := float(_sun_cfg.get("period_s", 3.2))
		var w := 0.5 + 0.5 * sin(_t / period * TAU)
		var sc := _vec(_sun_cfg.get("scale", [0.96, 1.06]))
		var al := _vec(_sun_cfg.get("alpha", [0.75, 1.0]))
		_sun.scale = Vector2.ONE * lerpf(sc.x, sc.y, w)
		_sun.modulate.a = lerpf(al.x, al.y, w)
	_loop_glints(delta)


func _loop_vultures() -> void:
	for i in _vultures.size():
		var v: Dictionary = _vultures[i]
		var s: Sprite2D = v.sprite
		var ang := _t / float(v.period) * TAU + float(v.phase)
		var c: Vector2 = v.center
		var r: Vector2 = v.radius
		s.position = c + Vector2(cos(ang) * r.x, sin(ang) * r.y)
		if not _vulture_frames.is_empty():
			s.texture = _vulture_frames[int(_t * _vulture_fps + i) % _vulture_frames.size()]


func _loop_tumbleweed(delta: float) -> void:
	if _tumble == null:
		return
	if not _tumble.visible:
		_tumble_wait -= delta
		if _tumble_wait <= 0.0:
			_tumble.visible = true
			_tumble.position.x = VIEW.x + 80.0
			_tumble_run = 0.0
		return
	var speed := float(_tumble_cfg.get("speed_px_s", 260))
	_tumble_run += speed * delta
	_tumble.position.x -= speed * delta
	_tumble.position.y = float(_tumble_cfg.get("path_y", 770)) \
			- absf(sin(_tumble_run / 110.0)) * float(_tumble_cfg.get("bounce_px", 18))
	_tumble.rotation -= deg_to_rad(float(_tumble_cfg.get("spin_deg_s", 280))) * delta
	if _tumble.position.x < -90.0:
		_tumble.visible = false
		var rs := _vec(_tumble_cfg.get("respawn_s", [6, 11]))
		_tumble_wait = randf_range(rs.x, rs.y)


func _loop_glints(delta: float) -> void:
	if _glints.is_empty():
		return
	var life := float(_glint_cfg.get("life_s", 0.6))
	_glint_timer -= delta
	if _glint_timer <= 0.0:
		_glint_timer = float(_glint_cfg.get("every_s", 0.35))
		for g in _glints:
			if float(g.age) < 0.0:
				var area := _rect(_glint_cfg.get("spawn_area", [1240, 700, 300, 140]),
						Rect2(1240, 700, 300, 140))
				var sp: Sprite2D = g.sprite
				sp.position = area.position + Vector2(randf() * area.size.x, randf() * area.size.y)
				g.age = 0.0
				break
	var sc := _vec(_glint_cfg.get("scale", [0.4, 1.0]))
	var rot := deg_to_rad(float(_glint_cfg.get("rotate_deg", 45)))
	for g in _glints:
		var sp: Sprite2D = g.sprite
		if float(g.age) < 0.0:
			sp.visible = false
			continue
		g.age = float(g.age) + delta
		var q := float(g.age) / life
		if q >= 1.0:
			g.age = -1.0
			sp.visible = false
			continue
		var bell := sin(q * PI)
		sp.visible = true
		sp.scale = Vector2.ONE * lerpf(sc.x, sc.y, bell)
		sp.modulate.a = bell
		sp.rotation = rot * q


# --- Helpers ---------------------------------------------------------------

func _once(key: String, cb: Callable, is_sound := true) -> void:
	if _fired.has(key):
		return
	_fired[key] = true
	if is_sound and _mute:
		return
	cb.call()


func _sfx(stream: AudioStream, pitch: float, db: float) -> void:
	if host != null and host.board != null:
		host.board._play_sound(stream, pitch, db)


func _tex(rel: String) -> Texture2D:
	if rel == "":
		return null
	var p := DIR + rel
	return load(p) if ResourceLoader.exists(p) else null


func _full_rect(t: Texture2D) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = VIEW
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## A 9-slice piece by manifest ui key.
func _nine(key: String) -> NinePatchRect:
	var info: Dictionary = _m.get("ui", {}).get(key, {})
	return _nine_file(String(info.get("file", "ui/%s.png" % key)),
			info.get("margins", [0, 0, 0, 0]))


func _nine_file(file: String, margins: Array) -> NinePatchRect:
	var np := NinePatchRect.new()
	np.texture = _tex(file)
	if margins.size() == 4:
		np.patch_margin_left = int(margins[0])
		np.patch_margin_top = int(margins[1])
		np.patch_margin_right = int(margins[2])
		np.patch_margin_bottom = int(margins[3])
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return np


## A horizontally tiled strip (ledger rules, dot leaders).
func _tile(key: String, r: Rect2) -> TextureRect:
	var info: Dictionary = _m.get("ui", {}).get(key, {})
	var tr := TextureRect.new()
	tr.texture = _tex(String(info.get("file", "ui/%s.png" % key)))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.position = r.position
	tr.size = r.size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _label(parent: Control, text: String, font: Font, fs: int, col: Color,
		r: Rect2, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = false
	l.position = r.position
	l.size = r.size
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _font(f: Font) -> Font:
	return f if f != null else ThemeDB.fallback_font


## Small caps labels want air between the letters.
func _spaced(f: Font, px: int) -> Font:
	var fv := FontVariation.new()
	fv.base_font = _font(f)
	fv.spacing_glyph = px
	return fv


func _layout_rect(key: String, fallback: Rect2) -> Rect2:
	return _rect(_m.get("layout", {}).get(key, []), fallback)


func _rect(a: Variant, fallback: Rect2) -> Rect2:
	if typeof(a) == TYPE_ARRAY and (a as Array).size() == 4:
		return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	return fallback


func _vec(a: Variant) -> Vector2:
	if typeof(a) == TYPE_ARRAY and (a as Array).size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return Vector2.ZERO


func _node_x(t: int) -> float:
	return _rail_x0 + (t - 1) * _node_dx


static func _commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


static func _c01(x: float) -> float:
	return clampf(x, 0.0, 1.0)


static func _ease_out(p: float) -> float:
	return 1.0 - pow(1.0 - p, 3.0)


static func _ease_in_out(p: float) -> float:
	return p * p * (3.0 - 2.0 * p)


static func _ease_out_back(p: float) -> float:
	const C1 := 1.70158
	const C3 := C1 + 1.0
	return 1.0 + C3 * pow(p - 1.0, 3.0) + C1 * pow(p - 1.0, 2.0)


static func _bounce(p: float) -> float:
	const N := 7.5625
	const D := 2.75
	if p < 1.0 / D:
		return N * p * p
	elif p < 2.0 / D:
		p -= 1.5 / D
		return N * p * p + 0.75
	elif p < 2.5 / D:
		p -= 2.25 / D
		return N * p * p + 0.9375
	p -= 2.625 / D
	return N * p * p + 0.984375
