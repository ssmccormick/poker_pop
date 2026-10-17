class_name MenuMobile
extends RefCounted

## The menus and meta screens on the phone canvas (1080×2340). As with
## TrailMobile, the desktop builders run first and these move the same
## nodes into one column at phone type sizes, so every refresh keeps
## working. Called from main when Form is mobile.

const M := TrailMobile.M


static func _n(parent: Node, id: String) -> Control:
	return parent.get_node_or_null(id) as Control


static func _btn(b: Control, r: Rect2, font_size: int) -> void:
	if b == null:
		return
	TrailMobile.place(b, r, font_size)
	b.set_meta("font_size", font_size)  # restyling keeps the phone size
	b.pivot_offset = r.size / 2.0
	if b is Button:
		UiKit.fit_button_text(b, font_size, maxi(18, font_size / 2))


## Resizes a UiKit.plate and the shadow and face it carries.
static func plate(p: Control, r: Rect2) -> void:
	if p == null:
		return
	p.position = r.position
	p.size = r.size
	for c in p.get_children():
		if c is Panel:
			var sh := (c as Panel).position == Vector2(-14, -8)
			(c as Panel).size = r.size + (Vector2(28, 28) if sh else Vector2.ZERO)
		elif c is UiKit.Rivets:
			(c as UiKit.Rivets).plate_size = r.size
			(c as Node2D).queue_redraw()


static func _grow_font(c: Control, k: float) -> void:
	if c is Label or c is Button:
		c.add_theme_font_size_override("font_size",
				roundi(c.get_theme_font_size("font_size") * k))


## A one-line desktop list row (1040 wide) restacked for the phone. What
## sits left of `split` (the icon, the name, the words) grows on the top
## line; what sits right of it (the price, the bar, the buttons) spreads
## across a second line underneath.
static func stack_row(row: Control, split: float) -> void:
	var w := TrailMobile.iw()
	var old := row.custom_minimum_size
	var k := minf(1.5, (w - 16.0) / split)
	var top_h := old.y * k
	var ky := 1.6
	var sx := (w - 48.0) / (1040.0 - split)
	var plates: Array = []
	var right: Array = []
	var y_min := INF
	for c in row.get_children():
		if c is Panel and (c as Panel).size == old:
			plates.append(c)
			continue
		var at: Vector2 = c.position
		var sz: Vector2 = (c as Control).size if c is Control else Vector2.ZERO
		if at.x + sz.x / 2.0 >= split:
			right.append(c)
			y_min = minf(y_min, at.y)
	var bottom := top_h
	for c in row.get_children():
		if c in plates:
			continue
		if c is Label and (c as Label).text == "NEW":
			TrailMobile.place(c, Rect2(w - 96.0, 10, 80, 30), 24)
			continue
		if c in right:
			if c is Control:
				var cc := c as Control
				var x := maxf(24.0, 24.0 + (cc.position.x - split) * sx)
				var cw := minf(cc.size.x * sx, w - 24.0 - x)
				var y := top_h + (cc.position.y - y_min) * ky
				cc.position = Vector2(x, y)
				cc.size = Vector2(cw, cc.size.y * ky)
				_grow_font(cc, ky)
				if cc is Button:
					cc.add_theme_font_size_override("font_size",
							maxi(28, cc.get_theme_font_size("font_size")))
					cc.mouse_filter = Control.MOUSE_FILTER_PASS
					cc.pivot_offset = cc.size / 2.0
					UiKit.fit_button_text(cc, cc.get_theme_font_size("font_size"), 18)
				bottom = maxf(bottom, y + cc.size.y)
			elif c is Node2D:
				(c as Node2D).position = Vector2(24.0 + (c.position.x - split) * sx,
						top_h + (c.position.y - y_min) * ky)
				(c as Node2D).scale *= ky
		elif c is Control:
			var cc := c as Control
			cc.position *= k
			cc.size *= k
			_grow_font(cc, k)
			if cc is Label and (cc as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
				cc.custom_minimum_size = Vector2(cc.size.x, 0)
		elif c is Node2D:
			(c as Node2D).position *= k
			(c as Node2D).scale *= k
	var h := bottom + 20.0
	row.custom_minimum_size = Vector2(w, h)
	row.size = row.custom_minimum_size
	for p in plates:
		plate(p, Rect2(0, 0, w, h))


# --- The splash and the main menu ----------------------------------------------

static func splash(m) -> void:
	var L: Control = m.splash_layer
	var logo := _n(L, "Logo")
	if logo != null:
		TrailMobile.place(logo, Rect2(90, 640, 900, 504))
	var prompt := _n(L, "Prompt") as Label
	if prompt != null:
		prompt.text = "TAP TO START"
		TrailMobile.text(prompt, Rect2(M, 1260, TrailMobile.iw(), 90), 56)


## The logo and the level up top, then THE TRAIL, the quick modes with
## their one-line notes, the other screens two by two, OPTIONS at the foot.
static func menu(m) -> void:
	var L: Control = m.menu_layer
	var w := Form.view().x
	var iw := TrailMobile.iw()
	var top := Form.safe_top()
	_btn(m._profile_menu_btn, Rect2(M, top + 8.0, 330, 100), 32)
	var lp: Control = m._level_plate
	lp.scale = Vector2(1.4, 1.4)
	lp.position = Vector2(w - M - lp.size.x * 1.4, top)
	TrailMobile.text(_n(L, "Tagline"), Rect2(M, 652, iw, 50), 34)
	_btn(_n(L, "Trail"), Rect2(M, 730, iw - 316.0, 130), 44)
	_btn(_n(L, "Upgrades"), Rect2(w - M - 300.0, 730, 300, 130), 34)
	var up_pip: Control = m._upgrades_pip
	up_pip.position = Vector2(w - M - 30.0, 712)
	TrailMobile.text(_n(L, "TrailNote"), Rect2(M, 872, iw, 84), 28)
	TrailMobile.text(_n(L, "TimeHead"), Rect2(M, 974, iw, 50), 36)
	var cw := (iw - 32.0) / 3.0
	for i in 3:
		_btn(_n(L, "Time%d" % i), Rect2(M + i * (cw + 16.0), 1034, cw, 110), 38)
	TrailMobile.text(_n(L, "TimeNote"), Rect2(M, 1156, iw, 84), 26)
	var y := 1256.0
	for id in ["Single", "Arcade", "Zen"]:
		_btn(_n(L, id), Rect2(M, y, iw, 110), 38)
		TrailMobile.text(_n(L, id + "Note"), Rect2(M, y + 116.0, iw, 44), 26)
		y += 174.0
	var hw := (iw - 16.0) / 2.0
	var grid := [["How", "Seeds"], ["Stats", "Contracts"]]
	for r in 2:
		for c in 2:
			_btn(_n(L, grid[r][c]), Rect2(M + c * (hw + 16.0), y + 4.0 + r * 116.0, hw, 100), 32)
	var cb := _n(L, "Contracts")
	var c_pip: Control = m._contracts_pip
	if cb != null:
		c_pip.position = cb.position + Vector2(cb.size.x - 28.0, -14.0)
	var quit := _n(L, "Quit")
	TrailMobile.bottom_btn(_n(L, "Options") as Button, 1 if quit != null else 0)
	if quit != null:
		TrailMobile.bottom_btn(quit as Button, 2)


# --- Options, profiles, stats, contracts ---------------------------------------

static func options(m) -> void:
	var L: Control = m.options_layer
	var iw := TrailMobile.iw()
	TrailMobile.title(_n(L, "Title") as Label)
	TrailMobile.back(_n(L, "Back") as Button)
	var y := TrailMobile.content_top() + 40.0
	if m.fullscreen_btn != null:
		TrailMobile.text(_n(L, "VideoHead"), Rect2(M, y, iw, 56), 40)
		y += 80.0
		_btn(m.fullscreen_btn, Rect2(M, y, iw, 120), 36)
		y += 140.0
		_btn(m.resolution_btn, Rect2(M, y, iw, 120), 36)
		y += 136.0
		TrailMobile.text(_n(L, "Hint"), Rect2(M, y, iw, 44), 26)
		y += 90.0
	_btn(m.ui_style_btn, Rect2(M, y, iw, 120), 36)
	y += 200.0
	TrailMobile.text(_n(L, "SoundHead"), Rect2(M, y, iw, 56), 40)
	y += 100.0
	for id in ["Music", "Sfx"]:
		var l := _n(L, id + "L") as Label
		TrailMobile.place(l, Rect2(M, y, 260, 90), 36)
		if l != null:
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var s := _n(L, id + "S")
		if s != null:
			s.scale = Vector2(1.6, 1.6)
			s.position = Vector2(M + 280.0, y + 16.0)
			s.size = Vector2((iw - 280.0) / 1.6, 36)
		y += 130.0


static func profiles(m) -> void:
	var L: Control = m.profile_layer
	var iw := TrailMobile.iw()
	var w := Form.view().x
	TrailMobile.title(_n(L, "Title") as Label)
	TrailMobile.back(_n(L, "Back") as Button)
	var y := TrailMobile.content_top() + 20.0
	for i in m._profile_slot_btns.size():
		_btn(m._profile_slot_btns[i], Rect2(M, y, iw, 400), 36)
		_btn(_n(L, "Erase%d" % i), Rect2(w - M - 280.0, y + 412.0, 280, 90), 30)
		y += 560.0


## The Ledger's three columns, stacked: each on its own plate.
static func stats(m) -> void:
	var L: Control = m.stats_layer
	var iw := TrailMobile.iw()
	TrailMobile.title(_n(L, "Title") as Label)
	TrailMobile.back(_n(L, "Back") as Button)
	var fs := 30
	var y := TrailMobile.content_top()
	for i in m._stats_cols.size():
		var names: Label = m._stats_cols[i][0]
		var values: Label = m._stats_cols[i][1]
		var lh: float = names.get_theme_font("font").get_height(fs) \
				+ names.get_theme_constant("line_spacing")
		var rows := names.text.count("\n") + 1
		var ph := 100.0 + rows * lh + 24.0
		plate(_n(L, "Plate%d" % i), Rect2(M, y, iw, ph))
		TrailMobile.text(_n(L, "Head%d" % i), Rect2(M + 24.0, y + 18.0, iw - 48.0, 50), 36)
		var rule := _n(L, "Rule%d" % i)
		if rule != null:
			rule.position = Vector2(M + 120.0, y + 78.0 - (7.0 if rule is Panel else 0.0))
			rule.size.x = iw - 240.0
		TrailMobile.place(names, Rect2(M + 40.0, y + 100.0, iw - 80.0, rows * lh), fs)
		TrailMobile.place(values, Rect2(M + 40.0, y + 100.0, iw - 80.0, rows * lh), fs)
		y += ph + 24.0


static func contracts(m) -> void:
	var L: Control = m.contracts_layer
	var iw := TrailMobile.iw()
	TrailMobile.title(_n(L, "Title") as Label)
	TrailMobile.back(_n(L, "Back") as Button)
	var ct := TrailMobile.content_top()
	TrailMobile.text(m._contracts_sub, Rect2(M, ct, iw, 50), 32)
	var sc: Control = m._contracts_scroll
	sc.position = Vector2(M, ct + 70.0)
	sc.size = Vector2(iw, Form.view().y - Form.safe_bottom() - ct - 70.0)
	(m._contracts_list as Control).custom_minimum_size = Vector2(iw, 0)


# --- The popups: the tutor poster, the tutorial offer, the table's lessons -----

static func tutor(m) -> void:
	var L: Control = m.tutor_layer
	var panel := _n(L, "Panel")
	panel.position = Vector2(60, 560)
	panel.size = Vector2(960, 900)
	for c in panel.get_children():
		if c is UiKit.Rivets:
			(c as UiKit.Rivets).plate_size = panel.size
	TrailMobile.place(m._tutor_title, Rect2(60, 604, 960, 90), 56)
	for i in 2:
		var rule := _n(L, "Rule%d" % i)
		if rule != null:
			rule.position = Vector2(160, 704 + i * 6)
			rule.size = Vector2(760, 3)
	TrailMobile.place(m._tutor_scroll, Rect2(110, 744, 860, 580))
	var body: Label = m._tutor_body
	body.custom_minimum_size = Vector2(830, 0)
	body.add_theme_font_size_override("font_size", 36)
	_btn(_n(L, "Ok"), Rect2(290, 1320, 500, 110), 40)


static func offer(m) -> void:
	var L: Control = m._offer_layer
	var panel := _n(L, "Panel")
	panel.position = Vector2(60, 700)
	panel.size = Vector2(960, 640)
	for c in panel.get_children():
		if c is UiKit.Rivets:
			(c as UiKit.Rivets).plate_size = panel.size
	TrailMobile.place(_n(L, "Title"), Rect2(60, 760, 960, 90), 60)
	TrailMobile.text(_n(L, "Body"), Rect2(120, 880, 840, 260), 36)
	_btn(_n(L, "Play"), Rect2(100, 1166, 430, 130), 32)
	_btn(_n(L, "Skip"), Rect2(550, 1166, 430, 130), 32)


## The tutorial's lesson plate covers the top bar and the stat cells (the
## tutorial has no target to show), with SKIP in its corner.
static func tutorial(m) -> void:
	var top := Form.safe_top()
	var iw := TrailMobile.iw()
	var h := 326.0
	var p: Control = m._tut_panel
	p.position = Vector2(M, top)
	p.size = Vector2(iw, h)
	for c in p.get_children():
		if c is Panel:
			plate(c, Rect2(Vector2.ZERO, p.size))
	var l: Label = m._tut_label
	TrailMobile.text(l, Rect2(24, 16, iw - 48.0, h - 100.0), 32, HORIZONTAL_ALIGNMENT_LEFT)
	_btn(m._tut_skip_btn, Rect2(M + iw - 330.0, top + h - 86.0, 310, 72), 26)


## The deck peek: six cards to a row, BACK TO THE TABLE pinned below.
static func peek(m) -> void:
	var L: Control = m._deck_peek
	var iw := TrailMobile.iw()
	(L as ColorRect).color.a = 0.92  # the whole table sits behind it here
	TrailMobile.title(_n(L, "PeekTitle") as Label)
	var ct := TrailMobile.content_top()
	TrailMobile.text(m._deck_peek_count, Rect2(M, ct, iw, 84), 30)
	TrailMobile.place(_n(L, "PeekScroll"), Rect2(M, ct + 100.0, iw, TrailMobile.bottom() - ct - 124.0))
	TrailMobile.bottom_btn(_n(L, "PeekClose") as Button)


# --- Seeded play -----------------------------------------------------------------

## Seeded play in one column: the modes in two rows, the seed and its
## buttons, the rider and the Ascension, then your best, the recent seeds
## and the online board in a scroll, and the name and START at the foot.
static func seeds(m) -> void:
	var L: Control = m.seeds_layer
	var iw := TrailMobile.iw()
	var w := Form.view().x
	TrailMobile.title(_n(L, "Title") as Label)
	TrailMobile.back(_n(L, "Back") as Button)
	var y := TrailMobile.content_top()
	TrailMobile.text(_n(L, "Sub"), Rect2(M, y, iw, 90), 30)
	y += 110.0
	var keys: Array = m._seed_mode_btns.keys()
	var bw := (iw - 48.0) / 4.0
	for i in keys.size():
		_btn(m._seed_mode_btns[keys[i]], Rect2(M + (i % 4) * (bw + 16.0), y + (i / 4) * 110.0,
				bw, 96), 30)
	y += 230.0
	var sl := _n(L, "SeedL")
	TrailMobile.place(sl, Rect2(M, y, 140, 100), 36)
	var edit: Control = m._seed_edit
	TrailMobile.place(edit, Rect2(M + 150.0, y, iw - 150.0, 100), 44)
	y += 116.0
	var row := ["Random", "Paste", "Copy", "Daily"]
	for i in row.size():
		_btn(_n(L, row[i]), Rect2(M + i * (bw + 16.0), y, bw, 96), 28)
	y += 116.0
	# The trail box is a full-canvas layer: its children sit in page space.
	var riders: Array = m._seed_rider_btns.keys()
	var rw := (iw - 32.0) / 3.0
	for i in riders.size():
		_btn(m._seed_rider_btns[riders[i]], Rect2(M + i * (rw + 16.0), y, rw, 96), 28)
	y += 112.0
	var box: Control = m._seed_trail_box
	_btn(_n(box, "Prev"), Rect2(M, y, 120, 96), 36)
	TrailMobile.place(m._seed_asc_label, Rect2(M + 136.0, y, iw - 272.0, 96), 36)
	_btn(_n(box, "Next"), Rect2(w - M - 120.0, y, 120, 96), 36)
	y += 120.0
	# Everything below the controls scrolls.
	var foot := TrailMobile.bottom() - 120.0
	var sc := ScrollContainer.new()
	sc.name = "Lower"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.position = Vector2(M, y)
	sc.size = Vector2(iw, foot - 56.0 - y)
	L.add_child(sc)
	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_PASS
	sc.add_child(inner)
	var k := 1.6
	var p1 := _n(L, "Plate1")
	p1.reparent(inner)
	plate(p1, Rect2(0, 0, iw, 620))
	for id in ["Best", "Rules", "RecentL"]:
		_n(L, id).reparent(inner)
	TrailMobile.place(m._seed_best, Rect2(24, 20, iw - 48.0, 50), 34)
	TrailMobile.text(m._seed_rules, Rect2(24, 76, iw - 48.0, 180), 26, HORIZONTAL_ALIGNMENT_LEFT)
	TrailMobile.place(_n(inner, "RecentL"), Rect2(24, 262, 400, 44), 30)
	var recent: Control = m._seed_recent_box
	recent.reparent(inner)
	recent.position = Vector2(24, 312)
	recent.scale = Vector2(k, k)
	var p2 := _n(L, "Plate2")
	p2.reparent(inner)
	plate(p2, Rect2(0, 640, iw, 620))
	var board: Control = m._seed_board_box
	board.reparent(inner)
	board.position = Vector2(24, 660)
	board.scale = Vector2(k, k)
	inner.custom_minimum_size = Vector2(iw, 1270)
	TrailMobile.text(m._seed_warn, Rect2(M, foot - 50.0, iw, 44), 26)
	TrailMobile.place(_n(L, "NameL"), Rect2(M, foot, 140, 100), 32)
	TrailMobile.place(m._seed_name_edit, Rect2(M + 150.0, foot, iw - 150.0, 100), 36)
	TrailMobile.bottom_btn(m._seed_start)


## The table's lesson poster at phone size; main fits its height to the
## words and hangs it above or below the card.
static func callout(m) -> void:
	var p: Control = m._callout_panel
	p.size = Vector2(920, 480)
	TrailMobile.place(m._callout_title, Rect2(0, 30, 920, 64), 48)
	var body: Label = m._callout_body
	body.position = Vector2(50, 110)
	body.custom_minimum_size = Vector2(820, 0)
	body.size = Vector2(820, 200)
	body.add_theme_font_size_override("font_size", 32)
	_btn(m._callout_ok, Rect2(310, 360, 300, 100), 34)
