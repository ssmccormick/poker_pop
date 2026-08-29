extends Node2D

## Game flow, main menu, modes, and UI for Poker Pop.

const BG := Color("1a1a1a")
const GOLD := Color("e8c547")
const OFFWHITE := Color("e8e0c8")
const RED := Color("c23b3b")
const DIM := Color("8a836e")

# Arcade mode difficulty curve. No hand limit — the draining meter is
# the challenge; keep scoring or the bar runs out.
const ARCADE_BASE_TARGET := 600   # level 1 score target
const ARCADE_TARGET_STEP := 150   # extra target per level
const ARCADE_BASE_DRAIN := 2.5    # meter % lost per second at level 1
const ARCADE_DRAIN_STEP := 0.3
const ARCADE_MAX_DRAIN := 7.0
const ARCADE_METER_GAIN := 0.4    # meter % gained per point scored

const VIEW := Vector2(1920, 1080)
const PANEL_X := 1420.0
# Play area the board is centered into (right edge leaves the panel free).
const BOARD_AREA_POS := Vector2(60, 100)
const BOARD_AREA_SIZE := Vector2(1320, 900)
const PLAY_WIDTH := 1400.0  # everything left of the panel

var board: Board
var trail: TrailMode
var score := 0
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
var countdown_overlay: ColorRect
var bg_rect: TextureRect
var backgrounds: Array = []

# Settings (persisted to user://settings.cfg).
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440),
]
var fullscreen_on := true
var res_index := 2
var music_vol := 0.8
var sfx_vol := 0.8
var options_layer: ColorRect
var fullscreen_btn: Button
var resolution_btn: Button
var pause_layer: ColorRect
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
	# Main must keep processing while the tree is paused so ESC can
	# unpause; everything gameplay-related is gated on tree.paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_buses()
	_load_settings()
	var theme_env := OS.get_environment("POKERPOP_THEME")
	if theme_env != "":
		Themes.index = clampi(int(theme_env), 0, Themes.LIST.size() - 1)
	RenderingServer.set_default_clear_color(Themes.current().bg)

	# Background image behind the (transparent) play area. Drop images
	# into assets/backgrounds/ to replace the generated placeholders;
	# arcade rotates them every level.
	backgrounds = _load_backgrounds()
	bg_rect = TextureRect.new()
	bg_rect.position = Vector2.ZERO
	bg_rect.size = Vector2(PLAY_WIDTH, VIEW.y)
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_rect.modulate = Color(0.55, 0.55, 0.55)  # dimmed so cards stay readable
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not backgrounds.is_empty():
		bg_rect.texture = backgrounds[0]
	add_child(bg_rect)

	board = Board.new()
	board.process_mode = Node.PROCESS_MODE_PAUSABLE  # don't inherit ALWAYS
	board.locked = true
	board.hand_played.connect(_on_hand_played)
	board.hand_rejected.connect(func() -> void:
		_announce("NOT A VALID HAND", RED))
	board.dead_board.connect(_on_dead_board)
	board.selection_changed.connect(_refresh_hand_display)
	add_child(board)
	_apply_board_layout()

	trail = TrailMode.new()
	trail.main = self
	add_child(trail)

	_build_ui()
	trail.build_ui()  # trail screens sit above the HUD, below the menu
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
			"options":
				_open_options()
			"trail":
				trail.open_buyin()
			"trailshop":
				menu_layer.visible = false
				trail._start_run(0)
				trail._choose_offer({"kind": "shop", "tarot": "THE HERMIT"}, false)
			"trailtarot":
				menu_layer.visible = false
				trail._start_run(0)
			"trailbet", "trailroom", "trailhazard":
				menu_layer.visible = false
				trail._start_run(0)
				for offer in trail._offers:
					if offer.kind == "play":
						trail._choose_offer(offer, false)
						break
				if m != "trailbet":
					trail._confirm_bet()
				if m == "trailhazard":
					_debug_seed_hazards()
			"trailheist":
				menu_layer.visible = false
				trail._start_run(0)
				trail._choose_offer({"kind": "play", "tarot": "THE MOON",
						"label": "Heist", "target": 0, "hands": 8, "odds": 2.0,
						"min_bet": 10, "goal": "safe"}, false)
				trail._confirm_bet()
			"ready":
				_start_mode("arcade")
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
	if get_tree().paused:
		return
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
			status_label.text = "LEVEL %d" % level
			status_label.add_theme_color_override("font_color", OFFWHITE)
		"trail":
			status_label.text = "HANDS LEFT  %d" % trail.room_hands_left
			status_label.add_theme_color_override("font_color",
					RED if trail.room_hands_left <= 2 else OFFWHITE)
			deck_label.text = "CHIPS %d    STAKE %d" % [trail.chips, trail.stake]
		_:
			status_label.text = "HANDS PLAYED  %d" % hands_played
			status_label.add_theme_color_override("font_color", OFFWHITE)

	var show_arcade := mode_kind == "arcade" and game_started and not menu_open
	var show_trail := mode_kind == "trail" and game_started and not menu_open and trail.in_room
	meter_back.visible = show_arcade
	meter_fill.visible = show_arcade
	target_label.visible = show_arcade or show_trail
	target_bar_back.visible = show_arcade or show_trail
	target_bar_fill.visible = show_arcade or show_trail
	if show_arcade:
		var h := 892.0 * meter / 100.0
		meter_fill.position.y = 104.0 + (892.0 - h)
		meter_fill.size.y = h
		meter_fill.color = GOLD if meter > 25.0 else RED
		var target := _arcade_target()
		target_label.text = "LEVEL %d      %d / %d" % [level, level_score, target]
		target_bar_fill.size.x = 1314.0 * clampf(float(level_score) / float(target), 0.0, 1.0)
	elif show_trail:
		if trail.room_goal == "safe":
			var digits := PackedStringArray()
			for d in trail.room_combo:
				digits.append(str(d))
			target_label.text = "ROOM %d / %d      SAFE  %s" % \
					[trail.room_index + 1, TrailMode.ROOMS_TOTAL, " · ".join(digits)]
			target_bar_fill.size.x = 1314.0 * trail.safe_progress() / 4.0
		elif trail.room_goal == "chest":
			target_label.text = "ROOM %d / %d      KEY + CHEST IN ONE HAND" % \
					[trail.room_index + 1, TrailMode.ROOMS_TOTAL]
			target_bar_fill.size.x = 0.0
		else:
			target_label.text = "ROOM %d / %d      %d / %d" % \
					[trail.room_index + 1, TrailMode.ROOMS_TOTAL, trail.room_score, trail.room_target]
			target_bar_fill.size.x = 1314.0 * clampf(
					float(trail.room_score) / float(maxi(trail.room_target, 1)), 0.0, 1.0)
	_update_preview()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if splash_layer.visible:
			_dismiss_splash()
			return
		if get_tree().paused:
			if event.keycode == KEY_ESCAPE:
				_toggle_pause()
			return
		if menu_open:
			return
		match event.keycode:
			KEY_ESCAPE:
				_toggle_pause()
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
		for card in board.selected:
			if card.is_safe:
				preview_label.text = "COMBINATION SET  —  play the hand to crack the safe!"
				preview_label.add_theme_color_override("font_color", GOLD)
				return
		for card in board.selected:
			if card.washed:
				preview_label.text = "???  —  a soaked card hides this hand's value."
				preview_label.add_theme_color_override("font_color", GOLD)
				return
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
	if mode_kind == "trail":
		trail.on_hand_played(result)
		return
	if mode_kind == "arcade":
		level_score += result.score
		meter = clampf(meter + result.score * ARCADE_METER_GAIN, 0.0, 100.0)
		if level_score >= _arcade_target():
			_level_up()


## Advances arcade to the next level: fresh board, fewer hands, faster drain.
func _level_up() -> void:
	level_transition = true
	board.locked = true
	# The refill after the winning hand would be thrown away by the
	# reset — skip it so the transition starts right after the pops.
	board.suppress_refill = true
	if board._refill_active:
		board._skip_refill()
	_announce("LEVEL %d CLEAR!" % level)
	while board.busy:
		await get_tree().process_frame
	if not game_started or mode_kind != "arcade":
		level_transition = false
		return
	level += 1
	level_score = 0
	meter = 100.0
	_set_level_background()
	board.reset()
	level_transition = false
	_begin_countdown()


func _on_dead_board() -> void:
	if game_over or not game_started:
		return
	if mode_kind == "arcade" or mode_kind == "trail":
		# These modes never dead-end: reshuffle the board and keep going.
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
	await get_tree().create_timer(1.4, false).timeout
	if not game_over or menu_open:
		return
	over_label.text = message
	over_layer.visible = true


func _restart() -> void:
	if mode_kind == "trail":
		return  # no free room retries at a betting table
	if not game_started or board.busy or level_transition:
		return
	score = 0
	hands_played = 0
	time_left = mode_time
	level = 1
	level_score = 0
	meter = 100.0
	game_over = false
	over_layer.visible = false
	if mode_kind == "arcade":
		_set_level_background()
	elif not backgrounds.is_empty():
		bg_rect.texture = backgrounds.pick_random()
	board.reset()
	_begin_countdown()


## Loads background images from assets/backgrounds (any the user drops
## in), falling back to generated gradient placeholders. Export builds
## list imported files with .import/.remap suffixes — strip them.
func _load_backgrounds() -> Array:
	var out: Array = []
	var seen := {}
	var dir := DirAccess.open("res://assets/backgrounds")
	if dir:
		for f in dir.get_files():
			var fname := f.trim_suffix(".import").trim_suffix(".remap")
			var lower := fname.to_lower()
			if not (lower.ends_with(".png") or lower.ends_with(".jpg")
					or lower.ends_with(".jpeg") or lower.ends_with(".webp")):
				continue
			if seen.has(fname):
				continue
			seen[fname] = true
			var tex := load("res://assets/backgrounds/" + fname)
			if tex is Texture2D:
				out.append(tex)
	if out.is_empty():
		out = _generate_placeholder_backgrounds()
	return out


func _generate_placeholder_backgrounds() -> Array:
	var palettes := [
		[Color("14532d"), Color("052014")],  # felt green
		[Color("1e3a5f"), Color("0a1220")],  # midnight blue
		[Color("5f1e2e"), Color("200a10")],  # wine red
		[Color("4a3a1e"), Color("1d1408")],  # tobacco brown
		[Color("3a1e5f"), Color("140a20")],  # violet
		[Color("1e5f5a"), Color("0a201e")],  # teal
	]
	var out: Array = []
	for p in palettes:
		var g := Gradient.new()
		g.colors = PackedColorArray([p[0], p[1]])
		g.offsets = PackedFloat32Array([0.0, 1.0])
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.35)
		tex.fill_to = Vector2(0.5, 1.2)
		tex.width = 480
		tex.height = 270
		out.append(tex)
	return out


func _set_level_background() -> void:
	if backgrounds.is_empty():
		return
	bg_rect.texture = backgrounds[(level - 1) % backgrounds.size()]


## "Ready... POP!" before play begins — on run start and on every arcade
## level. Timers and the arcade meter are frozen (countdown_active), the
## board stays locked, and a dark overlay covers the play area until the
## "POP!". A newer countdown or a menu exit cancels an older one via
## countdown_id.
func _begin_countdown() -> void:
	countdown_id += 1
	var my_id := countdown_id
	countdown_active = true
	board.locked = true
	countdown_overlay.visible = true
	if OS.get_environment("POKERPOP_SHOT") != "" and OS.get_environment("POKERPOP_MODE") != "ready":
		board.locked = false
		countdown_active = false
		countdown_overlay.visible = false
		return
	while board.busy:
		await get_tree().process_frame
		if my_id != countdown_id:
			return
	if my_id != countdown_id or menu_open or not game_started:
		return
	# READY holds at full opacity until the POP replaces it.
	if _announce_tween and _announce_tween.is_valid():
		_announce_tween.kill()
	announcer.text = "READY..."
	announcer.modulate = Color(1, 1, 1, 1)
	await get_tree().create_timer(1.5, false).timeout
	if my_id != countdown_id or menu_open or not game_started:
		return
	_announce("POP!")
	board.locked = false
	countdown_active = false
	countdown_overlay.visible = false


func _make_music_player(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var track: AudioStreamMP3 = load(path)
	track.loop = true
	p.stream = track
	p.volume_db = -12.0
	p.bus = "Music"
	add_child(p)
	return p


# --- Settings -------------------------------------------------------------

## The buses live in default_bus_layout.tres — runtime-created buses
## don't work on the web sample-playback audio path. This is only a
## fallback for odd situations (e.g. the layout failing to load).
func _setup_audio_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var i := AudioServer.bus_count
			AudioServer.add_bus(i)
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")


func _load_settings() -> void:
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")  # missing file is fine, defaults apply
	fullscreen_on = cf.get_value("video", "fullscreen", true)
	res_index = clampi(cf.get_value("video", "resolution", 2), 0, RESOLUTIONS.size() - 1)
	music_vol = clampf(cf.get_value("audio", "music", 0.8), 0.0, 1.0)
	sfx_vol = clampf(cf.get_value("audio", "sfx", 0.8), 0.0, 1.0)
	_apply_video()
	_apply_audio()


func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("video", "fullscreen", fullscreen_on)
	cf.set_value("video", "resolution", res_index)
	cf.set_value("audio", "music", music_vol)
	cf.set_value("audio", "sfx", sfx_vol)
	cf.save("user://settings.cfg")


func _apply_video() -> void:
	# The browser owns the window on web; screenshots stay windowed.
	if OS.has_feature("web") or OS.get_environment("POKERPOP_SHOT") != "":
		return
	if fullscreen_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var size := RESOLUTIONS[res_index]
		DisplayServer.window_set_size(size)
		var screen := DisplayServer.screen_get_size()
		DisplayServer.window_set_position(
				DisplayServer.screen_get_position() + (screen - size) / 2)


func _apply_audio() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"),
			linear_to_db(maxf(music_vol, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"),
			linear_to_db(maxf(sfx_vol, 0.0001)))


func _open_menu() -> void:
	if mode_kind == "trail":
		trail.on_abandon_room()  # mid-room exit counts as a fail
		trail._hide_all()
	countdown_id += 1  # cancel any running countdown
	countdown_active = false
	countdown_overlay.visible = false
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
	board.custom_deck.clear()
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
		mc.scale = Vector2(0.72, 0.72)
		mc.position = Vector2(i * 74.0, 0)
		mc.material = Themes.current_material()
		hand_display.add_child(mc)


func _announce(text: String, color: Color = GOLD) -> void:
	announcer.text = text
	announcer.add_theme_color_override("font_color", color)
	announcer.modulate = Color(1, 1, 1, 1)
	if _announce_tween and _announce_tween.is_valid():
		_announce_tween.kill()
	_announce_tween = create_tween()
	_announce_tween.tween_interval(0.9)
	_announce_tween.tween_property(announcer, "modulate:a", 0.0, 0.5)


## Centers the board inside the play area, scaling up or down to fit.
func _apply_board_layout() -> void:
	var px := board.board_px_size()
	var s: float = minf(BOARD_AREA_SIZE.x / px.x, BOARD_AREA_SIZE.y / px.y)
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
	# size everything explicitly to the fixed design resolution.
	ui_root.size = VIEW

	_label(ui_root, "POKER", Vector2(PANEL_X, 28), 64, RED)
	_label(ui_root, "POP", Vector2(PANEL_X + 254, 28), 64, OFFWHITE)

	score_label = _label(ui_root, "", Vector2(PANEL_X, 140), 40, GOLD)
	status_label = _label(ui_root, "", Vector2(PANEL_X, 204), 28, OFFWHITE)
	deck_label = _label(ui_root, "", Vector2(PANEL_X, 246), 20, OFFWHITE)
	meta_label = _label(ui_root, "", Vector2(PANEL_X, 276), 16, DIM)

	# Arcade banner: level target and progress, big across the board top.
	target_label = _label(ui_root, "", Vector2(60, 8), 44, GOLD)
	target_bar_back = ColorRect.new()
	target_bar_back.color = Color("2a2a2a")
	target_bar_back.position = Vector2(60, 74)
	target_bar_back.size = Vector2(1320, 16)
	ui_root.add_child(target_bar_back)
	target_bar_fill = ColorRect.new()
	target_bar_fill.color = GOLD
	target_bar_fill.position = Vector2(63, 77)
	target_bar_fill.size = Vector2(0, 10)
	ui_root.add_child(target_bar_fill)
	target_label.visible = false
	target_bar_back.visible = false
	target_bar_fill.visible = false

	var play_btn := _button(ui_root, "PLAY HAND", Vector2(PANEL_X, 316), Vector2(250, 64))
	play_btn.add_theme_font_size_override("font_size", 24)
	play_btn.pressed.connect(func() -> void:
		if game_started and not game_over:
			board.play_hand())
	var clear_btn := _button(ui_root, "CLEAR", Vector2(PANEL_X + 262, 316), Vector2(150, 64))
	clear_btn.add_theme_font_size_override("font_size", 24)
	clear_btn.pressed.connect(func() -> void:
		if game_started and not game_over:
			board.clear_selection())
	var menu_btn := _button(ui_root, "MENU", Vector2(PANEL_X, 392), Vector2(150, 42))
	menu_btn.add_theme_font_size_override("font_size", 18)
	menu_btn.pressed.connect(_open_menu)

	# Selected cards, shown sorted by rank so straights are easy to read.
	_label(ui_root, "YOUR HAND", Vector2(PANEL_X, 452), 18, DIM)
	hand_display = Node2D.new()
	hand_display.position = Vector2(PANEL_X + 32, 528)
	ui_root.add_child(hand_display)

	# Arcade meter: a vertical bar beside the board that drains constantly.
	meter_back = ColorRect.new()
	meter_back.color = Color("2a2a2a")
	meter_back.position = Vector2(14, 100)
	meter_back.size = Vector2(32, 900)
	meter_back.visible = false
	ui_root.add_child(meter_back)
	meter_fill = ColorRect.new()
	meter_fill.color = GOLD
	meter_fill.position = Vector2(18, 104)
	meter_fill.size = Vector2(24, 892)
	meter_fill.visible = false
	ui_root.add_child(meter_fill)

	_label(ui_root, "PAYOUTS", Vector2(PANEL_X, 602), 22, DIM)
	var names: Array = Poker.BASE_SCORES.keys()
	names.reverse()
	var lines := PackedStringArray()
	for hand_name in names:
		lines.append("%s   %d" % [hand_name, Poker.BASE_SCORES[hand_name]])
	var payouts := _label(ui_root, "\n".join(lines), Vector2(PANEL_X, 636), 18, OFFWHITE)
	payouts.add_theme_constant_override("line_spacing", 2)

	_label(ui_root, "Click or drag to chain adjacent cards\nEvery card must be part of the hand\nEnter / Space — play    C / Right click — clear\nEsc — pause    R — restart    T — theme    M — menu",
			Vector2(PANEL_X, 976), 16, DIM)

	preview_label = _label(ui_root, "", Vector2(60, 1026), 28, DIM)

	# Darkens the play area during the Ready countdown — a clear "not yet".
	countdown_overlay = ColorRect.new()
	countdown_overlay.color = Color(0, 0, 0, 0.55)
	countdown_overlay.size = Vector2(PLAY_WIDTH, VIEW.y)
	countdown_overlay.visible = false
	# Let clicks through so a deal animation can be skipped during the
	# countdown; the board is locked anyway.
	countdown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(countdown_overlay)

	announcer = Label.new()
	announcer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	announcer.add_theme_font_size_override("font_size", 92)
	announcer.add_theme_color_override("font_color", GOLD)
	announcer.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	announcer.add_theme_constant_override("shadow_offset_x", 5)
	announcer.add_theme_constant_override("shadow_offset_y", 5)
	announcer.modulate = Color(1, 1, 1, 0)
	ui_root.add_child(announcer)
	announcer.size = Vector2(PLAY_WIDTH, VIEW.y)  # centered over the board

	over_layer = ColorRect.new()
	over_layer.color = Color(0, 0, 0, 0.78)
	over_layer.visible = false
	over_layer.size = VIEW
	ui_root.add_child(over_layer)
	over_label = Label.new()
	over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	over_label.add_theme_font_size_override("font_size", 52)
	over_label.add_theme_color_override("font_color", OFFWHITE)
	over_label.size = VIEW
	over_layer.add_child(over_label)

	_build_pause()


func _build_pause() -> void:
	pause_layer = ColorRect.new()
	pause_layer.color = Color(0, 0, 0, 0.72)
	pause_layer.size = VIEW
	pause_layer.visible = false
	pause_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	ui_root.add_child(pause_layer)

	var title := _label(pause_layer, "PAUSED", Vector2(0, 250), 84, GOLD)
	title.size = Vector2(VIEW.x, 110)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var resume := _button(pause_layer, "RESUME", Vector2(810, 470), Vector2(300, 64))
	resume.add_theme_font_size_override("font_size", 26)
	resume.pressed.connect(_toggle_pause)
	var restart := _button(pause_layer, "RESTART", Vector2(810, 552), Vector2(300, 64))
	restart.add_theme_font_size_override("font_size", 26)
	restart.pressed.connect(func() -> void:
		_toggle_pause()
		_restart())
	var to_menu := _button(pause_layer, "MENU", Vector2(810, 634), Vector2(300, 64))
	to_menu.add_theme_font_size_override("font_size", 26)
	to_menu.pressed.connect(func() -> void:
		_toggle_pause()
		_open_menu())
	if not OS.has_feature("web"):
		var quit := _button(pause_layer, "QUIT", Vector2(810, 716), Vector2(300, 64))
		quit.add_theme_font_size_override("font_size", 26)
		quit.pressed.connect(func() -> void:
			get_tree().quit())


func _toggle_pause() -> void:
	if get_tree().paused:
		get_tree().paused = false
		pause_layer.visible = false
	elif game_started and not menu_open and not game_over:
		get_tree().paused = true
		pause_layer.visible = true


func _build_menu() -> void:
	menu_layer = ColorRect.new()
	menu_layer.color = BG
	menu_layer.size = VIEW
	ui_root.add_child(menu_layer)

	_label(menu_layer, "POKER", Vector2(600, 110), 110, RED)
	_label(menu_layer, "POP", Vector2(1042, 110), 110, OFFWHITE)
	_menu_center("Chain adjacent cards into poker hands", 280, 26, DIM)

	var trail_btn := _button(menu_layer, "THE TRAIL", Vector2(700, 336), Vector2(520, 66))
	trail_btn.add_theme_font_size_override("font_size", 26)
	trail_btn.pressed.connect(func() -> void:
		trail.open_buyin())
	_menu_center("Buy in · bet on every room · sculpt your deck · cash out or bust", 408, 20, DIM)

	_menu_center("TIME TRIAL", 456, 24, GOLD)
	var times := [60.0, 180.0, 300.0]
	var time_names := ["1:00", "3:00", "5:00"]
	for i in 3:
		var b := _button(menu_layer, time_names[i], Vector2(645 + i * 220, 494), Vector2(200, 56))
		b.add_theme_font_size_override("font_size", 22)
		var secs: float = times[i]
		b.pressed.connect(func() -> void:
			_start_mode("time", secs))
	_menu_center("Unlimited hands · reshuffling deck · beat the clock", 558, 18, DIM)

	var single_btn := _button(menu_layer, "SINGLE DECK", Vector2(700, 604), Vector2(520, 60))
	single_btn.add_theme_font_size_override("font_size", 24)
	single_btn.pressed.connect(func() -> void:
		_start_mode("single"))
	_menu_center("One 52-card deck · no timer · play until no hands remain", 672, 18, DIM)

	var arcade_btn := _button(menu_layer, "ARCADE", Vector2(700, 712), Vector2(520, 60))
	arcade_btn.add_theme_font_size_override("font_size", 24)
	arcade_btn.pressed.connect(func() -> void:
		_start_mode("arcade"))
	_menu_center("Rising score targets · an always-draining bar · keep scoring or lose", 780, 18, DIM)

	var zen_btn := _button(menu_layer, "ZEN", Vector2(700, 820), Vector2(520, 60))
	zen_btn.add_theme_font_size_override("font_size", 24)
	zen_btn.pressed.connect(func() -> void:
		_start_mode("zen"))
	_menu_center("No timer · no hand limit · deck reshuffles forever", 888, 18, DIM)

	if OS.has_feature("web"):
		var opt_btn := _button(menu_layer, "OPTIONS", Vector2(835, 972), Vector2(250, 54))
		opt_btn.add_theme_font_size_override("font_size", 22)
		opt_btn.pressed.connect(_open_options)
	else:
		var opt_btn := _button(menu_layer, "OPTIONS", Vector2(700, 972), Vector2(250, 54))
		opt_btn.add_theme_font_size_override("font_size", 22)
		opt_btn.pressed.connect(_open_options)
		var quit_btn := _button(menu_layer, "QUIT", Vector2(970, 972), Vector2(250, 54))
		quit_btn.add_theme_font_size_override("font_size", 22)
		quit_btn.pressed.connect(func() -> void:
			get_tree().quit())

	_build_options()


func _build_options() -> void:
	options_layer = ColorRect.new()
	options_layer.color = BG
	options_layer.size = VIEW
	options_layer.visible = false
	ui_root.add_child(options_layer)

	var title := _label(options_layer, "OPTIONS", Vector2(0, 110), 72, GOLD)
	title.size = Vector2(VIEW.x, 100)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if not OS.has_feature("web"):
		var vh := _label(options_layer, "VIDEO", Vector2(0, 280), 26, RED)
		vh.size = Vector2(VIEW.x, 40)
		vh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fullscreen_btn = _button(options_layer, "", Vector2(700, 336), Vector2(520, 60))
		fullscreen_btn.add_theme_font_size_override("font_size", 24)
		fullscreen_btn.pressed.connect(func() -> void:
			fullscreen_on = not fullscreen_on
			_apply_video()
			_save_settings()
			_refresh_options_buttons())
		resolution_btn = _button(options_layer, "", Vector2(700, 410), Vector2(520, 60))
		resolution_btn.add_theme_font_size_override("font_size", 24)
		resolution_btn.pressed.connect(func() -> void:
			res_index = (res_index + 1) % RESOLUTIONS.size()
			_apply_video()
			_save_settings()
			_refresh_options_buttons())
		var hint := _label(options_layer, "Window size applies when fullscreen is off", Vector2(0, 478), 18, DIM)
		hint.size = Vector2(VIEW.x, 30)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_refresh_options_buttons()

	var sh := _label(options_layer, "SOUND", Vector2(0, 560), 26, RED)
	sh.size = Vector2(VIEW.x, 40)
	sh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_label(options_layer, "MUSIC", Vector2(660, 626), 24, OFFWHITE)
	var music_slider := HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	music_slider.value = music_vol
	music_slider.position = Vector2(830, 626)
	music_slider.size = Vector2(430, 36)
	options_layer.add_child(music_slider)
	music_slider.value_changed.connect(func(v: float) -> void:
		music_vol = v
		_apply_audio()
		_save_settings())

	_label(options_layer, "SFX", Vector2(660, 700), 24, OFFWHITE)
	var sfx_slider := HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.value = sfx_vol
	sfx_slider.position = Vector2(830, 700)
	sfx_slider.size = Vector2(430, 36)
	options_layer.add_child(sfx_slider)
	sfx_slider.value_changed.connect(func(v: float) -> void:
		sfx_vol = v
		_apply_audio()
		_save_settings())

	var back := _button(options_layer, "BACK", Vector2(835, 860), Vector2(250, 60))
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(_close_options)


func _refresh_options_buttons() -> void:
	if fullscreen_btn:
		fullscreen_btn.text = "FULLSCREEN — %s" % ("ON" if fullscreen_on else "OFF")
	if resolution_btn:
		var r := RESOLUTIONS[res_index]
		resolution_btn.text = "WINDOW SIZE — %d × %d" % [r.x, r.y]


func _open_options() -> void:
	menu_layer.visible = false
	options_layer.visible = true


func _close_options() -> void:
	options_layer.visible = false
	menu_layer.visible = true


func _build_splash() -> void:
	splash_layer = ColorRect.new()
	splash_layer.color = BG
	splash_layer.size = VIEW
	ui_root.add_child(splash_layer)
	_label(splash_layer, "POKER", Vector2(600, 380), 110, RED)
	_label(splash_layer, "POP", Vector2(1042, 380), 110, OFFWHITE)
	var prompt := _label(splash_layer, "CLICK TO START", Vector2(0, 640), 36, GOLD)
	prompt.size = Vector2(VIEW.x, 72)
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
	l.size = Vector2(VIEW.x, font_size * 2.0)
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


## Screenshot-only helper: seeds one of every hazard plus a washed card
## so all overlays can be eyeballed in one frame.
func _debug_seed_hazards() -> void:
	while board.busy:
		await get_tree().process_frame
	for kind in ["bomb", "fire", "wind", "stone", "water"]:
		board.apply_room_hazards(kind, 1)
	for p in board.grid:
		var c: PlayingCard = board.grid[p]
		if c.hazard == "" and not c.cursed:
			c.washed = true
			break


## Debug helper: POKERPOP_SHOT=<png path> captures a frame after the deal
## settles, then quits. POKERPOP_MODE picks menu/time/single/limited/zen.
func _take_screenshot(path: String) -> void:
	match OS.get_environment("POKERPOP_MODE"):
		"trailhazard", "trailheist":
			await get_tree().create_timer(4.2).timeout
			get_viewport().get_texture().get_image().save_png(path)
			get_tree().quit()
			return
		"deal":
			await get_tree().create_timer(1.3).timeout
			get_viewport().get_texture().get_image().save_png(path)
			get_tree().quit()
			return
		"over":
			await get_tree().create_timer(3.5).timeout
			get_viewport().get_texture().get_image().save_png(path)
			get_tree().quit()
			return
		"ready":
			await get_tree().create_timer(2.0).timeout
			get_viewport().get_texture().get_image().save_png(path)
			get_tree().quit()
			return
	await get_tree().create_timer(1.6).timeout
	# Prefer an adjacent same-rank pair so the valid-hand (green) border
	# state is visible; fall back to three arbitrary cards.
	var pair_found := false
	for p: Vector2i in board.grid:
		for q: Vector2i in board.grid:
			if p != q and board.grid[p].rank == board.grid[q].rank \
					and Board._is_adjacent(p, q):
				board._toggle_select(board.grid[p])
				board._toggle_select(board.grid[q])
				pair_found = true
				break
		if pair_found:
			break
	if not pair_found:
		for cell in [Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4)]:
			if board.grid.has(cell):
				board._toggle_select(board.grid[cell])
	if not menu_open:
		board._spawn_float_text("+59", board.cell_center(Vector2i(3, 2)))
	await get_tree().create_timer(0.45).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	get_tree().quit()
