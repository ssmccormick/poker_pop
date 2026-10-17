extends Node2D

## Game flow, main menu, modes, and UI for Poker Pop.

const LOGO_STACKED := preload("res://assets/art/brand/logo_stacked.png")
const LOGO_HORIZONTAL := preload("res://assets/art/brand/logo_horizontal.png")

# Brand palette: Coal ground, Bone text, gold kept as the hot accent.
const BG := Color("15100c")
const GOLD := Color("e8c547")
const OFFWHITE := Color("e6d5b0")
const RED := Color("b8402c")  # functional red, toned to sit with oxblood
const DIM := Color("9a8a68")

# Arcade mode difficulty curve. No hand limit — the draining meter is
# the challenge; keep scoring or the bar runs out.
const ARCADE_BASE_TARGET := 600   # level 1 score target
const ARCADE_TARGET_STEP := 150   # extra target per level
const ARCADE_BASE_DRAIN := 2.5    # meter % lost per second at level 1
const ARCADE_DRAIN_STEP := 0.3
const ARCADE_MAX_DRAIN := 7.0
const ARCADE_METER_GAIN := 0.4    # meter % gained per point scored

# The canvas every screen is laid out on: 1920×1080 on desktop, or the
# mobile reference canvas Form picks (1080×2340 phone, 1536×2048 tablet).
var VIEW := Vector2(1920, 1080)
# HUD in two slim columns — main controls LEFT, payouts/hints RIGHT —
# with the play area centered between them.
const PANEL_X := 40.0       # left column
const PANEL_R := 1580.0     # right column
const PLAY_X := 370.0       # left edge of the play area
const BOARD_AREA_POS := Vector2(380, 100)
const BOARD_AREA_SIZE := Vector2(1160, 900)
const PLAY_WIDTH := 1180.0  # width of the play area
const BAR_W := 1154.0       # banner progress-bar fill width
# The HUD geometry the update code reads, set per form factor in _build_ui
# (the desktop values here; the mobile relayout replaces them).
var _bar_w := BAR_W
var _bar_y := 74.0
var _bar_y_bounty := 122.0
var _board_area := Rect2(BOARD_AREA_POS, BOARD_AREA_SIZE)
var _community_w := 292.0
var _plaque_rest_y := 10.0
var _meter_top := 104.0
var _meter_h := 892.0
var _desk_only: Array = []      # desktop-only chrome the mobile layout hides
var _play_btn: Button
var _clear_btn: Button
var _menu_btn: Button
var _cells: Array = []          # mobile: [caption Label, value Label] × 4
var _bet_tag: Label             # mobile: the starting bet, in the top bar
var _pays_btn: Button
var _pays_sheet: Control        # mobile: the payouts, as a bottom sheet
var _kit_rects: Array = []      # mobile: sleeve rect, then one per kit slot
var _target_fit_text := ""       # mobile: the table line last fitted to the top bar
var _board_area_full := Rect2()   # mobile: the board with the strip below it
var _board_area_strip := Rect2()  # mobile: the board above the strip

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
var hud_root: Control
var score_label: Label
var status_label: Label
var deck_label: Label
var meta_label: Label
var meter_back: ColorRect
var meter_fill: ColorRect
var target_label: Label
var _twist_strip: CenterContainer   # the table's twists as chips, under the score bar
var _twist_key := ""
var target_bar_back: Panel
var _boss_ticks: Control  # HP segment marks over the banner bar
var _kit_plate: Panel
var _kit_title: Label
var _kit_btns: Array = []  # provision slot buttons
var _kit_icons: Array = [] # framed provision icons on those buttons
var _sleeve_btn: Button    # the rider's signature, top row of the kit
var _sleeve_icon: TextureRect
var _kit_sig := ""         # last-rendered kit state, to skip rebuilds
const DECK_STACK_MAX := 60  # backs to pool for the literal stack
const DECK_PILE_FACTOR := 1.35  # the pile's size relative to felt cards
var _deck_btn: Button      # invisible click area over the stack
var _deck_count: Label
var _deck_stack_cards: Array = []  # one drawn back per card in the shoe
var _deck_peek: ColorRect  # click the stack: what's left, out of order
var _deck_peek_grid: Control
var _deck_peek_count: Label
var _cardgrid_layer: ColorRect  # art-kit debug: every combo in a grid
var target_bar_fill: Panel
var hand_display: Node2D
var community_display: Node2D
var _community_label: Label
var outlaw: OutlawPortrait
var _bounty_plaque: Control        # the WANTED strip over the banner area
var _hp_label: Label               # the rider's HP pips, trail only
var _hp_pips: Array = []
var _plaque_line: Label
var _plaque_reward: Label
var _plaque_portrait: Control      # rebuilt whenever the head changes
var _plaque_face := ""
var _community_plate: Panel
var _payout_names: Label
var _payout_values: Label
var _damage_flash: ColorRect
var _fade_rect: ColorRect
var _fade_tween: Tween
var _board_home := Vector2.ZERO
var _shake_tween: Tween
var _shown_score := 0.0
var _score_pop_tween: Tween
var _dust: CPUParticles2D
var splash_layer: ColorRect
var countdown_overlay: ColorRect
var parallax: ParallaxScene

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
var ui_style_btn: Button
var _vignette: TextureRect
var _vignette_rect_tex := false   # the vignette is the kit's art (so it follows the UI style)
var pause_layer: ColorRect
var _pause_music_slider: HSlider
var _pause_sfx_slider: HSlider
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var countdown_active := false
var countdown_id := 0
var preview_label: Label
var announcer: Label
var over_layer: ColorRect
var over_label: Label
var menu_layer: ColorRect
var _announce_tween: Tween

# Profiles: three save slots; trail meta/run and tutorial flags live
# under the active one. The slot choice itself persists in settings.
var profile := 1
var profile_layer: ColorRect
var _profile_menu_btn: Button
var _profile_slot_btns: Array = []
var stats_layer: ColorRect
var contracts_layer: ColorRect
var _contracts_sub: Label
var _contracts_scroll: ScrollContainer
var _contracts_list: VBoxContainer
var _stats_cols: Array = []  # 3 × [names Label, values Label]

# First-time tutorials, tracked per profile.
var tutor_seen := {}
var _tutor_queue: Array = []
var tutor_layer: ColorRect
var _tutor_title: Label
var _tutor_body: Label
var _tutor_scroll: ScrollContainer

# Board hover tooltip: full stats for the card under the mouse.
var _tooltip: PanelContainer
var _tooltip_label: Label
var _hover_card: PlayingCard = null
var _hover_time := 0.0

# Interactive how-to-play tutorial state.
var tut_step := 0
var _tut_label: Label
var _tut_skip_btn: Button


func _ready() -> void:
	get_window().title = "Poker Pop"
	# Main must keep processing while the tree is paused so ESC can
	# unpause; everything gameplay-related is gated on tree.paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_buses()
	FontLib.setup()
	UiKit.setup()  # round-2 painted chrome (the saved style lands in _load_settings)
	CardArt.validate()  # warn about any index entry missing its file
	# The brand cursor, tip at the arrow point, for every pointer shape
	# the game uses.
	var cursor: Texture2D = load("res://assets/art/brand/cursor.png")
	if cursor != null:
		Input.set_custom_mouse_cursor(cursor, Input.CURSOR_ARROW, Vector2(20, 16))
		Input.set_custom_mouse_cursor(cursor, Input.CURSOR_POINTING_HAND, Vector2(20, 16))
	_load_settings()
	# The form factor and its canvas, before any screen is built. Screenshots
	# can ask for a window (POKERPOP_WINDOW=540x1170) to shoot a phone.
	var win_env := OS.get_environment("POKERPOP_WINDOW")
	if OS.get_environment("POKERPOP_SHOT") != "" and win_env.contains("x"):
		get_window().size = Vector2i(int(win_env.get_slice("x", 0)), int(win_env.get_slice("x", 1)))
	Form.setup(get_window())
	VIEW = Form.view()
	ParallaxScene.VIEW = VIEW
	get_tree().root.size_changed.connect(_on_window_resized)
	var theme_env := OS.get_environment("POKERPOP_THEME")
	if theme_env != "":
		Themes.index = clampi(int(theme_env), 0, Themes.LIST.size() - 1)
	RenderingServer.set_default_clear_color(Themes.current().bg)

	# Procedural parallax backdrop: full-bleed silhouette scenes that
	# drift, and lurch forward whenever a hand scores.
	parallax = ParallaxScene.new()
	add_child(parallax)
	parallax.set_scene(UiKit.menu_scene())

	board = Board.new()
	board.process_mode = Node.PROCESS_MODE_PAUSABLE  # don't inherit ALWAYS
	board.locked = true
	board.fx = Fx.new()
	board.add_child(board.fx)
	board.hand_played.connect(_on_hand_played)
	board.shake_requested.connect(shake)
	board.hand_rejected.connect(func() -> void:
		_announce("NOT A VALID HAND", RED))
	board.dead_board.connect(_on_dead_board)
	board.selection_changed.connect(_refresh_hand_display)
	board.community_changed.connect(_refresh_community)
	add_child(board)
	_apply_board_layout()

	trail = TrailMode.new()
	trail.main = self
	add_child(trail)

	_build_ui()
	trail.build_ui()  # trail screens sit above the HUD, below the menu
	_build_menu()
	# The transition curtain rides above every screen except the splash.
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.size = VIEW
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(_fade_rect)
	leaderboard = Leaderboard.new()
	leaderboard.name = "Leaderboard"
	add_child(leaderboard)
	leaderboard.fetched.connect(_on_board_fetched)
	leaderboard.fetch_failed.connect(_on_board_failed)
	leaderboard.submitted.connect(_on_board_submitted)
	leaderboard.ranked.connect(_on_board_ranked)
	_build_seeds()
	_build_splash()
	_build_callout()
	_build_plaque()
	_build_ui_tip()
	_detail = DetailSheet.new()
	_detail.setup(self)
	ui_root.add_child(_detail)
	# A hazard dealt in for the first time gets its poster.
	board.card_dealt.connect(func(card: PlayingCard) -> void:
		if card.hazard != "":
			callout_card(card, "hazard_" + card.hazard))

	# Music (Western Audio Bundle): one jukebox player, fed a random
	# track from the area's playlist. Nothing plays until the splash is
	# clicked — that first gesture also unblocks web audio.
	music = _make_music_player()
	ambience = _make_music_player()

	var shot := OS.get_environment("POKERPOP_SHOT")
	if shot != "":
		var m := OS.get_environment("POKERPOP_MODE")
		if m != "splash":
			_dismiss_splash()
		match m:
			"tutoroffer":
				offer_tutorial(Callable())
			"trailcallout":
				# A water card's first-deal poster, with the table plaque.
				menu_layer.visible = false
				trail._start_run(0)
				for offer in trail._offers:
					if offer.kind == "play":
						trail._choose_offer(offer, false)
						break
				get_tree().create_timer(1.0).timeout.connect(func() -> void:
					trail._confirm_bet())
				get_tree().create_timer(3.4).timeout.connect(func() -> void:
					var wet: PlayingCard = board.grid.get(Vector2i(3, 2))
					if wet != null:
						wet.hazard = "water"
						_callout_queue.append({"card": wet, "key": "hazard_water"})
					table_banner("TABLE CLEARED"))
			"splash", "menu":
				pass
			"options":
				_open_options()
			"stats":
				_open_stats()
			"trail":
				trail.open_buyin()
			"seeds":
				# Sample boards for the picture (shot mode never saves them).
				var now := int(Time.get_unix_time_from_system())
				var rows := [[SeedBook.key("trail", "K7QX2M9P", "the_gambler-a0"), 48210],
						[SeedBook.key("time", "ABCDEFGH", "180"), 12750],
						[SeedBook.key("daily", SeedRng.daily_seed(), "the_doctor"), 30115],
						[SeedBook.key("arcade", "QWERTY23", ""), 9420]]
				for i in rows.size():
					var parts := String(rows[i][0]).split("|")
					seed_book.boards[rows[i][0]] = {"mode": parts[0], "seed": parts[1],
							"variant": parts[2], "best": rows[i][1], "attempts": 2, "last": now - i}
				open_seeds("trail", "K7QX2M9P")
				if OS.get_environment("POKERPOP_BOARD") != "":
					# A sample online answer, to picture the top ten.
					seed_book.player_name = "Steel"
					var names := ["Calamity", "Doc H", "Steel", "Big Nose", "Sundance", "Lefty",
							"Belle", "Kid Curry", "Two-Bit", "Ringo"]
					var sample: Array = []
					for i in names.size():
						sample.append({"player_id": seed_book.ensure_player() if names[i] == "Steel" else "x%d" % i,
								"player_name": names[i], "score": 61400 - i * 3170 - (i * i * 210)})
					_on_board_fetched(_shown_board_key, sample)
					_seed_name_edit.text = "Steel"
			"contracts":
				_refresh_contracts()
				contracts_layer.visible = true
				# POKERPOP_SCROLL=N shows the page scrolled N px down.
				_contracts_scroll.set_deferred("scroll_vertical",
						int(OS.get_environment("POKERPOP_SCROLL")))
			"upgrades":
				# POKERPOP_TAB picks the shelf (gear, riders, relics, ...).
				var tab := OS.get_environment("POKERPOP_TAB")
				if tab != "":
					trail._up_tab = tab
				trail.open_upgrades()
			"trailselect":
				menu_layer.visible = false
				trail.open_select()
			"trailcamp":
				menu_layer.visible = false
				trail._start_run(0)
				trail.hp = 6
				trail._choose_offer({"kind": "camp", "tarot": "THE CAMPFIRE"}, false)
				# POKERPOP_STAGE=tend shows the fire's three brands.
				if OS.get_environment("POKERPOP_STAGE") == "tend":
					trail._show_tend()
			"trailbuyin":
				# POKERPOP_RIDING shows the screen as it is with a ride saved.
				menu_layer.visible = false
				trail.preview_riding = OS.get_environment("POKERPOP_RIDING") != ""
				trail._open_buyin_now()
				# POKERPOP_ASCENSION=N turns the dial to N.
				if OS.get_environment("POKERPOP_ASCENSION") != "":
					trail._asc_pick = int(OS.get_environment("POKERPOP_ASCENSION"))
				else:
					trail._asc_pick = 0
				trail._render_ascension()
				# POKERPOP_BET shows a wager set: $25 brought, $20 on the Queen.
				if OS.get_environment("POKERPOP_BET") != "":
					trail.cash = 240
					trail.buyin_bring = 25
					trail.buyin_target = "queen"
					trail.buyin_stake = 20
				trail._render_wager()
			"trailshop":
				menu_layer.visible = false
				trail._start_run(0)
				# A couple of provisions in the kit, for the SELL row.
				trail.trail_cash = 42
				trail.provisions = ["canteen", "tonic"]
				# POKERPOP_MERCHANT picks the trader (0 peddler, 1 collector,
				# 2 card sharp); POKERPOP_BURNED shows the forge spent.
				var shop_offer := {"kind": "shop", "tarot": "GENERAL STORE"}
				if OS.get_environment("POKERPOP_MERCHANT") != "":
					shop_offer["merchant"] = int(OS.get_environment("POKERPOP_MERCHANT"))
				trail._choose_offer(shop_offer, false)
				if OS.get_environment("POKERPOP_BURNED") != "":
					trail._shop_burned_here = true
					trail._show_shop()
			"trailover":
				# POKERPOP_ENDING: laid_low (default), busted_out,
				# blinded_out or trail_complete.
				menu_layer.visible = false
				var ending := OS.get_environment("POKERPOP_ENDING")
				trail._start_run(int(OS.get_environment("POKERPOP_ASCENSION")))
				trail.outlaws_caught = 7 if ending == "trail_complete" else 3
				trail.best_hand_score = 840
				trail.best_hand_name = "Full House"
				score = 41300
				if OS.get_environment("POKERPOP_LEVELUP") != "":
					# Just shy of level 10, so the ride climbs two levels,
					# and one contract finishes on the way.
					trail.progress.exp_total = Progression.exp_at_level(10) - 60
					trail.progress.contracts_seen.erase("road_worn")
					trail.progress.contracts_claimed.erase("road_worn")
					stats["tables_cleared"] = maxi(int(stats.get("tables_cleared", 0)), 100)
				trail.relics.assign(["horseshoe", "rabbits_foot", "second_wind",
						"snake_oil", "chuck_wagon"])
				trail._second_wind_used = true  # or the free life would save the ride
				var log_kinds: Array = []
				for i in TrailMode.ROOMS_TOTAL:
					var k := TrailMode.stop_kind(i)
					log_kinds.append("outlaw" if k == "table" and i % 4 == 1 else k)
				trail.room_index = TrailMode.ROOMS_TOTAL - 1 if ending == "trail_complete" else 13
				for i in trail.room_index + 1:
					trail.room_index = i
					trail._log_stop({"kind": "camp"} if log_kinds[i] == "camp"
							else {"kind": "shop"} if log_kinds[i] == "shop"
							else {"kind": "play", "boss": "x"} if log_kinds[i] == "boss"
							else {"kind": "play", "goal": log_kinds[i]})
				trail.trail_cash = 37
				trail.bet = {"target": "queen", "stake": 20, "odds": 3.0, "paid": false}
				match ending:
					"trail_complete":
						trail.bet = {"target": "queen", "stake": 20, "odds": 3.0,
								"paid": true, "won": 80}
						trail.room_index = TrailMode.ROOMS_TOTAL
						trail._trail_complete()
					_:
						trail.take_damage(99, "", "Shot by %s."
								% TrailMode._title_case("BLACK JACK MCGREW"))
			"trailtarot":
				menu_layer.visible = false
				trail._start_run(0)
				# POKERPOP_ROOM teleports the probe deeper down the
				# trail, where the special job types start rolling.
				var shot_room := OS.get_environment("POKERPOP_ROOM")
				if shot_room != "":
					trail.room_index = clampi(int(shot_room), 0,
							TrailMode.ROOMS_TOTAL - 1)
					trail.trail_cash = 60
					trail._show_tarot()
				# Showcase the wanted poster: force a bounty into the rack.
				for offer in trail._offers:
					if offer.kind == "play":
						offer.tarot = "BOUNTY"
						offer.label = "Bounty"
						offer["goal"] = "outlaw"
						offer.odds = 3.0
						offer["outlaw_hp"] = 6
						offer["outlaws"] = trail._roll_posse(2)
						offer.hands = 13
						offer.target = 0
						offer["twists"] = [{"id": "hz_fire"}]
						break
				trail._render_tarot()
			"trailbet", "trailroom", "trailhazard":
				menu_layer.visible = false
				# POKERPOP_RIDER: the_gambler / the_machine / the_doctor.
				if TrailMode.CHARACTERS.has(OS.get_environment("POKERPOP_RIDER")):
					trail.character = OS.get_environment("POKERPOP_RIDER")
				# POKERPOP_TRICK: the Gambler's signature (sleeve / sleight).
				if TrailMode.GAMBLER_ABILITIES.has(OS.get_environment("POKERPOP_TRICK")):
					trail.gambler_ability = OS.get_environment("POKERPOP_TRICK")
				trail._start_run(0)
				for offer in trail._offers:
					if offer.kind == "play":
						trail._choose_offer(offer, false)
						break
				if m != "trailbet":
					trail._confirm_bet()
				if m == "trailroom":
					# Show the KIT stocked in the room screenshot, and a bet riding.
					trail.provisions = ["canteen", "tonic", "dynamite"]
					trail.trail_cash = 18
					trail.bet = {"target": "queen", "stake": 20, "odds": 3.0, "paid": false}
				if m == "trailhazard":
					_debug_seed_hazards()
			"trailtwist":
				# A plain table carrying three twists, for the twist strip.
				menu_layer.visible = false
				trail._start_run(0)
				trail._choose_offer({"kind": "play", "tarot": "FAT POT", "label": "Risky",
						"target": 1400, "hands": 9, "odds": 2.4, "limit": "hands",
						"goal": "", "objective": "plain", "twists": [{"id": "wild", "rank": 5},
						{"id": "hz_fire"}, {"id": "play_only", "hands": ["Pair", "Straight", "Flush"]}]}, false)
				if OS.get_environment("POKERPOP_STAGE") != "bet":
					trail._confirm_bet()
			"trailheist":
				menu_layer.visible = false
				trail._start_run(0)
				trail._choose_offer({"kind": "play", "tarot": "THE MOON",
						"label": "Heist", "target": 0, "hands": 8, "odds": 2.0,
						"goal": "safe"}, false)
				trail._confirm_bet()
			"cardgrid":
				_dismiss_splash()
				menu_layer.visible = false
				_open_cardgrid()
			"trailabilities":
				menu_layer.visible = false
				trail._start_run(0)
				trail.abilities = ["keep_the_peace", "keep_the_peace", "law_of_the_land",
						"high_noon@2", "wild_bunch", "desperado", "notches@3", "no_name",
						"good_bad_ugly", "huckleberry", "powder_keg", "spurs@2"]
				trail.loadout = {}
				trail.equip(0, "Pair")
				trail.equip(1, "Pair")
				trail.equip(2, "Two Pair")
				trail.equip(3, "Three of a Kind")
				trail.equip(7, "Flush")
				trail.equip(6, "Straight")
				trail.equip(8, "Full House")
				trail._hide_all()
				# POKERPOP_STAGE=combine picks up a twin, so COMBINE shows.
				if OS.get_environment("POKERPOP_STAGE") == "combine":
					trail.abilities_screen._sel = 1
				trail.abilities_screen.refresh()
				trail.abilities_screen.visible = true
			"trailpick":
				menu_layer.visible = false
				trail._start_run(0)
				trail.trail_cash = 23
				trail._win_rows = [["THE TABLE PAYS", 6],
						["TIN STAR", 2], ["3 HANDS TO SPARE", 1]]
				trail.pending_reward = {"room": 0, "source": "table", "round": 0,
						"offers": ["keep_the_peace", "wild_bunch", "no_name"], "chest_rounds": 0,
						"relic": "", "ledger": trail._win_rows.duplicate(true)}
				trail._show_pick()
			"traildeck":
				# The deck viewer, with a few enhanced cards and a curse in it.
				menu_layer.visible = false
				trail._start_run(0)
				trail.deck[0]["mod"] = "mult"
				trail.deck[1]["mod"] = "chip"
				trail.deck[2]["mod"] = "gold"
				trail.deck.append(TrailMode.cursed_card())
				trail._show_deck_now()
			"trailrelic":
				menu_layer.visible = false
				trail._start_run(0)
				trail._hide_all()
				# POKERPOP_RELIC shows any relic on the strongbox screen.
				var rid := OS.get_environment("POKERPOP_RELIC")
				trail._pending_relic_reward = rid if rid != "" else "horseshoe"
				trail._show_relic_reward_now()
			"trailbj":
				menu_layer.visible = false
				trail._start_run(0)
				trail._choose_offer({"kind": "play", "tarot": "BLACKJACK",
						"label": "Twenty-One", "target": 0, "hands": 8, "odds": 1.5,
						"goal": "blackjack", "wins": 3}, false)
				trail._confirm_bet()
			"trailholdem":
				menu_layer.visible = false
				trail._start_run(0)
				trail._choose_offer({"kind": "play", "tarot": "TEXAS HOLD'EM",
						"label": "Hold'em", "target": 1200, "hands": 9, "odds": 1.5,
						"goal": "holdem"}, false)
				trail._confirm_bet()
			"trailoutlaw":
				menu_layer.visible = false
				trail._start_run(0)
				trail._choose_offer({"kind": "play", "tarot": "BOUNTY",
						"label": "Bounty", "target": 0, "hands": 13, "odds": 3.0,
						"goal": "outlaw", "outlaw_hp": 6,
						"posse": 2}, false)
				trail._confirm_bet()
			"trailboss":
				menu_layer.visible = false
				trail._start_run(0)
				trail.room_index = TrailMode.ROOMS_TOTAL - 1  # King Cobra's table
				trail._show_tarot()
				trail._choose_offer(trail._offers[0], false)  # bosses sit straight down
			"tutorial":
				menu_layer.visible = false
				_start_tutorial()
				# POKERPOP_TUT_STEP=N opens on lesson N (1-based).

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
	if game_started and not menu_open and not game_over and not countdown_active \
			and not help_blocking():
		if mode_kind == "time":
			time_left -= delta
			if time_left <= 0.0:
				time_left = 0.0
				game_over = true
				board.locked = true
				stat_bump("time_games")
				stat_max("time_best", score)
				_show_game_over("TIME'S UP\n\nFinal score: %d\n\nR — play again    M — menu" % score)
		elif mode_kind == "arcade" and not level_transition:
			meter -= _arcade_drain() * delta
			if meter <= 0.0:
				meter = 0.0
				game_over = true
				board.locked = true
				stat_bump("arcade_games")
				stat_max("arcade_best_level", level)
				stat_max("arcade_best", score)
				_show_game_over("THE BAR HIT BOTTOM\n\nYou made it to level %d.\nTotal score: %d\n\nR — play again    M — menu" % [level, score])
		elif mode_kind == "trail" and trail.in_room and trail.room_on_clock():
			trail.room_time_left -= delta
			if trail.room_time_left <= 0.0:
				trail.room_time_left = 0.0
				trail.on_time_up()
	board.update_fuse_loop(game_started and not menu_open and not game_over
			and not get_tree().paused)
	_update_labels()
	if Form.is_touch():
		# No hover on a touchscreen: a held finger opens the detail sheet.
		if _detail != null:
			_detail.tick(delta)
	else:
		_update_tooltip(delta)
		_update_ui_tip(delta)
	_update_callout()


func _arcade_target() -> int:
	return ARCADE_BASE_TARGET + ARCADE_TARGET_STEP * (level - 1)


func _arcade_drain() -> float:
	return minf(ARCADE_MAX_DRAIN, ARCADE_BASE_DRAIN + ARCADE_DRAIN_STEP * (level - 1))


func _update_labels() -> void:
	hud_root.visible = not menu_open
	# The score ticks up to its true value rather than teleporting
	# (a drop means a fresh run — snap straight there).
	if score < int(_shown_score):
		_shown_score = score
	elif score > _shown_score:
		_shown_score = move_toward(_shown_score, score,
				maxf((score - _shown_score) * 8.0, 90.0) * get_process_delta_time())
	score_label.text = "SCORE  %d" % int(_shown_score)
	deck_label.text = "DECK  %d" % board.deck.size()
	var meta := "%s  ·  Theme: %s (T)" % [mode_label_text, Themes.current().name]
	if meta != meta_label.text:
		meta_label.text = meta
		# Long lines (the seed rides here now) shrink to stay on the panel.
		var mfont: Font = meta_label.get_theme_font("font")
		var fs := 16
		while fs > 11 and mfont.get_string_size(meta, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 318.0:
			fs -= 1
		meta_label.add_theme_font_size_override("font_size", fs)
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
			if trail.in_room and trail.room_on_clock():
				var tsecs := ceili(trail.room_time_left)
				status_label.text = "TIME  %d:%02d" % [tsecs / 60, tsecs % 60]
				status_label.add_theme_color_override("font_color",
						RED if trail.room_time_left < 15.0 else OFFWHITE)
			else:
				status_label.text = "HANDS LEFT  %d" % trail.room_hands_left
				status_label.add_theme_color_override("font_color",
						RED if trail.room_hands_left <= 2 else OFFWHITE)
			deck_label.text = trail.hud_cash_line()
		_:
			status_label.text = "HANDS PLAYED  %d" % hands_played
			status_label.add_theme_color_override("font_color", OFFWHITE)

	outlaw.visible = outlaw.dying or (mode_kind == "trail" and game_started \
			and not menu_open and trail.in_room \
			and trail.room_goal in ["outlaw", "boss"])
	# The scene's light falls on the table and the dust, never on the
	# cards or the HUD.
	var tint := parallax.ambient_tint()
	board.table.modulate = tint.lerp(Color.WHITE, 0.5)
	_dust.visible = game_started and not menu_open
	_dust.emitting = _dust.visible
	_dust.color = Color(tint.r * 0.85, tint.g * 0.8, tint.b * 0.62, 0.10)
	var show_community := not board.panel_cards().is_empty() \
			and game_started and not menu_open
	_community_label.visible = show_community
	community_display.visible = show_community
	_community_plate.visible = show_community
	if Form.is_mobile() and _board_area_full.size.y > 0.0:
		# The strip under the board is only there when the table uses it.
		var want := _board_area_strip if show_community or outlaw.visible else _board_area_full
		if want != _board_area and not board.busy:
			_board_area = want
			_apply_board_layout()
	if show_community:
		if board.blackjack_target > 0:
			_community_label.text = ("DEALER SHOWS %d" if board.blackjack_hole_hidden
					else "DEALER HAS %d") % board.blackjack_target
		else:
			_community_label.text = "COMMUNITY"
	if Form.is_mobile():
		_update_cells()
	_style_boss_bar(0, 0)  # gold progress by default; boss rooms restyle it
	var show_arcade := mode_kind == "arcade" and game_started and not menu_open
	var show_trail := mode_kind == "trail" and game_started and not menu_open and trail.in_room
	meter_back.visible = show_arcade
	meter_fill.visible = show_arcade
	target_label.visible = show_arcade or show_trail
	target_bar_back.visible = show_arcade or show_trail
	target_bar_fill.visible = show_arcade or show_trail
	# The rider's HP pips ride the left column through the whole trail.
	var show_hp := mode_kind == "trail" and game_started and not menu_open
	_hp_label.visible = show_hp
	for i in _hp_pips.size():
		var pip: Panel = _hp_pips[i]
		# Pips past the rider's max (8 from Ascension 18) stay hidden.
		pip.visible = show_hp and i < trail.max_hp()
		if show_hp:
			pip.add_theme_stylebox_override("panel",
					UiKit.bar_box("red") if i < trail.hp else UiKit.bar_box("track"))
	# Every table resets the banner strip; the bounty branch below
	# claims it back with the WANTED plaque and a dropped bar.
	_bounty_plaque.visible = false
	target_bar_back.position.y = _bar_y
	target_bar_fill.position.y = _bar_y
	if show_arcade:
		var h := _meter_h * meter / 100.0
		meter_fill.position.y = _meter_top + (_meter_h - h)
		meter_fill.size.y = h
		meter_fill.color = GOLD if meter > 25.0 else RED
		var target := _arcade_target()
		target_label.text = "LEVEL %d      %d / %d" % [level, level_score, target]
		target_bar_fill.size.x = _bar_w * clampf(float(level_score) / float(target), 0.0, 1.0)
	elif show_trail:
		if trail.room_goal == "boss":
			# The boss wears a segmented HEALTH bar in the banner slot.
			var bcard: PlayingCard = null
			for p in board.grid:
				if board.grid[p].boss != "":
					bcard = board.grid[p]
					break
			var bhp := 0
			var bhp_max := 0
			var bname := "THE BOSS IS DOWN"
			if bcard != null:
				match bcard.boss:
					"jack":
						bhp = bcard.boss_hp
						bhp_max = board.boss_max_hp("jack")
						bname = "JACK OF ALL TRADES  ·  BEAT %d TO WOUND" % board.jack_bar
					"queen":
						bhp = bcard.boss_hp
						bhp_max = board.boss_max_hp("queen")
						bname = "QUEEN BEE  ·  SCORE HANDS WITH HER"
					"cobra":
						bhp = bcard.boss_hp
						bhp_max = board.boss_max_hp("cobra")
						bname = "KING COBRA  ·  SCORE HANDS WITH HIS HEAD"
			target_label.text = "TABLE %d / %d      %s" % \
					[trail.room_index + 1, TrailMode.ROOMS_TOTAL, bname]
			_style_boss_bar(bhp, bhp_max)
			# The boss wears his medallion in the right gutter too.
			if bcard != null:
				outlaw.kind = bcard.boss
				outlaw.spec = {}
				outlaw.set_display(bhp, maxi(bhp_max, 1))
				outlaw.grit = -1
		elif trail.room_goal == "safe":
			var digits := PackedStringArray()
			for d in trail.room_combo:
				digits.append(str(d))
			target_label.text = "TABLE %d / %d      SAFE  %s" % \
					[trail.room_index + 1, TrailMode.ROOMS_TOTAL, " · ".join(digits)]
			target_bar_fill.size.x = _bar_w * trail.safe_progress() / 4.0
		elif trail.room_goal == "chest":
			target_label.text = "TABLE %d / %d      KEY + CHEST  %d / %d" % \
					[trail.room_index + 1, TrailMode.ROOMS_TOTAL,
					trail.room_chests_opened, trail.room_chests_needed]
			target_bar_fill.size.x = _bar_w * clampf(
					float(trail.room_chests_opened)
					/ float(maxi(trail.room_chests_needed, 1)), 0.0, 1.0)
		elif trail.room_goal == "mine":
			target_label.text = "TABLE %d / %d      GOLD MINE  %d / %d STONES" % \
					[trail.room_index + 1, TrailMode.ROOMS_TOTAL,
					trail.room_stones_broken, trail.room_stones_needed]
			target_bar_fill.size.x = _bar_w * clampf(
					float(trail.room_stones_broken)
					/ float(maxi(trail.room_stones_needed, 1)), 0.0, 1.0)
		elif trail.room_goal == "blackjack":
			target_label.text = "TABLE %d / %d      DEALER SHOWS %d  ·  WINS %d / %d" % \
					[trail.room_index + 1, TrailMode.ROOMS_TOTAL,
					board.blackjack_target, trail.room_wins, trail.room_wins_needed]
			target_bar_fill.size.x = _bar_w * clampf(
					float(trail.room_wins) / float(maxi(trail.room_wins_needed, 1)),
					0.0, 1.0)
		elif trail.room_goal == "outlaw":
			var posse_note := ""
			if trail.room_outlaws.size() > 1:
				posse_note = "  (%d OF %d)" % [trail.room_outlaw_idx + 1,
						trail.room_outlaws.size()]
			target_label.text = "TABLE %d / %d      BOUNTY: %s%s  ·  SCORE %d+" % \
					[trail.room_index + 1, TrailMode.ROOMS_TOTAL,
					trail.current_outlaw_name(), posse_note, trail._outlaw_bar()]
			_style_boss_bar(trail.room_outlaw_hp, trail.room_outlaw_max)
			outlaw.kind = "outlaw"
			outlaw.spec = trail.current_outlaw_spec()
			_update_bounty_plaque(posse_note)
		elif trail.room_goal == "purge":
			var quota := trail.purge_quota()
			target_label.text = "TABLE %d / %d      PURGE  %d / %d CLEARED  ·  %d ON THE TABLE" % \
					[trail.room_index + 1, TrailMode.ROOMS_TOTAL,
					trail.purged_count(), quota, trail.purge_left()]
			target_bar_fill.size.x = _bar_w * clampf(
					float(trail.purged_count()) / float(maxi(quota, 1)), 0.0, 1.0)
		elif trail.room_goal == "hands":
			target_label.text = "TABLE %d / %d      PLAY  %s" % \
					[trail.room_index + 1, TrailMode.ROOMS_TOTAL, trail.require_status()]
			target_bar_fill.size.x = _bar_w * clampf(trail.require_frac(), 0.0, 1.0)
		elif trail.room_goal == "collect":
			target_label.text = "TABLE %d / %d      %s" % \
					[trail.room_index + 1, TrailMode.ROOMS_TOTAL, trail.collect_status()]
			target_bar_fill.size.x = _bar_w * clampf(
					float(trail.room_collect_done)
					/ float(maxi(trail.room_collect_need, 1)), 0.0, 1.0)
		elif trail.room_goal == "landrush":
			var plots := board.cols * board.rows
			target_label.text = "TABLE %d / %d      PLOTS CLAIMED  %d / %d" % \
					[trail.room_index + 1, TrailMode.ROOMS_TOTAL,
					board.landrush_marks.size(), plots]
			target_bar_fill.size.x = _bar_w * clampf(
					float(board.landrush_marks.size()) / float(plots), 0.0, 1.0)
		else:
			target_label.text = "TABLE %d / %d      %d / %d" % \
					[trail.room_index + 1, TrailMode.ROOMS_TOTAL, trail.room_score, trail.room_target]
			target_bar_fill.size.x = _bar_w * clampf(
					float(trail.room_score) / float(maxi(trail.room_target, 1)), 0.0, 1.0)
	_update_kit()
	if _twist_strip != null:
		var in_table: bool = mode_kind == "trail" and game_started and not menu_open and trail.in_room
		var key: String = trail.twist_badges(trail.current_offer) if in_table else ""
		_twist_strip.visible = key != ""
		if key != _twist_key:
			_twist_key = key
			for ch in _twist_strip.get_children():
				ch.queue_free()
			if key != "":
				_twist_strip.add_child(twist_chips(trail.current_offer))
	if _deck_btn != null:
		var show_deck := game_started and not menu_open and not game_over
		_deck_btn.visible = show_deck
		_deck_count.visible = show_deck
		# One back per card still to be dealt: cards drawn but not yet
		# thrown stay counted on top, so each throw visibly takes the
		# top card off the stack.
		var shoe: int = board.deck.size() + board.undealt_in_flight()
		var shown := mini(shoe, _deck_stack_cards.size())
		# The pile stands a good third bigger than the felt cards — it
		# should look like the deck in your hand, not another slot.
		var pile_scale: Vector2 = board.scale * DECK_PILE_FACTOR
		board.deal_scale = DECK_PILE_FACTOR
		if Form.is_mobile():
			# No room for the pile on a phone: the deck is the button in
			# the top bar, and cards are dealt from it.
			board.deal_scale = 0.6
			for back in _deck_stack_cards:
				back.visible = false
		else:
			for i in _deck_stack_cards.size():
				var back: PlayingCard = _deck_stack_cards[i]
				if back.scale != pile_scale:
					back.scale = pile_scale
				back.visible = show_deck and i < shown
			if shown > 0:
				board.deal_anchor = (_deck_stack_cards[shown - 1] as PlayingCard).position
		if show_deck:
			_deck_count.text = ("DECK\n%d" if Form.is_mobile() else "DECK  %d") % shoe
		elif _deck_peek.visible:
			_deck_peek.visible = false
	_update_preview()


# --- Art-kit debug grid: every mod/hazard/special combo on one screen ------

func _open_cardgrid() -> void:
	if _cardgrid_layer != null:
		_cardgrid_layer.queue_free()
	# Reveal-everything flags for the grid only; restored on close.
	PlayingCard.wild_rank = 8
	PlayingCard.show_hazard_intent = true
	_cardgrid_layer = ColorRect.new()
	_cardgrid_layer.color = Color("15100c")
	_cardgrid_layer.size = VIEW
	_cardgrid_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(_cardgrid_layer)
	var title := _label(_cardgrid_layer, "CARD ART — EVERY COMBO", Vector2(0, 14), 34, GOLD)
	title.size = Vector2(VIEW.x, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var states: Array = [
		["5 of Spades", func(c: PlayingCard) -> void: c.rank = 5],
		["King of Hearts", func(c: PlayingCard) -> void: c.rank = 13; c.suit = 1],
		["Card back", func(c: PlayingCard) -> void: c.face_down = true],
		["Mult", func(c: PlayingCard) -> void: c.mod = "mult"],
		["Cash, scored twice", func(c: PlayingCard) -> void: c.mod = "chip"; c.chip_level = 2],
		["Plus →", func(c: PlayingCard) -> void: c.mod = "plus"; c.boost_dir = Vector2i.RIGHT],
		["Minus ←", func(c: PlayingCard) -> void: c.mod = "minus"; c.boost_dir = Vector2i.LEFT],
		["Bumper ↓", func(c: PlayingCard) -> void: c.mod = "bumper"; c.boost_dir = Vector2i.DOWN],
		["Gold", func(c: PlayingCard) -> void: c.mod = "gold"],
		["Wild", func(c: PlayingCard) -> void: c.mod = "wild"],
		["The Joker", func(c: PlayingCard) -> void: c.rank = 14; c.joker = true; c.mod = "wild"],
		["Prism mult", func(c: PlayingCard) -> void: c.mod = "mult"; c.finish = "prism"],
		["Metal cash, 2 pins left", func(c: PlayingCard) -> void: c.mod = "chip"; c.finish = "metal"; c.metal_wear = 2],
		["Holo 9", func(c: PlayingCard) -> void: c.rank = 9; c.suit = 1; c.finish = "holo"],
		["Negative King", func(c: PlayingCard) -> void: c.rank = 13; c.finish = "negative"],
		["Crazy 8 (wild)", func(c: PlayingCard) -> void: c.rank = 8],
		["Fire on an Ace", func(c: PlayingCard) -> void: c.rank = 14; c.hazard = "fire"],
		["Fire on a 2", func(c: PlayingCard) -> void: c.rank = 2; c.hazard = "fire"],
		["Water 1/4", func(c: PlayingCard) -> void: c.hazard = "water"; c.water_level = 1],
		["Water 3/4", func(c: PlayingCard) -> void: c.hazard = "water"; c.water_level = 3],
		["FILLED", func(c: PlayingCard) -> void: c.hazard = "water"; c.water_level = 4; c.washed = true],
		["Wind", func(c: PlayingCard) -> void: c.hazard = "wind"; c.wind_dir = Vector2i.UP],
		["Bomb, fuse 5", func(c: PlayingCard) -> void: c.hazard = "bomb"; c.fuse = 5],
		["Bomb, fuse 1", func(c: PlayingCard) -> void: c.hazard = "bomb"; c.fuse = 1],
		["Stone, fresh", func(c: PlayingCard) -> void: c.hazard = "stone"; c.stone_hits = 3],
		["Stone, 1 left", func(c: PlayingCard) -> void: c.hazard = "stone"; c.stone_hits = 1],
		["Stone, gold under", func(c: PlayingCard) -> void: c.hazard = "stone"; c.stone_hits = 1; c.stone_gold = true],
		["Fire incoming", func(c: PlayingCard) -> void: c.incoming = "fire"],
		["Water incoming", func(c: PlayingCard) -> void: c.incoming = "water"],
		["The Key", func(c: PlayingCard) -> void: c.objective = "key"],
		["The Chest", func(c: PlayingCard) -> void: c.objective = "chest"],
		["Your bullet", func(c: PlayingCard) -> void: c.objective = "bullet"],
		["His bullet", func(c: PlayingCard) -> void: c.objective = "hisbullet"],
		["Cursed", func(c: PlayingCard) -> void: c.cursed = true],
		["Honeyed", func(c: PlayingCard) -> void: c.honey = true],
		["The Safe", func(c: PlayingCard) -> void: c.is_safe = true; c.combo = [3, 9, 5, 2]; c.combo_progress = 2],
		["Cobra tail", func(c: PlayingCard) -> void: c.snake_tail = true],
		["Jack of All Trades", func(c: PlayingCard) -> void: c.boss = "jack"; c.boss_hp = 2000; c.rank = 11; c.suit = 2],
		["Queen Bee", func(c: PlayingCard) -> void: c.boss = "queen"; c.boss_hp = 2; c.rank = 12; c.suit = 1],
		["King Cobra", func(c: PlayingCard) -> void: c.boss = "cobra"; c.boss_hp = 5000; c.rank = 9],
		["The Outlaw (card)", func(c: PlayingCard) -> void: c.boss = "outlaw"; c.rank = 10; c.suit = 3],
	]
	var cols := 10
	for i in states.size():
		var cell := Vector2(110 + (i % cols) * 190.0, 170 + (i / cols) * 232.0)
		var pc := PlayingCard.new()
		pc.rank = 7
		pc.suit = 0
		(states[i][1] as Callable).call(pc)
		pc.material = Themes.current_material()
		pc.scale = Vector2(1.35, 1.35)
		pc.position = cell
		_cardgrid_layer.add_child(pc)
		var lbl := _label(_cardgrid_layer, String(states[i][0]),
				Vector2(cell.x - 90, cell.y + 82), 15, DIM)
		lbl.size = Vector2(180, 24)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var close := _button(_cardgrid_layer, "CLOSE", Vector2(810, 1008), Vector2(300, 54))
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(_close_cardgrid)


func _close_cardgrid() -> void:
	if _cardgrid_layer != null:
		_cardgrid_layer.queue_free()
		_cardgrid_layer = null
	# Back to the game's own rules for the reveal flags (hazard intent
	# stays on for everyone since the Weathervane retired).
	PlayingCard.wild_rank = board.wild_rank


## Riffle through the undealt pile — shuffled for display, so the
## draw order stays the dealer's secret.
func _open_deck_peek() -> void:
	if not game_started or game_over:
		return
	for c in _deck_peek_grid.get_children():
		c.queue_free()
	var pool: Array = board.deck.duplicate()
	pool.shuffle()
	_deck_peek_count.text = "%d cards left to deal, shown in no particular order" % pool.size()
	for i in pool.size():
		var d: Dictionary = pool[i]
		var pc := PlayingCard.new()
		pc.rank = int(d.rank)
		pc.suit = int(d.suit)
		pc.mod = Board.migrate_mod(String(d.get("mod", "")))
		pc.finish = PlayingCard.finish_of(d)
		pc.cursed = bool(d.get("cursed", false))
		pc.material = Themes.current_material()
		pc.scale = Vector2(0.9, 0.9)
		pc.position = Vector2(64 + (i % 12) * 110, 70 + (i / 12) * 128)
		_deck_peek_grid.add_child(pc)
	_deck_peek_grid.custom_minimum_size = Vector2(1360,
			70 + ceili(pool.size() / 12.0) * 128)
	board._play_sound(Board.SFX_SHUFFLES.pick_random(), 1.1, -10.0)
	_deck_peek.visible = true


## The provision kit: three slots in the right column, trail rooms only.
func _update_kit() -> void:
	var show := mode_kind == "trail" and game_started and not menu_open \
			and trail.in_room
	if _kit_plate == null:
		return
	_kit_plate.visible = show
	_kit_title.visible = show
	_sleeve_btn.visible = show
	for i in _kit_btns.size():
		_kit_btns[i].visible = show and i < trail.kit_size()
	if not show:
		_kit_sig = ""
		return
	var sig := str(trail.provisions) + str(trail._aiming_slot) + str(trail.kit_size()) \
			+ str(trail.sleeve_card) + str(trail.sleeve_used) + str(trail._aiming_sleeve) \
			+ trail.character + str(trail.laser_used) + str(trail._aiming_laser) \
			+ str(trail.ride_lv("laser")) + str(trail.watch_uses_left) + str(board.has_undo()) \
			+ trail.gambler_ability + str(trail.sleight_uses_left) + str(trail._aiming_sleight)
	if sig == _kit_sig:
		return
	_kit_sig = sig
	# Layout: the sleeve row plus the kit slots — compressed a little
	# when the Saddlebags add a fifth row.
	var rows := 1 + trail.kit_size()
	var spacing := 64.0 if rows <= 4 else 53.0
	var bh := 56.0 if rows <= 4 else 48.0
	_sleeve_btn.position = Vector2(PANEL_R, 574)
	_sleeve_btn.size = Vector2(300, bh)
	if not _kit_rects.is_empty():
		_sleeve_btn.position = (_kit_rects[0] as Rect2).position
		_sleeve_btn.size = (_kit_rects[0] as Rect2).size
		bh = _sleeve_btn.size.y
	_sleeve_btn.pivot_offset = _sleeve_btn.size / 2.0
	match trail.character:
		"the_machine":
			if trail._aiming_laser:
				_sleeve_btn.disabled = false
				_sleeve_btn.text = "AIMING…"
				_sleeve_btn.tooltip_text = "Pick a card on the table to burn. Right-click or press again to cancel."
			elif trail.laser_used:
				_sleeve_btn.disabled = true
				_sleeve_btn.text = "LASER — SPENT"
				_sleeve_btn.tooltip_text = "One shot per table. It recharges when you sit down at the next one."
			else:
				_sleeve_btn.disabled = false
				_sleeve_btn.text = "LASER  ×%d" % (1 + trail.ride_lv("laser"))
				_sleeve_btn.tooltip_text = "The Laser: once per table, burn a card right off the table%s. You can widen the beam at the Outfitter." \
						% ("" if trail.ride_lv("laser") == 0
						else ", plus %d more around it in a cross" % trail.ride_lv("laser"))
		"the_doctor":
			if trail.watch_uses_left <= 0:
				_sleeve_btn.disabled = true
				_sleeve_btn.text = "WATCH — WOUND DOWN"
				_sleeve_btn.tooltip_text = "No rewinds left at this table. The watch is wound again at the next one."
			elif not board.has_undo():
				_sleeve_btn.disabled = true
				_sleeve_btn.text = "POCKET WATCH  ×%d" % trail.watch_uses_left
				_sleeve_btn.tooltip_text = "The Pocket Watch: takes back your last hand. Play a hand first."
			else:
				_sleeve_btn.disabled = false
				_sleeve_btn.text = "POCKET WATCH  ×%d" % trail.watch_uses_left
				_sleeve_btn.tooltip_text = "The Pocket Watch: press to take back your last hand. The cards, the score and the hand you used all come back. You can buy extra rewinds at the Outfitter."
		_ when trail.gambler_ability == "sleight":
			if trail._aiming_sleight:
				_sleeve_btn.disabled = false
				_sleeve_btn.text = "AIMING…"
				_sleeve_btn.tooltip_text = "Pick a card, then the card next to it. Right-click or press again to cancel."
			elif trail.sleight_uses_left <= 0:
				_sleeve_btn.disabled = true
				_sleeve_btn.text = "SLEIGHT — PLAYED"
				_sleeve_btn.tooltip_text = "No swaps left at this table. They're ready again at the next one."
			else:
				_sleeve_btn.disabled = false
				_sleeve_btn.text = "SLEIGHT OF HAND" if trail.ride_lv("sleight") == 0 \
						else "SLEIGHT  ×%d" % trail.sleight_uses_left
				_sleeve_btn.tooltip_text = "Sleight of Hand: swap two cards that sit side by side. It doesn't cost a hand. You have %d swap%s left at this table, and the Outfitter can add more." \
						% [trail.sleight_uses_left, "" if trail.sleight_uses_left == 1 else "s"]
		_:
			if trail._aiming_sleeve:
				_sleeve_btn.disabled = false
				_sleeve_btn.text = "AIMING…"
				_sleeve_btn.tooltip_text = "Pick a card on the table to swap with. Right-click or press again to cancel."
			elif trail.sleeve_used:
				_sleeve_btn.disabled = true
				_sleeve_btn.text = "SLEEVE — SPENT"
				_sleeve_btn.tooltip_text = "One swap per table. It's back when you sit down at the next one."
			else:
				_sleeve_btn.disabled = false
				_sleeve_btn.text = "SLEEVE  %s" % trail.sleeve_label()
				_sleeve_btn.tooltip_text = "Ace Up the Sleeve: once per table, trade this card for any plain card on the table. The card you take stays up your sleeve for a later table. You can raise its starting rank at the Outfitter."
	var sig_icon := "laser" if trail.character == "the_machine" \
			else "watch" if trail.character == "the_doctor" \
			else trail.gambler_ability
	_sleeve_icon.texture = CardArt.tex("icon", sig_icon)
	_sleeve_icon.position = Vector2(8, 6)
	_sleeve_icon.size = Vector2(bh - 12, bh - 12)
	var kit_font := 26 if not _kit_rects.is_empty() else 19
	if _sleeve_icon.texture != null:
		UiKit.fit_button_text(_sleeve_btn, kit_font, 13, 2.0 * (_sleeve_icon.size.x + 14.0))
	else:
		UiKit.fit_button_text(_sleeve_btn, kit_font)
	for i in _kit_btns.size():
		var btn: Button = _kit_btns[i]
		btn.position = Vector2(PANEL_R, 574 + (i + 1) * spacing)
		btn.size = Vector2(300, bh)
		btn.pivot_offset = btn.size / 2.0
		var icon: TextureRect = _kit_icons[i]
		icon.position = Vector2(8, 6)
		icon.size = Vector2(bh - 12, bh - 12)
		if i + 1 < _kit_rects.size():
			# The phone kit: square icon buttons in a row; the name and what
			# it does are a long-press away.
			btn.position = (_kit_rects[i + 1] as Rect2).position
			btn.size = (_kit_rects[i + 1] as Rect2).size
			icon.position = Vector2(12, 12)
			icon.size = btn.size - Vector2(24, 24)
		icon.texture = CardArt.provision_icon(trail.provisions[i]) \
				if i < trail.provisions.size() else null
		if i < trail.provisions.size():
			var p: Dictionary = TrailMode.PROVISIONS[trail.provisions[i]]
			btn.disabled = false
			if trail._aiming_slot == i:
				btn.text = "AIMING…"
				btn.tooltip_text = "Pick a card on the table. Right-click or press again to cancel."
			else:
				btn.text = p.name
				btn.tooltip_text = trail.provision_desc(String(trail.provisions[i])) + (
						"\nClick it, then pick a card on the table. It doesn't cost a hand."
						if p.kind == "target" else "\nWorks the moment you click it. It doesn't cost a hand.")
		else:
			btn.disabled = true
			btn.text = "—"
			btn.tooltip_text = "An empty kit slot. You'll find provisions in shops, safes and chests."
		# Centered text keeps clear of the icon on the left edge.
		UiKit.fit_button_text(btn, 19, 13, 2.0 * (icon.position.x + icon.size.x + 6.0))
		if i + 1 < _kit_rects.size():
			var aiming := btn.text == "AIMING…"
			btn.text = "" if not btn.disabled or icon.texture != null else "—"
			btn.modulate = Color(1.35, 1.2, 0.75) if aiming else Color.WHITE


## Restyles the banner bar as a red segmented HEALTH bar (bosses and
## the Outlaw). max_hp 0 restores the plain gold progress fill.
func _style_boss_bar(hp: int, max_hp: int) -> void:
	if max_hp <= 0:
		target_bar_fill.add_theme_stylebox_override("panel", UiKit.bar_box("gold"))
		if _boss_ticks != null:
			_boss_ticks.visible = false
		return
	target_bar_fill.add_theme_stylebox_override("panel", UiKit.bar_box("red"))
	target_bar_fill.size.x = _bar_w * clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_boss_ticks.visible = true
	# One notch per life — or ten even notches for a score-pool boss
	# like the Jack, whose max runs to the thousands. The 3px gaps cut
	# the red fill into the kit's per-segment pills.
	var seg := max_hp if max_hp <= 12 else 10
	if _boss_ticks.get_child_count() != seg - 1:
		for c in _boss_ticks.get_children():
			c.queue_free()
		for i in range(1, seg):
			var t := ColorRect.new()
			t.color = Color(0, 0, 0, 0.55)
			t.position = Vector2(_bar_w * i / seg, 3.0)
			t.size = Vector2(3, 10)
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_boss_ticks.add_child(t)


## Dresses the WANTED plaque for the current head of the posse and
## drops the HP bar just below it, onto the table rim. Leaves the
## plain banner label alone when the kit (or the spec) is missing.
func _update_bounty_plaque(posse_note: String) -> void:
	var spec: Dictionary = trail.current_outlaw_spec()
	if spec.is_empty() or _plaque_line == null:
		return
	_bounty_plaque.visible = true
	target_label.visible = false
	target_bar_back.position.y = _bar_y_bounty
	target_bar_fill.position.y = _bar_y_bounty
	var who := trail.current_outlaw_name()
	_plaque_line.text = "%s%s  ·  DEAD OR ALIVE  ·  SCORE %d+" % [
			who, posse_note, trail._outlaw_bar()]
	_plaque_reward.text = "$%d" % trail.bounty_reward()
	if _plaque_face != who:
		_plaque_face = who
		if _plaque_portrait != null:
			_plaque_portrait.queue_free()
		_plaque_portrait = CharacterKit.add_portrait(_bounty_plaque, spec,
				Rect2(20, 14, 91, 91))


## The WANTED banner that drops when a bounty table opens: the kit's
## paper with the outlaw's face, name, the red line, and the pot inked
## as the reward. Slides in, holds, and rides off. Skipped in
## screenshot mode, where it would curtain the board.
func show_wanted_banner(spec: Dictionary, subtitle: String, reward: int) -> void:
	if spec.is_empty() or OS.get_environment("POKERPOP_SHOT") != "":
		return
	var info: Dictionary = CharacterKit.poster_info("banner_template")
	# The plain template bakes DEAD OR ALIVE into the red line; we
	# letter our own subtitle, so take the blank-line version.
	var tpl: Texture2D = CharacterKit.tex(String(info.get("no_subtitle",
			info.get("file", ""))))
	if tpl == null:
		return
	var holder := Control.new()
	holder.position = Vector2(160, -380)
	holder.size = Vector2(1600, 360)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.z_index = 80
	var paper := TextureRect.new()
	paper.texture = tpl
	paper.size = Vector2(1600, 360)
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(paper)
	CharacterKit.add_portrait(holder, spec, Rect2(69, 43, 274, 274))
	var sub := _label(holder, subtitle, Vector2(0, 196), 25, Color("8a3a30"))
	sub.size = Vector2(1600, 32)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if FontLib.numbers != null:
		sub.add_theme_font_override("font", FontLib.numbers)
	var name_l := _label(holder, String(spec.get("name", "")), Vector2(0, 238), 54,
			Color("3a3126"))
	name_l.size = Vector2(1600, 64)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var reward_l := _label(holder, "$%d" % reward, Vector2(1166, 180), 58,
			Color("8a3a30"))
	reward_l.size = Vector2(434, 72)
	reward_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if Form.is_mobile():
		holder.scale = Vector2.ONE * ((VIEW.x - 72.0) / 1600.0)
		holder.position.x = 36.0
	hud_root.add_child(holder)
	board._play_sound(Board.SFX_REVOLVERS.pick_random(), 0.9, -12.0)
	var tw := holder.create_tween()
	tw.tween_property(holder, "position:y", Form.safe_top() + 36.0, 0.5) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.7)
	tw.tween_property(holder, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(holder, "position:y", -80.0, 0.4) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(holder.queue_free)


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
		if _callout_layer != null and help_open(_callout_layer):
			# The card callout eats keys; ENTER/SPACE dismiss it.
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_dismiss_callout()
			return
		if tutor_layer != null and help_open(tutor_layer):
			# The explainer popup eats keys; ENTER/SPACE advance it.
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_tutor_next()
			return
		match event.keycode:
			KEY_ESCAPE:
				_toggle_pause()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if not game_over:
					board.play_hand()
			KEY_C:
				if not game_over:
					board.player_clear()
			KEY_R:
				_restart()
			KEY_M:
				_open_menu()
			KEY_T:
				Themes.cycle()
				RenderingServer.set_default_clear_color(Themes.current().bg)
				board.apply_theme()
				_refresh_hand_display()


## The tail of the score preview: what the selected mod cards add —
## the stacked multiplier and the cash it pays.
func _preview_mod_text(result: Dictionary) -> String:
	var parts := ""
	var mults := 0
	for card in board.selected:
		if card.mod == "mult":
			mults += 1
	if mults > 0:
		parts += "  ×%s MULT" % String.num(pow(board.mult_factor, mults), 2)
	if result.has("cash_earned"):
		parts += "  +$%d" % int(result.cash_earned)
	if int(result.get("cash_spent", 0)) > 0:
		parts += "  −$%d" % int(result.cash_spent)
	if mode_kind == "trail":
		# Every ability on this hand, scoring or not, so you know what
		# playing it will set off.
		var names: Array = []
		for id in trail.equipped_on(String(result.get("name", ""))):
			names.append(Abilities.ability_name(id).to_upper())
		if not names.is_empty():
			parts += "  ·  " + ", ".join(PackedStringArray(names))
	return parts


func _update_preview() -> void:
	if menu_open or not game_started:
		preview_label.text = ""
		return
	if game_over:
		preview_label.text = "R — play again    M — menu"
		preview_label.add_theme_color_override("font_color", DIM)
		return
	var data := board.get_selected_data()
	if board.blackjack_target > 0:
		if data.is_empty():
			if board.blackjack_presenting or not board.blackjack_hole_hidden:
				preview_label.text = "The dealer plays out his hand…"
			else:
				preview_label.text = "Dealer shows %d. Start from a face-up card and hit one card at a time. Go over 21 and you bust right away." % board.blackjack_target
			preview_label.add_theme_color_override("font_color", DIM)
		else:
			var total := Poker.blackjack_sum(data)
			if total == 21:
				preview_label.text = "TWENTY-ONE! Play it!"
				preview_label.add_theme_color_override("font_color", GOLD)
			else:
				preview_label.text = "You have %d against the dealer's %d. Hit again (no take-backs) or play the hand to stand." % [total, board.blackjack_target]
				preview_label.add_theme_color_override("font_color", GOLD)
		return
	if not board.holdem_community.is_empty():
		if data.size() != 2:
			preview_label.text = "Pick exactly TWO touching hole cards. With the community, your best 5 of 7 count."
			preview_label.add_theme_color_override("font_color", DIM)
		else:
			var best := board.holdem_result()
			if best.is_empty():
				preview_label.text = "There's no hand in those seven. Try different hole cards."
				preview_label.add_theme_color_override("font_color", RED)
			else:
				var shown: Dictionary = best.duplicate()
				board._apply_card_mods(shown)
				preview_label.text = "%s  —  %d pts%s" % [shown.name, shown.score,
						_preview_mod_text(shown)]
				preview_label.add_theme_color_override("font_color", GOLD)
		return
	if data.is_empty():
		preview_label.text = "Chain up to 5 adjacent cards to build a poker hand."
		preview_label.add_theme_color_override("font_color", DIM)
	else:
		for card in board.selected:
			if card.is_safe:
				preview_label.text = "COMBINATION SET! Play the hand to crack the safe."
				preview_label.add_theme_color_override("font_color", GOLD)
				return
		for card in board.selected:
			if card.washed:
				preview_label.text = "???  A filled card is hiding what this hand is worth."
				preview_label.add_theme_color_override("font_color", GOLD)
				return
		var result := Poker.evaluate(data)
		if result.playable and not board.hand_allowed(String(result.name)):
			preview_label.text = "This table only takes %s." % TableMods.join_and(Array(board.play_only))
			preview_label.add_theme_color_override("font_color", RED)
			return
		if result.playable and not board.hand_scores(String(result.name)):
			board._apply_card_mods(result)
			preview_label.text = "A %s plays here, but it won't score. Only %s count.%s" % [
					result.name, TableMods.join_and(Array(board.score_only)), _preview_mod_text(result)]
			preview_label.add_theme_color_override("font_color", RED)
			return
		if result.playable:
			board._apply_card_mods(result)
			preview_label.text = "%s  —  %d pts   (base %d + pips %d%s)" % \
					[result.name, result.score, result.base, result.pips,
					_preview_mod_text(result)]
			preview_label.add_theme_color_override("font_color", GOLD)
		elif result.name == "High Card":
			preview_label.text = "High Card won't play. You need at least a Pair."
			preview_label.add_theme_color_override("font_color", RED)
		else:
			preview_label.text = "Not a hand. Every card you pick has to be part of it."
			preview_label.add_theme_color_override("font_color", RED)


func _on_hand_played(result: Dictionary) -> void:
	score += result.score
	hands_played += 1
	if result.score > 0:
		# The score plate feels the win.
		score_label.pivot_offset = Vector2(score_label.size.x / 2.0, 24.0)
		if _score_pop_tween and _score_pop_tween.is_valid():
			_score_pop_tween.kill()
		score_label.scale = Vector2.ONE
		_score_pop_tween = create_tween()
		_score_pop_tween.tween_property(score_label, "scale",
				Vector2(1.14, 1.14), 0.08).set_trans(Tween.TRANS_QUAD)
		_score_pop_tween.tween_property(score_label, "scale", Vector2.ONE, 0.18) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if int(result.get("base", 0)) >= 900:
		shake(5.0)
	if mode_kind != "tutorial":
		# The ledger remembers everything.
		stat_bump("hands_played")
		stat_bump("cards_popped", int(result.get("count", 0)))
		stat_max("best_hand", int(result.score))
		if result.get("playable", false) and not result.has("blackjack_outcome"):
			stat_hand(String(result.name))
	_announce("%s  +%d" % [String(result.name).to_upper(), result.score])
	# The wagon rolls on: the scenery surges with every scored hand.
	parallax.lurch(1.0 + result.get("count", 0) * 0.15)
	if result.get("base", 0) >= 1200:
		board.confetti()  # straight flush or better earns the parade
		board._play_sound(Board.SFX_COINS.pick_random(), 1.0, -7.0, 0.25)
		# The saloon erupts — the closest thing the trail has to a
		# Candy Crush announcer.
		board._play_sound(Board.SFX_LAUGHS.pick_random(), 1.0, -8.0, 0.35)
	if mode_kind == "tutorial":
		_tut_on_hand(result)
		return
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
	board.confetti()
	while board.busy:
		await get_tree().process_frame
	if not game_started or mode_kind != "arcade":
		level_transition = false
		return
	level += 1
	board.rng = SeedRng.stream(mode_seed, "board", level)
	level_score = 0
	meter = 100.0
	parallax.set_scene("plains", level)
	board.reset()
	level_transition = false
	_begin_countdown()


func _on_dead_board() -> void:
	if game_over or not game_started:
		return
	if mode_kind in ["arcade", "trail", "tutorial"]:
		# These modes never dead-end: reshuffle the board and keep going.
		_announce("NO MOVES — RESHUFFLE")
		board.shuffle_board()
		if mode_kind == "tutorial":
			_tut_apply_step()  # re-stamp the lesson after the shuffle
		return
	game_over = true
	board.locked = true
	var msg: String
	if mode_kind == "single":
		stat_bump("single_games")
		stat_max("single_best", score)
		if board.grid.is_empty():
			stat_bump("perfect_clears")
			msg = "PERFECT CLEAR\n\nYou played out the entire deck!\nFinal score: %d" % score
		else:
			msg = "OUT OF HANDS\n\nThe deck's used up, so that's the game.\nFinal score: %d" % score
	else:
		msg = "DEAD BOARD\n\nThere are no playable hands left, so the game's over.\nFinal score: %d" % score
	_show_game_over(msg + "\n\nR — play again    M — menu")


func _show_game_over(message: String) -> void:
	_stats_save()
	var seed_msg := _record_mode_score()
	# Let the last pop/refill animation play out before covering the board.
	await get_tree().create_timer(1.4, false).timeout
	if not game_over or menu_open:
		return
	over_label.text = message
	if mode_seed != "":
		over_label.text += "\n\nSeed  %s" % SeedRng.pretty(mode_seed)
		if seed_msg != "":
			over_label.text += "   ·   " + seed_msg
		if _rank_line != "":
			over_label.text += "\n" + _rank_line
	over_layer.modulate = Color(1, 1, 1, 0)
	over_layer.visible = true
	create_tween().tween_property(over_layer, "modulate:a", 1.0, 0.4)


## The board this mode game's score belongs to.
func mode_board_key() -> String:
	var variant := str(int(mode_time)) if mode_kind == "time" else ""
	return SeedBook.key(mode_kind, mode_seed, variant)


## Logs this game on its seed's board; returns the line for the end card.
func _record_mode_score() -> String:
	if mode_seed == "" or mode_kind in ["trail", "tutorial", ""] or score <= 0 or _mode_scored:
		return ""
	_mode_scored = true  # once a game, however it ends
	var k := mode_board_key()
	var pb := seed_book.record(k, score, {"level": level})
	seed_score_recorded(k, score, "", 0, 0)
	return "NEW SEED BEST!" if pb else "Best on this seed: %d" % seed_book.best(k)


## A row of twist chips for a table: the kit's pill with the twist's icon
## and name, its rule as the tooltip. Plain text pills without the kit.
func twist_chips(offer: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill := CardArt.nine_half("ui", "twist_chip", [32, 16, 24, 16])
	for tw in offer.get("twists", []):
		var chip := PanelContainer.new()
		if pill != null:
			var sb: StyleBoxTexture = pill.duplicate()
			sb.content_margin_left = 4
			sb.content_margin_right = 12
			chip.add_theme_stylebox_override("panel", sb)
		else:
			chip.add_theme_stylebox_override("panel", UiKit.inset_box())
		chip.tooltip_text = TableMods.twist_desc(tw)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		var inner := HBoxContainer.new()
		inner.add_theme_constant_override("separation", 6)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(inner)
		var icon := CardArt.tex("twist_icon", String(tw.get("id", "")))
		if icon != null:
			var ir := TextureRect.new()
			ir.texture = icon
			ir.custom_minimum_size = Vector2(26, 26)
			ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(ir)
		var name := TableMods.twist_name(tw).to_upper()
		if String(tw.get("id", "")) == "wild" and int(tw.get("rank", 0)) <= 10:
			name = "WILD %ds" % int(tw.rank)
		var l := Label.new()
		l.text = name
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", GOLD)
		if FontLib.label != null:
			l.add_theme_font_override("font", FontLib.label)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(l)
		row.add_child(chip)
	return row


## Every finished game's board score passes through here, on its way to
## the online board (a no-op until SupabaseConfig holds keys).
func seed_score_recorded(k: String, value: int, rider: String, asc: int, tables: int) -> void:
	var parts := k.split("|")
	_rank_key = k
	_rank_score = value
	_rank_line = ""
	leaderboard.submit({"board_key": k, "mode": parts[0], "seed": parts[1],
			"variant": parts[2] if parts.size() > 2 else "",
			"player_id": seed_book.ensure_player(), "player_name": seed_book.display_name(),
			"score": value, "rider": rider, "ascension": asc, "tables": tables})


func _on_board_submitted(k: String, ok: bool) -> void:
	if ok and k == _rank_key:
		leaderboard.fetch_rank(k, _rank_score)


## The posted game's place on its seed's online board, onto its end card.
func _on_board_ranked(k: String, rank: int, _of: int) -> void:
	if k != _rank_key:
		return
	_rank_line = "#%d on this seed's online board" % rank
	if trail.end_layer.visible and trail._gameover_scene != null:
		trail._gameover_scene.add_online_line(_rank_line)
	elif over_layer.visible:
		over_label.text += "\n" + _rank_line
	if seeds_layer.visible and _shown_board_key == k:
		_shown_board_key = ""
		_refresh_seeds()


func _restart() -> void:
	if mode_kind == "trail" or mode_kind == "tutorial":
		return  # no free room retries at a betting table
	if not game_started or board.busy or level_transition:
		return
	score = 0
	_mode_scored = false
	hands_played = 0
	time_left = mode_time
	level = 1
	level_score = 0
	meter = 100.0
	game_over = false
	over_layer.visible = false
	if not _mode_seed_fixed or mode_seed == "":
		mode_seed = SeedRng.random_seed()
	board.rng = SeedRng.stream(mode_seed, "board", 1)
	mode_label_text = "%s · Seed %s" % [_mode_label_base, SeedRng.pretty(mode_seed)]
	match mode_kind:
		"arcade":
			parallax.set_scene("plains", level)
		"time":
			parallax.set_scene("canyon")
		"single":
			parallax.set_scene("homestead")
		"zen", "tutorial":
			parallax.set_scene("stars")
	board.visible = true
	board.reset()
	_begin_countdown()


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


# The jukebox: every area names its playlist, one random track plays
# looped until another area asks for a different playlist.
const MUSIC_TRACKS := {
	"menu": ["res://assets/music/under_the_sun.mp3"],
	"room": ["res://assets/music/hand_on_the_gun.mp3",
			"res://assets/music/bulletstorm.mp3",
			"res://assets/music/riding_all_day_long.mp3",
			"res://assets/music/hard_times.mp3",
			"res://assets/music/paramo.mp3"],
	"boss": ["res://assets/music/last_duel.mp3",
			"res://assets/music/heat_and_snakes.mp3"],
	"tarot": ["res://assets/music/thankful_town.mp3"],
	"shop": ["res://assets/music/bar_ragtime.mp3",
			"res://assets/music/saloon_can_can.mp3"],
	"lost": ["res://assets/music/tears_for_our_lands.mp3",
			"res://assets/music/harmonica_moments.mp3"],
}
# A quiet ambience bed under the music, keyed by the same categories:
# saloon chatter in shops, town sounds between rooms, wilderness at
# the tables, night sounds for bosses and losses.
const AMB_TRACKS := {
	"menu": "res://assets/music/amb/town_day.mp3",
	"room": "res://assets/music/amb/wild_day.mp3",
	"boss": "res://assets/music/amb/wild_night.mp3",
	"tarot": "res://assets/music/amb/town_night.mp3",
	"shop": "res://assets/music/amb/saloon.mp3",
	"lost": "res://assets/music/amb/night_camp.mp3",
}
const AMBIENCE_DB := -22.0
var music_category := ""


## Swaps the jukebox to an area's playlist (random track, looped) and
## fades it in, with the matching ambience bed underneath. Asking for
## the playlist already playing is a no-op.
func play_music(category: String) -> void:
	if category == music_category and music.playing:
		return
	music_category = category
	var track: AudioStreamMP3 = load(MUSIC_TRACKS[category].pick_random())
	track.loop = true
	music.stop()
	music.stream = track
	_fade_in(music)
	var amb: AudioStreamMP3 = load(AMB_TRACKS[category])
	amb.loop = true
	ambience.stop()
	ambience.stream = amb
	_fade_in(ambience, AMBIENCE_DB)


func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
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
	profile = clampi(int(cf.get_value("profile", "current", 1)), 1, 3)
	# Test runs boot straight onto a throwaway profile (never saved).
	if OS.get_environment("POKERPOP_PROFILE") != "":
		profile = int(OS.get_environment("POKERPOP_PROFILE"))
	_migrate_legacy_saves()
	_tutor_load()
	_stats_load()
	seed_book.load_file(profile_path("seeds.cfg"))
	fullscreen_on = cf.get_value("video", "fullscreen", true)
	res_index = clampi(cf.get_value("video", "resolution", 2), 0, RESOLUTIONS.size() - 1)
	music_vol = clampf(cf.get_value("audio", "music", 0.8), 0.0, 1.0)
	# The UI style is read before any chrome is built (POKERPOP_UI for shots).
	var ui_style := String(cf.get_value("video", "ui_style", "classic"))
	if OS.get_environment("POKERPOP_UI") != "":
		ui_style = OS.get_environment("POKERPOP_UI")
	UiKit.setup(ui_style)
	sfx_vol = clampf(cf.get_value("audio", "sfx", 0.8), 0.0, 1.0)
	_apply_video()
	_apply_audio()


# --- Profile stats: the Ledger ---------------------------------------------

## Lifetime numbers for the active profile: counters, records, and a
## tally of every poker hand ever scored. Saved to pN_stats.cfg at
## natural break points (game over, menu, trail milestones).
var stats := {}
var stats_hands := {}
var _stats_dirty := false


func stat_bump(key: String, n := 1) -> void:
	stats[key] = int(stats.get(key, 0)) + n
	_stats_dirty = true


func stat_max(key: String, v: int) -> void:
	if v > int(stats.get(key, 0)):
		stats[key] = v
		_stats_dirty = true


func stat_hand(hand_name: String) -> void:
	stats_hands[hand_name] = int(stats_hands.get(hand_name, 0)) + 1
	_stats_dirty = true


func _stats_load() -> void:
	stats = {}
	stats_hands = {}
	_stats_dirty = false
	var cf := ConfigFile.new()
	if cf.load(profile_path("stats.cfg")) != OK:
		return
	if cf.has_section("stats"):
		for key in cf.get_section_keys("stats"):
			stats[key] = cf.get_value("stats", key, 0)
	if cf.has_section("hands"):
		for key in cf.get_section_keys("hands"):
			stats_hands[key] = cf.get_value("hands", key, 0)


func _stats_save() -> void:
	if not _stats_dirty or OS.get_environment("POKERPOP_SHOT") != "":
		return
	_stats_dirty = false
	var cf := ConfigFile.new()
	for key in stats:
		cf.set_value("stats", key, stats[key])
	for key in stats_hands:
		cf.set_value("hands", key, stats_hands[key])
	cf.save(profile_path("stats.cfg"))


# --- Profiles -------------------------------------------------------------

## Per-profile save path: user://p1_trail_meta.cfg and friends.
func profile_path(base: String) -> String:
	return "user://p%d_%s" % [profile, base]


## Saves from before profiles existed become profile 1.
func _migrate_legacy_saves() -> void:
	for base: String in ["trail_meta.cfg", "trail_run.cfg"]:
		var old_path := "user://" + base
		var new_path := "user://p1_" + base
		if FileAccess.file_exists(old_path) and not FileAccess.file_exists(new_path):
			DirAccess.rename_absolute(old_path, new_path)


func _select_profile(n: int) -> void:
	profile = clampi(n, 1, 3)
	_save_settings()
	_tutor_load()
	_stats_load()
	seed_book.load_file(profile_path("seeds.cfg"))
	trail.run_active = false
	trail.pending_retry = {}
	trail._load_meta()
	_refresh_profile_ui()
	_refresh_level_plate()
	profile_layer.visible = false


func _erase_profile(n: int) -> void:
	for base in ["trail_meta.cfg", "trail_run.cfg", "tutorial.cfg", "stats.cfg", "seeds.cfg"]:
		DirAccess.remove_absolute("user://p%d_%s" % [n, base])
	if n == profile:
		_tutor_load()
		_stats_load()
		seed_book.load_file(profile_path("seeds.cfg"))
		trail.run_active = false
		trail.pending_retry = {}
		trail._load_meta()
	_refresh_profile_ui()
	_refresh_level_plate()


## One line of life per slot for the picker.
func _profile_summary(n: int) -> String:
	var cf := ConfigFile.new()
	var has_meta := cf.load("user://p%d_trail_meta.cfg" % n) == OK
	var cash := int(cf.get_value("meta", "cash", 0)) if has_meta else 0
	var run := ConfigFile.new()
	var riding: bool = run.load("user://p%d_trail_run.cfg" % n) == OK \
			and run.get_value("run", "active", false)
	if not has_meta and not FileAccess.file_exists("user://p%d_tutorial.cfg" % n):
		return "PROFILE %d\n\nnot started yet" % n
	var lv := Progression.level_for_exp(int(cf.get_value("progress", "exp", 0))) \
			if has_meta else 1
	return "PROFILE %d\n\nLevel %d  ·  $%d banked%s" % [n, lv, cash,
			"\nride in progress" if riding else ""]


func _refresh_profile_ui() -> void:
	if _profile_menu_btn != null:
		_profile_menu_btn.text = "PROFILE %d" % profile
	for i in _profile_slot_btns.size():
		var b: Button = _profile_slot_btns[i]
		b.text = _profile_summary(i + 1)
		b.disabled = (i + 1) == profile


# --- Board hover tooltip ---------------------------------------------------

## Touch input passes the detail sheet first: a held finger opens it,
## and the tap that closes it goes no further.
func _input(event: InputEvent) -> void:
	if _detail != null and Form.is_touch() and _detail.handle(event):
		get_viewport().set_input_as_handled()


## The words for whatever is under a held finger: the card's tooltip on
## the board, else the deepest control's tip (or its "detail" meta).
func detail_text_at(at: Vector2) -> String:
	if game_started and not menu_open and board.visible and not board.locked:
		var card := board.card_at(at, true)
		if card != null:
			return _card_tooltip_text(card)
	var c := _tip_control_at(ui_root, at)
	while c != null:
		if c.has_meta("detail"):
			return String(c.get_meta("detail"))
		if c.tooltip_text != "":
			return c.tooltip_text
		c = c.get_parent() as Control
	return ""


## A hold that opened the detail sheet shouldn't also pick the card the
## finger came down on: take it back out of the chain.
func cancel_touch_select(at: Vector2) -> void:
	if board == null:
		return
	var card := board.card_at(at, true)
	board.dragging = false
	if card != null and not board.selected.is_empty() and board.selected.back() == card:
		board._toggle_select(card)


## A rotation that changes the form factor rebuilds every screen for the
## new shape: the ride is saved and picked straight back up.
func _on_window_resized() -> void:
	if Form.override() != "":
		return
	if Form.choose(Vector2(get_window().size)) == Form.current:
		return
	if trail != null and trail.run_active:
		trail._save_run()
	get_tree().reload_current_scene.call_deferred()


func _update_tooltip(delta: float) -> void:
	if _tooltip == null:
		return
	var can := game_started and not menu_open and not game_over \
			and not get_tree().paused and not board.busy and not board.locked \
			and not help_blocking()
	var card: PlayingCard = board._card_under_mouse(true) if can else null
	if card != _hover_card:
		if _hover_card != null and is_instance_valid(_hover_card):
			_hover_card.hovered = false
		if card != null:
			card.hovered = true
			if not card.selected:
				# A whisper of cardboard as the cursor crosses it.
				board._play_sound(Board.SFX_CLICK, 1.7, -30.0)
		_hover_card = card
		_hover_time = 0.0
		_tooltip.visible = false
		return
	if card == null or _tooltip.visible:
		return
	_hover_time += delta
	if _hover_time < 0.35:
		return
	_tooltip_label.text = _card_tooltip_text(card)
	_tooltip.reset_size()
	var mp := ui_root.get_global_mouse_position()
	var tip_size := _tooltip.get_combined_minimum_size()
	_tooltip.position = Vector2(
			clampf(mp.x + 26.0, 0.0, VIEW.x - tip_size.x - 10.0),
			clampf(mp.y + 22.0, 0.0, VIEW.y - tip_size.y - 10.0))
	_tooltip.visible = true


## Hover tips for every button and panel (kit, abilities, shelves,
## the Outfitter...): the control's tooltip_text in the card tooltip's
## chrome, wrapped to a readable width. Godot's own tooltip popup is
## switched off (gui/timers/tooltip_delay_sec in project.godot).
const UI_TIP_DELAY := 0.4
const UI_TIP_WRAP := 360.0
var _ui_tip: PanelContainer
var _ui_tip_label: Label
var _ui_tip_src: Control
var _ui_tip_time := 0.0
var _ui_tip_force: Control  # screenshots: the control to tip as if hovered
var _detail: DetailSheet     # touch: the long-press stand-in for hover tips


## The deepest visible control with a tooltip under `at` (screenshots).
func _tip_control_at(node: Node, at: Vector2) -> Control:
	var found: Control = null
	for child in node.get_children():
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		var deeper := _tip_control_at(child, at)
		if deeper != null:
			found = deeper
		elif child is Control and (child as Control).tooltip_text != "" 				and (child as Control).get_global_rect().has_point(at):
			found = child
	return found


func _build_ui_tip() -> void:
	_ui_tip = PanelContainer.new()
	_ui_tip.add_theme_stylebox_override("panel", UiKit.tooltip_box())
	_ui_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_tip.visible = false
	_ui_tip.z_index = 100
	_ui_tip_label = Label.new()
	_ui_tip_label.add_theme_font_size_override("font_size", 18)
	if FontLib.body != null:
		_ui_tip_label.add_theme_font_override("font", FontLib.body)
	_ui_tip_label.add_theme_color_override("font_color", OFFWHITE)
	_ui_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_tip.add_child(_ui_tip_label)
	ui_root.add_child(_ui_tip)


func _update_ui_tip(delta: float) -> void:
	if _ui_tip == null:
		return
	var c := _ui_tip_force if _ui_tip_force != null else get_viewport().gui_get_hovered_control()
	var text := ""
	if c != null and c.is_visible_in_tree():
		text = c.tooltip_text
	if c != _ui_tip_src:
		_ui_tip_src = c
		_ui_tip_time = 0.0
		_ui_tip.visible = false
		return
	if text == "":
		_ui_tip.visible = false
		return
	if _ui_tip.visible:
		if _ui_tip_label.text != text:
			_show_ui_tip(text)  # the tip changed under the cursor (kit states)
		return
	_ui_tip_time += delta
	if _ui_tip_time >= UI_TIP_DELAY:
		_show_ui_tip(text)


func _show_ui_tip(text: String) -> void:
	# Short tips sit on one line; long ones wrap at UI_TIP_WRAP.
	var font: Font = _ui_tip_label.get_theme_font("font")
	var natural := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 18).x
	var w := minf(ceilf(natural) + 2.0, UI_TIP_WRAP)
	_ui_tip_label.text = text
	_ui_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ui_tip_label.custom_minimum_size = Vector2(w, 0)
	# Lay the label out at its real width first, so the wrapped height
	# is measured right (a zero width wraps every letter).
	_ui_tip_label.size = Vector2(w, 0)
	_ui_tip.move_to_front()
	_ui_tip.visible = true
	_fit_ui_tip()
	_fit_ui_tip.call_deferred()


func _fit_ui_tip() -> void:
	_ui_tip.reset_size()
	var mp := ui_root.get_global_mouse_position()
	var tip_size := _ui_tip.size
	_ui_tip.position = Vector2(
			clampf(mp.x + 18.0, 0.0, VIEW.x - tip_size.x - 10.0),
			clampf(mp.y + 24.0, 0.0, VIEW.y - tip_size.y - 10.0))


## Everything the hovered card is, in one small panel: its name, then
## one short "NAME — fact" line per thing on it. The long explanations
## live in the first-time tutorials and the Almanac.
func _card_tooltip_text(card: PlayingCard) -> String:
	if card.is_safe:
		return "THE SAFE\nPick its combination in order, then the safe."
	if card.hazard == "stone":
		var tip := "STONE\nThere's a card buried under this rock.\nClear cards next to it to chip it.\n%d more chip%s breaks it off." \
				% [card.stone_hits, "" if card.stone_hits == 1 else "s"]
		if card.stone_gold and card.stone_hits <= 1:
			tip += "\nThere's gold showing in the crack!"
		return tip
	if card.snake_tail:
		return "COBRA TAIL\nA wall you have to chain around.\nEach hit on his head crumbles one piece."
	if card.face_down:
		return "FACE DOWN\nSelect it to hit. Go over 21 and you bust."
	var rank_names := {11: "Jack", 12: "Queen", 13: "King", 14: "Ace"}
	var lines: Array[String] = []
	if card.washed:
		lines.append("FILLED: its face is hidden. Pours every hand.")
	elif card.joker:
		lines.append("The Joker")
	elif card.cursed:
		lines.append("A cursed card")
	else:
		lines.append("%s of %s" % [rank_names.get(card.rank, str(card.rank)),
				PlayingCard.SUIT_NAMES[card.suit]])
	match card.boss:
		"jack":
			lines.append("JACK: %d left. Hands that beat %d wound him." % [card.boss_hp, board.jack_bar])
		"queen":
			lines.append("QUEEN: %d left. Moves each turn, leaving honey." % card.boss_hp)
		"cobra":
			lines.append("COBRA: %d left. Score hands that use his head." % card.boss_hp)
	match card.hazard:
		"bomb":
			lines.append("BOMB: goes off in %d hand%s. Play it to defuse." % [card.fuse,
					"" if card.fuse == 1 else "s"])
		"fire":
			lines.append("FIRE: spreads and lowers its rank. Play to douse.")
		"wind":
			lines.append("WIND: blows off a card each hand. Play to stop it.")
		"water":
			lines.append("WATER: %d/4 full. Pours when full. Play to clear." % card.water_level)
	if card.incoming != "":
		lines.append("NEXT IN LINE: the %s hits this card next." % card.incoming.to_lower())
	if card.honey:
		lines.append("HONEY: only 1 card can follow it in a chain.")
	if card.cursed:
		lines.append("CURSED: it can't be played and it blocks chains. A Bumper can shove it off the edge, or the wind can blow it away. It's only dealt once a table. Burn it at a forge or cast it off at a campfire to get rid of it for good.")
	if card.joker:
		lines.append("JOKER: wild, and doubles the hand's score.")
	match card.mod:
		"chip":
			lines.append("CASH: +$%d trail cash when you play it. Pays more each time it scores." % (board.chip_bonus * (1 + card.chip_level)))
		"mult":
			lines.append("MULT: ×%.1f to the hand's score." % board.mult_factor)
		"gold":
			lines.append("GOLD: +$%d trail cash when you play it." % board.gold_pay)
		"plus":
			lines.append("PLUS: +1 rank to the card it points at.")
		"minus":
			lines.append("MINUS: −1 rank to its target. A 2 breaks.")
		"bumper":
			lines.append("BUMPER: shoves the line it points at.")
		"wild":
			if not card.joker:
				lines.append("WILD: counts as any rank and any suit.")
	if PlayingCard.wild_rank > 0 and card.rank == PlayingCard.wild_rank and not card.washed:
		lines.append("WILD RANK: wild at this table.")
	match card.finish:
		"holo":
			lines.append("HOLO: +%d to the hand, before multipliers." % board.holo_bonus)
		"negative":
			lines.append("NEGATIVE: score it and you get the hand back.")
		"prism":
			lines.append("PRISM: spreads its enhancement when cleared.")
		"metal":
			if card.metal_covered():
				lines.append("METAL: stays when scored. Hazard-proof. %d/%d pins." \
						% [PlayingCard.METAL_PINS - card.metal_wear, PlayingCard.METAL_PINS])
			else:
				lines.append("METAL: cover's off, so it clears on its next play.")
	match card.objective:
		"key":
			lines.append("KEY: score it in the same hand as the chest.")
		"chest":
			lines.append("CHEST: score it in the same hand as the key.")
		"bullet":
			lines.append("YOUR BULLET: score it to take a shot.")
		"hisbullet":
			lines.append("HIS BULLET: clear it and he shoots you (−1 HP).")
	return "\n".join(lines)


# --- First-time tutorials (per profile) ------------------------------------

const TUTOR := {
	"levels": ["LEVELS & UNLOCKS", "Every ride's score turns into EXP, win or bust, and each level unlocks ONE new thing for the trail: a relic, a provision, a card, a trick or a merchant. Merchants show up on the trail right away. Everything else has to be BOUGHT at the Outfitter (UPGRADES) before it starts turning up. New RIDERS can't be bought, only won: finish the trail as the Gambler to unlock the Machine, and as the Machine to unlock the Doctor. Beat the trail with a rider to open the next ASCENSION level for them, up to 20. You can upgrade the things you own, too. FIND makes them turn up more often, and POWER makes them stronger. Every level-up also pays a small purse, and the CONTRACTS on the menu pay cash when you meet their goals."],
	"mode_time": ["TIME TRIAL", "Score as much as you can before the clock runs out. Hands are unlimited and the deck keeps reshuffling, so speed is everything."],
	"mode_single": ["SINGLE DECK", "One 52-card deck and no timer. When the deck runs out, the game's over, so get every point you can out of every card."],
	"mode_arcade": ["ARCADE", "The bar on the right is always draining. Scoring fills it back up, and reaching the level target moves you up a level. When the bar runs empty, the game ends."],
	"mode_zen": ["ZEN", "No timer, no limits, no losing. Just you, the cards, and the sound of the pops."],
	"mode_trail": ["THE TRAIL", "A ride of 21 tables over 30 stops. Every region has two merchants and a campfire along the road, and a boss at the end. Tables are free to sit, and each one you clear pays TRAIL CASH. Safes, chests and bounties pay more, and so do Cash and Gold cards. Spend it at the merchants. Whatever trail cash you're holding only comes home if you RIDE TO THE END. Lose your HP and it's gone. Before you set out, you can also bring cash from the bank and bet on how far you'll get."],
	"combine": ["COMBINING ABILITIES", "You have two copies of the same ability. Open the ABILITIES screen, click one, and press COMBINE. The two become one card a level up (II, then III): its numbers grow, its rarity goes up a step, and it only takes one card's slots. A combined card also counts as two members of its posse, or three at level III, so your posse never shrinks. Only copies at the same level combine."],
	"the_bet": ["THE BET", "You can ride for free, or put some of your bank on the line. BRING CASH to spend at the merchants: it's yours again only if you finish the trail. Or BET on how far you'll get. Pick the Jack, the Queen, or King Cobra, and the further you go, the better the odds. A winning bet goes straight to the bank the moment that boss falls, so it's safe even if the trail gets you later."],
	"hazard_bomb": ["BOMB CARD", "The number on the fuse drops after every hand you score. Play the bomb in any hand to defuse it. If the fuse reaches zero, it goes off. The bomb is gone and the blast costs you 2 HP."],
	"hazard_fire": ["FIRE CARD", "After every hand, the fire spreads to one card next to it, and the fire card's own rank burns down. The card it'll catch next shows SPARKS along its bottom edge, so clear that card out of the way or play the fire card to douse it. If EVERY card on the table catches fire, you LOSE the table."],
	"hazard_wind": ["WIND CARD", "After every hand, the wind BLOWS the first card in the direction it's facing right off the board. That card doesn't score; it's just gone. The wind turns a quarter turn every hand, and the dust streaming across the card shows which way it's blowing. Play the wind card to make it stop."],
	"hazard_stone": ["STONE CARD", "A card buried under solid rock. While it's covered, you can't play it or chain through it. Every card you clear NEXT TO it chips the rock, and after three chips the stone breaks off and the card underneath is back in play. Sometimes that card is GOLD. When it is, you'll see a gold vein in the last crack."],
	"hazard_water": ["WATER CARD", "The leak FILLS its card a quarter of the way every hand. Once it's full, it POURS, turning the four cards around it into WATER CARDS that fill up and pour in turn. A full card hides its face completely, but it's still the same card underneath, if you can remember what it was. Play any water card, however full, to clear it."],
	"goal_safe": ["THE SAFE", "A locked safe sits on the board showing a 4-digit combination. Pick cards with those exact ranks IN ORDER, then the safe itself, and play the hand to crack it open."],
	"goal_chest": ["KEY & CHEST", "The stage runs on a SCHEDULE: you get unlimited hands, but the clock is ticking. Get the key and the chest into one valid scoring hand to open the chest. Each time you open one, a new key and chest appear, until you've opened enough. If you clear one piece WITHOUT the other, it just turns up again on a different card, and that hand is wasted. It's the hardest job on the trail, but the strongbox holds a RELIC."],
	"goal_purge": ["PURGE TABLE", "There's no score target here. The board is overrun with hazards, and they KEEP COMING. A few are dealt in at the start and more show up as you play. Clear the full quota to finish the job, any way you like: play them, let the wind blow them off, or let them burn out."],
	"goal_mine": ["GOLD MINE", "The board is packed with stone, and the seam runs 16 stones deep. Chip a stone by clearing cards NEXT TO it, and three chips breaks it off. Every stone has a card underneath, and some of those cards are GOLD. More stones drop in with the deal until the whole seam is on the table. Mine it DRY: the table only clears once every last stone is broken."],
	"goal_hands": ["DEALER'S CALL", "The dealer names the exact hands you have to play, and nothing else counts toward the goal. It has to be an exact match: a Full House doesn't count as three Pairs."],
	"goal_timed": ["ON THE CLOCK", "This table runs on TIME, not hands. Play as many hands as you like, but get the job done before the countdown runs out. The clock is in the side panel, and when it turns red, hurry."],
	"boss_jack": ["JACK OF ALL TRADES", "The Jack wears a new face every hand. Whenever cards are scored, he turns into a different card and jumps to a new spot. Catch him in a scoring hand that BEATS HIS BAR and the hand's WHOLE SCORE comes off his total, but the bar goes up with every hit. Deal 2,000 in all to put him away (more on higher Ascensions)."],
	"boss_queen": ["QUEEN BEE", "The Queen has a 2,400 SCORE pool (bigger on higher Ascensions), and every hand she's in takes its score out of it. She never sits still, though. Each turn she moves to a new space and leaves HONEY where she walked. A honeyed card can go in any hand, but once one joins your chain, only ONE more card can follow it, so big hands get harder to build."],
	"boss_cobra": ["KING COBRA", "King Cobra has a 5,000 SCORE pool (bigger on higher Ascensions), and every hand that includes his head takes its score out of it. Each hit stuns him and breaks off the tip of his tail. Every hand, he EATS a card next to him and takes its face. His tail is a wall you have to chain around."],
	"goal_holdem": ["TEXAS HOLD'EM", "Five COMMUNITY cards sit in the panel for the whole table. Each hand, chain exactly TWO touching hole cards, and your hand is the best five of those seven. Reach the score target to clear the table. Sometimes a RE-DEAL card shows up: play it to get a fresh set of community cards."],
	"goal_crazy8": ["A WILD RANK", "One rank is WILD at this table, and every card of that rank counts as any rank and suit. The wild cards wear a purple W. Score tables ask a quarter more to make up for it, so lean on the wild cards to build big hands."],
	"twists": ["TWISTS", "Some tables come with TWISTS: extra rules stacked on top of the table's job, listed under its goal. A twist might put hazards on the table, make a rank wild, shorten your hands, or limit which hands count. Every twist makes the table harder, and every one raises the odds it pays. Hover over a table on the trail to read its twists."],
	"twist_hands": ["HAND RULES", "This table limits your hands. With HOUSE RULES, only the listed hands can be played at all. With a PICKY CROWD, any hand plays, but only the listed ones add to your score. Cash and Gold cards in the others still pay. The list is under the score bar at the top."],
	"goal_blackjack": ["BLACKJACK", "Poker's off tonight. You're playing the house at a table dealt FACE DOWN, with only the four corners showing. Start a chain from a face-up card, then HIT one card at a time. Each face-down card you select flips over ON THE SPOT and its pips add to your total (face cards count 10, aces 11 or 1). Hits are final, with no clearing and no take-backs, and if a flip takes you over 21 you BUST right there. Press PLAY HAND to stand: the dealer flips his hole card and draws until he beats you or busts. Every hand turns another random card face up. Win enough rounds to clear the table."],
	"goal_outlaw": ["THE BOUNTY", "A wanted gunman has taken over this table. Clear YOUR bullets (gold) in scoring hands to shoot at him. HIS bullets (red) are trouble waiting to happen: clear a card carrying one and he SHOOTS you, so build your hands AROUND them. A hand that scores under the posted number gives him a free shot too. Some outlaws ride with a gang, and when you drop one, the next steps up fresh. Every shot he lands costs HP, and if you run out, the ride is over."],
	"campfire": ["THE CAMPFIRE", "A rest stop on the trail. Pick ONE of three things. REST lets you sleep off the road and get HP back. TEND A CARD gives a plain card in your deck a random enhancement. CAST ONE OFF burns a card out of your deck for good. Then the fire dies down and it's back to the trail."],
	"hp": ["YOUR HIDE", "The trail can hurt you now. A fire card that burns all the way down burns you, a bomb going off blasts you, every outlaw bullet costs you, and losing a table leaves a mark. The red pips under your score are all that stand between you and a shallow grave. Campfires along the trail patch you up."],
	"goal_collect": ["THE ROUNDUP", "This table wants particular cards: a number of one SUIT, a stack of one RANK, or cards of many DIFFERENT ranks. Only cards you actually clear in scoring hands count, and the banner keeps the tally."],
	"goal_landrush": ["LAND RUSH", "Stake a claim on every plot by clearing a card from each of the 25 spaces. A claimed plot gets a gold ring. Claim the whole homestead to win the table."],
	"loot_chest": ["KEY & CHEST", "Surprise loot! Get the key and the chest into one valid scoring hand to claim it. The chest opens once you CLEAR THE TABLE, and it might hold coin, an ability card, or even a charm. It's completely optional; the table's real goal still comes first."],
	"abilities": ["ABILITY CARDS", "Clearing a table now pays an ABILITY CARD instead of a card for your deck. Ability cards have no rank or suit. You put them on your poker hands, and each hand has one slot for every card in it: a Pair has 2, a Two Pair 4, a Flush 5. Every time you play that hand, its abilities kick in, or they just help in the background. Your first one went onto a hand for you. Between tables, press ABILITIES to move them around."],
	"relics": ["RELICS", "Charms that last the whole ride. Carry as many as you can afford. Each one quietly bends the rules in your favor until the ride is over."],
	"provisions": ["PROVISIONS", "Single-use supplies that sit in the KIT on the right. You have three slots, and good SADDLEBAGS add a fourth. Some are AIMED: click the provision, then a card on the table. Others work the moment you click them. Using one is FREE and never costs a hand. Restock at shops, or find more by cracking safes and chests."],
	"sleeve": ["ACE UP THE SLEEVE", "You ride with a card hidden up your sleeve: the SLEEVE row at the top of your kit. Once per table, click it and pick a plain card on the table. The two swap places, and the card you took waits up your sleeve for a later table. You can raise its starting rank with $cash at the Outfitter (UPGRADES on the main menu)."],
	"sleight": ["SLEIGHT OF HAND", "The Gambler has a trick ready: the SLEIGHT row at the top of your kit. Once per table (the Outfitter can add more uses), click it, pick a card, then pick the card right next to it, and the two swap places. It's free and doesn't cost a hand. Bosses and safes are too heavy to move."],
	"laser": ["THE LASER", "The Machine carries a laser: the LASER row at the top of your kit. Once per table, click it and pick a card, and the beam burns that card right off the table without scoring it. Safes, bosses and the cobra's coils block it. Each Outfitter upgrade adds one more card to the beam, spreading it out into a cross."],
	"watch": ["THE POCKET WATCH", "The Doctor carries a pocket watch: the row at the top of your kit. After any hand, press it and the hand UN-HAPPENS. The cards return, the score goes back to what it was, you get the hand back, and your HP and the bosses rewind too. If the table has a clock, it keeps ticking. You can buy more rewinds per table at the Outfitter."],
}
# (Modifier cards get no popup — hovering any board card shows a
# tooltip with its full story instead.)


func tutor_needs(key: String) -> bool:
	return not tutor_seen.get(key, false) \
			and OS.get_environment("POKERPOP_SHOT") == ""


## Queues a one-time explainer popup the first time `key` comes up.
func tutor_show(key: String) -> void:
	if not tutor_needs(key) or not TUTOR.has(key):
		return
	tutor_seen[key] = true
	_tutor_save()
	_tutor_queue.append(key)
	if not help_open(tutor_layer):
		_tutor_next()


func _tutor_next() -> void:
	# No board locking here: the scrim swallows mouse events and
	# _unhandled_input gates the keys while the popup is up. (Locking
	# raced with the deal countdown's own unlock and froze the board.)
	if _tutor_queue.is_empty():
		help_fade_out(tutor_layer)
		return
	var key: String = _tutor_queue.pop_front()
	_tutor_title.text = TUTOR[key][0]
	_tutor_body.text = TUTOR[key][1]
	_tutor_scroll.scroll_vertical = 0
	tutor_layer.move_to_front()
	help_fade_in(tutor_layer)


func _tutor_load() -> void:
	tutor_seen.clear()
	var cf := ConfigFile.new()
	if cf.load(profile_path("tutorial.cfg")) == OK and cf.has_section("seen"):
		for key in cf.get_section_keys("seen"):
			tutor_seen[key] = true


func _tutor_save() -> void:
	if OS.get_environment("POKERPOP_SHOT") != "":
		return
	var cf := ConfigFile.new()
	for key in tutor_seen:
		cf.set_value("seen", key, true)
	cf.save(profile_path("tutorial.cfg"))


# --- The how-to-play tutorial (interactive) --------------------------------

# Each step stamps a hand onto the board in a PATTERN — across, down,
# diagonal, around corners and rings — numbers the cards in the order a
# chain can take them, and waits for the player to play exactly those
# cards. cells: [[col, row, rank, suit], ...] in path order (suits: 0
# spades, 1 hearts, 2 diamonds, 3 clubs). Every hand in the game is here.
const TUT_STEPS := [
	{"want": "Pair", "cells": [[1, 2, 7, 0], [2, 2, 7, 1]],
		"text": "Welcome to the table! Hands are chains of cards that TOUCH. Two cards of the same rank make a PAIR. Click the glowing card 1, then card 2, then press SPACE or PLAY HAND."},
	{"want": "Two Pair", "cells": [[3, 0, 5, 3], [3, 1, 5, 2], [3, 2, 9, 0], [3, 3, 9, 1]],
		"text": "Chains can run in ANY direction. Two pairs in one chain make TWO PAIR, and this one runs straight DOWN a column. Pick them in order: 1, 2, 3, 4."},
	{"want": "Three of a Kind", "cells": [[0, 0, 9, 0], [1, 1, 9, 1], [2, 2, 9, 2]],
		"text": "DIAGONALS count too: every card touches all 8 cards around it. Here, THREE OF A KIND runs from corner to corner."},
	{"want": "Straight", "cells": [[0, 4, 5, 0], [1, 4, 6, 1], [2, 4, 7, 2], [3, 3, 8, 3], [3, 2, 9, 0]],
		"text": "A chain can TURN. Each card only has to touch the one you picked before it. This STRAIGHT (five ranks in a row, any suits) runs along the bottom, up a diagonal, then straight up."},
	{"want": "Flush", "cells": [[0, 1, 2, 1], [1, 0, 6, 1], [2, 1, 9, 1], [3, 0, 11, 1], [4, 1, 13, 1]],
		"text": "A FLUSH is five cards of ONE suit, any ranks. This one zig-zags up and down along the top two rows."},
	{"want": "Full House", "cells": [[2, 1, 4, 0], [1, 2, 4, 1], [2, 3, 4, 2], [3, 2, 11, 0], [2, 2, 11, 1]],
		"text": "ORDER MATTERS: each pick has to touch the LAST card you picked, so the chain is a path. Go around the diamond 1 to 4, then finish on 5 in the middle. Jumping from 1 to 3 won't work: they don't touch. Misclicked? Click a picked card to cut the chain back to it. This is a FULL HOUSE: three of a kind plus a pair."},
	{"want": "Four of a Kind", "cells": [[3, 3, 13, 0], [4, 3, 13, 1], [4, 4, 13, 2], [3, 4, 13, 3]],
		"text": "FOUR OF A KIND is four cards of one rank. A tight square works: just go around the block from 1 to 4. Every card in the chain has to be part of the hand. No spare cards, ever."},
	{"want": "Straight Flush", "cells": [[0, 3, 5, 3], [1, 4, 6, 3], [2, 3, 7, 3], [3, 4, 8, 3], [4, 3, 9, 3]],
		"text": "A STRAIGHT FLUSH is a straight all in one suit. Diagonal zig-zags are still one chain: down, up, down, up."},
	{"want": "Five of a Kind", "cells": [[2, 1, 12, 0], [2, 2, 12, 1], [1, 2, 12, 2], [2, 3, 12, 3], [3, 2, 12, 0]],
		"text": "FIVE OF A KIND is five cards of one rank. On the trail, you'll need duplicate cards or wilds to make one. Go around the cross: top, middle, left, bottom, right."},
	{"want": "Royal Flush", "cells": [[0, 0, 10, 2], [0, 1, 11, 2], [1, 2, 12, 2], [1, 3, 13, 2], [0, 4, 14, 2]],
		"text": "A ROYAL FLUSH is 10, J, Q, K, A of one suit, the best straight there is. This one snakes down the left side."},
	{"want": "Flushed Five", "cells": [[0, 1, 8, 1], [1, 2, 8, 1], [2, 3, 8, 1], [3, 2, 8, 1], [4, 1, 8, 1]],
		"text": "And the best hand of all: the FLUSHED FIVE, five copies of the exact same card. Go down the V and back up."},
	{"want": "", "cells": [],
		"text": "This last one's up to you: find ANY hand, a pair or better, and play it. Click or drag across touching cards in any direction. The PAYOUTS list on the right shows what every hand is worth."},
]


## A brand-new profile is asked once, before its first ride or mode:
## play the tutorial, or skip it for good. `then` is where they were
## headed — taken right after the tutorial, or at once on a skip.
var _offer_layer: ColorRect
var _tut_panel: Control
var _after_tutorial := Callable()


## Help windows (explainer popups, the tutorial question, the
## tutorial's instructions) fade in and out over HELP_FADE seconds. A
## window fading out is already closed: it ignores the mouse, its
## buttons go dead, and help_open() says no.
const HELP_FADE := 2.0


func _help_fade_time() -> float:
	return 0.0 if OS.get_environment("POKERPOP_SHOT") != "" else HELP_FADE


func help_open(c: CanvasItem) -> bool:
	return c != null and c.visible and not bool(c.get_meta("closing", false))


func help_fade_in(c: CanvasItem) -> void:
	if help_open(c):
		return
	_kill_help_fade(c)
	c.set_meta("closing", false)
	if not c.visible:
		c.modulate.a = 0.0
	c.visible = true
	_help_live(c, true)
	var t := _help_fade_time()
	if t <= 0.0:
		c.modulate.a = 1.0
		return
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", 1.0, t * (1.0 - c.modulate.a))
	c.set_meta("fade_tw", tw)


func help_fade_out(c: CanvasItem, then := Callable()) -> void:
	if not c.visible or bool(c.get_meta("closing", false)):
		if then.is_valid():
			then.call()
		return
	_kill_help_fade(c)
	c.set_meta("closing", true)
	_help_live(c, false)
	var t := _help_fade_time()
	if t <= 0.0:
		c.visible = false
		c.modulate.a = 1.0
		if then.is_valid():
			then.call()
		return
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", 0.0, t * c.modulate.a)
	tw.tween_callback(func() -> void:
		if bool(c.get_meta("closing", false)):
			c.visible = false
			c.modulate.a = 1.0
		if then.is_valid():
			then.call())
	c.set_meta("fade_tw", tw)


func _kill_help_fade(c: CanvasItem) -> void:
	if c.has_meta("fade_tw"):
		var old: Tween = c.get_meta("fade_tw")
		if old != null and old.is_valid():
			old.kill()
		c.remove_meta("fade_tw")


## A help window's scrim and buttons take the mouse only while it's open.
func _help_live(c: CanvasItem, live: bool) -> void:
	if c is Control and not c is BaseButton:
		var ctl := c as Control
		if not ctl.has_meta("filter"):
			ctl.set_meta("filter", ctl.mouse_filter)
		ctl.mouse_filter = int(ctl.get_meta("filter")) if live else Control.MOUSE_FILTER_IGNORE
	if c is BaseButton:
		(c as BaseButton).disabled = not live
	for child in c.get_children():
		if child is BaseButton:
			(child as BaseButton).disabled = not live


## A help window is up: the table waits (clocks and the arcade bar stop).
func help_blocking() -> bool:
	return help_open(tutor_layer) or help_open(_callout_layer)


# --- Card callouts: a poster pinned beside the card it explains ------------

var _callout_layer: Control
var _callout_panel: Panel
var _callout_title: Label
var _callout_body: Label
var _callout_pointer: Polygon2D
var _callout_queue: Array = []   # [{card, key}] waiting their turn
var _callout_card: PlayingCard
var _callout_ok: Button


## The first time something new is DEALT to the table (a hazard, for
## now), a poster pops up beside that very card explaining it. Once per
## profile per kind, like the tutor popups it shares its text with.
func callout_card(card: PlayingCard, key: String) -> void:
	if card == null or not tutor_needs(key) or not TUTOR.has(key):
		return
	tutor_seen[key] = true
	_tutor_save()
	_callout_queue.append({"card": card, "key": key})


func _update_callout() -> void:
	if _callout_layer == null or _callout_queue.is_empty() or help_open(_callout_layer) \
			or help_open(tutor_layer) or menu_open or board.busy or not game_started:
		return
	var q: Dictionary = _callout_queue.pop_front()
	var card: PlayingCard = q.card
	if not is_instance_valid(card) or not board.grid.has(card.grid_pos) \
			or board.grid[card.grid_pos] != card:
		return  # it left the table before its turn came
	_callout_card = card
	card.tut_order = -1  # the gold glow, no number
	_callout_title.text = String(TUTOR[q.key][0])
	_callout_body.text = String(TUTOR[q.key][1])
	# Fit the poster to its text: title, the wrapped body, then GOT IT.
	var font: Font = _callout_body.get_theme_font("font")
	var body_h := font.get_multiline_string_size(_callout_body.text,
			HORIZONTAL_ALIGNMENT_LEFT, 388.0, 17).y
	_callout_body.size = Vector2(388, body_h + 4.0)
	_callout_panel.size.y = 70.0 + body_h + 92.0
	_callout_ok.position.y = _callout_panel.size.y - 70.0
	_place_callout(card)
	_callout_layer.move_to_front()
	help_fade_in(_callout_layer)
	board._play_sound(Board.SFX_FLIP, 1.2, -10.0)


## Beside the card (right if there's room, else left), with a pointer.
func _place_callout(card: PlayingCard) -> void:
	var xf := board.get_global_transform_with_canvas()
	var at: Vector2 = xf * board.cell_center(card.grid_pos)
	var half_w := PlayingCard.W * board.scale.x / 2.0
	var size := _callout_panel.size
	var right := at.x + half_w + 34.0 + size.x <= VIEW.x - 12.0
	var x := at.x + half_w + 34.0 if right else at.x - half_w - 34.0 - size.x
	var y := clampf(at.y - size.y / 2.0, 12.0, VIEW.y - size.y - 12.0)
	_callout_panel.position = Vector2(x, y)
	var edge := x if right else x + size.x
	var tip := at.x + (half_w + 6.0) * (1.0 if right else -1.0)
	_callout_pointer.polygon = PackedVector2Array([
		Vector2(edge, at.y - 16.0), Vector2(edge, at.y + 16.0), Vector2(tip, at.y)])


func _dismiss_callout() -> void:
	if not help_open(_callout_layer):
		return
	if _callout_card != null and is_instance_valid(_callout_card) and _callout_card.tut_order == -1:
		_callout_card.tut_order = 0
	_callout_card = null
	board._play_sound(Board.SFX_CLICK, 1.0, -8.0)
	help_fade_out(_callout_layer)


func _build_callout() -> void:
	_callout_layer = Control.new()
	_callout_layer.size = VIEW
	_callout_layer.mouse_filter = Control.MOUSE_FILTER_STOP  # the table waits
	_callout_layer.visible = false
	ui_root.add_child(_callout_layer)
	_callout_pointer = Polygon2D.new()
	_callout_pointer.color = UiKit.POSTER_EDGE
	_callout_layer.add_child(_callout_pointer)
	_callout_panel = Panel.new()
	_callout_panel.size = Vector2(460, 340)
	_callout_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_callout_panel.add_theme_stylebox_override("panel", UiKit.poster_box())
	_callout_layer.add_child(_callout_panel)
	_callout_title = _label(_callout_panel, "", Vector2(0, 22), 30, RED)
	_callout_title.size = Vector2(460, 40)
	_callout_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_callout_body = _label(_callout_panel, "", Vector2(36, 70), 17, UiKit.POSTER_INK)
	UiKit.track_ink(_callout_body)
	_callout_body.size = Vector2(388, 196)
	_callout_body.custom_minimum_size = Vector2(388, 0)
	_callout_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if FontLib.body != null:
		_callout_body.add_theme_font_override("font", FontLib.body)
	var ok := _button(_callout_layer, "GOT IT", Vector2.ZERO, Vector2(200, 50))
	ok.add_theme_font_size_override("font_size", 20)
	ok.reparent(_callout_panel)
	ok.position = Vector2(130, 276)
	ok.pressed.connect(_dismiss_callout)
	_callout_ok = ok


# --- The table plaque: how a table ended, dropped in at the top ------------

var _plaque: Control
var _plaque_label: Label
var _plaque_tween: Tween


func table_banner(text: String, color: Color = GOLD) -> void:
	_plaque_label.text = text
	_plaque_label.add_theme_color_override("font_color", color)
	if _plaque_tween and _plaque_tween.is_valid():
		_plaque_tween.kill()
	_plaque.move_to_front()
	_plaque.position.y = -130.0
	_plaque.modulate.a = 1.0
	_plaque.visible = true
	_plaque_tween = create_tween()
	_plaque_tween.tween_property(_plaque, "position:y", _plaque_rest_y, 0.5) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_plaque_tween.tween_interval(2.6)
	_plaque_tween.tween_property(_plaque, "position:y", -130.0, 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_plaque_tween.tween_callback(func() -> void: _plaque.visible = false)


func _build_plaque() -> void:
	_plaque = Control.new()
	_plaque.size = Vector2(820, 112)
	_plaque.position = Vector2(PLAY_X + (PLAY_WIDTH - 820.0) / 2.0, -130.0)
	if Form.is_mobile():
		_plaque.position.x = (VIEW.x - 820.0) / 2.0
	_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque.visible = false
	ui_root.add_child(_plaque)
	UiKit.plate(_plaque, Rect2(Vector2.ZERO, _plaque.size))
	_plaque_label = _label(_plaque, "", Vector2(0, 0), 46, GOLD)
	_plaque_label.size = _plaque.size
	_plaque_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plaque_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if FontLib.display != null:
		_plaque_label.add_theme_font_override("font", FontLib.display)
	_plaque_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_plaque_label.add_theme_constant_override("shadow_offset_y", 3)


func offer_tutorial(then: Callable) -> void:
	_after_tutorial = then
	_offer_layer.move_to_front()
	help_fade_in(_offer_layer)


func _offer_take_tutorial() -> void:
	help_fade_out(_offer_layer)
	board._play_sound(Board.SFX_CLICK, 1.0, -8.0)
	transition(func() -> void:
		trail._hide_all()
		_start_tutorial())


func _offer_skip_tutorial() -> void:
	help_fade_out(_offer_layer)
	board._play_sound(Board.SFX_CLICK, 1.0, -8.0)
	tutor_seen["core"] = true
	_tutor_save()
	var then := _after_tutorial
	_after_tutorial = Callable()
	if then.is_valid():
		then.call()


func _start_tutorial() -> void:
	tutor_seen["core"] = true
	_tutor_save()
	mode_kind = "tutorial"
	mode_label_text = "Tutorial"
	board.single_deck = false
	board.custom_deck.clear()
	menu_open = false
	menu_layer.visible = false
	game_started = true
	game_over = false
	score = 0
	hands_played = 0
	play_music("room")
	parallax.set_scene("stars")
	board.visible = true
	board.reset()
	while board.busy:
		await get_tree().process_frame
	board.locked = false
	tut_step = 0
	if OS.get_environment("POKERPOP_SHOT") != "" and OS.get_environment("POKERPOP_TUT_STEP") != "":
		tut_step = clampi(int(OS.get_environment("POKERPOP_TUT_STEP")) - 1, 0, TUT_STEPS.size() - 1)
	help_fade_in(_tut_panel)
	help_fade_in(_tut_skip_btn)
	_tut_apply_step()


func _tut_apply_step() -> void:
	while board.busy:
		await get_tree().process_frame
	if mode_kind != "tutorial":
		return
	var step: Dictionary = TUT_STEPS[tut_step]
	_tut_clear_marks()
	var cells: Array = step.cells
	for n in cells.size():
		var p := Vector2i(int(cells[n][0]), int(cells[n][1]))
		if not board.grid.has(p):
			continue
		var card: PlayingCard = board.grid[p]
		card.rank = int(cells[n][2])
		card.suit = int(cells[n][3])
		card.mod = ""
		card.finish = ""
		card.hazard = ""
		card.joker = false
		card.cursed = false
		card.honey = false
		card.washed = false
		card.objective = ""
		card.tut_order = n + 1  # the numbered glow: the path to take
	var want := String(step.want)
	var head := "STEP %d / %d" % [tut_step + 1, TUT_STEPS.size()]
	if want != "":
		head += "   ·   %s  (%d)" % [want.to_upper(), int(Poker.BASE_SCORES.get(want, 0))]
	_tut_label.text = "%s\n%s" % [head, step.text]


func _tut_clear_marks() -> void:
	for p in board.grid:
		(board.grid[p] as PlayingCard).tut_order = 0


func _tut_on_hand(result: Dictionary) -> void:
	var hand_name := String(result.name)
	var step: Dictionary = TUT_STEPS[tut_step]
	if String(step.want) != "" and hand_name != String(step.want):
		_announce("THAT'S A %s, NOT A %s" % [hand_name.to_upper(),
				String(step.want).to_upper()], RED)
		_tut_apply_step()  # re-stamp in case the formation was eaten
		return
	if String(step.want) != "" and not _tut_played_marked(result, step):
		_announce("RIGHT HAND, BUT PLAY THE NUMBERED CARDS", RED)
		_tut_apply_step()
		return
	tut_step += 1
	if tut_step >= TUT_STEPS.size():
		_finish_tutorial()
	else:
		_tut_apply_step()


## The hand used exactly the step's numbered cards.
func _tut_played_marked(result: Dictionary, step: Dictionary) -> bool:
	var want := {}
	for c in step.cells:
		want[Vector2i(int(c[0]), int(c[1]))] = true
	var played: Array = result.get("cleared_cells", [])
	if played.size() != want.size():
		return false
	for p in played:
		if not want.has(p):
			return false
	return true


func _finish_tutorial() -> void:
	_announce("YOU'RE READY! WELCOME TO THE TABLE")
	_tut_label.text = "Tutorial complete! Pick a mode from the menu."
	while board.busy:
		await get_tree().process_frame
	await get_tree().create_timer(2.0).timeout
	if mode_kind == "tutorial":
		_end_tutorial()


func _end_tutorial() -> void:
	_tut_clear_marks()
	help_fade_out(_tut_panel)
	help_fade_out(_tut_skip_btn)
	mode_kind = ""
	var then := _after_tutorial
	_after_tutorial = Callable()
	if then.is_valid():
		# Straight on to where they were headed before the lesson.
		_open_menu_now()
		then.call()
		return
	_open_menu()


func _save_settings() -> void:
	if OS.get_environment("POKERPOP_PROFILE") != "" or OS.get_environment("POKERPOP_SHOT") != "" \
			or DisplayServer.get_name() == "headless":
		return  # tests and screenshots must never overwrite the player's settings
	var cf := ConfigFile.new()
	cf.set_value("profile", "current", profile)
	cf.set_value("video", "fullscreen", fullscreen_on)
	cf.set_value("video", "resolution", res_index)
	cf.set_value("audio", "music", music_vol)
	cf.set_value("audio", "sfx", sfx_vol)
	cf.set_value("video", "ui_style", UiKit.style)
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


## A short curtain between screens: fade to black, swap, fade back.
## Instant under screenshot capture so timed shots never race it.
func transition(swap: Callable, dur := 0.16) -> void:
	if _fade_rect == null or OS.get_environment("POKERPOP_SHOT") != "":
		swap.call()
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	# A soft whoosh under the curtain.
	board._play_sound(Board.SFX_SWOOSH, 1.25, -20.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_rect, "color:a", 1.0, dur)
	_fade_tween.tween_callback(swap)
	_fade_tween.tween_property(_fade_rect, "color:a", 0.0, dur)
	_fade_tween.tween_callback(func() -> void:
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE)


func _open_menu() -> void:
	transition(_open_menu_now)


func _open_menu_now() -> void:
	_stats_save()
	if mode_kind == "zen" and score > 0:
		_record_mode_score()  # Zen ends whenever you walk away
	if mode_kind == "trail":
		trail.on_abandon_room()  # mid-room exit counts as a fail
		trail._hide_all()
	trail.progress.standard = false  # a seeded ride's hold lifts off the menu
	countdown_id += 1  # cancel any running countdown
	countdown_active = false
	countdown_overlay.visible = false
	play_music("menu")
	parallax.set_scene(UiKit.menu_scene())
	board.visible = false  # no stale table lingering behind the menu scrim
	if _tut_label != null:
		_tut_panel.visible = false
		_tut_skip_btn.visible = false
	menu_open = true
	game_started = false
	game_over = false
	over_layer.visible = false
	board.locked = true
	menu_layer.visible = true
	_refresh_level_plate()
	# The first level-up earns the explainer, back at the menu.
	if trail.progress.level() > 1:
		tutor_show("levels")


## The rider's level under STATS: the number, a sliver of EXP bar, and
## what's waiting at the Outfitter. Clicking it opens the Outfitter.
var _level_plate: Button
var _level_label: Label
var _level_sub: Label
var _level_fill: Panel
var _upgrades_pip: Label
# SEEDS for the arcade-style modes (the trail keeps its own).
var mode_seed := ""
var seed_book := SeedBook.new()
var _mode_scored := false   # this game's score is already on its seed's board
var leaderboard: Leaderboard
var _rank_key := ""     # the board the last posted game went on
var _rank_score := 0
var _rank_line := ""    # "#N on this seed's online board", once it's back
var next_mode_seed := ""
var _mode_seed_fixed := false
var _mode_label_base := ""
var _contracts_pip: Label


## A small round gold counter on the menu (hidden at zero).
func _gold_pip(pos: Vector2) -> Label:
	var pip := _label(menu_layer, "", pos, 18, Color("1a1208"))
	pip.size = Vector2(34, 34)
	pip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = GOLD
	bg.set_corner_radius_all(17)
	pip.add_theme_stylebox_override("normal", bg)
	pip.visible = false
	return pip


func _build_level_plate() -> void:
	_level_plate = Button.new()
	_level_plate.position = Vector2(60, 196)
	_level_plate.size = Vector2(240, 96)
	_level_plate.flat = true
	_level_plate.focus_mode = Control.FOCUS_NONE
	_level_plate.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	menu_layer.add_child(_level_plate)
	UiKit.plate(_level_plate, Rect2(Vector2.ZERO, _level_plate.size))
	_level_label = _label(_level_plate, "", Vector2(0, 8), 26, GOLD)
	_level_label.size = Vector2(240, 34)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var track := Panel.new()
	track.position = Vector2(24, 46)
	track.size = Vector2(192, 12)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_theme_stylebox_override("panel", UiKit.bar_box("track"))
	_level_plate.add_child(track)
	_level_fill = Panel.new()
	_level_fill.position = Vector2(24, 46)
	_level_fill.size = Vector2(0, 12)
	_level_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_fill.add_theme_stylebox_override("panel", UiKit.bar_box("gold"))
	_level_plate.add_child(_level_fill)
	_level_sub = _label(_level_plate, "", Vector2(0, 64), 15, DIM)
	_level_sub.size = Vector2(240, 22)
	_level_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_plate.pressed.connect(func() -> void:
		trail.open_upgrades())
	_refresh_level_plate()


func _refresh_level_plate() -> void:
	if _level_plate == null:
		return
	var pr: Progression = trail.progress
	var into: Array = pr.exp_into_level()
	_level_label.text = "LEVEL %d" % pr.level()
	_level_fill.size.x = 192.0 * clampf(float(into[0]) / maxf(1.0, float(into[1])), 0.0, 1.0)
	var news: int = trail.outfitter_news()
	_level_sub.text = "%d NEW AT THE OUTFITTER" % news if news > 0 			else "%d / %d EXP" % [int(into[0]), int(into[1])]
	_level_sub.add_theme_color_override("font_color", GOLD if news > 0 else DIM)
	if _upgrades_pip != null:
		_upgrades_pip.text = str(news)
		_upgrades_pip.visible = news > 0
	if _contracts_pip != null:
		var ready := Contracts.ready_count(stats, stats_hands, pr)
		_contracts_pip.text = str(ready)
		_contracts_pip.visible = ready > 0
	_level_plate.tooltip_text = "Every ride's score turns into EXP. Each level unlocks something new for the trail."


func _start_mode(kind: String, seconds: float = 0.0) -> void:
	transition(func() -> void:
		_start_mode_now(kind, seconds))


func _start_mode_now(kind: String, seconds: float = 0.0) -> void:
	# A brand-new profile is asked about the tutorial before its first mode.
	if tutor_needs("core"):
		offer_tutorial(func() -> void:
			_start_mode(kind, seconds))
		return
	tutor_show("mode_" + kind)
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
	_mode_label_base = mode_label_text
	# A chosen seed (SEEDED PLAY) sticks for this sitting; otherwise
	# every game deals from a fresh random one.
	_mode_seed_fixed = SeedRng.is_valid(next_mode_seed)
	mode_seed = next_mode_seed if _mode_seed_fixed else ""
	next_mode_seed = ""
	board.single_deck = kind == "single"
	board.custom_deck.clear()
	menu_open = false
	menu_layer.visible = false
	game_started = true
	play_music("room")
	while board.busy:
		await get_tree().process_frame
	_restart()


## Starts a music player from silence and eases it up to full volume.
func _fade_in(p: AudioStreamPlayer, target_db := -12.0) -> void:
	p.volume_db = -40.0
	p.play()
	create_tween().tween_property(p, "volume_db", target_db, 1.5)


## Rebuilds the mini-card row showing the current selection in rank
## order. Soaked cards keep their secret: they render soaked, unsorted,
## at the end of the row (a sorted position would leak the rank).
func _refresh_hand_display() -> void:
	for child in hand_display.get_children():
		child.queue_free()
	var cards: Array = []
	var soaked_count := 0
	for card in board.selected:
		if card.washed:
			soaked_count += 1
		else:
			cards.append({"rank": card.rank, "suit": card.suit,
					"mod": "wild" if card.mod == "wild" else ""})
	cards.sort_custom(func(a, b): return a.rank < b.rank)
	for i in cards.size():
		var mc := PlayingCard.new()
		mc.rank = cards[i].rank
		mc.suit = cards[i].suit
		mc.mod = cards[i].mod
		mc.scale = Vector2(0.72, 0.72)
		mc.position = Vector2(i * 74.0, 0)
		mc.material = Themes.current_material()
		hand_display.add_child(mc)
	for i in soaked_count:
		var mc := PlayingCard.new()
		mc.washed = true
		mc.scale = Vector2(0.72, 0.72)
		mc.position = Vector2((cards.size() + i) * 74.0, 0)
		mc.material = Themes.current_material()
		hand_display.add_child(mc)


## The Outlaw landed one: a quick red blink over everything.
func flash_red() -> void:
	var tw := create_tween()
	tw.tween_property(_damage_flash, "color:a", 0.26, 0.05)
	tw.tween_property(_damage_flash, "color:a", 0.0, 0.4)


## Rebuilds the panel card row: the hold'em community, or the
## blackjack dealer's hand.
func _refresh_community() -> void:
	for child in community_display.get_children():
		child.queue_free()
	var cards: Array = board.panel_cards()
	# Big cards, slightly fanned: they overlap just enough that the
	# whole street fits the plate (each card's rank corner stays
	# clear), and spread back out when the panel holds fewer.
	var avail := _community_w / community_display.scale.x
	var pitch := 74.0
	if cards.size() > 1:
		pitch = minf(74.0, (avail - PlayingCard.W) / (cards.size() - 1))
	for i in cards.size():
		var data: Dictionary = cards[i]
		var mc := PlayingCard.new()
		mc.rank = data.rank
		mc.suit = data.suit
		# Real-blackjack style: the dealer's hole card stays face-down
		# until the player commits a hand.
		mc.face_down = i == 1 and board.blackjack_hole_hidden \
				and not board.blackjack_dealer_cards.is_empty()
		mc.position = Vector2(PlayingCard.W / 2.0 + i * pitch, 0)
		mc.material = Themes.current_material()
		community_display.add_child(mc)


func _announce(text: String, color: Color = GOLD) -> void:
	announcer.text = text
	announcer.add_theme_color_override("font_color", color)
	if _announce_tween and _announce_tween.is_valid():
		_announce_tween.kill()
	# Ease in gently from slightly oversized, hold long enough to
	# actually read, then melt away slowly.
	announcer.pivot_offset = announcer.size / 2.0
	announcer.scale = Vector2(1.18, 1.18)
	announcer.modulate = Color(1, 1, 1, 0)
	_announce_tween = create_tween()
	_announce_tween.tween_property(announcer, "scale", Vector2.ONE, 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_announce_tween.parallel().tween_property(announcer, "modulate:a", 1.0, 0.35)
	_announce_tween.tween_interval(2.2)
	_announce_tween.tween_property(announcer, "modulate:a", 0.0, 1.4)


## Centers the board inside the play area, scaling up or down to fit.
func _apply_board_layout() -> void:
	# Reserve room for the table rim around the card grid.
	var margin := TableSurface.RIM_W + TableSurface.FELT_PAD
	var px := board.board_px_size() + Vector2.ONE * margin * 2.0
	var s: float = minf(_board_area.size.x / px.x, _board_area.size.y / px.y)
	board.scale = Vector2(s, s)
	board.position = _board_area.position + (_board_area.size - px * s) / 2.0 \
			+ Vector2.ONE * margin * s
	_board_home = board.position


## Rattles the table (never the HUD): a decaying random jitter around
## the board's resting spot, restored exactly at the end.
func shake(strength: float) -> void:
	# A low thump under the rattle — pops pitched down to a body blow.
	board._play_sound(Board.SFX_POPS.pick_random(), 0.42, -6.0)
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	board.position = _board_home
	_shake_tween = create_tween()
	var steps := 7
	for i in steps:
		var falloff := strength * (1.0 - float(i) / steps)
		_shake_tween.tween_property(board, "position", _board_home
				+ Vector2(randf_range(-falloff, falloff),
				randf_range(-falloff, falloff)), 0.04)
	_shake_tween.tween_property(board, "position", _board_home, 0.05)


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

	# Everything gameplay-HUD lives under one container so the menu
	# (now translucent over the parallax) can hide it wholesale.
	hud_root = Control.new()
	hud_root.size = VIEW
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(hud_root)

	# Leather plates behind the HUD columns — added FIRST so every
	# label and button draws on top of them.
	_desk_only.append(UiKit.plate(hud_root, Rect2(PANEL_X - 18, 118, 336, 322)))
	_desk_only.append(UiKit.plate(hud_root, Rect2(PANEL_X - 18, 450, 336, 180)))
	_community_plate = UiKit.plate(hud_root, Rect2(PANEL_X - 18, 636, 336, 170))
	_desk_only.append(UiKit.plate(hud_root, Rect2(PANEL_R - 18, 126, 336, 384)))
	_desk_only.append(UiKit.plate(hud_root, Rect2(PANEL_R - 18, 840, 336, 236)))

	_desk_only.append(_logo(hud_root, LOGO_HORIZONTAL, Rect2(PANEL_X, 26, 300, 64)))
	_desk_only.append(UiKit.hrule(hud_root, Vector2(PANEL_X, 96), 300))

	score_label = _label(hud_root, "", Vector2(PANEL_X, 140), 40, GOLD)
	# The rider's HP, trail only: red segment pills, the same language
	# as the boss bar.
	_hp_label = _label(hud_root, "HP", Vector2(PANEL_X, 193), 15, DIM)
	_hp_label.visible = false
	for i in 10:
		var pip := Panel.new()
		pip.position = Vector2(PANEL_X + 38 + i * 26.0, 196)
		pip.size = Vector2(22, 12)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.visible = false
		hud_root.add_child(pip)
		_hp_pips.append(pip)
	status_label = _label(hud_root, "", Vector2(PANEL_X, 216), 28, OFFWHITE)
	deck_label = _label(hud_root, "", Vector2(PANEL_X, 252), 20, OFFWHITE)
	meta_label = _label(hud_root, "", Vector2(PANEL_X, 282), 16, DIM)

	# Arcade banner: level target and progress, big across the board top.
	target_label = _label(hud_root, "", Vector2(380, 8), 40, GOLD)
	target_bar_back = Panel.new()
	target_bar_back.add_theme_stylebox_override("panel", UiKit.bar_box("track"))
	target_bar_back.position = Vector2(380, 74)
	target_bar_back.size = Vector2(1160, 16)
	target_bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(target_bar_back)
	target_bar_fill = Panel.new()
	target_bar_fill.add_theme_stylebox_override("panel", UiKit.bar_box("gold"))
	target_bar_fill.position = Vector2(380, 74)
	target_bar_fill.size = Vector2(0, 16)
	target_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(target_bar_fill)
	target_label.visible = false
	target_bar_back.visible = false
	target_bar_fill.visible = false
	_twist_strip = CenterContainer.new()
	_twist_strip.position = Vector2(380, 90)
	_twist_strip.size = Vector2(1160, 34)
	_twist_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_twist_strip.visible = false
	hud_root.add_child(_twist_strip)
	_boss_ticks = Control.new()
	_boss_ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_bar_fill.add_child(_boss_ticks)

	# The bounty plaque: the kit's slim WANTED strip over the banner
	# area during bounty tables; the HP bar drops just below it onto
	# the table rim. Built empty when the character kit is absent.
	_bounty_plaque = Control.new()
	_bounty_plaque.position = Vector2(380, -6)
	_bounty_plaque.size = Vector2(1160, 120)
	_bounty_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bounty_plaque.visible = false
	var plaque_tpl: Texture2D = CharacterKit.tex(String(
			CharacterKit.poster_info("topbar_template").get("file", "")))
	if plaque_tpl != null:
		var plaque_paper := TextureRect.new()
		plaque_paper.texture = plaque_tpl
		plaque_paper.size = Vector2(1160, 120)
		plaque_paper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		plaque_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bounty_plaque.add_child(plaque_paper)
		_plaque_line = _label(_bounty_plaque, "", Vector2(160, 84), 16, Color("8a3a30"))
		_plaque_line.size = Vector2(840, 22)
		_plaque_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if FontLib.numbers != null:
			_plaque_line.add_theme_font_override("font", FontLib.numbers)
		_plaque_reward = _label(_bounty_plaque, "", Vector2(880, 44), 36, Color("8a3a30"))
		_plaque_reward.size = Vector2(316, 46)
		_plaque_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_root.add_child(_bounty_plaque)

	var play_btn := _button(hud_root, "PLAY HAND", Vector2(PANEL_X, 316), Vector2(300, 60), true)
	_play_btn = play_btn
	play_btn.add_theme_font_size_override("font_size", 24)
	play_btn.pressed.connect(func() -> void:
		if game_started and not game_over:
			board.play_hand())
	var clear_btn := _button(hud_root, "CLEAR", Vector2(PANEL_X, 388), Vector2(145, 48))
	_clear_btn = clear_btn
	clear_btn.add_theme_font_size_override("font_size", 24)
	clear_btn.pressed.connect(func() -> void:
		if game_started and not game_over:
			board.player_clear())
	var menu_btn := _button(hud_root, "MENU", Vector2(PANEL_X + 155, 388), Vector2(145, 48))
	_menu_btn = menu_btn
	menu_btn.add_theme_font_size_override("font_size", 18)
	menu_btn.pressed.connect(func() -> void:
		# Mid-game, MENU opens the pause screen (like ESC) so exiting
		# is a deliberate second click, with sound settings right there.
		if game_started and not game_over and not menu_open:
			_toggle_pause()
		else:
			_open_menu())

	# Selected cards, shown sorted by rank so straights are easy to read.
	_desk_only.append(_label(hud_root, "YOUR HAND", Vector2(PANEL_X, 460), 18, DIM))
	_desk_only.append(UiKit.hrule(hud_root, Vector2(PANEL_X, 488), 300))
	hand_display = Node2D.new()
	hand_display.position = Vector2(PANEL_X + 30, 532)
	hand_display.scale = Vector2(0.8, 0.8)
	hud_root.add_child(hand_display)

	# Hold'em community cards (visible only when a community is live).
	_community_label = _label(hud_root, "COMMUNITY", Vector2(PANEL_X, 646), 18, DIM)
	community_display = Node2D.new()
	community_display.position = Vector2(PANEL_X + 4, 734)
	community_display.scale = Vector2(0.95, 0.95)
	hud_root.add_child(community_display)

	# The Showdown's Outlaw, waiting in the left column.
	outlaw = OutlawPortrait.new()
	# The Outlaw stands in the RIGHT gutter now — the deck pile took
	# his old corner.
	outlaw.position = Vector2(1435, 790)
	outlaw.visible = false
	hud_root.add_child(outlaw)

	# Red vignette blink when the Outlaw lands a shot.
	_damage_flash = ColorRect.new()
	_damage_flash.color = Color(0.8, 0.1, 0.1, 0.0)
	_damage_flash.size = VIEW
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(_damage_flash)

	# Arcade meter: a vertical bar beside the board that drains constantly.
	meter_back = ColorRect.new()
	meter_back.color = Color("2a2a2a")
	meter_back.position = Vector2(1888, 100)
	meter_back.size = Vector2(26, 900)
	meter_back.visible = false
	hud_root.add_child(meter_back)
	meter_fill = ColorRect.new()
	meter_fill.color = GOLD
	meter_fill.position = Vector2(1892, 104)
	meter_fill.size = Vector2(18, 892)
	meter_fill.visible = false
	hud_root.add_child(meter_fill)

	_desk_only.append(_label(hud_root, "PAYOUTS", Vector2(PANEL_R, 140), 22, DIM))
	_desk_only.append(UiKit.hrule(hud_root, Vector2(PANEL_R, 170), 300))
	# A proper two-column table: hand names left, prices right in gold.
	var names: Array = Poker.BASE_SCORES.keys()
	names.reverse()
	var name_lines := PackedStringArray()
	var value_lines := PackedStringArray()
	for hand_name in names:
		name_lines.append(hand_name)
		value_lines.append(str(Poker.BASE_SCORES[hand_name]))
	_payout_names = _label(hud_root, "\n".join(name_lines), Vector2(PANEL_R, 180), 20, OFFWHITE)
	# Hand names read as prose — Old Standard serif per the type ruling.
	if FontLib.body != null:
		_payout_names.add_theme_font_override("font", FontLib.body)
	_payout_values = _label(hud_root, "\n".join(value_lines), Vector2(PANEL_R, 180), 20, GOLD)
	_payout_values.size = Vector2(300, 400)
	_payout_values.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if FontLib.numbers != null:
		_payout_values.add_theme_font_override("font", FontLib.numbers)
	# Serif names and Oswald values have different natural line heights;
	# pin both columns to one shared row pitch so the table stays ruled.
	var row_pitch := 30.0
	for pl: Label in [_payout_names, _payout_values]:
		var f: Font = pl.get_theme_font("font")
		pl.add_theme_constant_override("line_spacing",
				int(row_pitch - f.get_height(20)))

	_desk_only.append(_label(hud_root, "Click or drag to chain\ntouching cards. Every card\nmust be part of the hand.\n\nEnter / Space — play\nC / Right click — clear\nEsc — pause    R — restart\nT — theme    M — menu",
			Vector2(PANEL_R, 860), 16, DIM))

	# The KIT: the sleeve on top, then three provision slots (four with
	# Saddlebags), trail rooms only. Rows are laid out in _update_kit.
	_kit_plate = UiKit.plate(hud_root, Rect2(PANEL_R - 18, 524, 336, 312))
	_kit_title = _label(hud_root, "KIT", Vector2(PANEL_R, 536), 22, DIM)
	_sleeve_btn = _button(hud_root, "—", Vector2(PANEL_R, 574), Vector2(300, 56))
	_sleeve_btn.clip_text = true
	_sleeve_btn.add_theme_font_size_override("font_size", 19)
	# The rider's signature icon rides the left edge, like a provision.
	_sleeve_icon = TextureRect.new()
	_sleeve_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sleeve_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sleeve_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sleeve_btn.add_child(_sleeve_icon)
	_sleeve_btn.pressed.connect(func() -> void:
		trail.use_signature())
	for i in 4:
		var kb := _button(hud_root, "—", Vector2(PANEL_R, 574 + (i + 1) * 64), Vector2(300, 56))
		kb.clip_text = true
		kb.add_theme_font_size_override("font_size", 19)
		var slot := i
		kb.pressed.connect(func() -> void:
			trail.use_provision(slot))
		_kit_btns.append(kb)
		# The kit's framed provision icon rides the left edge.
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		kb.add_child(ic)
		_kit_icons.append(ic)
	_kit_plate.visible = false
	_kit_title.visible = false
	_sleeve_btn.visible = false
	for b in _kit_btns:
		b.visible = false

	# The player's DECK, floating loose in the lower left: one drawn
	# card back PER CARD in the shoe, so a 32-card deck is a stack of
	# 32 — and each deal visibly takes the top one. Click the stack to
	# riffle through what's left (in no particular order). The pile
	# lives in WORLD space (not the HUD layer) so dealt cards, at
	# z 20 while flying, sail OVER it instead of under.
	var pile_root := Node2D.new()
	pile_root.z_index = 5
	add_child(pile_root)
	for i in DECK_STACK_MAX:
		var back := PlayingCard.new()
		back.face_down = true
		back.visible = false
		# Scale is synced (bigger than the felt) in _update_labels.
		back.position = Vector2(182.0 + i * 0.7, 880.0 - i * 0.7)
		pile_root.add_child(back)
		_deck_stack_cards.append(back)
	_deck_count = _label(hud_root, "DECK", Vector2(PANEL_X, 992), 24, GOLD)
	_deck_count.size = Vector2(280, 32)
	_deck_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deck_btn = Button.new()
	_deck_btn.flat = true
	_deck_btn.focus_mode = Control.FOCUS_NONE  # Space stays PLAY HAND's
	_deck_btn.position = Vector2(PANEL_X - 10, 752)
	_deck_btn.size = Vector2(310, 276)
	_deck_btn.tooltip_text = "The cards still to be dealt. Click to look through them, though you won't see the order they come in. When the stack runs out, a fresh copy of your deck gets shuffled in."
	_deck_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_deck_btn.pressed.connect(_open_deck_peek)
	hud_root.add_child(_deck_btn)
	_deck_btn.visible = false
	_deck_count.visible = false
	board.deal_anchor = Vector2(164, 958)

	_deck_peek = ColorRect.new()
	_deck_peek.color = Color(0, 0, 0, 0.72)
	_deck_peek.size = VIEW
	_deck_peek.visible = false
	_deck_peek.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(_deck_peek)
	var peek_title := _label(_deck_peek, "LEFT IN THE DECK", Vector2(0, 80), 48, GOLD)
	peek_title.size = Vector2(VIEW.x, 70)
	peek_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deck_peek_count = _label(_deck_peek, "", Vector2(0, 156), 22, DIM)
	_deck_peek_count.size = Vector2(VIEW.x, 34)
	_deck_peek_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var peek_scroll := ScrollContainer.new()
	peek_scroll.position = Vector2(280, 220)
	peek_scroll.size = Vector2(1360, 690)
	peek_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_deck_peek.add_child(peek_scroll)
	_deck_peek_grid = Control.new()
	peek_scroll.add_child(_deck_peek_grid)
	var peek_close := _button(_deck_peek, "BACK TO THE TABLE", Vector2(785, 950), Vector2(350, 60))
	peek_close.add_theme_font_size_override("font_size", 22)
	peek_close.pressed.connect(func() -> void:
		_deck_peek.visible = false)

	preview_label = _label(hud_root, "", Vector2(380, 1026), 26, DIM)

	# Darkens the play area during the Ready countdown — a clear "not yet".
	countdown_overlay = ColorRect.new()
	countdown_overlay.color = Color(0, 0, 0, 0.55)
	countdown_overlay.position = Vector2(PLAY_X, 0)
	countdown_overlay.size = Vector2(PLAY_WIDTH, VIEW.y)
	countdown_overlay.visible = false
	# Let clicks through so a deal animation can be skipped during the
	# countdown; the board is locked anyway.
	countdown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(countdown_overlay)

	announcer = Label.new()
	announcer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	announcer.add_theme_font_size_override("font_size", 58)
	announcer.add_theme_color_override("font_color", GOLD)
	announcer.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	announcer.add_theme_constant_override("shadow_offset_x", 5)
	announcer.add_theme_constant_override("shadow_offset_y", 5)
	announcer.modulate = Color(1, 1, 1, 0)
	ui_root.add_child(announcer)
	announcer.position = Vector2(PLAY_X, 0)
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

	if Form.is_mobile():
		_relayout_hud_mobile()
	_build_pause()


## The portrait table, after the phone mockup: a top bar (the table and its
## target, the deck, pause), the progress bar and twists, four stat cells,
## the board as big as the room allows, a strip for the community cards or
## the outlaw, the hand preview, the kit row, and CLEAR / PLAY HAND / PAYS.
## It moves the desktop's own nodes, so every update keeps working.
func _relayout_hud_mobile() -> void:
	var w := VIEW.x
	var h := VIEW.y
	var m := 36.0
	var top := Form.safe_top()
	var inner := w - 2.0 * m
	for n in _desk_only:
		if n != null:
			(n as CanvasItem).visible = false
	for n in [hand_display, meta_label, score_label, status_label, deck_label]:
		n.visible = false
	score_label.position.y = -400.0  # off the canvas: the cells carry the numbers
	status_label.position.y = -400.0
	deck_label.position.y = -400.0
	meta_label.position.y = -400.0
	# Top bar.
	var bar_plate := UiKit.plate(hud_root, Rect2(m, top, inner, 112))
	hud_root.move_child(bar_plate, 0)
	target_label.position = Vector2(m + 24.0, top + 12.0)
	target_label.size = Vector2(inner - 290.0, 60)
	target_label.add_theme_font_size_override("font_size", 38)
	target_label.clip_text = true
	_hp_label.position = Vector2(m + 24.0, top + 76.0)
	for i in _hp_pips.size():
		var pip: Panel = _hp_pips[i]
		pip.position = Vector2(m + 66.0 + i * 30.0, top + 80.0)
		pip.size = Vector2(24, 14)
	_bet_tag = _label(hud_root, "", Vector2(m + 420.0, top + 72.0), 22, DIM)
	_bet_tag.size = Vector2(inner - 710.0, 30)
	_bet_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_deck_btn.flat = false
	UiKit.style_button(_deck_btn)
	_deck_btn.position = Vector2(w - m - 226.0, top + 12.0)
	_deck_btn.size = Vector2(116, 88)
	_deck_count.position = _deck_btn.position + Vector2(0, 12)
	_deck_count.size = Vector2(116, 64)
	_deck_count.add_theme_font_size_override("font_size", 22)
	_deck_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deck_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_deck_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck_count.move_to_front()
	_menu_btn.text = "II"
	_menu_btn.tooltip_text = "Pause: resume, restart, sound, or leave the table. A trail table waits for you."
	_menu_btn.position = Vector2(w - m - 98.0, top + 12.0)
	_menu_btn.size = Vector2(86, 88)
	_menu_btn.add_theme_font_size_override("font_size", 34)
	# The progress bar and the twists.
	_bar_y = top + 130.0
	_bar_y_bounty = top + 130.0
	_bar_w = inner
	target_bar_back.position = Vector2(m, _bar_y)
	target_bar_back.size = Vector2(inner, 18)
	target_bar_fill.position = Vector2(m, _bar_y)
	target_bar_fill.size = Vector2(0, 18)
	_twist_strip.position = Vector2(m, _bar_y + 22.0)
	_twist_strip.size = Vector2(inner, 44)
	_bounty_plaque.position = Vector2(m, top - 4.0)
	_bounty_plaque.scale = Vector2.ONE * (inner / 1160.0)
	# Four stat cells.
	var cy := _bar_y + 72.0
	var cw := (inner - 48.0) / 4.0
	_cells = []
	for i in 4:
		var cx := m + i * (cw + 16.0)
		UiKit.plate(hud_root, Rect2(cx, cy, cw, 124), "plain")
		var cap := _label(hud_root, "", Vector2(cx + 18.0, cy + 12.0), 20, DIM)
		cap.size = Vector2(cw - 36.0, 28)
		var val := _label(hud_root, "", Vector2(cx + 18.0, cy + 44.0), 44, GOLD)
		val.size = Vector2(cw - 36.0, 64)
		val.clip_text = true
		if FontLib.numbers != null:
			val.add_theme_font_override("font", FontLib.numbers)
			cap.add_theme_font_override("font", FontLib.label)
		_cells.append([cap, val])
	# The action bar along the bottom, then the kit row and the preview above it.
	var ay := h - Form.safe_bottom() - 120.0
	_clear_btn.position = Vector2(m, ay)
	_clear_btn.size = Vector2(232, 120)
	_clear_btn.add_theme_font_size_override("font_size", 30)
	_pays_btn = _button(hud_root, "PAYS", Vector2(w - m - 232.0, ay), Vector2(232, 120))
	_pays_btn.add_theme_font_size_override("font_size", 30)
	_pays_btn.tooltip_text = "What each poker hand pays at this table."
	_pays_btn.pressed.connect(_toggle_pays_sheet)
	_play_btn.position = Vector2(m + 248.0, ay)
	_play_btn.size = Vector2(inner - 2.0 * 248.0, 120)
	_play_btn.add_theme_font_size_override("font_size", 38)
	var ky := ay - 30.0 - 120.0
	var kit_w := inner * 0.58
	_kit_plate.position = Vector2(m, ky)
	_kit_plate.size = Vector2(kit_w, 120)
	for c in _kit_plate.get_children():
		(c as Control).size = _kit_plate.size
	_kit_title.position = Vector2(-400, -400)
	_kit_rects = [Rect2(m + kit_w + 16.0, ky + 4.0, inner - kit_w - 16.0, 112)]
	for i in _kit_btns.size():
		_kit_rects.append(Rect2(m + 14.0 + i * 112.0, ky + 10.0, 100, 100))
	var py := ky - 54.0
	preview_label.position = Vector2(m, py)
	preview_label.size = Vector2(inner, 44)
	preview_label.add_theme_font_size_override("font_size", 30)
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.clip_text = true
	# A strip under the board for the community cards (hold'em, the dealer)
	# and the outlaw's portrait.
	var sy := py - 160.0
	_community_plate.position = Vector2(m, sy)
	_community_plate.size = Vector2(inner, 150)
	for c in _community_plate.get_children():
		(c as Control).size = _community_plate.size
	_community_label.position = Vector2(m + 24.0, sy + 14.0)
	_community_label.add_theme_font_size_override("font_size", 24)
	community_display.position = Vector2(m + 210.0, sy + 75.0)
	community_display.scale = Vector2(1.05, 1.05)
	_community_w = inner - 420.0
	outlaw.position = Vector2(w - m - 130.0, sy + 40.0)
	outlaw.scale = Vector2(0.72, 0.72)
	# The board takes whatever is left between the cells and the preview;
	# tables with community cards or an outlaw give up the strip for them.
	var by := cy + 124.0 + 20.0
	_board_area_full = Rect2(m, by, inner, py - 12.0 - by)
	_board_area_strip = Rect2(m, by, inner, sy - 12.0 - by)
	_board_area = _board_area_full
	_apply_board_layout()
	meter_back.position = Vector2(w - 26.0, by)
	meter_back.size = Vector2(18, _board_area.size.y)
	meter_fill.position = Vector2(w - 24.0, by + 2.0)
	_meter_top = by + 2.0
	_meter_h = _board_area.size.y - 4.0
	meter_fill.size = Vector2(14, _meter_h)
	countdown_overlay.position = Vector2(0, by - 10.0)
	countdown_overlay.size = Vector2(w, _board_area.size.y + 20.0)
	announcer.position = Vector2(0, by)
	announcer.size = Vector2(w, _board_area.size.y)
	announcer.add_theme_font_size_override("font_size", 64)
	announcer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_plaque_rest_y = top + 12.0
	board.deal_anchor = _deck_btn.position + _deck_btn.size / 2.0
	_build_pays_sheet(ay)


## PAYS on the phone: the payouts table in a sheet over the board.
func _build_pays_sheet(above_y: float) -> void:
	_pays_sheet = ColorRect.new()
	(_pays_sheet as ColorRect).color = Color(0, 0, 0, 0.55)
	_pays_sheet.size = VIEW
	_pays_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_pays_sheet.visible = false
	_pays_sheet.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_pays_sheet.visible = false)
	ui_root.add_child(_pays_sheet)
	var sh := 760.0
	var rect := Rect2(36, above_y - 24.0 - sh, VIEW.x - 72.0, sh)
	UiKit.plate(_pays_sheet, rect)
	var title := _label(_pays_sheet, "PAYOUTS", rect.position + Vector2(40, 30), 30, DIM)
	title.size = Vector2(rect.size.x - 80.0, 40)
	for pl: Label in [_payout_names, _payout_values]:
		pl.reparent(_pays_sheet, false)
		pl.position = rect.position + Vector2(48, 96)
		pl.add_theme_font_size_override("font_size", 34)
		var f: Font = pl.get_theme_font("font")
		pl.add_theme_constant_override("line_spacing", int(56.0 - f.get_height(34)))
	_payout_values.size = Vector2(rect.size.x - 96.0, sh - 120.0)


func _toggle_pays_sheet() -> void:
	if _pays_sheet == null:
		return
	_pays_sheet.visible = not _pays_sheet.visible
	if _pays_sheet.visible:
		_pays_sheet.move_to_front()


## The four stat cells: score, then hands or time, then what the mode
## counts (trail cash and pay; arcade level and target; the deck).
func _update_cells() -> void:
	if _cells.size() < 4:
		return
	var vals := [["SCORE", str(int(_shown_score))], ["HANDS", str(hands_played)],
			["DECK", str(board.deck.size())], ["", ""]]
	match mode_kind:
		"time":
			var secs := ceili(time_left)
			vals[1] = ["TIME", "%d:%02d" % [secs / 60, secs % 60]]
		"arcade":
			vals[1] = ["LEVEL", str(level)]
			vals[3] = ["TARGET", str(_arcade_target())]
		"trail":
			if trail.in_room and trail.room_on_clock():
				var tsecs := ceili(trail.room_time_left)
				vals[1] = ["TIME", "%d:%02d" % [tsecs / 60, tsecs % 60]]
			else:
				vals[1] = ["HANDS", str(trail.room_hands_left)]
			vals[2] = ["CASH", "$%d" % trail.trail_cash]
			vals[3] = ["PAYS", "$%d" % trail._table_pay(trail.current_offer)
					if trail.in_room and not trail.current_offer.is_empty() else "—"]
	for i in 4:
		(_cells[i][0] as Label).text = String(vals[i][0])
		(_cells[i][1] as Label).text = String(vals[i][1])
	var warn := (mode_kind == "trail" and trail.in_room and (
			(trail.room_on_clock() and trail.room_time_left < 15.0)
			or (not trail.room_on_clock() and trail.room_hands_left <= 2))) \
			or (mode_kind == "time" and time_left < 15.0)
	(_cells[1][1] as Label).add_theme_color_override("font_color", RED if warn else GOLD)
	# The top bar's table line shrinks to fit (KING COBRA · SCORE HANDS…).
	if target_label.text != _target_fit_text:
		_target_fit_text = target_label.text
		var tf: Font = target_label.get_theme_font("font")
		var fs := 38
		while fs > 20 and tf.get_string_size(target_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x \
				> target_label.size.x:
			fs -= 1
		target_label.add_theme_font_size_override("font_size", fs)
	if _bet_tag != null:
		var bet_text := ""
		if mode_kind == "trail" and not trail.bet.is_empty():
			bet_text = "BET WON" if bool(trail.bet.get("paid", false)) \
					else "BET: " + String(TrailMode.BET_NAMES.get(String(trail.bet.get("target", "")), "")).to_upper()
		_bet_tag.text = bet_text


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
	if Form.is_mobile():
		_build_pause_mobile(title)
		return

	var resume := _button(pause_layer, "RESUME", Vector2(810, 470), Vector2(300, 64))
	resume.add_theme_font_size_override("font_size", 26)
	resume.pressed.connect(_toggle_pause)
	var restart := _button(pause_layer, "RESTART", Vector2(810, 552), Vector2(300, 64))
	restart.add_theme_font_size_override("font_size", 26)
	restart.pressed.connect(func() -> void:
		_toggle_pause()
		_restart())
	var to_menu := _button(pause_layer, "EXIT TO MENU", Vector2(810, 634), Vector2(300, 64))
	to_menu.add_theme_font_size_override("font_size", 24)
	to_menu.pressed.connect(func() -> void:
		_toggle_pause()
		_open_menu())
	_center_on(pause_layer, "It's safe to leave a trail table. It'll be waiting for you\njust the way you left it when you come back.", 712, 16, DIM)

	# Sound, right here — no need to leave the table to turn it down.
	_label(pause_layer, "MUSIC", Vector2(660, 790), 22, OFFWHITE)
	_pause_music_slider = _make_volume_slider(pause_layer, Vector2(830, 790),
			func(v: float) -> void:
				music_vol = v)
	_label(pause_layer, "SFX", Vector2(660, 848), 22, OFFWHITE)
	_pause_sfx_slider = _make_volume_slider(pause_layer, Vector2(830, 848),
			func(v: float) -> void:
				sfx_vol = v)
	if not OS.has_feature("web"):
		var quit := _button(pause_layer, "QUIT", Vector2(810, 930), Vector2(300, 56))
		quit.add_theme_font_size_override("font_size", 24)
		quit.pressed.connect(func() -> void:
			get_tree().quit())


## Pause on a phone: the same choices, stacked big for a thumb.
func _build_pause_mobile(title: Label) -> void:
	var w := VIEW.x
	var bw := w - 2.0 * 96.0
	title.position.y = Form.safe_top() + 260.0
	var y := Form.safe_top() + 520.0
	for spec in [["RESUME", _toggle_pause], ["RESTART", func() -> void:
				_toggle_pause()
				_restart()], ["EXIT TO MENU", func() -> void:
				_toggle_pause()
				_open_menu()]]:
		var b := _button(pause_layer, String(spec[0]), Vector2(96, y), Vector2(bw, 120), spec[0] == "RESUME")
		b.add_theme_font_size_override("font_size", 36)
		b.pressed.connect(spec[1])
		y += 150.0
	var note := _center_on(pause_layer, "It's safe to leave a trail table.\nIt'll be waiting just the way you left it.", y + 10.0, 26, DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	y += 150.0
	for spec in [["MUSIC", true], ["SFX", false]]:
		var lbl := _label(pause_layer, String(spec[0]), Vector2(96, y), 32, OFFWHITE)
		lbl.size = Vector2(160, 60)
		var slider := _make_volume_slider(pause_layer, Vector2(280, y + 6.0),
				(func(v: float) -> void: music_vol = v) if spec[1] else (func(v: float) -> void: sfx_vol = v))
		slider.size = Vector2(w - 280.0 - 96.0, 48)
		if spec[1]:
			_pause_music_slider = slider
		else:
			_pause_sfx_slider = slider
		y += 110.0


func _center_on(parent: Control, text: String, y: float, font_size: int, color: Color) -> Label:
	var l := _label(parent, text, Vector2(0, y), font_size, color)
	l.size = Vector2(VIEW.x, font_size * 3.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## A 0-1 volume slider wired through _apply_audio + settings save.
func _make_volume_slider(parent: Control, pos: Vector2, setter: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.position = pos
	s.size = Vector2(430, 36)
	UiKit.style_slider(s)
	parent.add_child(s)
	s.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		_apply_audio()
		_save_settings())
	return s


func _toggle_pause() -> void:
	if get_tree().paused:
		get_tree().paused = false
		pause_layer.visible = false
	elif game_started and not menu_open and not game_over:
		get_tree().paused = true
		_pause_music_slider.set_value_no_signal(music_vol)
		_pause_sfx_slider.set_value_no_signal(sfx_vol)
		pause_layer.visible = true


func _build_menu() -> void:
	# Translucent scrim: the dusk trail parallax rides behind the menu.
	menu_layer = ColorRect.new()
	menu_layer.color = Color(0.05, 0.05, 0.06, 0.62)
	menu_layer.size = VIEW
	ui_root.add_child(menu_layer)

	# Ghost cards drifting up behind the buttons, forever.
	for i in 7:
		var ghost := PlayingCard.new()
		ghost.rank = randi_range(2, 14)
		ghost.suit = randi_range(0, 3)
		ghost.modulate = Color(1, 1, 1, 0.13)
		ghost.scale = Vector2(1.4, 1.4)
		ghost.rotation = randf_range(-0.5, 0.5)
		var gx := randf_range(180.0, 1740.0)
		ghost.position = Vector2(gx, 1220.0)
		menu_layer.add_child(ghost)
		var dur := randf_range(16.0, 30.0)
		var gtw := create_tween().set_loops()
		gtw.tween_property(ghost, "position:y", -240.0, dur) \
				.from(1220.0 + i * 160.0)
		gtw.parallel().tween_property(ghost, "rotation",
				ghost.rotation + randf_range(-1.2, 1.2), dur)
		gtw.tween_callback(func() -> void:
			ghost.rank = randi_range(2, 14)
			ghost.suit = randi_range(0, 3)
			ghost.position.x = randf_range(180.0, 1740.0))

	# The brand logo rides the old wordmark's gentle bob.
	var title_logo := _logo(menu_layer, LOGO_STACKED, Rect2(735, 44, 450, 252))
	var ttw := create_tween().set_loops()
	ttw.tween_property(title_logo, "position:y", 38.0, 2.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ttw.tween_property(title_logo, "position:y", 50.0, 2.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_menu_center("Chain touching cards into poker hands", 280, 26, DIM)

	_profile_menu_btn = _button(menu_layer, "PROFILE %d" % profile, Vector2(60, 60), Vector2(240, 54))
	_profile_menu_btn.add_theme_font_size_override("font_size", 20)
	_profile_menu_btn.pressed.connect(func() -> void:
		transition(func() -> void:
			_refresh_profile_ui()
			profile_layer.visible = true))
	var stats_btn := _button(menu_layer, "STATS", Vector2(60, 124), Vector2(240, 54))
	stats_btn.add_theme_font_size_override("font_size", 20)
	stats_btn.pressed.connect(_open_stats)
	var how_btn := _button(menu_layer, "HOW TO PLAY", Vector2(1620, 60), Vector2(240, 54))
	how_btn.add_theme_font_size_override("font_size", 20)
	how_btn.pressed.connect(_start_tutorial)
	var contracts_btn := _button(menu_layer, "CONTRACTS", Vector2(1620, 124), Vector2(240, 54))
	contracts_btn.add_theme_font_size_override("font_size", 20)
	contracts_btn.pressed.connect(_open_contracts)
	var seeds_btn := _button(menu_layer, "SEEDED PLAY", Vector2(1620, 188), Vector2(240, 54))
	seeds_btn.add_theme_font_size_override("font_size", 20)
	seeds_btn.tooltip_text = "Play a seed, which deals the same game for everyone, and chase its high score. The DAILY RIDE is in here too."
	seeds_btn.pressed.connect(func() -> void:
		open_seeds())
	_contracts_pip = _gold_pip(Vector2(1836, 112))
	_build_level_plate()

	var trail_btn := _button(menu_layer, "THE TRAIL", Vector2(700, 336), Vector2(520, 66), true)
	trail_btn.add_theme_font_size_override("font_size", 26)
	trail_btn.pressed.connect(func() -> void:
		trail.open_trail())
	# The Outfitter: every $cash meta upgrade, right beside the ride.
	var upgrades_btn := _button(menu_layer, "UPGRADES", Vector2(1250, 336), Vector2(210, 66))
	upgrades_btn.add_theme_font_size_override("font_size", 20)
	upgrades_btn.pressed.connect(func() -> void:
		trail.open_upgrades())
	# A gold pip: how many unlocks the Outfitter hasn't shown yet.
	_upgrades_pip = _gold_pip(Vector2(1440, 322))
	_refresh_level_plate()
	_menu_center("Bet on how far you'll ride, build your deck, and bring your trail cash home.", 408, 20, DIM)

	_menu_center("TIME TRIAL", 456, 24, GOLD)
	var times := [60.0, 180.0, 300.0]
	var time_names := ["1:00", "3:00", "5:00"]
	for i in 3:
		var b := _button(menu_layer, time_names[i], Vector2(645 + i * 220, 494), Vector2(200, 56))
		b.add_theme_font_size_override("font_size", 22)
		var secs: float = times[i]
		b.pressed.connect(func() -> void:
			_start_mode("time", secs))
	_menu_center("Unlimited hands and a deck that reshuffles. Just beat the clock.", 558, 18, DIM)

	var single_btn := _button(menu_layer, "SINGLE DECK", Vector2(700, 604), Vector2(520, 60))
	single_btn.add_theme_font_size_override("font_size", 24)
	single_btn.pressed.connect(func() -> void:
		_start_mode("single"))
	_menu_center("One 52-card deck and no timer. Play until no hands are left.", 672, 18, DIM)

	var arcade_btn := _button(menu_layer, "ARCADE", Vector2(700, 712), Vector2(520, 60))
	arcade_btn.add_theme_font_size_override("font_size", 24)
	arcade_btn.pressed.connect(func() -> void:
		_start_mode("arcade"))
	_menu_center("Rising targets and an always-draining bar. Keep scoring or lose.", 780, 18, DIM)

	var zen_btn := _button(menu_layer, "ZEN", Vector2(700, 820), Vector2(520, 60))
	zen_btn.add_theme_font_size_override("font_size", 24)
	zen_btn.pressed.connect(func() -> void:
		_start_mode("zen"))
	_menu_center("No timer and no hand limit, and the deck never runs out.", 888, 18, DIM)

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
	_build_profiles_and_tutor()


func _build_profiles_and_tutor() -> void:
	# In-game tutorial instruction strip + skip button.
	# The tutorial's instructions ride a plate across the top of the table.
	_tut_panel = Control.new()
	_tut_panel.position = Vector2(370, 4)
	_tut_panel.size = Vector2(1180, 112)
	_tut_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tut_panel.visible = false
	hud_root.add_child(_tut_panel)
	UiKit.plate(_tut_panel, Rect2(Vector2.ZERO, _tut_panel.size))
	_tut_label = _label(_tut_panel, "", Vector2(24, 10), 19, GOLD)
	_tut_label.size = Vector2(1132, 92)
	_tut_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tut_skip_btn = _button(hud_root, "SKIP TUTORIAL", Vector2(PANEL_R, 60), Vector2(300, 50))
	_tut_skip_btn.add_theme_font_size_override("font_size", 20)
	_tut_skip_btn.visible = false
	_tut_skip_btn.pressed.connect(_end_tutorial)

	# Profile picker: three saddles.
	profile_layer = ColorRect.new()
	profile_layer.color = BG
	profile_layer.size = VIEW
	profile_layer.visible = false
	ui_root.add_child(profile_layer)
	var pt := _label(profile_layer, "CHOOSE YOUR SADDLE", Vector2(0, 140), 64, GOLD)
	pt.size = Vector2(VIEW.x, 90)
	pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in 3:
		var n := i + 1
		var slot := _button(profile_layer, "", Vector2(360 + i * 420, 360), Vector2(380, 300))
		slot.add_theme_font_size_override("font_size", 26)
		slot.pressed.connect(func() -> void:
			_select_profile(n))
		_profile_slot_btns.append(slot)
		var erase := _button(profile_layer, "ERASE", Vector2(460 + i * 420, 690), Vector2(180, 48))
		erase.add_theme_font_size_override("font_size", 18)
		erase.pressed.connect(func() -> void:
			if erase.text == "ERASE":
				erase.text = "SURE?"
			else:
				erase.text = "ERASE"
				_erase_profile(n))
	var pback := _button(profile_layer, "BACK", Vector2(860, 880), Vector2(200, 54))
	pback.add_theme_font_size_override("font_size", 20)
	pback.pressed.connect(func() -> void:
		transition(func() -> void:
			profile_layer.visible = false))
	_refresh_profile_ui()

	# The Ledger: lifetime stats for the active profile.
	stats_layer = ColorRect.new()
	stats_layer.color = BG
	stats_layer.size = VIEW
	stats_layer.visible = false
	ui_root.add_child(stats_layer)
	var st := _label(stats_layer, "THE LEDGER", Vector2(0, 110), 64, UiKit.BRASS_HI)
	st.size = Vector2(VIEW.x, 90)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var headers := ["AT THE TABLES", "ON THE TRAIL", "OTHER MODES"]
	for i in 3:
		var hx := 150.0 + i * 580.0
		# Each column on its own leather plate.
		UiKit.plate(stats_layer, Rect2(hx - 26, 240, 552, 640))
		var h := _label(stats_layer, headers[i], Vector2(hx, 262), 28, GOLD)
		h.size = Vector2(500, 40)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiKit.hrule(stats_layer, Vector2(hx + 50, 308), 400)
		var names := _label(stats_layer, "", Vector2(hx, 330), 22, OFFWHITE)
		names.size = Vector2(500, 560)
		var values := _label(stats_layer, "", Vector2(hx, 330), 22, GOLD)
		values.size = Vector2(500, 560)
		values.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_stats_cols.append([names, values])
	var sback := _button(stats_layer, "BACK", Vector2(860, 950), Vector2(200, 54))
	sback.add_theme_font_size_override("font_size", 20)
	sback.pressed.connect(func() -> void:
		transition(func() -> void:
			stats_layer.visible = false))

	# CONTRACTS: goals that pay cash, claimed here.
	contracts_layer = ColorRect.new()
	contracts_layer.color = BG
	contracts_layer.size = VIEW
	contracts_layer.visible = false
	ui_root.add_child(contracts_layer)
	var ct := _label(contracts_layer, "CONTRACTS", Vector2(0, 90), 64, UiKit.BRASS_HI)
	ct.size = Vector2(VIEW.x, 90)
	ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contracts_sub = _label(contracts_layer, "", Vector2(0, 186), 24, GOLD)
	_contracts_sub.size = Vector2(VIEW.x, 34)
	_contracts_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contracts_scroll = ScrollContainer.new()
	_contracts_scroll.position = Vector2(430, 246)
	_contracts_scroll.size = Vector2(1070, 680)
	_contracts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	contracts_layer.add_child(_contracts_scroll)
	_contracts_list = VBoxContainer.new()
	_contracts_list.add_theme_constant_override("separation", 10)
	_contracts_list.custom_minimum_size = Vector2(1040, 0)
	_contracts_scroll.add_child(_contracts_list)
	var cback := _button(contracts_layer, "BACK", Vector2(860, 960), Vector2(200, 54))
	cback.add_theme_font_size_override("font_size", 20)
	cback.pressed.connect(func() -> void:
		transition(func() -> void:
			contracts_layer.visible = false
			_refresh_level_plate()))

	# The one-time explainer popup, above everything in-game.
	tutor_layer = ColorRect.new()
	tutor_layer.color = Color(0, 0, 0, 0.65)
	tutor_layer.size = VIEW
	tutor_layer.visible = false
	tutor_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(tutor_layer)
	# A wanted poster: paper stock, heavy edge, nail heads, ink type.
	var panel := Panel.new()
	panel.position = Vector2(560, 300)
	panel.size = Vector2(800, 440)
	panel.add_theme_stylebox_override("panel", UiKit.poster_box())
	tutor_layer.add_child(panel)
	if not UiKit.has_art():
		# The painted paper bakes its own nail heads.
		var nails := UiKit.Rivets.new()
		nails.plate_size = Vector2(800, 440)
		panel.add_child(nails)
	_tutor_title = _label(tutor_layer, "", Vector2(560, 324), 40, RED)
	_tutor_title.size = Vector2(800, 60)
	_tutor_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for rule_y in [382.0, 388.0]:
		var rule := ColorRect.new()
		rule.color = UiKit.POSTER_EDGE
		rule.position = Vector2(660, rule_y)
		rule.size = Vector2(600, 2)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tutor_layer.add_child(rule)
	# The body lives in a scroll well: a long lesson scrolls instead of
	# running under the GOT IT button.
	_tutor_scroll = ScrollContainer.new()
	_tutor_scroll.position = Vector2(620, 411)
	_tutor_scroll.size = Vector2(680, 236)
	_tutor_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tutor_layer.add_child(_tutor_scroll)
	_tutor_body = Label.new()
	_tutor_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutor_body.custom_minimum_size = Vector2(655, 0)
	_tutor_body.add_theme_font_size_override("font_size", 26)
	UiKit.track_ink(_tutor_body)
	# Poster prose in Old Standard — ink on paper.
	if FontLib.body != null:
		_tutor_body.add_theme_font_override("font", FontLib.body)
	_tutor_scroll.add_child(_tutor_body)
	var ok := _button(tutor_layer, "GOT IT", Vector2(810, 660), Vector2(300, 60))
	ok.add_theme_font_size_override("font_size", 24)
	ok.pressed.connect(_tutor_next)

	# A fresh profile's first ride asks: learn the ropes, or skip them?
	_offer_layer = ColorRect.new()
	_offer_layer.color = Color(0, 0, 0, 0.7)
	_offer_layer.size = VIEW
	_offer_layer.visible = false
	_offer_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(_offer_layer)
	var offer_panel := Panel.new()
	offer_panel.position = Vector2(560, 330)
	offer_panel.size = Vector2(800, 400)
	offer_panel.add_theme_stylebox_override("panel", UiKit.poster_box())
	_offer_layer.add_child(offer_panel)
	if not UiKit.has_art():
		var offer_nails := UiKit.Rivets.new()
		offer_nails.plate_size = offer_panel.size
		offer_panel.add_child(offer_nails)
	var ot := _label(_offer_layer, "NEW IN TOWN?", Vector2(560, 360), 44, RED)
	ot.size = Vector2(800, 60)
	ot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ob := _label(_offer_layer, "A short tutorial shows you how to chain cards into poker hands. It takes about a minute, and you can replay it any time from HOW TO PLAY.",
			Vector2(640, 440), 26, UiKit.POSTER_INK)
	UiKit.track_ink(ob)
	ob.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ob.custom_minimum_size = Vector2(640, 0)
	ob.size = Vector2(640, 150)
	ob.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if FontLib.body != null:
		ob.add_theme_font_override("font", FontLib.body)
	var play := _button(_offer_layer, "PLAY THE TUTORIAL", Vector2(620, 620), Vector2(330, 64), true)
	play.add_theme_font_size_override("font_size", 22)
	play.pressed.connect(_offer_take_tutorial)
	var skip := _button(_offer_layer, "SKIP IT", Vector2(970, 620), Vector2(330, 64))
	skip.add_theme_font_size_override("font_size", 22)
	skip.pressed.connect(_offer_skip_tutorial)

	# Hover tooltip for board cards — above the HUD, ignores the mouse.
	_tooltip = PanelContainer.new()
	_tooltip.add_theme_stylebox_override("panel", UiKit.tooltip_box())
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.visible = false
	_tooltip_label = Label.new()
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_label.custom_minimum_size = Vector2(330, 0)
	_tooltip_label.add_theme_font_size_override("font_size", 18)
	if FontLib.body != null:
		_tooltip_label.add_theme_font_override("font", FontLib.body)
	_tooltip_label.add_theme_color_override("font_color", OFFWHITE)
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(_tooltip_label)
	hud_root.add_child(_tooltip)

	# A soft radial vignette framing play — above the HUD, below every
	# full-screen layer.
	# The round-2 kit paints one; the gradient is the fallback.
	var vin_tex: Texture2D = UiKit.tex("vignette")
	_vignette_rect_tex = vin_tex != null
	if vin_tex == null:
		var vin_grad := Gradient.new()
		vin_grad.set_color(0, Color(0, 0, 0, 0))
		vin_grad.add_point(0.62, Color(0, 0, 0, 0))
		vin_grad.set_color(vin_grad.get_point_count() - 1, Color(0, 0, 0, 0.32))
		var vin_fallback := GradientTexture2D.new()
		vin_fallback.gradient = vin_grad
		vin_fallback.fill = GradientTexture2D.FILL_RADIAL
		vin_fallback.fill_from = Vector2(0.5, 0.5)
		vin_fallback.fill_to = Vector2(0.5, -0.15)
		vin_fallback.width = 512
		vin_fallback.height = 512
		vin_tex = vin_fallback
	var vignette := TextureRect.new()
	vignette.texture = vin_tex
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.size = VIEW
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(vignette)
	_vignette = vignette
	# Built after the trail screens and menus, so pin it back down.
	ui_root.move_child(vignette, hud_root.get_index() + 1)

	# Dust motes drifting over the table while a game is on.
	_dust = CPUParticles2D.new()
	_dust.position = Vector2(960, 540) if not Form.is_mobile() else VIEW / 2.0
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(600, 520) if not Form.is_mobile() else VIEW / 2.0
	_dust.amount = 22
	_dust.lifetime = 9.0
	_dust.preprocess = 9.0
	_dust.explosiveness = 0.0
	_dust.direction = Vector2(-1, 0.3)
	_dust.spread = 30.0
	_dust.gravity = Vector2(-3, 2)
	_dust.initial_velocity_min = 6.0
	_dust.initial_velocity_max = 18.0
	_dust.scale_amount_min = 1.5
	_dust.scale_amount_max = 2.5
	_dust.color = Color(0.85, 0.78, 0.6, 0.10)
	add_child(_dust)


func _build_options() -> void:
	options_layer = ColorRect.new()
	options_layer.color = BG
	options_layer.size = VIEW
	options_layer.visible = false
	ui_root.add_child(options_layer)

	var title := _label(options_layer, "OPTIONS", Vector2(0, 110), 72, UiKit.BRASS_HI)
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
	# Classic leather and brass, or modern smoked glass.
	ui_style_btn = _button(options_layer, "", Vector2(700, 520 if not OS.has_feature("web") else 336),
			Vector2(520, 60))
	ui_style_btn.add_theme_font_size_override("font_size", 24)
	ui_style_btn.tooltip_text = "Classic is leather and brass. Modern is smoked glass. Casino is felt and lacquer. Machine is gunmetal and teal. Doctor is indigo clockwork."
	ui_style_btn.pressed.connect(func() -> void:
		var i := UiKit.STYLES.find(UiKit.style)
		_apply_ui_style(String(UiKit.STYLES[(i + 1) % UiKit.STYLES.size()]))
		_save_settings()
		_refresh_options_buttons())
	_refresh_options_buttons()

	var sh := _label(options_layer, "SOUND", Vector2(0, 610), 26, RED)
	sh.size = Vector2(VIEW.x, 40)
	sh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_label(options_layer, "MUSIC", Vector2(660, 668), 24, OFFWHITE)
	var music_slider := HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	music_slider.value = music_vol
	music_slider.position = Vector2(830, 668)
	music_slider.size = Vector2(430, 36)
	UiKit.style_slider(music_slider)
	options_layer.add_child(music_slider)
	music_slider.value_changed.connect(func(v: float) -> void:
		music_vol = v
		_apply_audio()
		_save_settings())

	_label(options_layer, "SFX", Vector2(660, 736), 24, OFFWHITE)
	var sfx_slider := HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.value = sfx_vol
	sfx_slider.position = Vector2(830, 736)
	sfx_slider.size = Vector2(430, 36)
	UiKit.style_slider(sfx_slider)
	options_layer.add_child(sfx_slider)
	sfx_slider.value_changed.connect(func(v: float) -> void:
		sfx_vol = v
		_apply_audio()
		_save_settings())

	var back := _button(options_layer, "BACK", Vector2(835, 880), Vector2(250, 60))
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(_close_options)


## Switches the UI style live; the painted vignette follows it.
func _apply_ui_style(ui_style: String) -> void:
	if not UiKit.set_style(ui_style):
		return
	var vin := UiKit.tex("vignette")
	if vin != null and _vignette != null and _vignette_rect_tex:
		_vignette.texture = vin
	# Off the table, the backdrop follows the style's home scene too.
	if mode_kind != "trail" or not trail.in_room:
		parallax.crossfade_scene(UiKit.menu_scene())


func _refresh_options_buttons() -> void:
	if ui_style_btn:
		ui_style_btn.text = "UI STYLE — %s" % String(UiKit.STYLE_NAMES[UiKit.style]).to_upper()
	if fullscreen_btn:
		fullscreen_btn.text = "FULLSCREEN — %s" % ("ON" if fullscreen_on else "OFF")
	if resolution_btn:
		var r := RESOLUTIONS[res_index]
		resolution_btn.text = "WINDOW SIZE — %d × %d" % [r.x, r.y]


func _open_stats() -> void:
	transition(_open_stats_now)


func _open_stats_now() -> void:
	var s := func(key: String) -> int:
		return int(stats.get(key, 0))
	# Favorite hand: the poker hand scored most often.
	var fav := "—"
	var fav_n := 0
	for hand_name in stats_hands:
		if int(stats_hands[hand_name]) > fav_n:
			fav_n = int(stats_hands[hand_name])
			fav = "%s ×%d" % [hand_name, fav_n]
	var tables: Array = [
		["Hands played", str(s.call("hands_played"))],
		["Cards popped", str(s.call("cards_popped"))],
		["Best hand", "%d pts" % s.call("best_hand")],
		["Favorite hand", fav],
		["Flushes", str(int(stats_hands.get("Flush", 0)))],
		["Full Houses", str(int(stats_hands.get("Full House", 0)))],
		["Straight Flushes", str(int(stats_hands.get("Straight Flush", 0)))],
		["Royal Flushes", str(int(stats_hands.get("Royal Flush", 0)))],
	]
	var the_trail: Array = [
		["Rider level", "%d" % trail.progress.level()],
		["Rides started",str(s.call("trail_runs"))],
		["Trails completed", str(s.call("trail_wins"))],
		["Best ride score", str(s.call("trail_score_best"))],
		["Busted out", str(s.call("trail_busts"))],
		["Deepest table", "%d / %d" % [s.call("deepest_table"), TrailMode.ROOMS_TOTAL]],
		["Tables cleared", str(s.call("tables_cleared"))],
		["Bosses beaten", str(s.call("bosses_beaten"))],
		["Duels won", str(s.call("duels_won"))],
		["Blackjack rounds won", str(s.call("blackjack_rounds"))],
		["Relics found", str(s.call("relics_found"))],
		["Cash banked", "$%d" % trail.cash],
	]
	var other: Array = [
		["Arcade runs", str(s.call("arcade_games"))],
		["Best arcade level", str(s.call("arcade_best_level"))],
		["Best arcade score", str(s.call("arcade_best"))],
		["Time trials played",str(s.call("time_games"))],
		["Best time-trial score", str(s.call("time_best"))],
		["Single decks played", str(s.call("single_games"))],
		["Best single-deck score", str(s.call("single_best"))],
		["Perfect clears", str(s.call("perfect_clears"))],
	]
	var cols: Array = [tables, the_trail, other]
	for i in 3:
		var names := PackedStringArray()
		var values := PackedStringArray()
		for row: Array in cols[i]:
			names.append(String(row[0]))
			values.append(String(row[1]))
		(_stats_cols[i][0] as Label).text = "\n".join(names)
		(_stats_cols[i][1] as Label).text = "\n".join(values)
	stats_layer.visible = true


# --- SEEDED PLAY: pick a mode and a seed, chase its board ----------------

const SEED_MODES := [["trail", "TRAIL", 0.0], ["time60", "1:00", 60.0], ["time180", "3:00", 180.0],
		["time300", "5:00", 300.0], ["single", "SINGLE", 0.0], ["arcade", "ARCADE", 0.0],
		["zen", "ZEN", 0.0]]
var seeds_layer: ColorRect
var _seed_mode := "trail"
var _seed_rider := "the_gambler"
var _seed_asc := 0
var _seed_daily := false
var _seed_edit: LineEdit
var _seed_mode_btns := {}
var _seed_rider_btns := {}
var _seed_trail_box: Control
var _seed_asc_label: Label
var _seed_best: Label
var _seed_rules: Label
var _seed_warn: Label
var _seed_recent_box: VBoxContainer
var _seed_start: Button
var _seed_board_box: VBoxContainer   # the online top ten
var _shown_board_key := ""           # the board the top ten is showing (or loading)
var _seed_name_edit: LineEdit


## Opens SEEDED PLAY, optionally on a given mode and seed (the last
## page's PLAY THIS SEED lands here).
func open_seeds(mode := "", seed_text := "", rider := "", asc := -1) -> void:
	if mode != "":
		_seed_mode = mode
	if seed_text != "":
		_seed_edit.text = SeedRng.pretty(seed_text)
	elif _seed_edit.text == "":
		_seed_edit.text = SeedRng.pretty(SeedRng.random_seed())
	if rider != "":
		_seed_rider = rider
	if asc >= 0:
		_seed_asc = asc
	_seed_daily = SeedRng.is_daily(seed_text)
	transition(func() -> void:
		trail._hide_all()
		menu_layer.visible = false
		over_layer.visible = false
		_refresh_seeds()
		seeds_layer.visible = true)


func _seed_text() -> String:
	return SeedRng.daily_seed() if _seed_daily else SeedRng.normalize(_seed_edit.text)


## The board the page is showing.
func _seed_key() -> String:
	var st := _seed_text()
	match _seed_mode:
		"trail":
			if _seed_daily:
				return SeedBook.key("daily", st, _seed_rider)
			return SeedBook.key("trail", st, SeedBook.trail_variant(_seed_rider, _seed_asc))
		"time60", "time180", "time300":
			return SeedBook.key("time", st, _seed_mode.substr(4))
	return SeedBook.key(_seed_mode, st, "")


func _refresh_seeds() -> void:
	for k in _seed_mode_btns:
		trail._style_signature_toggle(_seed_mode_btns[k], k == _seed_mode)
	var is_trail := _seed_mode == "trail"
	_seed_trail_box.visible = is_trail
	var top: int = 0 if _seed_daily else trail.progress.asc_max(_seed_rider)
	_seed_asc = clampi(_seed_asc, 0, top)
	_seed_asc_label.text = "ASCENSION %d" % _seed_asc
	for r in _seed_rider_btns:
		trail._style_signature_toggle(_seed_rider_btns[r], r == _seed_rider)
	var st := _seed_text()
	var ok := SeedRng.is_valid(st)
	_seed_start.disabled = not ok
	_seed_edit.editable = not _seed_daily
	if _seed_daily:
		_seed_edit.text = SeedRng.pretty(st)
	var best := seed_book.best(_seed_key()) if ok else 0
	_seed_best.text = ("YOUR BEST ON THIS SEED:  %d" % best) if best > 0 \
			else ("NO SCORE ON THIS SEED YET" if ok else "A SEED IS 8 LETTERS AND NUMBERS")
	if is_trail:
		_seed_rules.text = "A seeded ride uses the STANDARD LOADOUT: every relic, provision and card on the trail at base power, no Outfitter gear, and any rider you like. You'll earn EXP, but not cash, Ascension levels or progress toward the next rider. Everyone on this seed rides the exact same trail."
	else:
		_seed_rules.text = "The same seed deals the same table, in the same order, for everyone who plays it."
	_seed_warn.text = ""
	if is_trail and trail._has_saved_run():
		_seed_warn.text = "Starting a seeded ride ends your saved ride, but you keep its EXP."
	if _seed_daily:
		var used := seed_book.daily_used(st)
		_seed_start.text = "PRACTICE THE DAILY" if used else "RIDE THE DAILY"
		if used:
			_seed_warn.text = "You've used today's scored daily ride, so this one is just practice."
	else:
		_seed_start.text = "START"
	if _seed_name_edit != null and not _seed_name_edit.has_focus():
		_seed_name_edit.text = seed_book.player_name
		_seed_name_edit.placeholder_text = seed_book.display_name()
	_show_online_board(_seed_key() if ok else "")
	for c in _seed_recent_box.get_children():
		c.queue_free()
	for e in seed_book.recent(4):
		var b := _button(_seed_recent_box, "", Vector2.ZERO, Vector2(520, 36))
		b.custom_minimum_size = Vector2(520, 36)
		b.add_theme_font_size_override("font_size", 15)
		var mode := String(e.mode)
		var v := String(e.get("variant", ""))
		var label := SeedRng.pretty(String(e.seed))
		if mode == "time":
			label = "TIME %d:%02d  ·  %s" % [int(v) / 60, int(v) % 60, label]
		elif mode != "daily":
			label = "%s  ·  %s" % [mode.to_upper(), label]
		if v != "" and mode != "time":
			label += "  ·  " + v.replace("the_", "").replace("-a", " A")
		b.text = "%s   —   %d" % [label, int(e.get("best", 0))]
		var row: Dictionary = e
		b.pressed.connect(func() -> void:
			_load_seed_row(row))


## The page's online top ten: loading, the rows, or offline.
func _show_online_board(k: String) -> void:
	if k == _shown_board_key:
		return
	_shown_board_key = k
	if k == "":
		_board_message("")
	elif not Leaderboard.live():
		_board_message("You're offline. Your best scores are still saved on this machine.")
	else:
		_board_message("Loading the board…")
		leaderboard.fetch_top(k)


func _board_message(text: String) -> void:
	for c in _seed_board_box.get_children():
		c.queue_free()
	if text != "":
		var head := _label(_seed_board_box, "ONLINE TOP 10", Vector2.ZERO, 22, GOLD)
		head.custom_minimum_size = Vector2(540, 34)
		var l := _label(_seed_board_box, text, Vector2.ZERO, 17, DIM)
		l.custom_minimum_size = Vector2(540, 60)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _on_board_failed(k: String) -> void:
	if k == _shown_board_key:
		_board_message("Can't reach the online board right now. Your best scores are still saved on this machine.")


func _on_board_fetched(k: String, rows: Array) -> void:
	if k != _shown_board_key:
		return
	_board_message("")
	var head := _label(_seed_board_box, "ONLINE TOP 10", Vector2.ZERO, 22, GOLD)
	head.custom_minimum_size = Vector2(540, 34)
	if rows.is_empty():
		var none := _label(_seed_board_box, "No one has posted on this seed yet. Be the first.",
				Vector2.ZERO, 17, DIM)
		none.custom_minimum_size = Vector2(540, 30)
		return
	for i in rows.size():
		var r: Dictionary = rows[i]
		var mine := String(r.get("player_id", "")) == seed_book.player_id and seed_book.player_id != ""
		var line := HBoxContainer.new()
		line.custom_minimum_size = Vector2(540, 30)
		_seed_board_box.add_child(line)
		var who := _label(line, "%2d.  %s" % [i + 1, String(r.get("player_name", "?"))], Vector2.ZERO,
				19, GOLD if mine else OFFWHITE)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pts := _label(line, "%d" % int(r.get("score", 0)), Vector2.ZERO, 19, GOLD if mine else OFFWHITE)
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


## Clicking a recent seed loads its board back onto the page.
func _load_seed_row(e: Dictionary) -> void:
	_seed_daily = String(e.mode) == "daily"
	match String(e.mode):
		"trail", "daily":
			_seed_mode = "trail"
			var v := String(e.get("variant", ""))
			if v.contains("-a"):
				_seed_rider = v.get_slice("-a", 0)
				_seed_asc = int(v.get_slice("-a", 1))
			elif v != "":
				_seed_rider = v
		"time":
			_seed_mode = "time" + String(e.get("variant", "60"))
		_:
			_seed_mode = String(e.mode)
	if not _seed_daily:
		_seed_edit.text = SeedRng.pretty(String(e.seed))
	board._play_sound(Board.SFX_CLICK, 1.1, -10.0)
	_refresh_seeds()


func _start_seeded() -> void:
	var st := _seed_text()
	if not SeedRng.is_valid(st):
		board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		return
	seeds_layer.visible = false
	if _seed_mode == "trail":
		trail.character = _seed_rider
		trail.next_seed = st
		trail.next_standard = true
		trail.next_daily = _seed_daily
		menu_open = false
		trail._start_run(0 if _seed_daily else _seed_asc)
		return
	next_mode_seed = st
	match _seed_mode:
		"time60":
			_start_mode("time", 60.0)
		"time180":
			_start_mode("time", 180.0)
		"time300":
			_start_mode("time", 300.0)
		_:
			_start_mode(_seed_mode)


func _build_seeds() -> void:
	seeds_layer = ColorRect.new()
	seeds_layer.color = BG
	seeds_layer.size = VIEW
	seeds_layer.visible = false
	ui_root.add_child(seeds_layer)
	var title := _label(seeds_layer, "SEEDED PLAY", Vector2(0, 70), 64, UiKit.BRASS_HI)
	title.size = Vector2(VIEW.x, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(seeds_layer, "One seed deals the same game for everyone. Share it and beat it.",
			Vector2(0, 160), 22, DIM)
	sub.size = Vector2(VIEW.x, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in SEED_MODES.size():
		var key := String(SEED_MODES[i][0])
		var mb := _button(seeds_layer, String(SEED_MODES[i][1]), Vector2(395 + i * 165, 212), Vector2(155, 50))
		mb.focus_mode = Control.FOCUS_NONE
		mb.pressed.connect(func() -> void:
			_seed_mode = key
			if key != "trail":
				_seed_daily = false
			board._play_sound(Board.SFX_FLIP, 1.2, -10.0)
			_refresh_seeds())
		_seed_mode_btns[key] = mb
	# The seed itself.
	var sl := _label(seeds_layer, "SEED", Vector2(395, 300), 26, GOLD)
	sl.size = Vector2(100, 56)
	sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_seed_edit = LineEdit.new()
	_seed_edit.position = Vector2(500, 300)
	_seed_edit.size = Vector2(360, 56)
	_seed_edit.max_length = 16
	_seed_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seed_edit.add_theme_font_size_override("font_size", 28)
	_seed_edit.add_theme_stylebox_override("normal", UiKit.inset_box())
	_seed_edit.add_theme_stylebox_override("focus", UiKit.inset_box())
	_seed_edit.add_theme_color_override("font_color", GOLD)
	if FontLib.display != null:
		_seed_edit.add_theme_font_override("font", FontLib.display)
	_seed_edit.text_changed.connect(func(_t: String) -> void:
		_refresh_seeds())
	seeds_layer.add_child(_seed_edit)
	var rnd := _button(seeds_layer, "RANDOM", Vector2(880, 300), Vector2(170, 56))
	rnd.pressed.connect(func() -> void:
		_seed_daily = false
		_seed_edit.text = SeedRng.pretty(SeedRng.random_seed())
		_refresh_seeds())
	var paste := _button(seeds_layer, "PASTE", Vector2(1065, 300), Vector2(150, 56))
	paste.pressed.connect(func() -> void:
		_seed_daily = false
		_seed_edit.text = SeedRng.pretty(SeedRng.normalize(DisplayServer.clipboard_get()))
		_refresh_seeds())
	var copy := _button(seeds_layer, "COPY", Vector2(1230, 300), Vector2(130, 56))
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(SeedRng.pretty(_seed_text()))
		_announce("SEED COPIED"))
	var daily := _button(seeds_layer, "DAILY RIDE", Vector2(1375, 300), Vector2(180, 56), true)
	daily.tooltip_text = "Today's seed: the same trail for everyone, at Ascension 0. You get one scored ride a day."
	daily.pressed.connect(func() -> void:
		_seed_daily = true
		_seed_mode = "trail"
		_seed_asc = 0
		board._play_sound(Board.SFX_FLIP, 1.0, -8.0)
		_refresh_seeds())
	# Trail: the rider and the Ascension.
	_seed_trail_box = Control.new()
	_seed_trail_box.size = VIEW
	_seed_trail_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seeds_layer.add_child(_seed_trail_box)
	var riders := ["the_gambler", "the_machine", "the_doctor"]
	for i in riders.size():
		var rid: String = riders[i]
		var rb := _button(_seed_trail_box, String(TrailMode.CHARACTERS[rid].name).to_upper(),
				Vector2(395 + i * 210, 390), Vector2(200, 50))
		rb.focus_mode = Control.FOCUS_NONE
		rb.pressed.connect(func() -> void:
			_seed_rider = rid
			_refresh_seeds())
		_seed_rider_btns[rid] = rb
	var prev := _button(_seed_trail_box, "◀", Vector2(1075, 390), Vector2(60, 50))
	prev.pressed.connect(func() -> void:
		_seed_asc -= 1
		_refresh_seeds())
	_seed_asc_label = _label(_seed_trail_box, "", Vector2(1140, 390), 26, GOLD)
	_seed_asc_label.size = Vector2(250, 50)
	_seed_asc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seed_asc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var nxt := _button(_seed_trail_box, "▶", Vector2(1395, 390), Vector2(60, 50))
	nxt.pressed.connect(func() -> void:
		_seed_asc += 1
		_refresh_seeds())
	# Your best, the rules, the warning; recent seeds; the online board.
	UiKit.plate(seeds_layer, Rect2(395, 470, 560, 410))
	_seed_best = _label(seeds_layer, "", Vector2(420, 490), 24, GOLD)
	_seed_best.size = Vector2(510, 34)
	_seed_rules = _label(seeds_layer, "", Vector2(420, 534), 16, OFFWHITE)
	_seed_rules.size = Vector2(510, 120)
	_seed_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rl := _label(seeds_layer, "RECENT SEEDS", Vector2(420, 662), 20, GOLD)
	rl.size = Vector2(300, 28)
	_seed_recent_box = VBoxContainer.new()
	_seed_recent_box.position = Vector2(415, 694)
	_seed_recent_box.add_theme_constant_override("separation", 6)
	seeds_layer.add_child(_seed_recent_box)
	UiKit.plate(seeds_layer, Rect2(965, 470, 590, 410))
	_seed_board_box = VBoxContainer.new()
	_seed_board_box.position = Vector2(990, 490)
	_seed_board_box.size = Vector2(540, 370)
	_seed_board_box.add_theme_constant_override("separation", 2)
	seeds_layer.add_child(_seed_board_box)
	_seed_warn = _label(seeds_layer, "", Vector2(0, 892), 18, RED)
	_seed_warn.size = Vector2(VIEW.x, 26)
	_seed_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nl := _label(seeds_layer, "NAME", Vector2(1160, 930), 22, GOLD)
	nl.size = Vector2(90, 56)
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_seed_name_edit = LineEdit.new()
	_seed_name_edit.position = Vector2(1250, 930)
	_seed_name_edit.size = Vector2(305, 56)
	_seed_name_edit.max_length = SeedBook.NAME_MAX
	_seed_name_edit.add_theme_font_size_override("font_size", 22)
	_seed_name_edit.add_theme_stylebox_override("normal", UiKit.inset_box())
	_seed_name_edit.add_theme_stylebox_override("focus", UiKit.inset_box())
	_seed_name_edit.add_theme_color_override("font_color", OFFWHITE)
	_seed_name_edit.tooltip_text = "The name your scores post under on the online boards (up to 12 letters)."
	_seed_name_edit.text_changed.connect(func(t: String) -> void:
		seed_book.player_name = SeedBook.clean_name(t)
		seed_book.save())
	seeds_layer.add_child(_seed_name_edit)
	_seed_start = _button(seeds_layer, "START", Vector2(810, 926), Vector2(300, 64), true)
	_seed_start.add_theme_font_size_override("font_size", 26)
	_seed_start.pressed.connect(_start_seeded)
	var back := _button(seeds_layer, "BACK", Vector2(60, 970), Vector2(200, 54))
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(func() -> void:
		transition(func() -> void:
			seeds_layer.visible = false
			_open_menu_now()))


func _open_contracts() -> void:
	transition(func() -> void:
		_contracts_scroll.scroll_vertical = 0
		_refresh_contracts()
		contracts_layer.visible = true)


## Rebuilds the contract rows: ready to claim on top, then in progress,
## then greyed (content not unlocked), then claimed.
func _refresh_contracts() -> void:
	var rows := Contracts.sorted(stats, stats_hands, trail.progress)
	var ready := 0
	for r in rows:
		if r.state == "ready":
			ready += 1
	_contracts_sub.text = "CASH  $%d%s" % [trail.cash,
			"   ·   %d READY TO CLAIM" % ready if ready > 0 else ""]
	var keep := _contracts_scroll.scroll_vertical
	for child in _contracts_list.get_children():
		_contracts_list.remove_child(child)
		child.queue_free()
	for r in rows:
		_contracts_list.add_child(_contract_row(r.c, String(r.state)))
	_contracts_scroll.set_deferred("scroll_vertical", keep)


func _contract_row(c: Dictionary, state: String) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(1040, 84)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	UiKit.plate(row, Rect2(0, 0, 1040, 84))
	var name_l := _label(row, String(c.name), Vector2(28, 8), 22, GOLD)
	name_l.size = Vector2(600, 30)
	var desc := _label(row, String(c.desc), Vector2(28, 42), 16, OFFWHITE)
	desc.size = Vector2(620, 26)
	desc.clip_text = true
	var reward := _label(row, "$%d" % int(c.reward), Vector2(900, 10), 22, GOLD)
	reward.size = Vector2(120, 30)
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	match state:
		"ready":
			reward.visible = false
			var b := _button(row, "CLAIM  $%d" % int(c.reward), Vector2(764, 18),
					Vector2(256, 48), true)
			b.add_theme_font_size_override("font_size", 20)
			var id := String(c.id)
			b.pressed.connect(func() -> void:
				_claim_contract(id))
		"open":
			var have := Contracts.progress_of(c, stats, stats_hands)
			var count := _label(row, "%d / %d" % [have, int(c.target)],
					Vector2(660, 10), 18, DIM)
			count.size = Vector2(220, 26)
			var track := Panel.new()
			track.position = Vector2(660, 48)
			track.size = Vector2(360, 12)
			track.mouse_filter = Control.MOUSE_FILTER_IGNORE
			track.add_theme_stylebox_override("panel", UiKit.bar_box("track"))
			row.add_child(track)
			var fill := Panel.new()
			fill.position = Vector2(660, 48)
			fill.size = Vector2(360.0 * float(have) / maxf(1.0, float(c.target)), 12)
			fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fill.add_theme_stylebox_override("panel", UiKit.bar_box("gold"))
			row.add_child(fill)
		"locked":
			row.modulate = Color(1, 1, 1, 0.45)
			var lock := _label(row, Contracts.lock_text(c, trail.progress),
					Vector2(560, 48), 16, DIM)
			lock.size = Vector2(460, 26)
			lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		"claimed":
			row.modulate = Color(1, 1, 1, 0.55)
			reward.text = "CLAIMED  ·  $%d" % int(c.reward)
			reward.position.x = 720
			reward.size.x = 300
			reward.add_theme_color_override("font_color", DIM)
	return row


func _claim_contract(id: String) -> void:
	var paid: int = trail.claim_contract(id)
	if paid <= 0:
		board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		return
	board._play_sound(Board.SFX_COINS.pick_random(), 1.0, -6.0)
	_announce("CONTRACT CLAIMED  +$%d" % paid)
	_refresh_contracts()


func _open_options() -> void:
	transition(func() -> void:
		menu_layer.visible = false
		options_layer.visible = true)


func _close_options() -> void:
	transition(func() -> void:
		options_layer.visible = false
		menu_layer.visible = true)


func _build_splash() -> void:
	splash_layer = ColorRect.new()
	splash_layer.color = BG
	splash_layer.size = VIEW
	ui_root.add_child(splash_layer)
	_logo(splash_layer, LOGO_STACKED, Rect2(610, 180, 700, 392))
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
		play_music("menu")


func _menu_center(text: String, y: float, font_size: int, color: Color) -> Label:
	var l := _label(menu_layer, text, Vector2(0, y), font_size, color)
	l.size = Vector2(VIEW.x, font_size * 2.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## A brand image fitted into a rect, keeping its aspect.
func _logo(parent: Control, tex: Texture2D, rect: Rect2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	# expand_mode must be set BEFORE size: with the default KEEP_SIZE
	# the texture's full resolution is the minimum, and the rect
	# refuses to shrink below it (the Label autowrap pitfall again).
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.position = rect.position
	tr.size = rect.size
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr


func _label(parent: Control, text: String, pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	# The round-2 type ruling: Rye for display sizes, Oswald for every
	# other UI string (prose call sites switch to FontLib.body).
	if size >= 36 and FontLib.display != null:
		l.add_theme_font_override("font", FontLib.display)
	elif FontLib.label != null:
		l.add_theme_font_override("font", FontLib.label)
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, pos: Vector2, btn_size: Vector2,
		primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = btn_size
	b.focus_mode = Control.FOCUS_NONE
	# Every button in the game clicks — one wire, all screens, one
	# simple consistent sound.
	b.pressed.connect(func() -> void:
		board._play_sound(Board.SFX_CLICK, 1.15, -14.0))
	# Painted oak (or oxblood for the big calls to action) with a flat
	# leather fallback — the kit owns every state.
	UiKit.style_button(b, primary)
	b.add_theme_font_size_override("font_size", 17)
	UiKit.track_button(b)
	# A small lean-in on hover (not on touch, where there is no hover).
	b.pivot_offset = btn_size / 2.0
	if Form.is_touch():
		parent.add_child(b)
		return b
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			# The faintest tick — presence, not noise.
			board._play_sound(Board.SFX_CLICK, 1.45, -26.0)
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(1.04, 1.04), 0.08) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	b.mouse_exited.connect(func() -> void:
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.08) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
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
	# POKERPOP_SCENE swaps the backdrop once the table is up (trail_dusk…);
	# POKERPOP_FADE starts a slow crossfade to one, to catch it halfway.
	if OS.get_environment("POKERPOP_SCENE") != "":
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			parallax.set_scene(OS.get_environment("POKERPOP_SCENE")))
	if OS.get_environment("POKERPOP_FADE") != "":
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			parallax.crossfade_scene(OS.get_environment("POKERPOP_FADE"), 6.4))
	# POKERPOP_HOVER=x,y parks the mouse there (view pixels) and waits for
	# the hover tip before the shot.
	var hover := OS.get_environment("POKERPOP_HOVER")
	if hover != "":
		await get_tree().create_timer(3.0).timeout
		var xy := hover.split(",")
		var at := Vector2(float(xy[0]), float(xy[1]))
		Input.warp_mouse(at * Vector2(get_window().size) / VIEW)
		_ui_tip_force = _tip_control_at(ui_root, at)
		await get_tree().create_timer(1.2).timeout
		get_viewport().get_texture().get_image().save_png(path)
		get_tree().quit()
		return
	match OS.get_environment("POKERPOP_MODE"):
		"trailhazard", "trailtwist", "trailheist", "trailboss", "trailbj", "trailholdem", "trailpick", "cardgrid", "trailover", "tutorial", "trailcallout":
			# The last page's EXP bar and level-up banner come in last.
			# POKERPOP_WAIT=seconds holds the shot longer (a phone's level-up banner).
			var shot_wait := 6.2 if OS.get_environment("POKERPOP_MODE") in ["trailover", "trailcallout"] else 4.2
			if OS.get_environment("POKERPOP_WAIT") != "":
				shot_wait = float(OS.get_environment("POKERPOP_WAIT"))
			await get_tree().create_timer(shot_wait).timeout
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
