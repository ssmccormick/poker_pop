class_name TrailMobile
extends RefCounted

## The trail's screens on the phone canvas (1080×2340). Every screen is
## built for the desktop first, then these move its own nodes into a
## portrait layout and set phone-sized type, so all the code that fills
## the screens in stays shared. Called from TrailMode when Form is mobile.
## Layout follows the Mobile v2 mockups: back button top left, the title
## under it, content in one column, the main action pinned to the bottom.

const M := 36.0          # side margin
const BTN_H := 130.0     # the pinned bottom buttons
const CARD_K := 1.55     # tarot cards (300×380 on desktop)
const RIDER := Vector2(680, 1020)


static func vw() -> float:
	return Form.view().x


## The inner width: the canvas less both margins.
static func iw() -> float:
	return vw() - 2.0 * M


## The y of the pinned bottom row.
static func bottom() -> float:
	return Form.view().y - Form.safe_bottom() - BTN_H


## Where content starts, under the back button and the title.
static func content_top() -> float:
	return Form.safe_top() + 218.0


static func place(n: Control, r: Rect2, font_size := 0) -> void:
	if n == null:
		return
	if n is Label and (n as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
		n.custom_minimum_size = Vector2(r.size.x, 0)
	n.position = r.position
	n.size = r.size
	if font_size > 0:
		n.add_theme_font_size_override("font_size", font_size)


## A text block across a box: wraps, centered unless told otherwise.
static func text(l: Label, r: Rect2, font_size: int, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	if l == null:
		return
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = align
	l.clip_text = false
	place(l, r, font_size)


static func title(t: Label) -> void:
	place(t, Rect2(M, Form.safe_top() + 104.0, iw(), 100), 72)


static func back(b: Button) -> void:
	place(b, Rect2(M, Form.safe_top(), 220, 96), 30)
	b.pivot_offset = b.size / 2.0


## A bottom-row button: the whole width, or the left or right half.
static func bottom_btn(b: Button, half := 0) -> void:
	if b == null:
		return
	var w := iw() if half == 0 else (iw() - 16.0) / 2.0
	var x := M if half <= 1 else M + w + 16.0
	place(b, Rect2(x, bottom(), w, BTN_H), 40)
	b.pivot_offset = b.size / 2.0
	UiKit.fit_button_text(b, 40, 22)


static func relayout(t) -> void:
	_select(t)
	_buyin(t)
	_tarot(t)
	_bet(t)
	_pick(t)
	_relic(t)
	_shop(t)
	_camp(t)
	_tend(t)
	_deck(t)


# --- Rider select: a carousel ------------------------------------------------------

static func _select(t) -> void:
	var layer: Control = t.select_layer
	bottom_btn(layer.get_node_or_null("Ride"))
	for id in t._select_cards:
		var tr: TextureRect = t._select_cards[id]
		var b := tr.get_parent() as Button
		b.size = RIDER
		tr.size = RIDER
		var veil: Control = t._select_locks[id]
		veil.size = RIDER
		var lock_l: Label = t._select_lock_labels[id]
		lock_l.size = RIDER
		lock_l.add_theme_font_size_override("font_size", 40)
	var dots := Label.new()
	dots.name = "Dots"
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dots.add_theme_color_override("font_color", Color("d9b572"))
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dots)
	place(dots, Rect2(M, content_top() + RIDER.y + 8.0, iw(), 50), 36)
	var keys: Array = t._gambler_ability_btns.keys()
	for k in keys.size():
		var tb: Button = t._gambler_ability_btns[keys[k]]
		place(tb, Rect2(M + k * (iw() + 16.0) / 2.0, content_top() + RIDER.y + 296.0,
				(iw() - 16.0) / 2.0, 120), 34)
		tb.pivot_offset = tb.size / 2.0


## The chosen rider large in the middle, the others peeking at the edges;
## the chosen one's signature and lore underneath.
static func select_carousel(t) -> void:
	var layer: Control = t.select_layer
	var ids: Array = t._select_cards.keys()
	var at := maxi(0, ids.find(t.character))
	var x0 := (vw() - RIDER.x) / 2.0
	for j in ids.size():
		var id := String(ids[j])
		var b := (t._select_cards[id] as TextureRect).get_parent() as Button
		var off := j - at
		b.visible = absi(off) <= 1
		b.position = Vector2(x0 + off * (RIDER.x + 40.0), content_top())
		b.modulate = Color.WHITE if off == 0 else Color(0.6, 0.6, 0.6)
		var ab := layer.get_node_or_null("Ab_" + id) as Label
		var line := layer.get_node_or_null("Line_" + id) as Label
		if ab != null:
			ab.visible = off == 0
			text(ab, Rect2(M, content_top() + RIDER.y + 66.0, iw(), 56), 40)
		if line != null:
			line.visible = off == 0
			text(line, Rect2(M, content_top() + RIDER.y + 126.0, iw(), 160), 30)
	var dots := layer.get_node_or_null("Dots") as Label
	if dots != null:
		var marks := PackedStringArray()
		for j in ids.size():
			marks.append("●" if j == at else "○")
		dots.text = "  ".join(marks)
	for key in t._gambler_ability_btns:
		var tb: Button = t._gambler_ability_btns[key]
		tb.visible = t.character == "the_gambler"
		tb.add_theme_font_size_override("font_size", 34)  # restyling resets it


## A swipe moves the carousel one rider along.
static func select_step(t, d: int) -> void:
	var ids: Array = t._select_cards.keys()
	var at := ids.find(t.character)
	var to := clampi(at + d, 0, ids.size() - 1)
	if to != at:
		t._pick_character(String(ids[to]))


# --- The buy-in ----------------------------------------------------------------------

static func _buyin(t) -> void:
	var box: Control = t._asc_box
	box.size = Form.view()
	var wb: Control = t._wager_box
	wb.size = Form.view()
	place(t._asc_prev, Rect2(M, 430, 150, 130), 44)
	place(t._asc_next, Rect2(vw() - M - 150.0, 430, 150, 130), 44)
	text(t._asc_label, Rect2(M + 150.0, 436, iw() - 300.0, 70), 56)
	text(t._asc_sub, Rect2(M + 150.0, 508, iw() - 300.0, 46), 26)
	var plate := box.get_node_or_null("AscPlate") as Control
	if plate != null:
		plate.position = Vector2(M, 580)
		plate.size = Vector2(iw(), 400)
		for c in plate.get_children():
			(c as Control).size = plate.size + ((c as Control).size - Vector2(800, 250))
	text(t._asc_rule, Rect2(M + 36.0, 604, iw() - 72.0, 130), 36)
	text(t._asc_rest, Rect2(M + 36.0, 740, iw() - 72.0, 160), 28)
	text(t._asc_reward, Rect2(M + 36.0, 914, iw() - 72.0, 44), 26)
	_wager_row(wb, "BringT", t._bring_label, 1010)
	place(wb.get_node_or_null("BetT"), Rect2(M, 1140, 520, 60), 40)
	var keys := ["", "jack", "queen", "king"]
	for i in keys.size():
		var tb: Button = t._bet_target_btns.get(keys[i])
		if tb != null:
			place(tb, Rect2(M + (i % 2) * (iw() + 16.0) / 2.0, 1206 + (i / 2) * 126.0,
					(iw() - 16.0) / 2.0, 110), 32)
			tb.pivot_offset = tb.size / 2.0
	_wager_row(wb, "StakeT", t._stake_label, 1466)
	text(t._bet_pays_label, Rect2(M, 1590, iw(), 56), 32)
	text(t._wager_note, Rect2(M, 1656, iw(), 110), 26)
	text(t._buyin_cash_label, Rect2(M, 340, iw(), 60), 44)
	place(t._buyin_resume_btn, Rect2(M, 420, iw(), BTN_H), 40)
	text(t._buyin_new_label, Rect2(M, 566, iw(), 50), 30)


static func _wager_row(wb: Control, title_name: String, amount: Label, y: float) -> void:
	place(wb.get_node_or_null(title_name), Rect2(M, y + 10.0, 520, 60), 40)
	if amount == null:
		return
	var minus := amount.get_meta("minus") as Button
	var plus := amount.get_meta("plus") as Button
	place(minus, Rect2(vw() - M - 440.0, y, 130, 110), 40)
	place(amount, Rect2(vw() - M - 310.0, y + 10.0, 180, 90), 44)
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	place(plus, Rect2(vw() - M - 130.0, y, 130, 110), 40)


## A saved ride pushes the dial down and splits the bottom row.
static func buyin_place(t, riding: bool) -> void:
	var dy := 220.0 if riding else 0.0
	t._asc_box.position = Vector2(0, dy)
	# Opening the screen puts these back at their desktop spots.
	place(t._buyin_resume_btn, Rect2(M, 420, iw(), BTN_H), 40)
	t._buyin_resume_btn.pivot_offset = t._buyin_resume_btn.size / 2.0
	text(t._buyin_new_label, Rect2(M, 566, iw(), 50), 30)
	if riding:
		bottom_btn(t._buyin_saddle_btn, 1)
		bottom_btn(t._buyin_rider_btn, 2)
	else:
		bottom_btn(t._buyin_saddle_btn)


# --- FATE DEALS: the offers in a 2×2 grid --------------------------------------------------

static func _tarot(t) -> void:
	var layer: Control = t.tarot_layer
	text(t._tarot_info, Rect2(M, 340, iw(), 100), 32)
	text(t._tarot_relics, Rect2(M, 446, iw(), 90), 26)
	t._tarot_cards_box.position = Vector2(0, 560)
	text(layer.get_node_or_null("Note"), Rect2(M, bottom() - 150.0, iw(), 120), 26)
	bottom_btn(t._tarot_ab_btn, 1)
	bottom_btn(layer.get_node_or_null("ViewDeck"), 2)


static func tarot_grid(t) -> void:
	var cards: Array = []
	for c in t._tarot_cards_box.get_children():
		if c is Button and not c.is_queued_for_deletion():
			cards.append(c)
	var cw := 300.0 * CARD_K
	var ch := 380.0 * CARD_K
	var gap := 30.0
	for i in cards.size():
		var b: Button = cards[i]
		var row := i / 2
		var in_row := mini(2, cards.size() - row * 2)
		var x0 := (vw() - (in_row * cw + (in_row - 1) * gap)) / 2.0
		b.scale = Vector2.ONE * CARD_K
		b.pivot_offset = Vector2.ZERO
		b.position = Vector2(x0 + (i % 2) * (cw + gap), row * (ch + 90.0))


# --- THE TABLE --------------------------------------------------------------------------------

static func _bet(t) -> void:
	text(t._bet_info, Rect2(M, 360, iw(), 620), 38)
	text(t._bet_stake_label, Rect2(M, 1000, iw(), 80), 56)
	t._bet_chips.scale = Vector2.ONE * 1.6
	t._bet_chips.position = Vector2(0, 1110)
	t._bet_chips.size = Vector2(vw() / 1.6, 40)
	text(t._bet_twists, Rect2(M, 1200, iw(), 520), 32)
	bottom_btn(t._bet_deal_btn)


# --- The ability reward ---------------------------------------------------------------------------

static func _pick(t) -> void:
	var layer: Control = t.pick_layer
	title(t._pick_title)
	text(t._pick_sub, Rect2(M, 340, iw(), 100), 32)
	t._win_box.scale = Vector2.ONE * 1.6
	t._win_box.position = Vector2((vw() - 420.0 * 1.6) / 2.0, 460)
	t._pick_box.position = Vector2(0, 1000)
	bottom_btn(layer.get_node_or_null("PickAb"), 1)
	bottom_btn(layer.get_node_or_null("Skip"), 2)


## The offered cards side by side (330 px each on a phone), each with
## what it does underneath.
static func pick_cards(t) -> void:
	var holders: Array = []
	var words: Array = []
	for c in t._pick_box.get_children():
		if c.is_queued_for_deletion():
			continue
		if c is Button:
			holders.append(c)
		elif c is Label:
			words.append(c)
	var n := holders.size()
	if n == 0:
		return
	var gap := 24.0
	var k := minf(330.0 / 170.0, (iw() - (n - 1) * gap) / (n * 170.0))
	var cw := 170.0 * k
	var x0 := (vw() - (n * cw + (n - 1) * gap)) / 2.0
	# With no ledger above (a chest's pick), the cards come up the screen.
	t._pick_box.position.y = 1000.0 if t._win_box.get_child_count() > 0 else 520.0
	for i in n:
		var b: Button = holders[i]
		b.scale = Vector2.ONE * k
		b.pivot_offset = Vector2.ZERO
		b.position = Vector2(x0 + i * (cw + gap), 0)
		if i < words.size():
			var w: Label = words[i]
			text(w, Rect2(x0 + i * (cw + gap) - 8.0, 240.0 * k + 16.0, cw + 16.0, 300), 26)


# --- The strongbox -------------------------------------------------------------------------------

static func _relic(t) -> void:
	var layer: Control = t.relic_layer
	text(t._relic_sub, Rect2(M, 340, iw(), 90), 32)
	var sb := layer.get_node_or_null("Strongbox") as Control
	if sb != null:
		place(sb, Rect2(90, 470, 900, 720))
		t._relic_icon.position = Vector2(vw() / 2.0, 470.0 + 150.0 * 1.5)
		t._relic_icon.scale = Vector2.ONE * 3.9
	text(t._relic_name, Rect2(M, 1230, iw(), 80), 56)
	text(t._relic_desc, Rect2(M, 1320, iw(), 320), 34)
	bottom_btn(layer.get_node_or_null("Take"))


# --- The shop: one scrolling shelf, a detail panel, then BUY -------------------------------

const SHOP_CARD_K := 1.8      # card and ability slots (170×250)
const SHOP_RELIC_K := 2.2     # relic slots (400×158)
const SHOP_PROV_K := 2.3      # provision slots (210×126)


static func _shop(t) -> void:
	var layer: Control = t.shop_layer
	var top := Form.safe_top()
	title(t._shop_title)
	t._shop_title.position.y = top + 20.0
	text(t._shop_flavor, Rect2(M, top + 124.0, iw(), 90), 28)
	text(t._shop_info, Rect2(M, top + 216.0, iw(), 56), 38)
	var row1 := bottom() - 146.0
	var detail_h := 300.0
	var detail_y := row1 - 16.0 - detail_h
	var scroll := ScrollContainer.new()
	scroll.name = "ShopScroll"
	scroll.position = Vector2(0, top + 286.0)
	scroll.size = Vector2(vw(), detail_y - 16.0 - (top + 286.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer.add_child(scroll)
	var content := Control.new()
	content.name = "ShopContent"
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(content)
	for box in [t._shop_box, t._shop_relic_box, t._shop_prov_box, t._shop_sell_box]:
		(box as Control).reparent(content, false)
		(box as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	# What the picked item is, on the theme's poster card.
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UiKit.poster_box())
	panel.position = Vector2(M, detail_y)
	panel.size = Vector2(iw(), detail_h)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var detail := Label.new()
	detail.name = "ShopDetail"
	if FontLib.body != null:
		detail.add_theme_font_override("font", FontLib.body)
	UiKit.track_ink(detail)
	detail.clip_text = true
	panel.add_child(detail)
	text(detail, Rect2(36, 24, iw() - 72.0, detail_h - 48.0), 30)
	t.set_meta("shop_detail", detail)
	# ABILITIES and the forge above; LEAVE and BUY along the bottom.
	var ab := layer.get_node_or_null("ShopAb") as Button
	place(ab, Rect2(M, row1, (iw() - 16.0) / 2.0, BTN_H), 36)
	place(t._shop_burn_btn, Rect2(M + (iw() + 16.0) / 2.0, row1, (iw() - 16.0) / 2.0, BTN_H), 30)
	t._shop_burn_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom_btn(layer.get_node_or_null("Leave"), 1)
	var buy: Button = t.main._button(layer, "BUY", Vector2.ZERO, Vector2(10, 10), true)
	buy.name = "Buy"
	bottom_btn(buy, 2)
	buy.pressed.connect(func() -> void:
		shop_buy(t))
	t.set_meta("shop_buy", buy)


## Lays the freshly rendered shelves out down the scroll, and turns every
## slot into "tap to look": its purchase waits for BUY.
static func shop_flow(t) -> void:
	var y := 16.0
	y = _shelf(t._shop_box, y, SHOP_CARD_K, 3, "")
	y = _shelf(t._shop_relic_box, y, SHOP_RELIC_K, 1, "RELICS")
	y = _shelf(t._shop_prov_box, y, SHOP_PROV_K, 2, "PROVISIONS")
	# Your kit, to sell back: one wide button each.
	var sell: Control = t._shop_sell_box
	sell.position = Vector2(0, y)
	var sy := 0.0
	for c in _live(sell):
		if c is Label:
			text(c, Rect2(M, 0, iw(), 60), 40, HORIZONTAL_ALIGNMENT_CENTER)
			sy = 70.0
	var n := 0
	for c in _live(sell):
		if c is Button:
			place(c, Rect2(M, sy + n * 126.0, iw(), 110), 32)
			(c as Button).mouse_filter = Control.MOUSE_FILTER_PASS
			n += 1
	if sy > 0.0 or n > 0:
		y += sy + n * 126.0 + 24.0
	var content := sell.get_parent() as Control
	content.custom_minimum_size = Vector2(vw(), y)
	content.size = content.custom_minimum_size
	UiKit.fit_button_text(t._shop_burn_btn, 32, 20)  # each render refits it small
	# Tap to look, BUY to buy.
	for box in [t._shop_box, t._shop_relic_box, t._shop_prov_box]:
		for c in _live(box):
			if c is Button:
				_reroute(t, c)
	shop_select(t, null)


## One shelf: an optional header, then its slots scaled up in a grid.
static func _shelf(box: Control, y: float, k: float, cols: int, header: String) -> float:
	box.position = Vector2(0, y)
	var sy := 0.0
	var slots: Array = []
	for c in _live(box):
		if c is Button:
			slots.append(c)
		elif c is Label and header != "":
			text(c, Rect2(M, 0, iw(), 60), 40)
			sy = 70.0
	if slots.is_empty():
		return y
	var sw: float = (slots[0] as Button).size.x * k
	var sh: float = (slots[0] as Button).size.y * k
	var gap := 24.0
	var x0 := (vw() - (cols * sw + (cols - 1) * gap)) / 2.0
	for i in slots.size():
		var b: Button = slots[i]
		b.scale = Vector2.ONE * k
		b.pivot_offset = Vector2.ZERO
		b.position = Vector2(x0 + (i % cols) * (sw + gap), sy + (i / cols) * (sh + gap))
	var rows := ceili(slots.size() / float(cols))
	return y + sy + rows * (sh + gap) + 24.0


static func _live(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if not c.is_queued_for_deletion():
			out.append(c)
	return out


## Moves a slot's purchase off its tap: the tap picks it, BUY runs it.
static func _reroute(t, b: Button) -> void:
	var buy: Array = []
	for conn in b.get_signal_connection_list("pressed"):
		buy.append(conn.callable)
		b.pressed.disconnect(conn.callable)
	for sig in ["mouse_entered", "mouse_exited"]:
		for conn in b.get_signal_connection_list(sig):
			b.disconnect(sig, conn.callable)
	b.set_meta("buy", buy)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.pressed.connect(func() -> void:
		t.main.board._play_sound(Board.SFX_CLICK, 1.1, -10.0)
		shop_select(t, b))


static func shop_select(t, b: Button) -> void:
	var detail := t.get_meta("shop_detail", null) as Label
	var buy := t.get_meta("shop_buy", null) as Button
	if detail == null or buy == null:
		return
	for box in [t._shop_box, t._shop_relic_box, t._shop_prov_box]:
		for c in _live(box):
			if c is Button:
				(c as Button).modulate = Color(1.3, 1.18, 0.8) if c == b else Color.WHITE
	t.set_meta("shop_sel", weakref(b) if b != null else null)
	if b == null:
		detail.text = "Tap anything on the shelves to see what it does, then press BUY."
		buy.text = "BUY"
		buy.disabled = true
		return
	var words := String(b.get_meta("detail", b.tooltip_text))
	detail.text = words
	buy.text = "BUY  $%d" % int(b.get_meta("price", 0))
	buy.disabled = false
	UiKit.fit_button_text(buy, 40, 22)


static func shop_buy(t) -> void:
	var w: WeakRef = t.get_meta("shop_sel", null)
	var b: Button = w.get_ref() if w != null else null
	if b == null or b.disabled:
		return
	for c in b.get_meta("buy", []):
		(c as Callable).call()


# --- The campfire and Tend: the fire cropped into the top band ------------------------------

const CAMP_K := 1.3


static func _camp_scene(scene: Node2D) -> void:
	scene.scale = Vector2.ONE * CAMP_K
	scene.position = Vector2(vw() / 2.0 - 700.0 * CAMP_K, 850.0 - 760.0 * CAMP_K)


static func _camp(t) -> void:
	var layer: Control = t.camp_layer
	_camp_scene(t._camp_scene)
	var top := Form.safe_top()
	text(layer.get_node_or_null("Sub"), Rect2(M, top + 204.0, iw(), 90), 28)
	text(t._camp_hp_label, Rect2(M, top + 300.0, iw(), 60), 40)
	var ids := ["rest", "tend", "cast"]
	var tips := ["Rest: sleep off the road and get some HP back.",
			"Tend a card: the fire offers three brands. Pick one, then the plain card it goes on.",
			"Cast one off: throw a card in the fire. It's gone from your deck for good."]
	var cw := 315.0
	var gap := 18.0
	var x0 := (vw() - (3 * cw + 2 * gap)) / 2.0
	for i in ids.size():
		var tb := layer.get_node_or_null("Choice_" + String(ids[i])) as Control
		if tb != null:
			place(tb, Rect2(x0 + i * (cw + gap), 1240, cw, cw * 346.0 / 272.0))
			tb.tooltip_text = String(tips[i])
	bottom_btn(layer.get_node_or_null("Leave"))


static func _tend(t) -> void:
	var layer: Control = t.tend_layer
	_camp_scene(t._tend_scene)
	text(layer.get_node_or_null("Sub"), Rect2(M, Form.safe_top() + 204.0, iw(), 100), 30)
	t._tend_box.position = Vector2(0, Form.safe_top() + 340.0)


## Each brand as a wide row: the sample card on the left, its name and what
## it does beside it.
static func tend_rows(t) -> void:
	var i := 0
	for b in _live(t._tend_box):
		if not b is Button:
			continue
		place(b, Rect2(M, i * 350.0, iw(), 330))
		var labels: Array = []
		for c in b.get_children():
			if c is PlayingCard:
				c.position = Vector2(140, 165)
				c.scale = Vector2.ONE * 2.0
			elif c is Label:
				labels.append(c)
		if labels.size() >= 1:
			text(labels[0], Rect2(290, 34, iw() - 320.0, 56), 40, HORIZONTAL_ALIGNMENT_LEFT)
		if labels.size() >= 2:
			text(labels[1], Rect2(290, 100, iw() - 320.0, 210), 30, HORIZONTAL_ALIGNMENT_LEFT)
		i += 1


# --- The deck view: a scrolling grid, four across ------------------------------------------------

static func _deck(t) -> void:
	var layer: Control = t.remove_layer
	text(t._remove_info, Rect2(M, Form.safe_top() + 204.0, iw(), 110), 32)
	for c in layer.get_children():
		if c is ScrollContainer:
			var top := Form.safe_top() + 330.0
			place(c, Rect2(M, top, iw(), Form.view().y - Form.safe_bottom() - 20.0 - top))
			(c as ScrollContainer).horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	t._remove_grid.columns = 4
	t._remove_grid.add_theme_constant_override("h_separation", 16)
	t._remove_grid.add_theme_constant_override("v_separation", 16)


static func deck_grid(t) -> void:
	var cell := Vector2((iw() - 3 * 16.0) / 4.0, 330)
	for h in _live(t._remove_grid):
		if not h is Button:
			continue
		var b := h as Button
		b.custom_minimum_size = cell
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		for sig in ["mouse_entered", "mouse_exited"]:
			for conn in b.get_signal_connection_list(sig):
				b.disconnect(sig, conn.callable)
		for c in b.get_children():
			if c is PlayingCard:
				c.position = cell / 2.0
				c.scale = Vector2.ONE * 2.3
	t._deck_tip.visible = false