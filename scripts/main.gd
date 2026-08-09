extends Node2D

## Game flow, main menu, modes, and UI for Poker Pop.

const BG := Color("1a1a1a")
const GOLD := Color("e8c547")
const OFFWHITE := Color("e8e0c8")
const RED := Color("c23b3b")
const DIM := Color("8a836e")

# Arcade mode difficulty curve.
const ARCADE_BASE_TARGET := 200   # level 1 score target
const ARCADE_TARGET_STEP := 100   # extra target per level
const ARCADE_BASE_HANDS := 16     # level 1 hand budget
const ARCADE_MIN_HANDS := 8
const ARCADE_BASE_DRAIN := 2.5    # meter % lost per second at level 1
const ARCADE_DRAIN_STEP := 0.6
const ARCADE_MAX_DRAIN := 8.0
const ARCADE_METER_GAIN := 0.4    # meter % gained per point scored

const PANEL_X := 672.0
# Play area the board is centered into.
const BOARD_AREA_POS := Vector2(40, 56)
const BOARD_AREA_SIZE := Vector2(620, 600)

var board: Board
var score := 0
var hands_left := 0
var hands_played := 0
var game_over := false
var game_started := false
var menu_open := true

# Mode: "time" (countdown, reshuffles), "single" (one deck, no timer),
# "arcade" (leveled score targets, draining meter), "zen" (no limits).
var mode_kind := ""
var mode_time := 0.0
var mode_label_text := ""
var time_left := 0.0

# Arcade state.
var level := 1
var level_score := 0
var meter := 100.0
var level_transition := false

var ui_root: Control
var score_label: Label
var status_label: Label
var deck_label: Label
var meta_label: Label
var meter_back: ColorRect
var meter_fill: ColorRect
var target_label: Label
var target_bar_back: ColorRect
var target_bar_fill: ColorRect
var hand_display: Node2D
var splash_layer: ColorRect
var music: AudioStreamPlayer
var menu_music: AudioStreamPlayer
var countdown_active := false
var countdown_id := 0
var preview_label: Label
var announcer: Label
var over_layer: ColorRect
var over_label: Label
var menu_layer: ColorRect
var _announce_tween: Tween


func _ready() -> void:
	get_window().title = "Poker Pop"
	var theme_env := OS.get_environment("POKERPOP_THEME")
	if theme_env != "":
		Themes.index = clampi(int(theme_env), 0, Themes.LIST.size() - 1)
	RenderingServer.set_default_clear_color(Themes.current().bg)

	board = Board.new()
	board.locked = true
	board.hand_played.connect(_on_hand_played)
	board.dead_board.connect(_on_dead_board)
	board.selection_changed.connect(_refresh_hand_display)
	add_child(board)
	_apply_board_layout()

	_build_ui()
	_build_menu()
	_build_splash()

	# Music (Echoes Below pack): "Crimson Sparks" in-game, "Tiny
	# Troublemaker" on the menu, both looped. Nothing plays until the
	# splash is clicked — that first gesture also unblocks web audio.
	music = _make_music_player("res://assets/music/crimson_sparks.mp3")
	menu_music = _make_music_player("res://assets/music/tiny_troublemaker.mp3")

	var shot := OS.get_environment("POKERPOP_SHOT")
	if shot != "":
		var m := OS.get_environment("POKERPOP_MODE")
		if m != "splash":
			_dismiss_splash()
		match m:
			"splash", "menu":
				pass
			"time":
				_start_mode("time", 60.0)
			"single":
				_start_mode("single")
			"zen":
				_start_mode("zen")
			"over":
				_start_mode("time", 0.6)
			_:
				_start_mode("arcade")
		_take_screenshot(shot)


func _process(delta: float) -> void:
	if game_started and not menu_open and not game_over and not countdown_active:
		if mode_kind == "time":
			time_left -= delta
			if time_left <= 0.0:
				time_left = 0.0
				game_over = true
				board.locked = true
				_show_game_over("TIME'S UP\n\nFinal score: %d\n\nR — play again    M — menu" % score)
		elif mode_kind == "arcade" and not level_transition:
			meter -= _arcade_drain() * delta
			if meter <= 0.0:
				meter = 0.0
				game_over = true
				board.locked = true
				_show_game_over("THE BAR HIT BOTTOM\n\nYou made it to level %d.\nTotal score: %d\n\nR — play again    M — menu" % [level, score])
	_update_labels()


func _arcade_target() -> int:
	return ARCADE_BASE_TARGET + ARCADE_TARGET_STEP * (level - 1)


func _arcade_hands() -> int:
	return maxi(ARCADE_MIN_HANDS, ARCADE_BASE_HANDS - (level - 1))


func _arcade_drain() -> float:
	return minf(ARCADE_MAX_DRAIN, ARCADE_BASE_DRAIN + ARCADE_DRAIN_STEP * (level - 1))


func _update_labels() -> void:
	score_label.text = "SCORE  %d" % score
	deck_label.text = "DECK  %d" % board.deck.size()
	meta_label.text = "%s  ·  Theme: %s (T)" % [mode_label_text, Themes.current().name]
	match mode_kind:
		"time":
			var secs := ceili(time_left)
			status_label.text = "TIME  %d:%02d" % [secs / 60, secs % 60]
			status_label.add_theme_color_override("font_color",
					RED if time_left < 15.0 else OFFWHITE)
		"arcade":
			status_label.text = "LEVEL %d    HANDS %d" % [level, hands_left]
			status_label.add_theme_color_override("font_color",
					RED if hands_left <= 2 else OFFWHITE)
		_:
			status_label.text = "HANDS PLAYED  %d" % hands_played
			status_label.add_theme_color_override("font_color", OFFWHITE)

	var show_arcade := mode_kind == "arcade" and game_started and not menu_open
	meter_back.visible = show_arcade
	meter_fill.visible = show_arcade
	target_label.visible = show_arcade
	target_bar_back.visible = show_arcade
	target_bar_fill.visible = show_arcade
	if show_arcade:
		var h := 596.0 * meter / 100.0
		meter_fill.position.y = 58.0 + (596.0 - h)
		meter_fill.size.y = h
		meter_fill.color = GOLD if meter > 25.0 else RED
		var target := _arcade_target()
		target_label.text = "LEVEL %d      %d / %d" % [level, level_score, target]
		target_bar_fill.size.x = 616.0 * clampf(float(level_score) / float(target), 0.0, 1.0)
	_update_preview()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if splash_layer.visible:
			_dismiss_splash()
			return
		if menu_open:
			return
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if not game_over:
					board.play_hand()
			KEY_C:
				if not game_over:
					board.clear_selection()
			KEY_R:
				_restart()
			KEY_M:
				_open_menu()
			KEY_T:
				Themes.cycle()
				RenderingServer.set_default_clear_color(Themes.current().bg)
				board.apply_theme()
				_refresh_hand_display()


func _update_preview() -> void:
	if menu_open or not game_started:
		preview_label.text = ""
		return
	if game_over:
		preview_label.text = "R — play again    M — menu"
		preview_label.add_theme_color_override("font_color", DIM)
		return
	var data := board.get_selected_data()
	if data.is_empty():
		preview_label.text = "Chain up to 5 adjacent cards to build a poker hand."
		preview_label.add_theme_color_override("font_color", DIM)
	else:
		var result := Poker.evaluate(data)
		if result.playable:
			preview_label.text = "%s  —  %d pts   (base %d + pips %d)" % \
					[result.name, result.score, result.base, result.pips]
			preview_label.add_theme_color_override("font_color", GOLD)
		elif result.name == "High Card":
			preview_label.text = "High Card — not playable, you need at least a Pair."
			preview_label.add_theme_color_override("font_color", RED)
		else:
			preview_label.text = "Not a hand — every card must be part of the hand."
			preview_label.add_theme_color_override("font_color", RED)


func _on_hand_played(result: Dictionary) -> void:
	score += result.score
	hands_played += 1
	_announce("%s  +%d" % [String(result.name).to_upper(), result.score])
	if mode_kind == "arcade":
		level_score += result.score
		meter = clampf(meter + result.score * ARCADE_METER_GAIN, 0.0, 100.0)
		hands_left -= 1
		if level_score >= _arcade_target():
			_level_up()
		elif hands_left <= 0:
			game_over = true
			board.locked = true
			_show_game_over("OUT OF HANDS\n\nLevel %d needed %d more points.\nTotal score: %d\n\nR — play again    M — menu" % \
					[level, _arcade_target() - level_score, score])


## Advances arcade to the next level: fresh board, fewer hands, faster drain.
func _level_up() -> void:
	level_transition = true
	board.locked = true
	_announce("LEVEL %d CLEAR!" % level)
	while board.busy:
		await get_tree().process_frame
	if not game_started or mode_kind != "arcade":
		level_transition = false
		return
	level += 1
	level_score = 0
	hands_left = _arcade_hands()
	meter = 100.0
	board.reset()
	level_transition = false
	_begin_countdown()


func _on_dead_board() -> void:
	if game_over or not game_started:
		return
	if mode_kind == "arcade":
		# Arcade never dead-ends: reshuffle the board and keep going.
		_announce("NO MOVES — RESHUFFLE")
		board.shuffle_board()
		return
	game_over = true
	board.locked = true
	var msg: String
	if mode_kind == "single":
		if board.grid.is_empty():
			msg = "PERFECT CLEAR\n\nYou played out the entire deck!\nFinal score: %d" % score
		else:
			msg = "OUT OF HANDS\n\nThe deck is spent — that's the run.\nFinal score: %d" % score
	else:
		msg = "DEAD BOARD\n\nNo playable hands left — that's a loss.\nFinal score: %d" % score
	_show_game_over(msg + "\n\nR — play again    M — menu")


func _show_game_over(message: String) -> void:
	# Let the last pop/refill animation play out before covering the board.
	await get_tree().create_timer(1.4).timeout
	if not game_over or menu_open:
		return
	over_label.text = message
	over_layer.visible = true


func _restart() -> void:
	if not game_started or board.busy or level_transition:
		return
	score = 0
	hands_played = 0
	time_left = mode_time
	level = 1
	level_score = 0
	meter = 100.0
	hands_left = _arcade_hands()
	game_over = false
	over_layer.visible = false
	board.reset()
	_begin_countdown()


## "3, 2, 1, Pop!" before play begins — on run start and on every arcade
## level. Timers and the arcade meter are frozen (countdown_active) and
## the board stays locked until the "POP!". A newer countdown or a menu
## exit cancels an older one via countdown_id.
func _begin_countdown() -> void:
	countdown_id += 1
	var my_id := countdown_id
	countdown_active = true
	board.locked = true
	if OS.get_environment("POKERPOP_SHOT") != "":
		board.locked = false
		countdown_active = false
		return
	while board.busy:
		await get_tree().process_frame
		if my_id != countdown_id:
			return
	for step in ["3", "2", "1"]:
		if my_id != countdown_id or menu_open or not game_started:
			return
		_announce(step)
		await get_tree().create_timer(0.7).timeout
	if my_id != countdown_id or menu_open or not game_started:
		return
	_announce("POP!")
	board.locked = false
	countdown_active = false


func _make_music_player(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var track: AudioStreamMP3 = load(path)
	track.loop = true
	p.stream = track
	p.volume_db = -12.0
	add_child(p)
	return p


func _open_menu() -> void:
	countdown_id += 1  # cancel any running countdown
	countdown_active = false
	music.stop()
	_fade_in(menu_music)
	menu_open = true
	game_started = false
	game_over = false
	over_layer.visible = false
	board.locked = true
	menu_layer.visible = true


func _start_mode(kind: String, seconds: float = 0.0) -> void:
	mode_kind = kind
	mode_time = seconds
	match kind:
		"time":
			mode_label_text = "Time Trial %d:00" % int(seconds / 60.0)
		"single":
			mode_label_text = "Single Deck"
		"arcade":
			mode_label_text = "Arcade"
		"zen":
			mode_label_text = "Zen"
	board.single_deck = kind == "single"
	menu_open = false
	menu_layer.visible = false
	game_started = true
	menu_music.stop()
	if not music.playing:
		_fade_in(music)
	while board.busy:
		await get_tree().process_frame
	_restart()


## Starts a music player from silence and eases it up to full volume.
func _fade_in(p: AudioStreamPlayer) -> void:
	p.volume_db = -40.0
	p.play()
	create_tween().tween_property(p, "volume_db", -12.0, 1.5)


## Rebuilds the mini-card row showing the current selection in rank order.
func _refresh_hand_display() -> void:
	for child in hand_display.get_children():
		child.queue_free()
	var cards: Array = []
	for card in board.selected:
		cards.append({"rank": card.rank, "suit": card.suit})
	cards.sort_custom(func(a, b): return a.rank < b.rank)
	for i in cards.size():
		var mc := PlayingCard.new()
		mc.rank = cards[i].rank
		mc.suit = cards[i].suit
		mc.scale = Vector2(0.45, 0.45)
		mc.position = Vector2(i * 46.0, 0)
		mc.material = Themes.current_material()
		hand_display.add_child(mc)


func _announce(text: String) -> void:
	announcer.text = text
	announcer.modulate = Color(1, 1, 1, 1)
	if _announce_tween and _announce_tween.is_valid():
		_announce_tween.kill()
	_announce_tween = create_tween()
	_announce_tween.tween_interval(0.9)
	_announce_tween.tween_property(announcer, "modulate:a", 0.0, 0.5)


## Centers the board inside the play area (scales down if it ever outgrows it).
func _apply_board_layout() -> void:
	var px := board.board_px_size()
	var s: float = minf(1.0, minf(BOARD_AREA_SIZE.x / px.x, BOARD_AREA_SIZE.y / px.y))
	board.scale = Vector2(s, s)
	board.position = BOARD_AREA_POS + (BOARD_AREA_SIZE - px * s) / 2.0


# --- UI construction ------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_root = Control.new()
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui_root)
	# A Control under a CanvasLayer doesn't inherit the viewport rect, so
	# size everything explicitly to the fixed 960x720 design resolution.
	ui_root.size = Vector2(960, 720)

	_label(ui_root, "POKER", Vector2(PANEL_X, 20), 40, RED)
	_label(ui_root, "POP", Vector2(PANEL_X + 158, 20), 40, OFFWHITE)

	score_label = _label(ui_root, "", Vector2(PANEL_X, 90), 26, GOLD)
	status_label = _label(ui_root, "", Vector2(PANEL_X, 130), 18, OFFWHITE)
	deck_label = _label(ui_root, "", Vector2(PANEL_X, 158), 14, OFFWHITE)
	meta_label = _label(ui_root, "", Vector2(PANEL_X, 178), 12, DIM)

	# Arcade banner: level target and progress, big across the board top.
	target_label = _label(ui_root, "", Vector2(40, 2), 28, GOLD)
	target_bar_back = ColorRect.new()
	target_bar_back.color = Color("2a2a2a")
	target_bar_back.position = Vector2(40, 42)
	target_bar_back.size = Vector2(620, 10)
	ui_root.add_child(target_bar_back)
	target_bar_fill = ColorRect.new()
	target_bar_fill.color = GOLD
	target_bar_fill.position = Vector2(42, 44)
	target_bar_fill.size = Vector2(0, 6)
	ui_root.add_child(target_bar_fill)
	target_label.visible = false
	target_bar_back.visible = false
	target_bar_fill.visible = false

	var play_btn := _button(ui_root, "PLAY HAND", Vector2(PANEL_X, 220), Vector2(158, 44))
	play_btn.pressed.connect(func() -> void:
		if game_started and not game_over:
			board.play_hand())
	var clear_btn := _button(ui_root, "CLEAR", Vector2(PANEL_X + 166, 220), Vector2(96, 44))
	clear_btn.pressed.connect(func() -> void:
		if game_started and not game_over:
			board.clear_selection())
	var menu_btn := _button(ui_root, "MENU", Vector2(PANEL_X, 272), Vector2(96, 28))
	menu_btn.add_theme_font_size_override("font_size", 13)
	menu_btn.pressed.connect(_open_menu)

	# Selected cards, shown sorted by rank so straights are easy to read.
	_label(ui_root, "YOUR HAND", Vector2(PANEL_X, 306), 13, DIM)
	hand_display = Node2D.new()
	hand_display.position = Vector2(PANEL_X + 22, 356)
	ui_root.add_child(hand_display)

	# Arcade meter: a vertical bar beside the board that drains constantly.
	meter_back = ColorRect.new()
	meter_back.color = Color("2a2a2a")
	meter_back.position = Vector2(8, 56)
	meter_back.size = Vector2(22, 600)
	meter_back.visible = false
	ui_root.add_child(meter_back)
	meter_fill = ColorRect.new()
	meter_fill.color = GOLD
	meter_fill.position = Vector2(11, 58)
	meter_fill.size = Vector2(16, 596)
	meter_fill.visible = false
	ui_root.add_child(meter_fill)

	_label(ui_root, "PAYOUTS", Vector2(PANEL_X, 392), 16, DIM)
	var names: Array = Poker.BASE_SCORES.keys()
	names.reverse()
	var lines := PackedStringArray()
	for hand_name in names:
		lines.append("%s   %d" % [hand_name, Poker.BASE_SCORES[hand_name]])
	var payouts := _label(ui_root, "\n".join(lines), Vector2(PANEL_X, 418), 12, OFFWHITE)
	payouts.add_theme_constant_override("line_spacing", 3)

	_label(ui_root, "Click or drag to chain adjacent cards\nEvery card must be part of the hand\nEnter / Space — play    C / Right click — clear\nR — restart    T — theme    M — menu",
			Vector2(PANEL_X, 642), 12, DIM)

	preview_label = _label(ui_root, "", Vector2(40, 668), 20, DIM)

	announcer = Label.new()
	announcer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	announcer.add_theme_font_size_override("font_size", 52)
	announcer.add_theme_color_override("font_color", GOLD)
	announcer.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	announcer.add_theme_constant_override("shadow_offset_x", 3)
	announcer.add_theme_constant_override("shadow_offset_y", 3)
	announcer.modulate = Color(1, 1, 1, 0)
	ui_root.add_child(announcer)
	announcer.size = Vector2(670, 720)  # centered over the board, not the panel

	over_layer = ColorRect.new()
	over_layer.color = Color(0, 0, 0, 0.78)
	over_layer.visible = false
	over_layer.size = Vector2(960, 720)
	ui_root.add_child(over_layer)
	over_label = Label.new()
	over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	over_label.add_theme_font_size_override("font_size", 34)
	over_label.add_theme_color_override("font_color", OFFWHITE)
	over_label.size = Vector2(960, 720)
	over_layer.add_child(over_label)


func _build_menu() -> void:
	menu_layer = ColorRect.new()
	menu_layer.color = BG
	menu_layer.size = Vector2(960, 720)
	ui_root.add_child(menu_layer)

	_label(menu_layer, "POKER", Vector2(262, 90), 72, RED)
	_label(menu_layer, "POP", Vector2(548, 90), 72, OFFWHITE)
	_menu_center("Chain adjacent cards into poker hands", 196, 16, DIM)

	_menu_center("TIME TRIAL", 258, 16, GOLD)
	var times := [60.0, 180.0, 300.0]
	var time_names := ["1:00", "3:00", "5:00"]
	for i in 3:
		var b := _button(menu_layer, time_names[i], Vector2(285 + i * 135, 284), Vector2(120, 40))
		var secs: float = times[i]
		b.pressed.connect(func() -> void:
			_start_mode("time", secs))
	_menu_center("Unlimited hands · reshuffling deck · beat the clock", 330, 13, DIM)

	var single_btn := _button(menu_layer, "SINGLE DECK", Vector2(320, 372), Vector2(320, 44))
	single_btn.pressed.connect(func() -> void:
		_start_mode("single"))
	_menu_center("One 52-card deck · no timer · play until no hands remain", 422, 13, DIM)

	var arcade_btn := _button(menu_layer, "ARCADE", Vector2(320, 460), Vector2(320, 44))
	arcade_btn.pressed.connect(func() -> void:
		_start_mode("arcade"))
	_menu_center("Rising score targets · shrinking hand budget · an always-draining bar", 510, 13, DIM)

	var zen_btn := _button(menu_layer, "ZEN", Vector2(320, 548), Vector2(320, 44))
	zen_btn.pressed.connect(func() -> void:
		_start_mode("zen"))
	_menu_center("No timer · no hand limit · deck reshuffles forever", 598, 13, DIM)


func _build_splash() -> void:
	splash_layer = ColorRect.new()
	splash_layer.color = BG
	splash_layer.size = Vector2(960, 720)
	ui_root.add_child(splash_layer)
	_label(splash_layer, "POKER", Vector2(262, 240), 72, RED)
	_label(splash_layer, "POP", Vector2(548, 240), 72, OFFWHITE)
	var prompt := _label(splash_layer, "CLICK TO START", Vector2(0, 420), 24, GOLD)
	prompt.size = Vector2(960, 48)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pulse := create_tween().set_loops()
	pulse.tween_property(prompt, "modulate:a", 0.35, 0.8)
	pulse.tween_property(prompt, "modulate:a", 1.0, 0.8)
	splash_layer.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_dismiss_splash())


## First user gesture: closes the splash and starts the menu music —
## this same click is what unblocks audio in web builds.
func _dismiss_splash() -> void:
	if not splash_layer.visible:
		return
	splash_layer.visible = false
	if OS.get_environment("POKERPOP_SHOT") == "":
		_fade_in(menu_music)


func _menu_center(text: String, y: float, font_size: int, color: Color) -> Label:
	var l := _label(menu_layer, text, Vector2(0, y), font_size, color)
	l.size = Vector2(960, font_size * 2.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _label(parent: Control, text: String, pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, pos: Vector2, btn_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = btn_size
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("2a2a2a")
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.bg_color = Color("3d3a2c")
	b.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = sb.duplicate()
	pressed.bg_color = Color("55503a")
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", OFFWHITE)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_font_size_override("font_size", 17)
	parent.add_child(b)
	return b


## Debug helper: POKERPOP_SHOT=<png path> captures a frame after the deal
## settles, then quits. POKERPOP_MODE picks menu/time/single/limited/zen.
func _take_screenshot(path: String) -> void:
	if OS.get_environment("POKERPOP_MODE") == "over":
		await get_tree().create_timer(3.5).timeout
		get_viewport().get_texture().get_image().save_png(path)
		get_tree().quit()
		return
	await get_tree().create_timer(1.6).timeout
	for cell in [Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4)]:
		if board.grid.has(cell):
			board._toggle_select(board.grid[cell])
	if not menu_open:
		board._spawn_float_text("+59", board.cell_center(Vector2i(3, 2)))
	await get_tree().create_timer(0.45).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	get_tree().quit()
