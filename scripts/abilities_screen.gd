class_name AbilitiesScreen
extends ColorRect

## The ABILITIES screen, between tables: put your ability cards on poker
## hands. The hands are on the left, one row each with a slot for every
## card the hand uses; your collection is on the right. Click an
## ability, then a hand. Click an equipped ability to take it off (it
## stays picked up, so you can move it). Esc or right-click lets go.

const ROW_Y := 262.0
const ROW_H := 62.0
const CELL_W := 112.0
const CELL_H := 46.0
const CELL_GAP := 8.0
const CELLS_X := 470.0

var trail   # TrailMode (untyped: it owns this screen)
var main
var _back := Callable()
var _sel := -1               # the collection index picked up, or -1
var _rows := {}              # hand -> Button (the whole row)
var _row_box: Control
var _grid: GridContainer
var _status: Label
var _empty_note: Label
var _posse: Label            # how many of each side ride along
var _combine: Button         # merges the picked copy with its twin


func setup(owner_trail) -> void:
	trail = owner_trail
	main = trail.main
	color = main.BG
	size = main.VIEW
	visible = false
	var title: Label = main._label(self, "ABILITIES", Vector2(0, 70), 64, UiKit.BRASS_HI)
	title.size = Vector2(main.VIEW.x, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub: Label = main._label(self,
			"Put abilities on your poker hands. Each hand has one slot for every card it uses.",
			Vector2(0, 168), 22, main.DIM)
	sub.size = Vector2(main.VIEW.x, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_posse = main._label(self, "", Vector2(0, 200), 20, main.GOLD)
	_posse.size = Vector2(main.VIEW.x, 28)
	_posse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.plate(self, Rect2(90, 236, 1040, 712))
	_row_box = Control.new()
	_row_box.size = main.VIEW
	_row_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row_box)
	UiKit.plate(self, Rect2(1150, 236, 690, 712))
	var yl: Label = main._label(self, "YOUR ABILITIES", Vector2(1176, 252), 24, main.GOLD)
	yl.size = Vector2(400, 32)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(1170, 296)
	scroll.size = Vector2(654, 636)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)
	_empty_note = main._label(self, "You don't have any ability cards yet. Clear a table to earn one.",
			Vector2(1180, 330), 18, main.DIM)
	_empty_note.size = Vector2(620, 80)
	_empty_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status = main._label(self, "", Vector2(0, 952), 20, main.OFFWHITE)
	_status.size = Vector2(main.VIEW.x, 30)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var back: Button = main._button(self, "BACK", Vector2(60, 984), Vector2(200, 54))
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(close)
	_combine = main._button(self, "COMBINE", Vector2(1230, 984), Vector2(350, 54), true)
	_combine.add_theme_font_size_override("font_size", 18)
	_combine.visible = false
	_combine.pressed.connect(_do_combine)
	var clear: Button = main._button(self, "TAKE ALL OFF", Vector2(1600, 984), Vector2(260, 54))
	clear.add_theme_font_size_override("font_size", 18)
	clear.tooltip_text = "Takes every ability off your hands. They stay in your collection."
	clear.pressed.connect(func() -> void:
		for i in trail.abilities.size():
			trail.unequip(i)
		_sel = -1
		trail._save_run()
		main.board._play_sound(Board.SFX_SHUFFLES.pick_random(), 1.2, -10.0)
		refresh())


## Opens the screen; `back` runs when it closes.
func open(back: Callable) -> void:
	_back = back
	_sel = -1
	main.transition(func() -> void:
		trail._hide_all()
		refresh()
		visible = true)


func close() -> void:
	_sel = -1
	trail._save_run()
	var then := _back
	_back = Callable()
	main.transition(func() -> void:
		visible = false
		if then.is_valid():
			then.call())


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _sel < 0:
		return
	var cancel: bool = event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton
			and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)
	if cancel:
		_sel = -1
		refresh()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	_build_rows()
	_build_collection()
	var pc := Abilities.posse_counts(trail.all_equipped())
	_posse.text = "YOUR POSSE:   Sheriff %d   ·   Outlaw %d   ·   Bounty Hunter %d" \
			% [int(pc.sheriff), int(pc.outlaw), int(pc.bounty)]
	var twin: int = trail.combine_partner(_sel) if _sel >= 0 else -1
	_combine.visible = twin >= 0
	if twin >= 0:
		var up := Abilities.combined(String(trail.abilities[_sel]))
		_combine.text = "COMBINE INTO %s" % Abilities.display_name(up).to_upper()
		UiKit.fit_button_text(_combine, 18)
		_combine.tooltip_text = "Two copies become one %s: %s" % [Abilities.display_name(up),
				Abilities.describe(up)]
	if _sel >= 0:
		_status.text = "Now pick a hand for %s. Right-click to put it down." \
				% Abilities.display_name(String(trail.abilities[_sel]))
		if twin >= 0:
			_status.text = "Pick a hand for %s, or combine it with its twin." \
					% Abilities.display_name(String(trail.abilities[_sel]))
		_status.add_theme_color_override("font_color", main.GOLD)
	elif trail.abilities.is_empty():
		_status.text = ""
	elif _any_twins():
		_status.text = "You have two of the same ability. Click one to combine them into a stronger card."
		_status.add_theme_color_override("font_color", main.GOLD)
	else:
		_status.text = "Click an ability, then a hand to put it on."
		_status.add_theme_color_override("font_color", main.OFFWHITE)


func _any_twins() -> bool:
	for i in trail.abilities.size():
		if trail.combine_partner(i) >= 0:
			return true
	return false


## Two copies become one a level up, with a flourish.
func _do_combine() -> void:
	if _sel < 0:
		return
	var at: int = trail.combine(_sel)
	if at < 0:
		return
	_sel = -1
	main.board._play_sound(Board.SFX_REVOLVER_CHARGE, 1.1, -6.0)
	main._announce("COMBINED — %s" % Abilities.display_name(String(trail.abilities[at])).to_upper(), main.GOLD)
	trail._save_run()
	refresh()
	_reveal_at(at)


## Plays the card reveal on the upgraded copy in the collection.
func _reveal_at(idx: int) -> void:
	await get_tree().process_frame
	if idx < _grid.get_child_count():
		var holder := _grid.get_child(idx)
		for c in holder.get_children():
			if c is AbilityCard:
				(c as AbilityCard).reveal()


func _build_rows() -> void:
	for c in _row_box.get_children():
		c.queue_free()
	_rows.clear()
	var hands: Array = Abilities.HAND_ORDER
	for i in hands.size():
		var hand: String = hands[i]
		var y := ROW_Y + i * ROW_H
		var plate := CardArt.nine_half("ui", "ability_row", [24, 20, 24, 20])
		if plate != null:
			var bg := Panel.new()
			bg.position = Vector2(106, y)
			bg.size = Vector2(1008, ROW_H - 6)
			bg.add_theme_stylebox_override("panel", plate)
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_row_box.add_child(bg)
		var row: Button = main._button(_row_box, "", Vector2(106, y), Vector2(1008, ROW_H - 6))
		row.flat = true
		row.focus_mode = Control.FOCUS_NONE
		if plate != null:
			for st in ["normal", "hover", "pressed", "disabled", "focus"]:
				row.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var reason := ""
		if _sel >= 0:
			reason = trail.can_equip(_sel, hand)
			row.modulate = Color(1, 1, 1, 1) if reason == "" else Color(1, 1, 1, 0.4)
			row.tooltip_text = reason if reason != "" else "Put it on your %s." % hand
		row.pressed.connect(func() -> void:
			_on_row(hand))
		_rows[hand] = row
		var name_l: Label = main._label(_row_box, hand, Vector2(124, y + 6), 22,
				main.GOLD if _sel >= 0 and reason == "" else main.OFFWHITE)
		name_l.size = Vector2(240, 40)
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var base_l: Label = main._label(_row_box, "%d" % int(Poker.BASE_SCORES.get(hand, 0)),
				Vector2(366, y + 10), 16, main.DIM)
		base_l.size = Vector2(80, 32)
		base_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The slots: equipped tiles packed left, then the empty cells.
		var cells := int(Abilities.HAND_SLOTS[hand])
		var at := 0
		for idx in trail.loadout.get(hand, []):
			var id := String(trail.abilities[int(idx)])
			var n := Abilities.slots(id)
			var tile: Button = main._button(_row_box, Abilities.display_name(id),
					Vector2(CELLS_X + at * (CELL_W + CELL_GAP), y + 4),
					Vector2(n * CELL_W + (n - 1) * CELL_GAP, CELL_H))
			tile.add_theme_font_size_override("font_size", 15 if n > 1 else 11)
			tile.tooltip_text = "%s\n%s\nClick to take it off." % [Abilities.display_name(id),
					Abilities.describe(id)]
			var tile_sb := CardArt.nine_half("ui", "ability_tile_" + Abilities.RARITY_IDS[Abilities.rarity(id)],
					[28, 22, 28, 22])
			if tile_sb != null:
				for st in ["normal", "hover", "pressed", "focus"]:
					tile.add_theme_stylebox_override(st, tile_sb)
				tile.add_theme_color_override("font_color", main.OFFWHITE)
				tile.add_theme_color_override("font_hover_color", main.GOLD)
				tile.alignment = HORIZONTAL_ALIGNMENT_LEFT
				var glyph := AbilityCard.glyph_tex(id)
				if glyph != null and n > 1:
					tile.icon = glyph
					tile.expand_icon = true
					tile.add_theme_constant_override("icon_max_width", 30)
			else:
				tile.modulate = Color(AbilityCard.RARITY_COLORS[Abilities.rarity(id)]).lightened(0.45)
			var copy: int = int(idx)
			tile.pressed.connect(func() -> void:
				trail.unequip(copy)
				_sel = copy
				main.board._play_sound(Board.SFX_FLIP, 0.9, -10.0)
				trail._save_run()
				refresh())
			at += n
		var socket := CardArt.half_tex("ui", "ability_socket_empty")
		for k in range(at, cells):
			var pos := Vector2(CELLS_X + k * (CELL_W + CELL_GAP), y + 4)
			if socket != null:
				var sr := TextureRect.new()
				sr.texture = socket
				sr.position = pos
				sr.size = Vector2(CELL_W, CELL_H)
				sr.stretch_mode = TextureRect.STRETCH_SCALE
				sr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_row_box.add_child(sr)
				continue
			var cell := Panel.new()
			cell.position = pos
			cell.size = Vector2(CELL_W, CELL_H)
			cell.add_theme_stylebox_override("panel", UiKit.inset_box())
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_row_box.add_child(cell)


func _build_collection() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_empty_note.visible = trail.abilities.is_empty()
	for i in trail.abilities.size():
		var id := String(trail.abilities[i])
		var holder: Button = main._button(_grid, "", Vector2.ZERO, Vector2(204, 196))
		holder.custom_minimum_size = Vector2(204, 196)
		UiKit.style_shop_slot(holder)
		var on: String = trail.hand_of(i)
		holder.tooltip_text = "%s (%s, %s, %d slot%s)\n%s%s" % [Abilities.display_name(id),
				Abilities.side_name(id), Abilities.RARITY_NAMES[Abilities.rarity(id)], Abilities.slots(id),
				"" if Abilities.slots(id) == 1 else "s", Abilities.describe(id),
				("\nIt's on your %s." % on) if on != "" else ""]
		var face := AbilityCard.new()
		face.ability_id = id
		face.scale = Vector2(0.78, 0.78)
		face.position = Vector2(102, 88)
		face.faded = on != "" and _sel != i
		holder.add_child(face)
		if _sel == i:
			# Picked up: a gold rim with a soft glow around the whole slot,
			# drawn over it, and the card lifts a little. (The kit's
			# ability_held glow is shaped for the short hand tiles.)
			var rim := Panel.new()
			var sb := StyleBoxFlat.new()
			sb.draw_center = false
			sb.border_color = main.GOLD
			sb.set_border_width_all(4)
			sb.set_corner_radius_all(10)
			sb.shadow_color = Color(main.GOLD, 0.45)
			sb.shadow_size = 14
			rim.add_theme_stylebox_override("panel", sb)
			rim.position = Vector2(-3, -3)
			rim.size = Vector2(210, 202)
			rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(rim)
			face.scale = Vector2(0.84, 0.84)
			face.position = Vector2(102, 84)
		var tag: Label = main._label(holder, ("ON " + on.to_upper()) if on != "" else "",
				Vector2(0, 172), 13, main.GOLD)
		tag.size = Vector2(204, 20)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var copy: int = i
		holder.pressed.connect(func() -> void:
			_sel = -1 if _sel == copy else copy
			main.board._play_sound(Board.SFX_CLICK, 1.1, -10.0)
			refresh())


func _on_row(hand: String) -> void:
	if _sel < 0:
		return
	var reason: String = trail.can_equip(_sel, hand)
	if reason != "":
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		_status.text = reason
		_status.add_theme_color_override("font_color", main.RED)
		return
	trail.equip(_sel, hand)
	_sel = -1
	main.board._play_sound(Board.SFX_FLIP, 1.2, -8.0)
	trail._save_run()
	refresh()
