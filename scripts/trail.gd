class_name TrailMode
extends Node

## Trail mode: a betting roguelike run. Buy in for a chip stack, ride
## 21 tables, wager chips at every one, sculpt your deck as you go.
## Bankruptcy ends the run; chips become permanent cash ONLY by
## finishing the trail (gold cards pay $1 apiece along the way).
## v1 scope: risk-tiered Normal rooms + shops. Bosses, room-rule
## variety, and card modifiers beyond Cursed come later (TRAIL_MODE.md).

const ROOMS_TOTAL := 21
const REGION_SIZE := 7
# Every 7th room is a boss; the tarot deals a single court card.
const BOSS_ROOMS := {6: "jack", 13: "queen", 20: "cobra"}
const JACK_ROOM := 6
const QUEEN_ROOM := 13
# Beyond the Jack the trail plays for real money: every cost — antes,
# bets, shop goods, relics, the forge — runs 6×, and beyond the
# Queen it jumps 6× again (36× the frontier prices). A won boss
# all-in quadruples the stack (3:1), so the wall stings without
# flattening riders who limped through.
const POST_BOSS_COST_MULT := 6
const BOSSES := {
	"jack": {"tarot": "THE JACK", "name": "Jack of All Trades", "hands": 30},
	"queen": {"tarot": "THE QUEEN", "name": "Queen Bee", "hands": 14},
	"cobra": {"tarot": "THE KING", "name": "King Cobra", "hands": 14},
}

# Buy-in tables: [name, cash cost, starting chips, cash-out rate,
# target multiplier, blind multiplier]
const TABLES := [
	{"name": "PENNY ANTE", "cost": 0, "chips": 140, "rate": 1.0, "target_mult": 1.0, "blind_mult": 1.0},
	{"name": "TABLE STAKES", "cost": 250, "chips": 300, "rate": 1.5, "target_mult": 1.35, "blind_mult": 1.5},
	{"name": "HIGH ROLLER", "cost": 1000, "chips": 600, "rate": 2.5, "target_mult": 1.75, "blind_mult": 2.0},
]

# Room risk tiers offered by the draw, named for what they pay — a
# safe grind, a sweetened pot, a rich table that'll bleed you.
# "hands" is the budget the table deals you — it shrinks as the
# trail deepens; the player doesn't haggle over it.
const RISKS := [
	{"tarot": "EASY MONEY", "label": "Steady", "target_scale": 0.85, "odds": 1.0, "hands": 11},
	{"tarot": "FAT POT", "label": "Risky", "target_scale": 1.15, "odds": 1.5, "hands": 9},
	{"tarot": "HIGH STAKES", "label": "Dangerous", "target_scale": 1.4, "odds": 2.0, "hands": 8},
]

# Entering a room costs its ANTE (the house keeps it, win or lose),
# then you BET chips on yourself at the table's posted odds. The hand
# (or minute) budget is fixed by the table and tightens with depth.
const MAX_HANDS_BUY := 12
const WIN_LINGER_SECS := 2.5  # savour a cleared table before the pick

# Hazards are AMBIENT: any play room (bosses included) can be seeded,
# with the chance and count climbing with depth and table stakes. The
# tarot decides only the room's GOAL.
const HAZARD_KINDS := ["bomb", "fire", "wind", "stone", "water"]
const HAZARD_BASE_CHANCE := 0.20
const HAZARD_ROOM_STEP := 0.055  # + per room index — deep tables always bite
const HAZARD_TIER_STEP := 0.15   # + per buy-in tier
const HAZARD_COUNT_ROOMS := 5    # seed count grows every N tables
const HAZARD_COUNT_MAX := 6
# Every refill can deal danger: chance per fresh card, climbing with
# depth. Purge rooms are exempt (extra hazards would warp the goal).
const REFILL_HAZARD_BASE := 0.03
const REFILL_HAZARD_STEP := 0.006  # + per room index
const REFILL_HAZARD_MAX := 0.16
const OBJECTIVE_CHANCE := 0.12   # heist/treasure rooms, from room 2 on
const PURGE_CHANCE := 0.12       # purge rooms: clear a QUOTA of one hazard kind
const COLLECT_CHANCE := 0.08     # roundup rooms: clear called suits/ranks
const LANDRUSH_CHANCE := 0.07    # land rush: clear a card from every cell
const PURGE_SEED := 4            # hazards on the table at the deal
const PURGE_QUOTA_BASE := 10     # total to clear (+ per region below)
const PURGE_QUOTA_REGION := 2    # deeper tables demand more
const PURGE_FLOOR := 4           # trickle keeps at least this many on board
const PURGE_TRICKLE := 2         # at most this many arrive per hand
const CRAZY8_HAZARDS_BASE := 6   # crazy-8s hazard storm (+1 per region)
const BLACKJACK_HAZARDS_BASE := 4  # blackjack table hazards (+1 per region)
const REQUIRE_CHANCE := 0.10     # called-hands rooms: play the demanded hands
const ROYAL_CHANCE := 0.10       # of called-hands rooms (region 2+): THE WORLD
const TIMED_MAX_MINUTES := 6     # the most time a clock table will sell
# Variant rooms that play by DIFFERENT rules (from room 2 on):
const HOLDEM_CHANCE := 0.08      # community cards + 2 hole cards
const CRAZY8_CHANCE := 0.07      # every 8 on the board is wild
const BLACKJACK_CHANCE := 0.08   # sum to 21, beat the dealer
const OUTLAW_CHANCE := 0.08      # the duel: your bullets vs his
const AMBIENT_CHANCE := 0.12     # bonus safe or chest in plain rooms
# Every table the draw can deal, by weight (from table 2 on). These are
# the chances above, split per goal: a locked goal drops out and the
# rest share its odds. FIND upgrades lift a goal's weight.
const ROOM_TABLE := {
	"safe": OBJECTIVE_CHANCE * 0.5, "chest": OBJECTIVE_CHANCE * 0.5,
	"mine": PURGE_CHANCE * 0.2, "purge": PURGE_CHANCE * 0.8,
	"hands": REQUIRE_CHANCE, "holdem": HOLDEM_CHANCE, "crazy8": CRAZY8_CHANCE,
	"blackjack": BLACKJACK_CHANCE, "outlaw": OUTLAW_CHANCE,
	"collect": COLLECT_CHANCE, "landrush": LANDRUSH_CHANCE,
	"plain": 0.20,
}
# Enhancements by weight: the classics common, the exotics rarer, and
# WILD the unicorn.
const MOD_WEIGHTS := {"mult": 26, "chip": 26, "plus": 14, "minus": 10,
		"bumper": 11, "gold": 10, "wild": 3}

# Western job names for the purge rooms; a stone roll becomes the
# GOLD MINE instead (its own room type).
const PURGE_TAROTS := {"bomb": "POWDER KEG", "fire": "WILDFIRE",
		"wind": "DUST STORM", "water": "FLASH FLOOD"}
const GOLD_MINE_QUOTA := 16        # break them ALL — the full seam
const GOLD_MINE_STONE_SEED := 10   # stones seeded (under half the board)
const GOLD_MINE_FLOOR := 6         # trickle keeps at least this many standing
const GOLD_MINE_TRICKLE := 2       # at most this many ride in per hand
# Called-hands templates by region: [hand name, count] — exact hands
# only (this game scores exact compositions, so a Full House is NOT
# three Pairs).
const REQUIRE_POOLS := [
	[[["Pair", 6], ["Two Pair", 2]], [["Pair", 5], ["Three of a Kind", 3]],
			[["Pair", 8]]],
	[[["Two Pair", 3], ["Pair", 4], ["Three of a Kind", 2]],
			[["Three of a Kind", 4], ["Pair", 4]],
			[["Straight", 1], ["Pair", 5], ["Two Pair", 2]],
			[["Flush", 1], ["Pair", 5], ["Two Pair", 2]]],
	[[["Flush", 2], ["Pair", 4], ["Two Pair", 3]],
			[["Full House", 1], ["Three of a Kind", 3], ["Pair", 4]],
			[["Straight", 2], ["Two Pair", 4], ["Pair", 3]],
			[["Four of a Kind", 1], ["Pair", 5], ["Two Pair", 2]]],
]

const BASE_TARGET := 1000         # table 1 target before scaling
const TARGET_STEP := 165          # + per table (21-table curve)
const BLIND_BASE := 25            # table 1 ante / minimum bet
const BLIND_STEP := 6             # + per table cleared — the floor climbs
const SHOP_CARD_PRICE := 40       # plain card
const SHOP_DUP_PRICE := 50        # exact duplicate of a card you own
const SHOP_MOD_PRICE := 80        # chip/mult enhanced card
const SHOP_REMOVE_PRICE := 30     # first burn; climbs every use
const SHOP_REMOVE_STEP := 25      # + per burn used this run
const PICK_MOD_CHANCE := 0.25     # card picks: chance of an enhanced offer
const SHOP_MOD_CHANCE := 0.35     # shop slots: chance of an enhanced card
const FATE_KICKER := 15           # chips for trusting The Fool
const COMPLETE_RATE_BONUS := 1.5  # completion multiplies cash-out rate
const COMPLETE_PURSE := 100       # x (tier+1) cash on finishing

# Meta and run saves live under the active profile (main.profile_path).

# The Outfitter's shelves: GEAR holds the upgrade ladders, the rest list
# the catalog by kind.
const OUTFITTER_TABS := [["gear", "GEAR"], ["riders", "RIDERS"], ["relics", "RELICS"],
		["provisions", "PROVISIONS"], ["cards", "CARDS"], ["tables", "TABLES"]]
const TAB_KINDS := {"riders": ["rider", "trick"], "relics": ["relic"],
		"provisions": ["provision"], "cards": ["mod", "finish"],
		"tables": ["stake", "room", "merchant"]}
# [ladder id, title, blurb, owner kind, owner id]
const LADDERS := [
	["sleeve", "ACE UP THE SLEEVE — THE GAMBLER",
		"His hidden swap card — once per table, trade it for any plain card on the felt. Raising it raises its starting rank, all the way to an Ace.",
		"rider", "the_gambler"],
	["sleight", "SLEIGHT OF HAND — THE GAMBLER",
		"His other trick: swap two cards that sit side by side. Each upgrade palms another trick per table.",
		"trick", "sleight"],
	["laser", "THE LASER — THE MACHINE",
		"One shot per table burns a card clean off the felt. Each upgrade extends the beam one more card into a full cross.",
		"rider", "the_machine"],
	["watch", "THE POCKET WATCH — THE DOCTOR",
		"Turns the last hand back: cards, score, the spent hand, all of it. Each upgrade winds in another turn per table.",
		"rider", "the_doctor"],
	["bankroll", "BANKROLL",
		"Ride out heavier: +20 starting chips on every buy-in, per level, at every stake.",
		"gear", "bankroll"],
	["provisions", "PACKED KIT",
		"Never leave town empty-handed: a random provision already in the kit at every run's start, per level.",
		"gear", "provisions"],
]
const ROOM_EMBLEMS := {"room:plain": "limit_table", "room:clock": "high_noon",
		"room:safe": "bank_job", "room:outlaw": "wanted", "room:hands": "dealers_call",
		"room:chest": "stagecoach_haul", "room:purge": "powder_keg", "room:mine": "gold_mine",
		"room:collect": "the_roundup", "room:crazy8": "crazy_8s", "room:landrush": "land_rush",
		"room:blackjack": "blackjack", "room:holdem": "texas_holdem", "room:royal": "royal_hunt",
		"room:dealer": "showdown", "merchant:peddler": "traveling_merchant",
		"merchant:collector": "traveling_merchant", "merchant:sharp": "traveling_merchant",
		"stake:0": "limit_table", "stake:1": "pot_limit", "stake:2": "no_limit"}
const CATALOG_DESCS := {
	"mod:mult": "×1.5 to the hand's score.",
	"mod:chip": "Extra chips on every score, growing each time it's played.",
	"mod:gold": "+$1 cash every time it's played.",
	"mod:plus": "+1 rank to the card it aims at. Lifts an Ace into THE JOKER: wild, ×2.",
	"mod:minus": "−1 rank to the card it aims at; a 2 breaks.",
	"mod:bumper": "Cleared, it shoves the line it aims at one step.",
	"mod:wild": "Any rank, any suit. The rarest card on the trail.",
	"room:plain": "Score the target before the hands run out.",
	"room:clock": "HIGH NOON: tables against a countdown instead of a hand budget.",
	"room:safe": "BANK JOB: play the safe's combo in order, then crack it.",
	"room:outlaw": "BOUNTY: clear your bullets, dodge his — outdraw a wanted gun or his posse.",
	"room:hands": "DEALER'S CALL: play exactly the hands the table demands.",
	"room:chest": "STAGECOACH HAUL: pair keys with chests. The strongbox holds a relic.",
	"room:purge": "Powder Keg, Wildfire, Dust Storm, Flash Flood: clear a quota of one hazard.",
	"room:mine": "GOLD MINE: break the seam of stones. Gold turns up in the rubble.",
	"room:collect": "THE ROUNDUP & THE CENSUS: clear the called suit, rank, or every rank.",
	"room:crazy8": "Every 8 on the board is wild.",
	"room:landrush": "Stake a claim on every plot: clear a card from all 25 cells.",
	"room:blackjack": "Chains count to 21. Beat the dealer, round after round.",
	"room:holdem": "Five community cards, two in the hole.",
	"room:royal": "One Royal Flush. On the clock.",
	"room:dealer": "Past the last saloon, THE DEALER shuffles a perfect deck and waits.",
}

# Relics: run-wide passives, max 5, bought at shops / found in chests.
const MAX_RELICS := 999  # no satchel limit — the price is the gate
const RELIC_PRICES := [150, 300, 600, 1000]  # by rarity C/R/EPIC/L — carry is unlimited, so they cost dear

# Traveling merchants: each shop stop is a different trader, rolled
# per room, with their own stock — some deal only in relics.
const MERCHANTS := [
	{"id": "peddler", "name": "THE PEDDLER'S WAGON",
		"line": "A little of everything, friend — cards, trinkets, and a hot forge.",
		"cards": 8, "relics": 2, "provisions": 2, "forge": true},
	{"id": "collector", "name": "THE COLLECTOR",
		"line": "No cardboard here. Only trinkets of real power.",
		"cards": 0, "relics": 4, "provisions": 2, "forge": false},
	{"id": "sharp", "name": "THE CARD SHARP",
		"line": "Finest cardboard on the trail — and a forge for your regrets.",
		"cards": 10, "relics": 0, "provisions": 1, "forge": true},
]

# Provisions: one-shot consumables in a 3-slot kit. "target" ones are
# aimed at a card on the table; "instant" ones fire on the spot. Using
# one is a free action — the provision itself is the price.
const PROVISIONS := {
	"canteen": {"name": "Canteen", "kind": "target", "price": 45,
		"desc": "Douse one card: removes any hazard or soak"},
	"dynamite": {"name": "Dynamite Stick", "kind": "target", "price": 60,
		"desc": "Destroy one card outright, unscored - stones and curses included"},
	"branding_iron": {"name": "Branding Iron", "kind": "target", "price": 70,
		"desc": "Brand a plain card with a random enhancement"},
	"razor": {"name": "Barber's Razor", "kind": "target", "price": 50,
		"desc": "Re-roll one card's rank and suit"},
	"gold_pan": {"name": "Gold Pan", "kind": "target", "price": 65,
		"desc": "Turn one plain card solid GOLD"},
	"shell_game": {"name": "Shell Game", "kind": "target", "price": 50,
		"desc": "Swap two neighboring cards - pick one, then its neighbor"},
	"fresh_deck": {"name": "Fresh Deck", "kind": "instant", "price": 55,
		"desc": "Re-deal every plain and enhanced card on the table"},
	"pocket_flask": {"name": "Pocket Flask", "kind": "instant", "price": 60,
		"desc": "+2 hands at this table (+20s on a timed one)"},
	"tonic": {"name": "Rattlesnake Tonic", "kind": "instant", "price": 70,
		"desc": "Your next scored hand counts DOUBLE"},
}
const MAX_PROVISIONS := 3
const RELICS := {
	"horseshoe": {"name": "Horseshoe", "rarity": 0, "desc": "+1 hand in every room"},
	"card_sleeve": {"name": "Card Sleeve", "rarity": 0, "desc": "Card picks offer 4 choices"},
	"snake_oil": {"name": "Snake Oil", "rarity": 0, "desc": "Shop prices -25%"},
	"tin_star": {"name": "Tin Star", "rarity": 0, "desc": "Every cleared table pays an extra blind"},
	"rabbits_foot": {"name": "Rabbit's Foot", "rarity": 0, "desc": "Surprise safes and chests turn up twice as often on plain tables"},
	"bomb_badge": {"name": "Bomb Squad Badge", "rarity": 0, "desc": "Bombs start with +2 fuse"},
	"chisel": {"name": "Chisel", "rarity": 0, "desc": "Stones need one fewer use"},
	"fire_blanket": {"name": "Fire Blanket", "rarity": 1, "desc": "Fire only ticks every 2nd hand"},
	"swimming_goggles": {"name": "Swimming Goggles", "rarity": 1, "desc": "Filled cards still show their suit"},
	"gold_tooth": {"name": "Gold Tooth", "rarity": 1, "desc": "Chip cards pay double"},
	"mirror_shades": {"name": "Mirror Shades", "rarity": 1, "desc": "Mult cards x2 instead of x1.5"},
	"second_wind": {"name": "Second Wind", "rarity": 1, "desc": "One free life: when the trail would end you, rise with 5 HP and chips for the table. Then it's spent"},
	"bankroll_clip": {"name": "Bankroll Clip", "rarity": 1, "desc": "Trail completion pays +0.25x"},
	"dowsing_rod": {"name": "Dowsing Rod", "rarity": 1, "desc": "Safe combos use only ranks 2-6"},
	"saddlebags": {"name": "Saddlebags", "rarity": 1, "desc": "A 4th slot in your provision kit"},
	"lucky_chip": {"name": "Lucky Chip", "rarity": 3, "desc": "10% chance a hand costs no hand"},
	"chuck_wagon": {"name": "Chuck Wagon", "rarity": 2, "desc": "A random provision at every table's start"},
}

var main: Node2D  # set by main.gd before build()

# Meta (persists forever) — everything the OUTFITTER sells for $cash.
var cash := 0
var sleeve_rank := 2     # ACE UP THE SLEEVE: the starting rank, up to an Ace
var meta_bankroll := 0   # +20 starting chips per level on every buy-in (max 5)
var meta_provisions := 0 # random provisions in the kit at run start (max 2)
# Levels, unlocks, purchases and contracts (scripts/progression.gd).
var progress := Progression.new()
var _last_grant := {}    # the last ride's EXP payout, for the game-over page
var _ride_contracts: Array = []  # contract names completed this ride

# Run state
var run_active := false
var run_uid := ""        # one id per ride, so it's only ever paid EXP once
var run_bosses := 0      # boss tables beaten this ride
var table_tier := 0
var chips := 0
var deck: Array = []          # [{rank, suit, cursed}]
var room_index := 0           # 0-based; next room to play
var in_room := false
var room_score := 0
var room_hands_left := 0
var room_time_left := 0.0        # timed tables: seconds on the clock
var room_target := 0
var room_goal := ""      # "" score · safe/chest · purge/mine · hands · boss ·
                         # holdem · crazy8 · blackjack · outlaw
var room_limit := "hands"  # "hands" budget or "time" countdown
var room_combo: Array = []
var room_require: Array = []     # [[hand name, remaining count], ...]
var room_require_total := 0      # hands demanded at room start (progress bar)
var room_chests_needed := 1      # treasure rooms: pairs to open
var room_chests_opened := 0
var room_stones_needed := 1      # gold mine: stones to grind to dust
var room_stones_broken := 0
var room_collect_need := 0       # roundup rooms: cards demanded
var room_collect_done := 0
var room_collect_kinds := {}     # census variant: distinct ranks seen
var room_wins_needed := 3        # blackjack: rounds to take off the dealer
var room_wins := 0
var room_outlaw_hp := 5          # bounty: the current outlaw's health...
var room_outlaw_max := 5
var room_outlaws: Array = []     # the posse, leader first (character specs)
var room_outlaw_idx := 0
# (Grit retired: outlaw lead now hits the rider's run-wide HP.)
const OUTLAW_BAR_BASE := 75      # score under this and he fires (+ per region)
var relics: Array = []   # relic ids held this run
var provisions: Array = []       # provision ids in the kit (max 3, dupes fine)
var _aiming_slot := -1           # kit slot waiting on a target, -1 = none
# ACE UP THE SLEEVE: the hidden card you can trade onto the table once
# per room — the card you take waits up the sleeve for another table.
var sleeve_card := {}            # {rank, suit, mod, finish, joker}
var sleeve_used := false         # one swap per table (the Gambler)
# --- Playable characters: three riders, one signature ability each.
const CHARACTERS := {
	"the_gambler": {"name": "The Gambler", "ability": "ACE UP THE SLEEVE",
			"line": "Once per table, trade the card up his sleeve for any plain card on the felt."},
	"the_machine": {"name": "The Machine", "ability": "THE LASER",
			"line": "Once per table, burn a card clean off the felt. Upgrades extend the beam into a cross."},
	"the_doctor": {"name": "The Doctor", "ability": "THE POCKET WATCH",
			"line": "Turn the last hand back as if it never happened. Upgrades wind in extra uses."},
}
## The Gambler picks one signature when he saddles up.
const GAMBLER_ABILITIES := {
	"sleeve": {"ability": "ACE UP THE SLEEVE", "short": "SLEEVE",
			"line": "Once per table, trade the card up his sleeve for any plain card on the felt."},
	"sleight": {"ability": "SLEIGHT OF HAND", "short": "SLEIGHT",
			"line": "Swap two cards that sit side by side, once per table. Upgrades palm in more tricks."},
}
const LASER_DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
var character := "the_gambler"   # the rider this run
var gambler_ability := "sleeve"  # the Gambler's chosen signature (remembered)
var sleight_uses_left := 1       # Sleight of Hand tricks left this table
var sleight_level := 0           # meta: extra tricks per table (0..2)
var _aiming_sleight := false
# The rider's HITPOINTS, run-wide: burnt-out flames, dynamite, outlaw
# lead and lost tables all take their pound of flesh; campfires give
# some back. Zero and the trail claims the rider.
const MAX_HP := 10
const CAMP_REST_HP := 5
var hp := MAX_HP
# The ride's tally for the end-of-trail ledger.
var outlaws_caught := 0
var best_hand_score := 0
var best_hand_name := ""
# What each stop on the ride was, by room index: "table", "outlaw",
# "boss", "shop" or "camp" — the end-of-trail map lights these.
var trail_log: Array = []
var laser_used := false        # one shot per table (the Machine)
var _aiming_laser := false
var watch_uses_left := 1         # turns left this table (the Doctor)
var _watch_snapshot := {}        # trail-side state alongside board.undo_state
var laser_level := 0             # meta: beam arms unlocked (0..4)
var watch_level := 0             # meta: extra turns per table (0..2)
var _aiming_sleeve := false
var _shop_stock_provisions: Array = []   # [{id, bought}] on the shelf
var burns_used := 0      # run-wide: each burn costs more than the last
var _second_wind_used := false
var _fire_ticks := 0
var _shop_stock: Array = []      # this shop room's shelves (no restocking)
var _shop_stock_room := -1
var _shop_stock_relics: Array = []   # [{id, bought}] on this merchant's shelf
var _shop_merchant: Dictionary = MERCHANTS[0]
var _shop_burned_here := false   # one burn per shop
var pending_retry := {}          # a room that MUST be played next
var _outlaw_dead_pending := false  # killing slug in flight; clear on impact
var pending_is_retry := true     # true = failed there (scarred); false = just stepped away
var current_offer := {}
var stake := 0
var _offers: Array = []
var _fate_offer := {}
var _offers_room := -1       # the room those offers were dealt for
var _room_save := {}         # mid-table photograph for seamless resume

# UI
var buyin_layer: ColorRect
var tarot_layer: ColorRect
var bet_layer: ColorRect
var pick_layer: ColorRect
var shop_layer: ColorRect
var remove_layer: ColorRect
var relic_layer: ColorRect
var end_layer: ColorRect
var _relic_icon: RelicIcon
var _relic_name: Label
var _relic_desc: Label
var _pending_relic_reward := ""
var _buyin_cash_label: Label
var _buyin_resume_btn: Button
var _buyin_rider_btn: Button
var _buyin_new_label: Label
var preview_riding := false  # screenshot mode: show the buy-in as if a ride were saved
var _buyin_tier_btns: Array = []
var upgrades_layer: ColorRect    # the OUTFITTER: meta upgrades for $cash
var select_layer: ColorRect      # pick your rider before the buy-in
var _select_cards := {}          # id -> TextureRect (full card art)
var _select_locks := {}          # id -> the dim veil over a locked rider
var _select_lock_labels := {}    # id -> its lock text
var camp_layer: ColorRect        # the campfire: rest, tend, or cast off
var _camp_scene: CampScene       # the animated night camp behind it all
var _camp_hp_label: Label
var _camp_rest_btn: BaseButton
var _camp_mode := ""             # "" | "tend" | "burn" — deck view purpose
var _swap_first: PlayingCard = null  # the Shell Game's first pick
var _up_cash: Label
var _up_level: Label
var _up_fill: Panel
var _up_tab := "gear"
var _up_tab_btns := {}
var _up_tab_pips := {}
var _up_scroll: ScrollContainer
var _up_list: VBoxContainer
var _win_rows: Array = []        # last table's winnings, itemized for the pick screen
var _win_box: Control
var _pick_title: Label
var _pick_sub: Label
var _relic_sub: Label
var _chest_rewards: Array = []   # ambient chests opened this room: "chips"/"card"/"relic"
var _chest_won_cards: Array = [] # deck cards won from chests, shown on the victory screen
var _chest_card_rounds := 0      # extra 3-card pick rounds owed by chests
var _in_chest_pick := false      # the pick screen is showing a chest round
var _relic_ambient := false      # the strongbox screen shows chest loot, not the stagecoach job
var _tarot_info: Label
var _tarot_cards_box: Control
var _bet_info: Label
var _bet_stake_label: Label
var _bet_amount := 0
var _bet_amount_label: Label
var _bet_deal_btn: Button
var _deck_view_burn := true   # deck viewer doubles as the shop's burn picker
var stake_odds := 1.0    # effective odds locked in when the bet is placed
var _pick_box: Control
var _pick_tip: PanelContainer
var _pick_tip_label: Label
var _shop_tip: PanelContainer
var _shop_tip_label: Label
var _shop_info: Label
var _shop_box: Control
var _remove_grid: GridContainer
var _remove_info: Label
var _deck_tip: PanelContainer
var _deck_tip_label: Label
var _end_label: Label
var _gambler_ab_label: Label
var _gambler_line_label: Label
var _gambler_ability_btns := {}
var _end_leave_btn: Button
var _gameover_scene: GameOverScene
var _shop_title: Label
var _shop_flavor: Label
var _shop_relic_box: Control
var _shop_prov_box: Control
var _shop_burn_btn: Button
var _bet_back_btn: Button
var _tarot_relics: Label


func _ready() -> void:
	_load_meta()
	main.board.safe_cracked.connect(on_safe_cracked)
	main.board.provision_targeted.connect(_on_provision_target)
	main.board.hand_committing.connect(_on_hand_committing)
	main.board.boss_defeated.connect(func() -> void:
		# Scored kills clear the room via result.boss_defeated inside
		# on_hand_played (in_room is already false here). This catches
		# the deaths that happen mid-animation instead: a boss GUSTED
		# or SHOVED off the table on his last life.
		if in_room and room_goal == "boss":
			_room_cleared())


# --- Persistence ----------------------------------------------------------

func _load_meta() -> void:
	var cf := ConfigFile.new()
	cf.load(main.profile_path("trail_meta.cfg"))
	cash = int(cf.get_value("meta", "cash", 0))
	sleeve_rank = clampi(int(cf.get_value("meta", "sleeve_rank", 2)), 2, 14)
	meta_bankroll = clampi(int(cf.get_value("meta", "bankroll", 0)), 0, 5)
	meta_provisions = clampi(int(cf.get_value("meta", "provisions", 0)), 0, 2)
	laser_level = clampi(int(cf.get_value("meta", "laser", 0)), 0, 4)
	watch_level = clampi(int(cf.get_value("meta", "watch", 0)), 0, 2)
	sleight_level = clampi(int(cf.get_value("meta", "sleight", 0)), 0, 2)
	character = String(cf.get_value("meta", "character", "the_gambler"))
	if not CHARACTERS.has(character):
		character = "the_gambler"
	gambler_ability = String(cf.get_value("meta", "gambler_ability", "sleeve"))
	if not GAMBLER_ABILITIES.has(gambler_ability):
		gambler_ability = "sleeve"
	var legacy := {"character": character, "laser": laser_level,
			"watch": watch_level, "sleight": sleight_level,
			"gambler_ability": gambler_ability, "provisions": meta_provisions}
	var built := progress.read(cf, main.stats, legacy)
	if not progress.contracts_init:
		# Contracts already met before they existed are claimable on the
		# page, but not news at the next table or the next last page.
		for c in Contracts.LIST:
			if Contracts.is_complete(c, main.stats, main.stats_hands):
				progress.contracts_seen[String(c.id)] = true
		progress.contracts_init = true
		built = true
	if built:
		_save_meta()  # an old profile, seated at the level its stats earned
	if OS.get_environment("POKERPOP_SHOT") != "":
		# Screenshots show everything on the trail — or, with
		# POKERPOP_LEVEL=N, a fresh rider at that level.
		var lv_env := OS.get_environment("POKERPOP_LEVEL")
		progress.unlock_all = lv_env == ""
		if lv_env != "":
			progress.read(ConfigFile.new(), {})
			progress.exp_total = Progression.exp_at_level(int(lv_env))
			progress.seen_level = maxi(1, int(lv_env) - 2)
	# A rider or trick that isn't the player's yet can't be the saddle.
	if not _avail("rider", character):
		character = "the_gambler"
	if not _avail("trick", gambler_ability):
		gambler_ability = "sleeve"


func _save_meta() -> void:
	if OS.get_environment("POKERPOP_SHOT") != "":
		return  # screenshot runs must not touch real saves
	var cf := ConfigFile.new()
	cf.set_value("meta", "cash", cash)
	cf.set_value("meta", "sleeve_rank", sleeve_rank)
	cf.set_value("meta", "bankroll", meta_bankroll)
	cf.set_value("meta", "provisions", meta_provisions)
	cf.set_value("meta", "laser", laser_level)
	cf.set_value("meta", "watch", watch_level)
	cf.set_value("meta", "sleight", sleight_level)
	cf.set_value("meta", "character", character)
	cf.set_value("meta", "gambler_ability", gambler_ability)
	# The [progress] section rides in the same file — it MUST be written
	# here, since every save rebuilds the file from blank.
	progress.write(cf)
	cf.save(main.profile_path("trail_meta.cfg"))


func _save_run() -> void:
	if OS.get_environment("POKERPOP_SHOT") != "":
		return
	var cf := ConfigFile.new()
	cf.set_value("run", "active", run_active)
	cf.set_value("run", "tier", table_tier)
	cf.set_value("run", "chips", chips)
	cf.set_value("run", "room", room_index)
	cf.set_value("run", "uid", run_uid)
	cf.set_value("run", "score", main.score)
	cf.set_value("run", "bosses", run_bosses)
	var ranks := PackedInt32Array()
	var suits := PackedInt32Array()
	var curses := PackedInt32Array()
	var mods := PackedStringArray()
	var finishes := PackedStringArray()
	var chip_lvs := PackedInt32Array()
	for c in deck:
		ranks.append(c.rank)
		suits.append(c.suit)
		curses.append(1 if c.get("cursed", false) else 0)
		mods.append(c.get("mod", ""))
		finishes.append(PlayingCard.finish_of(c))
		chip_lvs.append(int(c.get("chip_lv", 0)))
	cf.set_value("run", "ranks", ranks)
	cf.set_value("run", "suits", suits)
	cf.set_value("run", "curses", curses)
	cf.set_value("run", "mods", mods)
	cf.set_value("run", "finishes", finishes)
	cf.set_value("run", "chip_lvs", chip_lvs)
	var relic_arr := PackedStringArray()
	for id in relics:
		relic_arr.append(id)
	cf.set_value("run", "relics", relic_arr)
	var prov_arr := PackedStringArray()
	for id in provisions:
		prov_arr.append(id)
	cf.set_value("run", "provisions", prov_arr)
	cf.set_value("run", "sleeve", sleeve_card)
	cf.set_value("run", "character", character)
	cf.set_value("run", "gambler_ability", gambler_ability)
	cf.set_value("run", "hp", hp)
	cf.set_value("run", "outlaws_caught", outlaws_caught)
	cf.set_value("run", "best_hand_score", best_hand_score)
	cf.set_value("run", "best_hand_name", best_hand_name)
	cf.set_value("run", "trail_log", PackedStringArray(trail_log))
	cf.set_value("run", "second_wind_used", _second_wind_used)
	cf.set_value("run", "burns_used", burns_used)
	cf.set_value("run", "pending", pending_retry)
	cf.set_value("run", "pending_hard", pending_is_retry)
	cf.set_value("run", "offers", _offers)
	cf.set_value("run", "fate", _fate_offer)
	cf.set_value("run", "offers_room", _offers_room)
	# Photograph the live table whenever it CAN be photographed, so
	# even a hard app close resumes at the same stage. A busy board
	# keeps the previous (pre-hand) photograph instead.
	if in_room and not main.board.busy:
		_room_save = _capture_room_state()
	cf.set_value("run", "room_state", _room_save)
	cf.save(main.profile_path("trail_run.cfg"))


func _clear_run_save() -> void:
	run_active = false
	if OS.get_environment("POKERPOP_SHOT") != "":
		return  # screenshot runs must not touch real saves
	var cf := ConfigFile.new()
	cf.set_value("run", "active", false)
	cf.save(main.profile_path("trail_run.cfg"))


func _load_run() -> bool:
	var cf := ConfigFile.new()
	if cf.load(main.profile_path("trail_run.cfg")) != OK or not cf.get_value("run", "active", false):
		return false
	table_tier = int(cf.get_value("run", "tier", 0))
	chips = int(cf.get_value("run", "chips", 0))
	room_index = int(cf.get_value("run", "room", 0))
	run_uid = String(cf.get_value("run", "uid", ""))
	if run_uid == "":
		run_uid = _mint_run_uid()  # a ride saved before EXP existed
	main.score = int(cf.get_value("run", "score", 0))
	run_bosses = int(cf.get_value("run", "bosses", 0))
	var ranks: PackedInt32Array = cf.get_value("run", "ranks", PackedInt32Array())
	var suits: PackedInt32Array = cf.get_value("run", "suits", PackedInt32Array())
	var curses: PackedInt32Array = cf.get_value("run", "curses", PackedInt32Array())
	var mods: PackedStringArray = cf.get_value("run", "mods", PackedStringArray())
	var booms: PackedInt32Array = cf.get_value("run", "booms", PackedInt32Array())  # pre-Prism saves
	var finishes: PackedStringArray = cf.get_value("run", "finishes", PackedStringArray())
	var chip_lvs: PackedInt32Array = cf.get_value("run", "chip_lvs", PackedInt32Array())
	deck.clear()
	for i in ranks.size():
		var raw_mod: String = mods[i] if i < mods.size() else ""
		deck.append({"rank": ranks[i], "suit": suits[i],
				"cursed": curses[i] == 1,
				"mod": Board.migrate_mod(raw_mod),
				"finish": finishes[i] if i < finishes.size()
						else ("prism" if (i < booms.size() and booms[i] == 1)
						or raw_mod == "chipsplode" else ""),
				"chip_lv": chip_lvs[i] if i < chip_lvs.size() else 0})
	relics.clear()
	for id in cf.get_value("run", "relics", PackedStringArray()):
		# Renamed relics carry over; retired ones (the Weathervane)
		# fall off resumed runs.
		var rid := String(id)
		if rid == "magnifying_glass":
			rid = "swimming_goggles"
		if RELICS.has(rid):
			relics.append(rid)
	provisions.clear()
	for id in cf.get_value("run", "provisions", PackedStringArray()):
		if PROVISIONS.has(String(id)):
			provisions.append(String(id))
	sleeve_card = cf.get_value("run", "sleeve", {})
	if sleeve_card.is_empty():
		sleeve_card = _fresh_sleeve()  # runs saved before the sleeve existed
	if bool(sleeve_card.get("joker", sleeve_card.get("two_plus", false))):
		# A Joker saved from before he moved above the Ace.
		sleeve_card["rank"] = 14
		sleeve_card["mod"] = "wild"
		sleeve_card["joker"] = true
	character = String(cf.get_value("run", "character", "the_gambler"))
	if not CHARACTERS.has(character):
		character = "the_gambler"
	gambler_ability = String(cf.get_value("run", "gambler_ability", "sleeve"))
	if not GAMBLER_ABILITIES.has(gambler_ability):
		gambler_ability = "sleeve"
	hp = clampi(int(cf.get_value("run", "hp", MAX_HP)), 1, MAX_HP)
	outlaws_caught = int(cf.get_value("run", "outlaws_caught", 0))
	best_hand_score = int(cf.get_value("run", "best_hand_score", 0))
	best_hand_name = String(cf.get_value("run", "best_hand_name", ""))
	trail_log = Array(cf.get_value("run", "trail_log", PackedStringArray()))
	_second_wind_used = cf.get_value("run", "second_wind_used", false)
	burns_used = int(cf.get_value("run", "burns_used", 0))
	pending_retry = cf.get_value("run", "pending", {})
	pending_is_retry = cf.get_value("run", "pending_hard", true)
	_offers = cf.get_value("run", "offers", [])
	_fate_offer = cf.get_value("run", "fate", {})
	_offers_room = int(cf.get_value("run", "offers_room", -1))
	_room_save = cf.get_value("run", "room_state", {})
	_shop_stock_room = -1  # resumed runs sit at a tarot or a retry bet
	run_active = true
	return true


# --- Run math -------------------------------------------------------------

func _table() -> Dictionary:
	return TABLES[table_tier]


func has_relic(id: String) -> bool:
	return relics.has(id)


## Shop pricing with Snake Oil applied.
func _cost_mult(room: int) -> int:
	if room > QUEEN_ROOM:
		return POST_BOSS_COST_MULT * POST_BOSS_COST_MULT
	if room > JACK_ROOM:
		return POST_BOSS_COST_MULT
	return 1


func _price(base: int) -> int:
	var p := base * _cost_mult(room_index)
	return int(p * (1.0 - float(rv("snake_oil", "off")))) if has_relic("snake_oil") else p


## POWER values at the Outfitter level the player bought: a relic's,
## a provision's, an enhancement's.
func rv(id: String, k: String) -> Variant:
	return progress.val("relic", id, k)


func pv(id: String, k: String, fallback: Variant = 0) -> Variant:
	return progress.val("provision", id, k, fallback)


func mv(id: String, k: String) -> Variant:
	return progress.val("mod", id, k)


## What a relic does at the POWER level the player owns.
func relic_desc(id: String) -> String:
	var d := progress.pdesc("relic", id)
	return d if d != "" else String(RELICS.get(id, {}).get("desc", ""))


func provision_desc(id: String) -> String:
	var d := progress.pdesc("provision", id)
	return d if d != "" else String(PROVISIONS.get(id, {}).get("desc", ""))


## Pushes relic- and POWER-driven settings into the board/card layer.
## Call at run start, on load, and whenever a relic is gained.
func _apply_relic_effects() -> void:
	var chip := float(mv("chip", "chips")) \
			* (float(rv("gold_tooth", "x")) if has_relic("gold_tooth") else 1.0)
	main.board.chip_bonus = roundi(chip)
	PlayingCard.chip_pay_base = main.board.chip_bonus
	main.board.mult_factor = float(mv("mult", "x")) \
			+ (float(rv("mirror_shades", "plus")) if has_relic("mirror_shades") else 0.0)
	main.board.gold_pay = int(mv("gold", "cash"))
	main.board.holo_bonus = int(progress.val("finish", "holo", "score", 50))
	main.board.gold_find_chance = float(rv("chisel", "gold")) if has_relic("chisel") \
			else Board.GOLD_FIND_CHANCE
	PlayingCard.washed_show_suit = has_relic("swimming_goggles")


func _gain_relic(id: String) -> void:
	if relics.size() >= MAX_RELICS or relics.has(id):
		return
	main.tutor_show("relics")
	main.stat_bump("relics_found")
	relics.append(id)
	if id == "saddlebags" and int(rv("saddlebags", "packed")) > 0 and run_active:
		gain_provision(_random_provision())
	_apply_relic_effects()
	_save_run()


# --- Ace up the Sleeve ------------------------------------------------------

const RANK_CHARS := {11: "J", 12: "Q", 13: "K", 14: "A"}
const SUIT_CHARS := ["♠", "♥", "♦", "♣"]


## A new run's sleeve: the meta-upgraded rank, in a random suit.
func _fresh_sleeve() -> Dictionary:
	return {"rank": sleeve_rank, "suit": randi_range(0, 3),
			"mod": "", "finish": "", "joker": false}


## "A♥"-style label for whatever is up the sleeve right now.
func sleeve_label() -> String:
	if sleeve_card.is_empty():
		return "—"
	var r := int(sleeve_card.rank)
	var txt: String = RANK_CHARS.get(r, str(r))
	if bool(sleeve_card.get("joker", sleeve_card.get("two_plus", false))):
		txt = "JOKER"
	if String(sleeve_card.get("mod", "")) != "":
		txt += " · %s" % String(sleeve_card.mod).to_upper()
	return "%s%s" % [txt, SUIT_CHARS[int(sleeve_card.suit)]]


## The next sleeve upgrade's $cash price (rank 2 → ... → Ace).
func sleeve_upgrade_cost() -> int:
	return 10 * (sleeve_rank - 1)


## The SLEEVE button: arms the swap (or holsters it again).
func use_sleeve() -> void:
	if _aiming_sleeve:
		main.board.pending_provision = ""
		_aiming_sleeve = false
		main._announce("HOLSTERED", main.DIM)
		return
	if not in_room or not main.game_started or main.board.busy \
			or main.board.locked or main.board.blackjack_presenting:
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		return
	if sleeve_used:
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		main._announce("THE SLEEVE IS SPENT — one swap per table", main.RED)
		return
	_aiming_slot = -1  # only one thing aims at a time
	_aiming_sleeve = true
	main.board.pending_provision = "sleeve"
	main._announce("PICK A CARD TO SWAP FOR THE %s — right-click to holster"
			% sleeve_label(), main.GOLD)


## Why this card can't be traded up the sleeve — "" when it can.
func _sleeve_refusal(card: PlayingCard) -> String:
	if card.face_down:
		return "IT'S FACE DOWN — no blind trades"
	if card.boss != "" or card.is_safe or card.snake_tail:
		return "THAT WON'T FIT UP A SLEEVE"
	if card.cursed or card.hazard != "" or card.washed or card.water_level > 0:
		return "NOTHING CURSED, BURNING, TICKING, OR DRIPPING GOES UP THE SLEEVE"
	if card.objective != "":
		return "THE JOB PIECE STAYS ON THE TABLE"
	return ""


## The trade: the table card and the sleeve card swap identities in
## place. What you took rides along to the next table.
func _do_sleeve_swap(card: PlayingCard) -> void:
	var taken := {"rank": card.rank, "suit": card.suit, "mod": card.mod,
			"finish": card.finish, "joker": card.joker,
			"chip_lv": card.chip_level}
	card.rank = int(sleeve_card.rank)
	card.suit = int(sleeve_card.suit)
	card.mod = String(sleeve_card.get("mod", ""))
	card.finish = PlayingCard.finish_of(sleeve_card)
	card.joker = bool(sleeve_card.get("joker", sleeve_card.get("two_plus", false)))
	card.chip_level = int(sleeve_card.get("chip_lv", 0))
	if card.mod in ["plus", "minus", "bumper"]:
		card.boost_dir = Board.HAZARD_DIRS.pick_random()
	card.queue_redraw()
	sleeve_card = taken
	sleeve_used = true
	main.stat_bump("sleeve_swaps")
	main.board._play_sound(Board.SFX_FLIP, 1.2, -6.0)
	main.board._play_sound(Board.SFX_SHUFFLES.pick_random(), 1.4, -10.0, 0.08)
	main.board._fx(card.position, "pop", card.suit_color())
	main._announce("UP THE SLEEVE IT GOES — NOW HOLDING %s" % sleeve_label())
	_save_run()


# --- Signature abilities (the other two riders) ---------------------------

## The KIT's top button fires whichever signature the rider carries.
func use_signature() -> void:
	match character:
		"the_machine":
			use_laser()
		"the_doctor":
			use_watch()
		_:
			if gambler_ability == "sleight":
				use_sleight()
			else:
				use_sleeve()


## THE GAMBLER's Sleight of Hand: arms a two-pick neighbor swap (or
## pockets it again). Once per table.
func use_sleight() -> void:
	if _aiming_sleight:
		main.board.pending_provision = ""
		_aiming_sleight = false
		_swap_first = null
		main._announce("POCKETED", main.DIM)
		return
	if not in_room or not main.game_started or main.board.busy \
			or main.board.locked or main.board.blackjack_presenting:
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		return
	if sleight_uses_left <= 0:
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		main._announce("NO TRICKS LEFT AT THIS TABLE", main.RED)
		return
	_aiming_slot = -1  # only one thing aims at a time
	_aiming_sleeve = false
	_aiming_laser = false
	_aiming_sleight = true
	_swap_first = null
	main.board.pending_provision = "sleight"
	main._announce("PICK A CARD, THEN ITS NEIGHBOR — right-click to pocket", main.GOLD)


## Two picks for a side-by-side swap: returns the first card once
## `card` completes a neighboring pair, null while still choosing.
func _swap_pair_pick(card: PlayingCard, anywhere := false) -> PlayingCard:
	if _swap_first == null or not is_instance_valid(_swap_first) \
			or not main.board.grid.has(_swap_first.grid_pos) \
			or main.board.grid[_swap_first.grid_pos] != _swap_first:
		_swap_first = card
		main.board._play_sound(Board.SFX_FLIP, 1.3, -10.0)
		main.board._fx(card.position, "pop", main.GOLD)
		main._announce("NOW PICK %s — right-click to holster"
				% ("ANY OTHER CARD" if anywhere else "THE CARD BESIDE IT"), main.GOLD)
		return null
	if card == _swap_first:
		_swap_first = null
		main._announce("UNPICKED — choose the first card again", main.DIM)
		return null
	var dp: Vector2i = card.grid_pos - _swap_first.grid_pos
	if absi(dp.x) + absi(dp.y) != 1 and not anywhere:
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		main._announce("THEY MUST SIT SIDE BY SIDE", main.RED)
		return null
	var first := _swap_first
	_swap_first = null
	return first


## THE MACHINE's laser: arms the beam (or powers it down again).
func use_laser() -> void:
	if _aiming_laser:
		main.board.pending_provision = ""
		_aiming_laser = false
		main._announce("POWERED DOWN", main.DIM)
		return
	if not in_room or not main.game_started or main.board.busy \
			or main.board.locked or main.board.blackjack_presenting:
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		return
	if laser_used:
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		main._announce("THE LASER IS SPENT — one shot per table", main.RED)
		return
	_aiming_slot = -1  # only one thing aims at a time
	_aiming_sleeve = false
	_aiming_sleight = false
	_aiming_laser = true
	main.board.pending_provision = "laser"
	main._announce("TARGET A CARD — right-click to power down", main.GOLD)


## The beam: the target plus one more card per unlocked arm (up,
## right, down, left). Safes, bosses and coils deflect it; job
## pieces caught in the burn resurface, dynamite-style.
func _do_laser(target: PlayingCard) -> void:
	laser_used = true
	var cells: Array = [target.grid_pos]
	for i in mini(laser_level, LASER_DIRS.size()):
		cells.append(target.grid_pos + (LASER_DIRS[i] as Vector2i))
	var cards: Array = []
	var pieces: Array = []
	for cell in cells:
		if not main.board.grid.has(cell):
			continue
		var c: PlayingCard = main.board.grid[cell]
		if c.is_safe or c.boss != "" or c.snake_tail:
			continue  # the beam glances off
		if c.objective in ["key", "chest"]:
			pieces.append(c.objective)
		if c.hazard == "stone" and room_goal == "mine":
			room_stones_broken += 1
		cards.append(c)
	main._announce("THE LASER FIRES")
	main.stat_bump("laser_shots")
	await main.board.laser_destroy(target.position, cards)
	for piece in pieces:
		if room_goal == "chest" and in_room:
			main.board.spawn_objective(String(piece))
			main._announce("THE %s TURNS UP ELSEWHERE" % String(piece).to_upper())


## THE DOCTOR's pocket watch: the last hand un-happens — cards,
## score, grit, the spent hand, all of it. The clock, if one runs,
## keeps its seconds.
func use_watch() -> void:
	if not in_room or not main.game_started or main.board.busy \
			or main.board.locked or main.board.blackjack_presenting \
			or _outlaw_dead_pending:
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		return
	if watch_uses_left <= 0:
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		main._announce("THE WATCH IS WOUND DOWN — no more turns this table", main.RED)
		return
	if room_goal == "blackjack":
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		main._announce("THE DEALER GUARDS HIS DEAL — no rewinds at blackjack", main.RED)
		return
	if _watch_snapshot.is_empty() or not main.board.has_undo():
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		main._announce("NOTHING TO TURN BACK — play a hand first", main.RED)
		return
	if not main.board.restore_state():
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		return
	room_score = int(_watch_snapshot.room_score)
	main.score = int(_watch_snapshot.get("run_score", main.score))
	room_hands_left = int(_watch_snapshot.room_hands_left)
	room_wins = int(_watch_snapshot.room_wins)
	hp = int(_watch_snapshot.hp)
	room_outlaw_hp = int(_watch_snapshot.room_outlaw_hp)
	room_outlaw_idx = int(_watch_snapshot.room_outlaw_idx)
	room_stones_broken = int(_watch_snapshot.room_stones_broken)
	room_chests_opened = int(_watch_snapshot.room_chests_opened)
	room_collect_done = int(_watch_snapshot.room_collect_done)
	room_collect_kinds = _watch_snapshot.room_collect_kinds.duplicate()
	room_require = _watch_snapshot.room_require.duplicate(true)
	deck = _watch_snapshot.deck.duplicate(true)
	chips = int(_watch_snapshot.chips)
	cash = int(_watch_snapshot.cash)
	outlaws_caught = int(_watch_snapshot.get("outlaws_caught", outlaws_caught))
	best_hand_score = int(_watch_snapshot.get("best_hand_score", best_hand_score))
	best_hand_name = String(_watch_snapshot.get("best_hand_name", best_hand_name))
	_watch_snapshot = {}
	watch_uses_left -= 1
	main.stat_bump("hands_unwound")
	main.board._play_sound(Board.SFX_FLIP, 0.7, -6.0)
	main.board._play_sound(Board.SFX_SHUFFLES.pick_random(), 0.8, -10.0, 0.1)
	main._announce("THE WATCH TURNS BACK — THAT HAND NEVER HAPPENED")
	_save_meta()
	_save_run()


## Board signal, fired as a valid hand commits: the Doctor notes the
## room as it stands, to pair with the board's own snapshot.
func _on_hand_committing() -> void:
	if not in_room or character != "the_doctor":
		_watch_snapshot = {}
		return
	_watch_snapshot = {
		"room_score": room_score, "room_hands_left": room_hands_left,
		"run_score": main.score,
		"room_wins": room_wins, "hp": hp,
		"room_outlaw_hp": room_outlaw_hp, "room_outlaw_idx": room_outlaw_idx,
		"room_stones_broken": room_stones_broken,
		"room_chests_opened": room_chests_opened,
		"room_collect_done": room_collect_done,
		"room_collect_kinds": room_collect_kinds.duplicate(),
		"room_require": room_require.duplicate(true),
		"deck": deck.duplicate(true),
		"chips": chips, "cash": cash,
		"outlaws_caught": outlaws_caught,
		"best_hand_score": best_hand_score, "best_hand_name": best_hand_name,
	}


## Second Wind still has its one free life in it.
func second_wind_ready() -> bool:
	return has_relic("second_wind") and not _second_wind_used


## The free life: back up with at least 5 HP and enough chips to sit
## the table at hand (`seat`, or this table's cheapest seat). The relic
## stays in the satchel, spent, so no merchant sells a second one.
func _second_wind_revive(seat := -1) -> void:
	_second_wind_used = true
	hp = maxi(hp, int(rv("second_wind", "hp")))
	chips = maxi(chips, seat if seat >= 0 else _cheapest_seat(room_index))
	main.stat_bump("second_winds")
	main.board._play_sound(Board.SFX_STING_WIN, 0.9, -6.0)
	main.board._play_sound(Board.SFX_WINDS.pick_random(), 1.0, -8.0)
	_save_run()
	# Let the blow (or the lost table's verdict) land first.
	var text := "SECOND WIND — BACK ON YOUR FEET  ·  HP %d  ·  %d CHIPS" % [hp, chips]
	while main.board.busy:
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	main._announce(text, main.GOLD)


func character_name() -> String:
	return String(CHARACTERS.get(character, {}).get("name", "The Gambler"))


## The trail hurts: burnt-out flames, dynamite, outlaw lead, lost
## tables. Returns false when the damage ends the run — callers must
## stop what they were doing.
func take_damage(amount: int, why := "", cause := "") -> bool:
	if amount <= 0 or not run_active:
		return true
	hp = maxi(0, hp - amount)
	main.flash_red()
	main.board._play_sound(Board.SFX_POPS.pick_random(), 0.42, -4.0)
	if hp > 0:
		if why != "":
			main._announce("%s — HP %d" % [why, hp], main.RED)
		_save_run()
		return true
	if second_wind_ready():
		_second_wind_revive()
		return true
	# The trail claims the rider.
	in_room = false
	main.board.locked = true
	main.stat_bump("trail_deaths")
	_clear_run_save()
	_end_run("LAID LOW",
			"%s\nThe trail took its last pound of flesh.\n%s won't finish this ride." \
			% [why if why != "" else "The last blow landed.", character_name()], 0,
			cause if cause != "" else "The last blow landed.")
	return false


# --- Provisions -----------------------------------------------------------

## Kit capacity: three slots, four with the Saddlebags relic.
func kit_size() -> int:
	return MAX_PROVISIONS + (1 if has_relic("saddlebags") else 0)


## Adds a provision to the kit. False when the kit is full.
func gain_provision(id: String) -> bool:
	if provisions.size() >= kit_size():
		return false
	provisions.append(id)
	main.tutor_show("provisions")
	main.stat_bump("provisions_found")
	_save_run()
	return true


## Kit button pressed: instants fire on the spot, targeted ones arm the
## cursor and wait for a card. Free action — no hand spent.
func use_provision(slot: int) -> void:
	if slot < 0 or slot >= provisions.size():
		return
	if _aiming_slot == slot:
		# Second press holsters the aimed provision.
		main.board.pending_provision = ""
		_aiming_slot = -1
		_swap_first = null
		main._announce("HOLSTERED", main.DIM)
		return
	if not in_room or not main.game_started or main.board.busy \
			or main.board.locked or main.board.blackjack_presenting:
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		return
	var id: String = provisions[slot]
	var p: Dictionary = PROVISIONS[id]
	if p.kind == "instant":
		_spend_provision(slot)
		_apply_instant_provision(id)
		return
	_aiming_sleeve = false  # only one thing aims at a time
	_aiming_sleight = false
	_aiming_slot = slot
	_swap_first = null
	main.board.pending_provision = id
	main._announce("PICK A CARD FOR THE %s — right-click to holster"
			% String(p.name).to_upper(), main.GOLD)


func _spend_provision(slot: int) -> void:
	var id: String = provisions[slot]
	# Upgraded tools sometimes survive the job.
	if randf() < float(pv(id, "keep", 0.0)):
		main._announce("THE %s HOLDS UP — still in the kit" % String(PROVISIONS[id].name).to_upper())
	else:
		provisions.remove_at(slot)
	_aiming_slot = -1
	main.board.pending_provision = ""
	main.stat_bump("provisions_used")
	_save_run()


func _apply_instant_provision(id: String) -> void:
	match id:
		"fresh_deck":
			main._announce("FRESH DECK — THE TABLE TURNS OVER")
			main.board.provision_redeal()
		"pocket_flask":
			if room_limit == "time":
				var secs := int(pv("pocket_flask", "secs"))
				room_time_left += secs
				main._announce("POCKET FLASK  +%d SECONDS" % secs)
			else:
				var more := int(pv("pocket_flask", "hands"))
				room_hands_left += more
				main._announce("POCKET FLASK  +%d HANDS" % more)
			main.board._play_sound(Board.SFX_COINS.pick_random(), 1.2, -8.0)
		"tonic":
			var x := float(pv("tonic", "x"))
			main.board.next_hand_mult = x
			main.board._play_sound(Board.SFX_FLIP, 0.8, -8.0)
			main._announce("RATTLESNAKE TONIC — NEXT HAND COUNTS ×%s" % String.num(x, 1))


## The aimed provision or sleeve picked a card (null = holstered).
func _on_provision_target(card) -> void:
	if _aiming_laser:
		if card == null:
			_aiming_laser = false
			main._announce("POWERED DOWN", main.DIM)
			return
		if card.is_safe or card.boss != "" or card.snake_tail:
			main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
			main._announce("THE BEAM GLANCES OFF — pick a softer target", main.RED)
			return  # still aiming
		_aiming_laser = false
		main.board.pending_provision = ""
		_do_laser(card)
		return
	if _aiming_sleeve:
		if card == null:
			_aiming_sleeve = false
			main._announce("HOLSTERED", main.DIM)
			return
		var swap_why := _sleeve_refusal(card)
		if swap_why != "":
			main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
			main._announce(swap_why, main.RED)
			return  # still aiming — pick another card or holster
		_aiming_sleeve = false
		main.board.pending_provision = ""
		_do_sleeve_swap(card)
		return
	if _aiming_sleight:
		if card == null:
			_aiming_sleight = false
			_swap_first = null
			main._announce("POCKETED", main.DIM)
			return
		var trick_why := _provision_refusal("shell_game", card)
		if trick_why != "":
			main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
			main._announce(trick_why, main.RED)
			return  # still aiming
		var first := _swap_pair_pick(card)
		if first == null:
			return  # still aiming
		_aiming_sleight = false
		main.board.pending_provision = ""
		sleight_uses_left -= 1
		main.stat_bump("sleights")
		main._announce("SLEIGHT OF HAND — NOBODY SAW A THING")
		await main.board.provision_swap(first, card)
		_save_run()
		return
	if _aiming_slot < 0 or _aiming_slot >= provisions.size():
		_aiming_slot = -1
		_swap_first = null
		return
	if card == null:
		_aiming_slot = -1
		_swap_first = null
		main._announce("HOLSTERED", main.DIM)
		return
	var id: String = provisions[_aiming_slot]
	var why := _provision_refusal(id, card)
	if why != "":
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		main._announce(why, main.RED)
		return  # still aiming — pick another card or holster
	if id == "shell_game":
		# Two picks: the first card waits while you choose its neighbor
		# (any card at all, once the Outfitter has taught the trick).
		var first := _swap_pair_pick(card, int(pv("shell_game", "any")) > 0)
		if first == null:
			return  # still aiming
		_spend_provision(_aiming_slot)
		main._announce("THE SHELL GAME — WATCH THE CARDS")
		await main.board.provision_swap(first, card)
		return
	var slot := _aiming_slot
	_spend_provision(slot)
	_apply_target_provision(id, card)


## Why this card can't take this provision — "" when it can.
func _provision_refusal(id: String, card: PlayingCard) -> String:
	if card.face_down:
		return "IT'S FACE DOWN — no telling what you'd hit"
	match id:
		"canteen":
			if card.hazard == "" and not card.washed and card.water_level == 0:
				return "NOTHING TO DOUSE THERE"
			if card.hazard == "stone":
				return "WATER WON'T MOVE STONE — try dynamite"
		"dynamite":
			if card.boss != "" or card.is_safe or card.snake_tail:
				return "TOO BIG TO BLOW — pick something smaller"
		"branding_iron", "gold_pan":
			if card.boss != "" or card.is_safe or card.snake_tail \
					or card.cursed or card.hazard != "" or card.washed \
					or card.mod != "" or card.water_level > 0:
				return "THE BRAND NEEDS A PLAIN, DRY CARD"
		"razor":
			if card.boss != "" or card.is_safe or card.snake_tail \
					or card.cursed or card.hazard == "stone":
				return "NOTHING THERE TO SHAVE"
		"shell_game":
			if card.is_safe or card.boss != "" or card.snake_tail:
				return "TOO HEAVY TO SHUFFLE — pick an ordinary card"
	return ""


func _apply_target_provision(id: String, card: PlayingCard) -> void:
	match id:
		"canteen":
			main._announce("DOUSED")
			main.board.provision_clean(card)
			if int(pv("canteen", "spread")) > 0:
				# The upgraded canteen splashes the four neighbors too.
				for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					var n: PlayingCard = main.board.grid.get(card.grid_pos + d)
					if n != null and _provision_refusal("canteen", n) == "":
						main.board.provision_clean(n)
		"dynamite":
			if card.hazard == "stone" and room_goal == "mine":
				# Blasting the seam still counts toward the quota.
				room_stones_broken += 1
			var piece: String = card.objective if card.objective in ["key", "chest"] else ""
			main._announce("DYNAMITE!")
			await main.board.provision_destroy(card)
			if piece != "" and room_goal == "chest" and in_room:
				main.board.spawn_objective(piece)
				main._announce("THE %s TURNS UP ELSEWHERE" % piece.to_upper())
		"branding_iron":
			var mod := _random_mod()
			main._announce("BRANDED: %s" % mod.to_upper())
			main.board.provision_enhance(card, mod)
		"gold_pan":
			main._announce("STRUCK GOLD")
			main.board.provision_enhance(card, "gold")
		"razor":
			main._announce("A FRESH FACE")
			main.board.provision_reroll(card,
					card.rank if int(pv("razor", "up")) > 0 else 2)


## A random provision id for shops and loot.
func _random_provision(exclude: Array = []) -> String:
	var w := {}
	for id in PROVISIONS:
		w[id] = 1.0
	var id := progress.pick("provision", w, exclude)
	return id if id != "" else "canteen"


## `n` different provisions for a shelf (fewer if the pool runs dry).
func _provision_shelf(n: int) -> Array:
	var out: Array = []
	var w := {}
	for id in PROVISIONS:
		w[id] = 1.0
	for i in n:
		var id := progress.pick("provision", w, out)
		if id == "":
			break
		out.append(id)
	return out


## A relic the rider doesn't carry yet, weighted by FIND ("" if none).
func _relic_pick(exclude: Array = [], common_only := false) -> String:
	var w := {}
	for id in RELICS:
		if relics.has(id) or (common_only and int(RELICS[id].rarity) != 0):
			continue
		w[id] = 1.0
	return progress.pick("relic", w, exclude)


## `n` different relics for a merchant's shelf.
func _relic_shelf(n: int) -> Array:
	var out: Array = []
	for i in n:
		var id := _relic_pick(out)
		if id == "":
			break
		out.append(id)
	return out


func _avail(kind: String, id: String) -> bool:
	return progress.is_available(kind, id)


## A merchant on the trail, by MERCHANTS index (saves keep the index,
## so that list is never reordered).
func _random_merchant_index() -> int:
	var w := {}
	for m in MERCHANTS:
		w[String(m.id)] = 1.0
	var id := progress.pick("merchant", w)
	for i in MERCHANTS.size():
		if String(MERCHANTS[i].id) == id:
			return i
	return 0


## A random relic id the player doesn't own yet, or "" if none left.
func _unowned_relic() -> String:
	return _relic_pick()


func _blind_for(room: int) -> int:
	return int((BLIND_BASE + BLIND_STEP * room) * _table().blind_mult) \
			* _cost_mult(room)


## The least a seat at this table can cost: the ante plus the minimum
## bet (also the ante). Bosses take the whole stack anyway, so just
## the ante.
func _cheapest_seat(room: int) -> int:
	if BOSS_ROOMS.has(room):
		return _blind_for(room)
	return _blind_for(room) * 2


## True if the stack can't cover `cost` — and in that case the run is
## over: chips only turn to cash for riders who reach the end, so a
## short stack forfeits — the house keeps what's left.
func _short_stacked(cost: int) -> bool:
	if chips >= cost:
		return false
	if second_wind_ready():
		_second_wind_revive(cost)
		return false
	if chips <= 0:
		_clear_run_save()
		_end_run("BUSTED OUT",
				"That table took your last chip.\nThe trail ends here.", 0,
				"Lost every chip at Table %d." % mini(room_index + 1, ROOMS_TOTAL))
		return true
	_clear_run_save()
	_end_run("BLINDED OUT",
			"A seat at this table costs at least %d chips — you're down to %d.\nOnly riders who reach the end cash out. The house keeps the rest." % [cost, chips],
			0, "Needed %d chips, held %d." % [cost, chips])
	return true


func _target_for(room: int, risk: Dictionary) -> int:
	var base := BASE_TARGET + TARGET_STEP * room
	return int(base * risk.target_scale * _table().target_mult)


func _fresh_deck() -> Array:
	var d: Array = []
	for s in 4:
		for r in range(2, 15):
			d.append({"rank": r, "suit": s, "cursed": false})
	return d


func _cashout_value(rate_bonus := 1.0) -> int:
	var rate: float = _table().rate + (float(rv("bankroll_clip", "rate")) if has_relic("bankroll_clip") else 0.0)
	return int(chips * rate * rate_bonus / 10.0)


## Weighted enhancement roll over the ones on the trail (MOD_WEIGHTS).
func _random_mod() -> String:
	var id := progress.pick("mod", MOD_WEIGHTS)
	return id if id != "" else "chip"


## FINISHES ride along as a rare extra on any enhanced card, one of
## them (Prism or Metal) at random.
const FINISH_CHANCE := 0.2


func _roll_finish() -> String:
	if randf() >= FINISH_CHANCE:
		return ""
	var w := {}
	for id in PlayingCard.FINISHES:
		w[id] = 1.0
	return progress.pick("finish", w)


func _random_card_offer(mod_chance := PICK_MOD_CHANCE) -> Dictionary:
	var mod := ""
	var finish := ""
	if randf() < mod_chance:
		mod = _random_mod()
		finish = _roll_finish()
	# Half the time, offer an exact duplicate of a card already owned
	# (the Five of a Kind / Flushed Five enabler).
	if randf() < 0.5 and not deck.is_empty():
		var src: Dictionary = deck.pick_random()
		if not src.get("cursed", false):
			return {"rank": src.rank, "suit": src.suit, "cursed": false,
					"mod": mod, "finish": finish}
	return {"rank": randi_range(2, 14), "suit": randi_range(0, 3),
			"cursed": false, "mod": mod, "finish": finish}


# --- Flow: entry ----------------------------------------------------------

## THE TRAIL's first stop: pick your rider. Falls straight through
## to the buy-in when the character art isn't installed.
## THE TRAIL from the menu: a ride in progress comes first, straight to
## the buy-in with RESUME on top; otherwise saddle a rider.
func open_trail() -> void:
	if _has_saved_run():
		open_buyin()
	else:
		open_select()


func open_select() -> void:
	if _select_cards.is_empty():
		open_buyin()
		return
	main.transition(_open_select_now)


func _open_select_now() -> void:
	main.menu_layer.visible = false
	main.menu_open = false
	_hide_all()
	_refresh_select()
	select_layer.visible = true


func _refresh_select() -> void:
	for id in _select_cards:
		var tr: TextureRect = _select_cards[id]
		var suffix := "_selected" if id == character else ""
		var p := "res://assets/art/playable/full/%s%s.png" % [id, suffix]
		if ResourceLoader.exists(p):
			tr.texture = load(p)
	var pick: Dictionary = GAMBLER_ABILITIES[gambler_ability]
	if _gambler_ab_label != null:
		_gambler_ab_label.text = String(pick.ability)
		_gambler_line_label.text = String(pick.line)
	for key in _gambler_ability_btns:
		var tb: Button = _gambler_ability_btns[key]
		_style_signature_toggle(tb, key == gambler_ability)
		var open := _avail("trick", key)
		tb.modulate = Color.WHITE if open else Color(1, 1, 1, 0.45)
		tb.tooltip_text = String(GAMBLER_ABILITIES[key].ability) if open \
				else _lock_text("trick", key)
	for id in _select_locks:
		var lock: Control = _select_locks[id]
		lock.visible = not _avail("rider", id)
		(_select_lock_labels[id] as Label).text = _lock_text("rider", id)


## Why an item can't be had yet: the level it unlocks at, or its price
## at the Outfitter.
func _lock_text(kind: String, id: String) -> String:
	var r := Progression.row(kind, id)
	if r.is_empty():
		return ""
	if not progress.is_unlocked(kind, id):
		return "UNLOCKS AT LEVEL %d" % int(r.level)
	return "BUY AT THE OUTFITTER — $%d" % int(r.price)


## The Gambler's two-way selector: the kit's oxblood "selected" face
## with a hot-brass rim, or the quieter unselected one (hover lifts
## it). Falls back to the button kit's primary/plain chrome.
func _style_signature_toggle(b: Button, chosen: bool) -> void:
	var pieces := {"normal": "signature_toggle_unselected",
			"hover": "signature_toggle_unselected_hover",
			"pressed": "signature_toggle_selected"}
	if chosen:
		pieces = {"normal": "signature_toggle_selected",
				"hover": "signature_toggle_selected",
				"pressed": "signature_toggle_selected"}
	if CardArt.tex("ui", "signature_toggle_selected") == null:
		UiKit.style_button(b, chosen)
		return
	for state in pieces:
		var sb := StyleBoxTexture.new()
		sb.texture = CardArt.tex("ui", String(pieces[state]))
		sb.texture_margin_left = 18
		sb.texture_margin_right = 18
		sb.texture_margin_top = 14
		sb.texture_margin_bottom = 14
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ink := Color("e6d5b0") if chosen else Color("b8a888")
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, ink)
	b.add_theme_font_size_override("font_size", 18)


## The Gambler's trick for this ride; choosing one also saddles him.
func _pick_gambler_ability(key: String) -> void:
	if not GAMBLER_ABILITIES.has(key):
		return
	if not _avail("trick", key):
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		main._announce(_lock_text("trick", key), main.RED)
		return
	var changed := gambler_ability != key or character != "the_gambler"
	gambler_ability = key
	character = "the_gambler"
	if changed:
		main.board._play_sound(Board.SFX_FLIP, 1.1, -8.0)
		_save_meta()
	_refresh_select()


func _pick_character(id: String) -> void:
	if not CHARACTERS.has(id) or character == id:
		return
	if not _avail("rider", id):
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		main._announce(_lock_text("rider", id), main.RED)
		return
	character = id
	main.board._play_sound(Board.SFX_FLIP, 1.1, -8.0)
	_save_meta()  # the trail remembers the last rider saddled
	_refresh_select()


func open_buyin() -> void:
	main.transition(_open_buyin_now)


func _open_buyin_now() -> void:
	# A brand-new profile learns the game before hitting the trail.
	if main.tutor_needs("core"):
		main._start_tutorial()
		return
	main.tutor_show("mode_trail")
	main.menu_layer.visible = false
	main.menu_open = false
	_hide_all()
	_buyin_cash_label.text = "CASH  $%d" % cash
	for i in _buyin_tier_btns.size():
		var tb: Button = _buyin_tier_btns[i]
		var open := _avail("stake", str(i))
		tb.disabled = not open
		var t: Dictionary = TABLES[i]
		tb.text = _tier_label(i) if open \
				else "%s\nunlocks at level %d" % [t.name, int(Progression.row("stake", str(i)).level)]
	# A ride in progress takes top billing; fresh saddles move down.
	var riding := _has_saved_run() or preview_riding
	_buyin_resume_btn.visible = riding
	_buyin_rider_btn.visible = riding and not _select_cards.is_empty()
	_buyin_new_label.visible = riding
	if riding:
		_buyin_resume_btn.position = Vector2(660, 320)
		for i in _buyin_tier_btns.size():
			(_buyin_tier_btns[i] as Button).position = Vector2(660, 470 + i * 130)
	else:
		for i in _buyin_tier_btns.size():
			(_buyin_tier_btns[i] as Button).position = Vector2(660, 330 + i * 130)
	buyin_layer.visible = true


# --- The Outfitter: meta upgrades bought with $cash -----------------------

func open_upgrades() -> void:
	main.transition(_open_upgrades_now)


func _open_upgrades_now() -> void:
	main.menu_layer.visible = false
	main.menu_open = false
	_hide_all()
	_refresh_upgrades()
	upgrades_layer.visible = true


## The next level's price for one upgrade — 0 when it's maxed out.
func upgrade_cost(id: String) -> int:
	match id:
		"sleeve":
			return 0 if sleeve_rank >= 14 else sleeve_upgrade_cost()
		"laser":
			return 0 if laser_level >= 4 else 30 * (laser_level + 1)
		"watch":
			return 0 if watch_level >= 2 else 50 * (watch_level + 1)
		"sleight":
			return 0 if sleight_level >= 2 else 40 * (sleight_level + 1)
		"bankroll":
			return 0 if meta_bankroll >= 5 else 20 * (meta_bankroll + 1)
		"provisions":
			return 0 if meta_provisions >= 2 else 35 * (meta_provisions + 1)
	return 0


func _buy_upgrade(id: String) -> void:
	var cost := upgrade_cost(id)
	if cost <= 0 or cash < cost or not _ladder_open(id):
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		return
	cash -= cost
	match id:
		"sleeve":
			sleeve_rank += 1
		"laser":
			laser_level += 1
		"watch":
			watch_level += 1
		"sleight":
			sleight_level += 1
		"bankroll":
			meta_bankroll += 1
		"provisions":
			meta_provisions += 1
	_save_meta()
	main.board._play_sound(Board.SFX_COINS.pick_random(), 1.1, -8.0)
	_refresh_upgrades()


func _refresh_upgrades() -> void:
	_up_cash.text = "CASH  $%d" % cash
	var into: Array = progress.exp_into_level()
	_up_level.text = "LEVEL %d   ·   %d / %d EXP to level %d" % [progress.level(),
			int(into[0]), int(into[1]), progress.level() + 1]
	_up_fill.size.x = 600.0 * clampf(float(into[0]) / maxf(1.0, float(into[1])), 0.0, 1.0)
	for key in _up_tab_btns:
		_style_signature_toggle(_up_tab_btns[key], key == _up_tab)
		(_up_tab_pips[key] as Label).visible = _tab_news(key) > 0
	var keep := _up_scroll.scroll_vertical
	for child in _up_list.get_children():
		_up_list.remove_child(child)
		child.queue_free()
	if _up_tab == "gear":
		for def in LADDERS:
			_up_list.add_child(_ladder_row(def))
	else:
		for r in Progression.CATALOG:
			if String(r.kind) in TAB_KINDS[_up_tab]:
				_up_list.add_child(_catalog_row(r))
	_up_scroll.set_deferred("scroll_vertical", keep)


func _set_up_tab(key: String) -> void:
	if _up_tab == key:
		return
	_up_tab = key
	main.board._play_sound(Board.SFX_FLIP, 1.2, -10.0)
	_up_scroll.scroll_vertical = 0
	_refresh_upgrades()


## Unlocks the Outfitter hasn't shown yet (NEW since its last visit).
func outfitter_news() -> int:
	var n := 0
	for r in Progression.unlocks_between(progress.seen_level, progress.level()):
		n += 1
	return n


func _tab_news(key: String) -> int:
	if key == "gear" or not TAB_KINDS.has(key):
		return 0
	var n := 0
	for r in Progression.unlocks_between(progress.seen_level, progress.level()):
		if String(r.kind) in TAB_KINDS[key]:
			n += 1
	return n


## Leaving the Outfitter marks everything on show as seen.
func _close_upgrades() -> void:
	if progress.seen_level != progress.level():
		progress.seen_level = progress.level()
		_save_meta()
	back_to_menu()


## A ladder's upgrades can only be bought once its owner is the player's.
func _ladder_open(id: String) -> bool:
	for def in LADDERS:
		if String(def[0]) == id:
			return _avail(String(def[3]), String(def[4]))
	return true


func _ladder_texts(id: String, cost: int) -> Array:
	var st := ""
	var bt := ""
	match id:
		"sleeve":
			st = "Starts every run as a %s of a random suit" \
					% String(RANK_CHARS.get(sleeve_rank, str(sleeve_rank)))
			bt = "FULLY SHARPENED — AN ACE" if cost <= 0 \
					else "RAISE TO %s — $%d" % [String(RANK_CHARS.get(
							sleeve_rank + 1, str(sleeve_rank + 1))), cost]
		"laser":
			st = "Beam burns %d card%s%s" % [1 + laser_level,
					"" if laser_level == 0 else "s",
					"" if laser_level == 0 else " in a cross"]
			bt = "EXTEND THE BEAM — $%d" % cost if cost > 0 \
					else "A FULL CROSS"
		"watch":
			st = "Level %d / 2  ·  %d turn%s back per table" \
					% [watch_level, 1 + watch_level,
					"" if watch_level == 0 else "s"]
			bt = "WIND ANOTHER TURN — $%d" % cost if cost > 0 \
					else "WOUND TO THE LIMIT"
		"sleight":
			st = "Level %d / 2  ·  %d trick%s per table" \
					% [sleight_level, 1 + sleight_level,
					"" if sleight_level == 0 else "s"]
			bt = "PALM ANOTHER TRICK — $%d" % cost if cost > 0 \
					else "QUICKEST HANDS ON THE TRAIL"
		"bankroll":
			st = "Level %d / 5  ·  +%d chips at every buy-in" \
					% [meta_bankroll, 20 * meta_bankroll]
			bt = "SADDLE HEAVIER — $%d" % cost if cost > 0 \
					else "AS HEAVY AS IT GETS"
		"provisions":
			st = "Level %d / 2  ·  %d provision%s at the start" \
					% [meta_provisions, meta_provisions,
					"" if meta_provisions == 1 else "s"]
			bt = "PACK ANOTHER — $%d" % cost if cost > 0 \
					else "THE KIT RIDES FULL"
	return [st, bt]


## One GEAR row: an existing upgrade ladder, behind its owner's lock.
func _ladder_row(def: Array) -> Control:
	var id := String(def[0])
	var row := _row_shell()
	var icon_id := id if id in ["sleeve", "sleight", "laser", "watch"] else ""
	if id == "sleeve":
		var pc := PlayingCard.new()
		pc.material = Themes.current_material()
		pc.rank = sleeve_rank
		pc.suit = 0
		pc.position = Vector2(56, 48)
		pc.scale = Vector2(0.72, 0.72)
		row.add_child(pc)
	elif icon_id != "":
		_row_texture(row, CardArt.tex("icon", icon_id))
	_row_text(row, String(def[1]), String(def[2]))
	var cost := upgrade_cost(id)
	var texts := _ladder_texts(id, cost)
	var open := _ladder_open(id)
	var status := _row_status(row, String(texts[0]))
	if not open:
		row.modulate = Color(1, 1, 1, 0.5)
		status.text = "LOCKED  ·  " + _owner_lock(String(def[3]), String(def[4]))
		return row
	var b := _row_button(row, String(texts[1]), Vector2(700, 46), Vector2(324, 40))
	b.disabled = cost <= 0 or cash < cost
	b.pressed.connect(func() -> void:
		_buy_upgrade(id))
	return row


func _owner_lock(kind: String, id: String) -> String:
	var r := Progression.row(kind, id)
	if not progress.is_unlocked(kind, id):
		return "%s AT LEVEL %d" % [String(r.name).to_upper(), int(r.level)]
	return "BUY %s FIRST" % String(r.name).to_upper()


## One catalog row: locked, waiting to be bought, or on the trail with
## FIND upgrades.
func _catalog_row(r: Dictionary) -> Control:
	var kind := String(r.kind)
	var id := String(r.id)
	var row := _row_shell()
	_row_icon(row, kind, id)
	_row_text(row, String(r.name), _catalog_desc(kind, id))
	if r.get("reserved", false):
		row.modulate = Color(1, 1, 1, 0.5)
		_row_status(row, "COMING SOON  ·  LEVEL %d" % int(r.level))
		return row
	if not progress.is_unlocked(kind, id):
		row.modulate = Color(1, 1, 1, 0.5)
		_row_status(row, "UNLOCKS AT LEVEL %d" % int(r.level))
		return row
	if int(r.level) > progress.seen_level:
		var pip: Label = main._label(row, "NEW", Vector2(966, 8), 15, main.GOLD)
		pip.size = Vector2(60, 20)
		pip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if not progress.is_available(kind, id):
		var cost := progress.buy_cost(kind, id)
		_row_status(row, "UNLOCKED  ·  LEVEL %d" % int(r.level))
		var b := _row_button(row, "BUY — $%d" % cost, Vector2(700, 46), Vector2(324, 40), true)
		b.disabled = cash < cost
		b.pressed.connect(func() -> void:
			_buy_catalog(kind, id))
		return row
	var fl := progress.find_level(kind, id)
	var note := "ON THE TRAIL"
	if kind == "stake":
		note = "AT THE BUY-IN"
	elif kind in ["rider", "trick"]:
		note = "YOURS TO RIDE"
	if fl > 0:
		note += "  ·  FOUND %s× AS OFTEN" % String.num(float(Progression.FIND_MULT[fl]), 1)
	_row_status(row, note)
	var pmax := Progression.power_max(kind, id)
	if kind in Progression.FINDABLE:
		var fcost := progress.find_cost(kind, id)
		var label := "FIND %d / %d — $%d" % [fl + 1, Progression.MAX_FIND, fcost] \
				if fcost > 0 else "FIND MAXED"
		var wide := Vector2(324, 40) if pmax == 0 else Vector2(158, 40)
		var fb := _row_button(row, label, Vector2(700, 46), wide)
		fb.disabled = fcost <= 0 or cash < fcost
		fb.tooltip_text = "Turns up more often on the trail. Applies to rides in progress too."
		fb.pressed.connect(func() -> void:
			_buy_find(kind, id))
	if pmax > 0:
		var plv := progress.power_level(kind, id)
		var pcost := progress.power_cost(kind, id)
		var plabel := "POWER %d / %d — $%d" % [plv + 1, pmax, pcost] if pcost > 0 \
				else "POWER MAXED"
		var pb := _row_button(row, plabel, Vector2(866, 46), Vector2(158, 40), pcost > 0)
		pb.disabled = pcost <= 0 or cash < pcost
		pb.tooltip_text = ("Next: " + progress.pdesc(kind, id, plv + 1)) if pcost > 0 \
				else "As strong as it gets."
		pb.pressed.connect(func() -> void:
			_buy_power(kind, id))
	return row


func _buy_power(kind: String, id: String) -> void:
	var cost := progress.power_cost(kind, id)
	if cost <= 0 or cash < cost:
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		return
	cash -= cost
	progress.raise_power(kind, id)
	_save_meta()
	if run_active:
		_apply_relic_effects()
	main.board._play_sound(Board.SFX_COINS.pick_random(), 1.1, -8.0)
	main._announce("%s — POWER %d" % [String(Progression.row(kind, id).name).to_upper(),
			progress.power_level(kind, id)])
	_refresh_upgrades()


func _buy_catalog(kind: String, id: String) -> void:
	var cost := progress.buy_cost(kind, id)
	if cost <= 0 or cash < cost:
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		return
	cash -= cost
	progress.mark_owned(kind, id)
	_save_meta()
	main.board._play_sound(Board.SFX_COINS.pick_random(), 1.1, -8.0)
	main._announce("%s — %s" % [String(Progression.row(kind, id).name).to_upper(),
			"YOURS TO RIDE" if kind in ["rider", "trick"] else "ON THE TRAIL"])
	_refresh_upgrades()


func _buy_find(kind: String, id: String) -> void:
	var cost := progress.find_cost(kind, id)
	if cost <= 0 or cash < cost:
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		return
	cash -= cost
	progress.raise_find(kind, id)
	_save_meta()
	main.board._play_sound(Board.SFX_COINS.pick_random(), 1.1, -8.0)
	_refresh_upgrades()


func _row_shell() -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(1040, 96)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	UiKit.plate(row, Rect2(0, 0, 1040, 96))
	return row


func _row_text(row: Control, title: String, desc: String) -> void:
	var name_l: Label = main._label(row, title, Vector2(112, 10), 22, main.GOLD)
	name_l.size = Vector2(570, 30)
	name_l.clip_text = true
	_wrap_label(row, desc, Rect2(112, 42, 570, 48), 15, main.OFFWHITE)


func _row_status(row: Control, text: String) -> Label:
	var l: Label = main._label(row, text, Vector2(700, 12), 16, main.DIM)
	l.size = Vector2(324, 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	return l


func _row_button(row: Control, text: String, pos: Vector2, size: Vector2,
		primary := false) -> Button:
	var b: Button = main._button(row, text, pos, size, primary)
	b.add_theme_font_size_override("font_size", 15)
	UiKit.fit_button_text(b, 15, 12)
	return b


func _row_texture(row: Control, t: Texture2D, rect := Rect2(16, 8, 80, 80)) -> void:
	if t == null:
		return
	var tr := TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.position = rect.position
	tr.size = rect.size
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tr)


func _row_icon(row: Control, kind: String, id: String) -> void:
	match kind:
		"relic":
			var icon := RelicIcon.new()
			icon.relic_id = id
			icon.position = Vector2(56, 48)
			icon.scale = Vector2(1.1, 1.1)
			row.add_child(icon)
		"provision":
			_row_texture(row, CardArt.provision_icon(id))
		"mod", "finish":
			var pc := PlayingCard.new()
			pc.material = Themes.current_material()
			pc.rank = 14 if id == "wild" else 10
			pc.suit = 1
			if kind == "mod":
				pc.mod = id
			else:
				pc.mod = "chip"
				pc.finish = id
			pc.position = Vector2(56, 48)
			pc.scale = Vector2(0.72, 0.72)
			row.add_child(pc)
		"rider":
			_row_texture(row, load("res://assets/art/playable/hud/%s_512.png" % id)
					if ResourceLoader.exists("res://assets/art/playable/hud/%s_512.png" % id) else null)
		"trick":
			_row_texture(row, CardArt.tex("icon", id))
		"room", "merchant", "stake":
			var emblem := String(ROOM_EMBLEMS.get("%s:%s" % [kind, id], ""))
			var path := "res://assets/art/r2/posters/emblem/%s.png" % emblem
			if emblem != "" and ResourceLoader.exists(path):
				_row_texture(row, load(path))


func _catalog_desc(kind: String, id: String) -> String:
	match kind:
		"relic":
			return relic_desc(id)
		"provision":
			return provision_desc(id)
		"mod":
			var d := progress.pdesc("mod", id)
			if d != "":
				return d
		"finish":
			var fd := progress.pdesc("finish", id)
			if fd != "":
				return fd
			return String(PlayingCard.FINISHES[id].desc) if PlayingCard.FINISHES.has(id) else ""
		"rider":
			return "%s — %s" % [String(CHARACTERS[id].ability), String(CHARACTERS[id].line)]
		"trick":
			return String(GAMBLER_ABILITIES[id].line)
		"merchant":
			for m in MERCHANTS:
				if String(m.id) == id:
					return String(m.line)
		"stake":
			var t: Dictionary = TABLES[int(id)]
			return "Buy in for $%d: %d chips, payout ×%.1f%s." % [int(t.cost), int(t.chips),
					float(t.rate), "" if int(id) == 0 else ", tougher tables"]
	return String(CATALOG_DESCS.get("%s:%s" % [kind, id], ""))


func _tier_label(i: int) -> String:
	var t: Dictionary = TABLES[i]
	if t.cost == 0:
		return "%s\n%d chips · payout ×%.1f" % [t.name, t.chips, t.rate]
	return "%s — $%d\n%d chips · payout ×%.1f · harder" % [t.name, t.cost, t.chips, t.rate]


func _has_saved_run() -> bool:
	var cf := ConfigFile.new()
	return cf.load(main.profile_path("trail_run.cfg")) == OK and cf.get_value("run", "active", false)


func _start_run(tier: int) -> void:
	var cost: int = TABLES[tier].cost
	if cash < cost or not _avail("stake", str(tier)):
		return
	if not _avail("rider", character):
		character = "the_gambler"
	if not _avail("trick", gambler_ability):
		gambler_ability = "sleeve"
	cash -= cost
	# A ride left saddled up is paid its EXP before the new one starts.
	_credit_abandoned_ride()
	main.stat_bump("trail_runs")
	_save_meta()
	main.menu_open = false
	run_uid = _mint_run_uid()
	run_bosses = 0
	_ride_contracts = []
	table_tier = tier
	chips = TABLES[tier].chips
	deck = _fresh_deck()
	room_index = 0
	# The Outfitter's gear rides along: extra chips on the stack, and
	# provisions already in the kit.
	chips += 20 * meta_bankroll
	relics.clear()
	provisions.clear()
	for i in (meta_provisions if _avail("gear", "provisions") else 0):
		provisions.append(_random_provision())
	_aiming_slot = -1
	sleeve_card = _fresh_sleeve()
	sleeve_used = false
	_aiming_sleeve = false
	_aiming_sleight = false
	hp = MAX_HP
	outlaws_caught = 0
	best_hand_score = 0
	best_hand_name = ""
	trail_log = []
	burns_used = 0
	_second_wind_used = false
	_fire_ticks = 0
	_shop_stock_room = -1
	_offers_room = -1
	_room_save = {}
	pending_retry = {}
	run_active = true
	main.score = 0
	_apply_relic_effects()
	_save_run()
	_show_tarot()


func _resume_run() -> void:
	if _load_run():
		_apply_relic_effects()
		if not _room_save.is_empty():
			# The photographed table: back to the exact stage you
			# stood up from.
			main.menu_open = false
			main.menu_layer.visible = false
			_hide_all()
			_restore_room_state()
			return
		if not pending_retry.is_empty():
			# A failed room still bars the way — back to its table.
			if _short_stacked(_cheapest_seat(room_index)):
				return
			main.menu_open = false
			current_offer = pending_retry.duplicate(true)
			_hide_all()
			_show_bet()
		else:
			pending_retry = {}
			_show_tarot()


func back_to_menu() -> void:
	_hide_all()
	main._open_menu()


# --- Flow: tarot (between rooms) -----------------------------------------

func _show_tarot() -> void:
	main.transition(_show_tarot_now)


func _show_tarot_now() -> void:
	_hide_all()
	in_room = false
	main.game_started = false
	main.board.locked = true
	main.play_music("tarot")
	# Bankruptcy check against the coming room's cheapest seat.
	if _short_stacked(_cheapest_seat(room_index)):
		return
	# Fate deals each room's offers ONCE: peeking at the deck, the
	# menu, or a saved game never reshuffles the wall.
	if _offers_room != room_index or _offers.is_empty():
		_offers = _make_offers()
		_fate_offer = _make_one_offer(true)
		_offers_room = room_index
		_save_run()
	_render_tarot()
	tarot_layer.visible = true


func _make_offers() -> Array:
	# Boss rooms: fate deals exactly one court card.
	if BOSS_ROOMS.has(room_index):
		var kind: String = BOSS_ROOMS[room_index]
		var b: Dictionary = BOSSES[kind]
		return [{
			"kind": "play",
			"tarot": b.tarot,
			"label": b.name,
			"target": 0,
			"hands": int(b.hands),
			"odds": 3.0,
			"min_bet": mini(_blind_for(room_index), chips),
			"boss": kind,
		}]
	var offers: Array = []
	# Shops appear twice per 7-room region; a campfire glows once,
	# between them.
	var want_shop := room_index % REGION_SIZE in [2, 5]
	var want_camp := room_index % REGION_SIZE == 3
	var risk_pool := RISKS.duplicate()
	risk_pool.shuffle()
	for i in 3:
		if want_shop and i == 1:
			offers.append(_make_shop_offer())
		elif want_camp and i == 1:
			offers.append({"kind": "camp", "tarot": "THE CAMPFIRE"})
		else:
			offers.append(_make_one_offer(false, risk_pool[i % risk_pool.size()]))
	return offers


## A shop offer names its merchant up front, so the tarot card shows
## WHO is waiting before you commit to the stop.
func _make_shop_offer() -> Dictionary:
	return {"kind": "shop", "tarot": "TRAVELING MERCHANT",
			"merchant": _random_merchant_index()}


## Which kind of table the draw deals (ROOM_TABLE over the goals on
## the trail); "plain" is the ordinary score table.
func _roll_room_goal() -> String:
	var goal := progress.pick("room", ROOM_TABLE)
	return goal if goal != "" else "plain"


func _make_one_offer(random_risk: bool, risk: Dictionary = {}) -> Dictionary:
	if random_risk:
		if randf() < 0.15:
			return _make_shop_offer()
		risk = RISKS.pick_random()
	var region := room_index / REGION_SIZE
	var offer := {
		"kind": "play",
		"tarot": risk.tarot,
		"label": risk.label,
		"target": _target_for(room_index, risk),
		# Depth costs ONE hand at most — the climbing targets are
		# squeeze enough without the budget draining too.
		"hands": maxi(1, int(risk.hands) - mini(region, 1)),
		"odds": float(risk.odds),
		"min_bet": _blind_for(room_index),
	}
	var goal := _roll_room_goal() if room_index >= 1 else "plain"
	if goal != "plain":
		if goal in ["safe", "chest"]:
			# Objective rooms: no score target — do the job to clear.
			if goal == "safe":
				offer.tarot = "BANK JOB"
				offer.label = "Heist"
				offer.odds = 2.0
				offer["goal"] = "safe"
			else:
				# The hardest job on the trail — but the strongbox
				# holds a RELIC.
				offer.tarot = "STAGECOACH HAUL"
				offer.label = "Treasure"
				offer.odds = 2.0
				offer["goal"] = "chest"
				offer["chest_count"] = mini(3 + region, 5)
				# References for either limit: ~2 hands per pair, or
				# about a minute per pair plus one on the clock.
				offer.hands = mini(MAX_HANDS_BUY, 2 * int(offer.chest_count) + 1)
				offer["minutes"] = mini(TIMED_MAX_MINUTES,
						1 + int(offer.chest_count))
			if offer.get("goal", "") == "safe":
				offer.hands = maxi(1, 8 - region)
			offer.target = 0
		elif goal in ["mine", "purge"]:
			var kind: String = "stone" if goal == "mine" \
					else ["bomb", "fire", "wind", "water"].pick_random()
			if kind == "stone":
				# GOLD MINE: a board of solid rock — break stones free
				# and gold cards turn up in the rubble.
				offer.tarot = "GOLD MINE"
				offer.label = "Gold Mine"
				offer.odds = 2.0
				offer["goal"] = "mine"
				offer["stones"] = GOLD_MINE_QUOTA
				offer.hands = MAX_HANDS_BUY
				# The seam always runs on the clock (set below), and a
				# full twenty stones earns a longer fuse than the formula.
				offer["minutes"] = 5
				offer.target = 0
			else:
				# Purge rooms: clear a QUOTA of one hazard kind — a few
				# seeded at the deal, the rest trickling in as you play.
				offer.tarot = String(PURGE_TAROTS[kind])
				offer.label = "Purge"
				offer.odds = 2.0 if kind in ["bomb", "fire"] else 1.5
				offer["goal"] = "purge"
				offer["purge_kind"] = kind
				offer["purge_count"] = PURGE_SEED
				offer["purge_quota"] = PURGE_QUOTA_BASE + PURGE_QUOTA_REGION * region
				offer.hands = mini(MAX_HANDS_BUY, 9 + region)
				offer.target = 0
		elif goal == "hands":
			# Called hands: play exactly what the table demands.
			offer["goal"] = "hands"
			if region >= 1 and randf() < ROYAL_CHANCE and _avail("room", "royal"):
				offer.tarot = "ROYAL HUNT"
				offer.label = "Royal Hunt"
				offer.odds = 5.0
				offer["require"] = [["Royal Flush", 1]]
				# The hunt always runs on the clock (set below):
				# stalking one royal on a hand budget was a coin
				# flip, not a hunt.
				offer["minutes"] = 4
			else:
				offer.tarot = "DEALER'S CALL"
				offer.label = "Called Hands"
				offer.odds = 1.5 if region == 0 else 2.0
				var pool: Array = REQUIRE_POOLS[mini(region, REQUIRE_POOLS.size() - 1)]
				offer["require"] = (pool.pick_random() as Array).duplicate(true)
			# ~8-9 called hands on a 10-hand reference: one, maybe two
			# hands to waste — every other play works toward a demand.
			offer.hands = 10
			offer.target = 0
		elif goal == "holdem":
			# Hold'em: 5 community cards, pick 2 hole cards per hand.
			offer.tarot = "TEXAS HOLD'EM"
			offer.label = "Hold'em"
			offer.odds = 2.0
			offer["goal"] = "holdem"
			offer.target = _target_for(room_index, {"target_scale": 1.1})
			offer.hands = 8
		elif goal == "crazy8":
			# Crazy 8s: a normal table, but every 8 is wild.
			offer.tarot = "CRAZY 8s"
			offer.label = "Wild Eights"
			offer.odds = 1.5
			offer["goal"] = "crazy8"
			offer.target = _target_for(room_index, {"target_scale": 1.25})
		elif goal == "blackjack":
			# Blackjack: chains score their pip sum — beat the dealer.
			offer.tarot = "BLACKJACK"
			offer.label = "Twenty-One"
			offer.odds = 2.0
			offer["goal"] = "blackjack"
			offer["wins"] = 4 + region
			offer.hands = mini(MAX_HANDS_BUY, 2 * (4 + region) + 1)
			offer.target = 0
		elif goal == "outlaw":
			# The bounty: a wanted gun — or a whole posse, hunted down
			# one head at a time. Clear YOUR bullets to shoot, dodge HIS.
			# region is 0-based: lone guns in region one, pairs from
			# region two, full gangs of three in region three.
			var posse := 1 + randi() % mini(region + 1, 3)
			offer.tarot = "BOUNTY"
			offer.label = "Bounty"
			offer.odds = 2.0 + 0.5 * posse
			offer["goal"] = "outlaw"
			offer["outlaw_hp"] = 5 + region
			offer["outlaws"] = _roll_posse(posse)
			offer.hands = 10 + 3 * (posse - 1)
			offer.target = 0
		elif goal == "collect":
			# Roundup family: clear a called count of one suit, one
			# rank, or many DIFFERENT ranks.
			offer["goal"] = "collect"
			offer.odds = 1.5
			offer.target = 0
			offer.hands = mini(MAX_HANDS_BUY, 10 + region)
			match randi() % 3:
				0:
					# A real drive: most hands must be built around the
					# called suit to land the count in time.
					offer.tarot = "THE ROUNDUP"
					offer.label = "Roundup"
					offer["collect_suit"] = randi_range(0, 3)
					offer["collect_need"] = 12 + 3 * region
				1:
					# The rank drive is a ROUNDUP too — WANTED belongs
					# to the bounty posters now.
					offer.tarot = "THE ROUNDUP"
					offer.label = "Roundup"
					offer.odds = 2.0
					offer["collect_rank"] = randi_range(2, 14)
					offer["collect_need"] = 5 + region
				_:
					offer.tarot = "THE CENSUS"
					offer.label = "Census"
					offer["collect_kinds"] = true
					offer["collect_need"] = mini(13, 11 + region)
		elif goal == "landrush":
			# Land rush: stake a claim on every plot — clear a card
			# from each of the 25 cells.
			offer.tarot = "LAND RUSH"
			offer.label = "Land Rush"
			offer.odds = 2.0
			offer["goal"] = "landrush"
			offer.hands = MAX_HANDS_BUY
			offer.target = 0
	# Every job deals as either a HAND BUDGET or a COUNTDOWN (50/50) —
	# except the BANK JOB, the STAGECOACH, the GOLD MINE and the
	# ROYAL HUNT, which always run on the clock: vaults, schedules,
	# collapsing seams and stalked royals wait for no hand count.
	# Plain score tables that draw the clock take the HIGH NOON name.
	# The clock itself (HIGH NOON) is an unlock: before it, only the
	# always-timed jobs run on one — and those unlock after it.
	if String(offer.get("goal", "")) in ["safe", "chest", "mine"] \
			or String(offer.get("tarot", "")) == "ROYAL HUNT" \
			or (randf() < 0.5 and _avail("room", "clock")):
		offer["limit"] = "time"
		if not offer.has("minutes"):
			offer["minutes"] = clampi(roundi(int(offer.hands) * 0.35), 2,
					TIMED_MAX_MINUTES)
		if offer.get("goal", "") == "":
			offer.tarot = "HIGH NOON"
	else:
		offer["limit"] = "hands"
	return offer


func _render_tarot() -> void:
	for child in _tarot_cards_box.get_children():
		child.queue_free()
	var is_boss := BOSS_ROOMS.has(room_index)
	var region := room_index / REGION_SIZE + 1
	_tarot_info.text = "TABLE %d / %d   ·   REGION %d   ·   CHIPS %d   ·   DECK %d cards" \
			% [room_index + 1, ROOMS_TOTAL, region, chips, deck.size()]
	if relics.is_empty():
		_tarot_relics.text = ""
	else:
		var names := PackedStringArray()
		for id in relics:
			var relic_name := String(RELICS[id].name)
			if id == "second_wind" and _second_wind_used:
				relic_name += " (spent)"
			names.append(relic_name)
		_tarot_relics.text = "RELICS:  " + "  ·  ".join(names)
	var slot_count := _offers.size() + (0 if is_boss else 1)
	var total_w := slot_count * 330 - 30
	var start_x := (1920.0 - total_w) / 2.0
	for i in _offers.size():
		var offer: Dictionary = _offers[i]
		if offer.is_empty() or not offer.has("kind"):
			continue  # one bad roll must never blank the whole wall
		var b := _tarot_card_button(offer, start_x + i * 330)
		var picked := offer
		b.pressed.connect(func() -> void:
			_choose_offer(picked, false))
	if not is_boss:
		# The Fool: face-down fate.
		var fool: Button = main._button(_tarot_cards_box, "",
				Vector2(start_x + _offers.size() * 330, 0), Vector2(300, 380))
		var fool_tier := _apply_poster(fool, "luck_of_the_draw")
		if fool_tier != "":
			_poster_face(fool, "LUCK OF THE DRAW", fool_tier, "Face-down fate",
					"Let fate decide\n+%d chips" % (FATE_KICKER * _cost_mult(room_index)))
		else:
			_tarot_face(fool, "LUCK OF THE DRAW", "Face-down fate", "?",
					"Let fate decide\n+%d chips" % (FATE_KICKER * _cost_mult(room_index)),
					false, 64)
		fool.pressed.connect(func() -> void:
			_choose_offer(_fate_offer, true))


func _tarot_card_button(offer: Dictionary, x: float) -> Button:
	var b: Button = main._button(_tarot_cards_box, "", Vector2(x, 0), Vector2(300, 380))
	if offer.kind == "shop":
		var m: Dictionary = MERCHANTS[int(offer.get("merchant", 0))]
		var wares := PackedStringArray()
		if int(m.cards) > 0:
			wares.append("%d cards" % int(m.cards))
		if int(m.relics) > 0:
			wares.append("%d relics" % int(m.relics))
		if m.forge:
			wares.append("forge")
		var shop_tier := _apply_poster(b, "traveling_merchant")
		if shop_tier != "":
			_poster_face(b, String(m.name), shop_tier, String(m.line),
					"%s\nNo bet — browse free" % "  ·  ".join(wares))
		else:
			_tarot_face(b, String(m.name), "Safe haven", String(m.line),
					"%s\nNo bet — browse free" % "  ·  ".join(wares))
	elif offer.kind == "camp":
		if _apply_camp_poster(b):
			_poster_face(b, "CAMPFIRE", "rest stop",
					"Rest your bones, tend a card, or cast one to the flames",
					"No bet — one comfort\nHP %d / %d" % [hp, MAX_HP])
		else:
			_tarot_face(b, "THE CAMPFIRE", "Rest stop",
					"Rest, tend a card, or cast one to the flames",
					"No bet — one comfort\nHP %d / %d" % [hp, MAX_HP])
	else:
		var goal_line := "Target  %d" % offer.target
		if offer.has("boss"):
			goal_line = "BOSS FIGHT"
		elif offer.get("goal", "") == "safe":
			goal_line = "Crack the safe"
		elif offer.get("goal", "") == "chest":
			goal_line = "Open %d chests — win a RELIC" % int(offer.get("chest_count", 1))
		elif offer.get("goal", "") == "purge":
			goal_line = "Clear %d %s cards — %d seeded, more keep coming" % [
					int(offer.get("purge_quota", PURGE_QUOTA_BASE)),
					String(offer.purge_kind).to_upper(), offer.purge_count]
		elif offer.get("goal", "") == "mine":
			goal_line = "Clear the whole seam: %d stones — gold in the rubble" % offer.stones
		elif offer.get("goal", "") == "holdem":
			goal_line = "Target %d — HOLD'EM rules" % offer.target
		elif offer.get("goal", "") == "crazy8":
			goal_line = "Target %d — 8s WILD, hazards everywhere" % offer.target
		elif offer.get("goal", "") == "blackjack":
			goal_line = "Beat the dealer %d times — hazards in play" % offer.wins
		elif offer.get("goal", "") == "outlaw":
			var gang: Array = offer.get("outlaws", [])
			if gang.size() > 1:
				goal_line = "Hunt down a gang of %d — %d HP a head" % [
						gang.size(), offer.outlaw_hp]
			else:
				goal_line = "Gun down %s (%d HP)" % [
						String(gang[0].name) if not gang.is_empty()
						else "the wanted man", offer.outlaw_hp]
		elif offer.get("goal", "") == "collect":
			goal_line = _collect_goal_text(offer)
		elif offer.get("goal", "") == "landrush":
			goal_line = "Claim all 25 plots — clear a card from every cell"
		elif offer.get("goal", "") == "hands":
			goal_line = "Play " + _require_text(offer.require)
		elif offer.get("goal", "") == "timed":
			goal_line = "Target %d — beat the clock" % offer.target
		var bet_line := "Ante %d  ·  ~%d hands" % [offer.min_bet, offer.hands]
		if offer.get("limit", "hands") == "time":
			bet_line = "Ante %d  ·  on the clock, ~%d min" % [offer.min_bet,
					offer.get("minutes", 4)]
		if offer.has("boss"):
			bet_line = "ALL IN"
		if offer.get("goal", "") == "outlaw" and _apply_wanted_poster(b, offer):
			return b
		var tier := _apply_poster(b, _poster_job(String(offer.tarot)),
				_offer_tier(offer))
		if tier != "":
			_poster_face(b, offer.tarot, tier, goal_line,
					"Odds  %s\n%s" % [_odds_text(offer.odds), bet_line])
		else:
			_tarot_face(b, offer.tarot, "%s table" % offer.label, goal_line,
					"Odds  %s\n%s" % [_odds_text(offer.odds), bet_line],
					offer.has("boss"))
	return b


## The campfire's poster: the design pack's REST STOP band and
## campfire medallion on the kit parchment. Falls back to the steady
## ribbon with a code-drawn fire, then to no poster at all.
func _apply_camp_poster(b: Button) -> bool:
	var base_p := "res://assets/art/r2/posters/base/poster.png"
	var tier_p := "res://assets/art/campfire/poster/tier_rest_stop.png"
	var emblem_p := "res://assets/art/campfire/poster/emblem_campfire.png"
	if ResourceLoader.exists(base_p) and ResourceLoader.exists(tier_p) \
			and ResourceLoader.exists(emblem_p):
		for state in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		b.size = Vector2(300, 420)
		b.pivot_offset = b.size / 2.0
		for p in [base_p, tier_p, emblem_p]:
			var tr := TextureRect.new()
			tr.texture = load(p)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			tr.size = Vector2(300, 420)
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(tr)
		return true
	var tier := _apply_poster(b, "", "steady")
	if tier == "":
		return false
	# Logs crossed under three licks of flame, at the emblem circle.
	var cx := 150.0
	var cy := 232.0
	for ang in [-0.5, 0.5]:
		var log := ColorRect.new()
		log.color = Color("4a3020")
		log.size = Vector2(66, 9)
		log.position = Vector2(cx - 33, cy + 26)
		log.pivot_offset = Vector2(33, 4.5)
		log.rotation = ang
		log.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(log)
	var flames := [[26.0, 44.0, Color("b8402c")], [18.0, 32.0, Color("e8862c")],
			[10.0, 20.0, Color("f0c060")]]
	for f in flames:
		var w: float = f[0]
		var h: float = f[1]
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(cx - w, cy + 26), Vector2(cx - w * 0.4, cy + 4 - h * 0.4),
			Vector2(cx, cy + 26 - h), Vector2(cx + w * 0.5, cy + 8 - h * 0.3),
			Vector2(cx + w, cy + 26)])
		poly.color = f[2]
		b.add_child(poly)
	return true


## The BOUNTY offer is a real wanted poster: the leader's composed
## portrait on the card template, name in Rye ink, DEAD OR ALIVE in
## red, and the reward inked on the dashed line. Returns false when
## the character kit is absent (the tier-poster path takes over).
func _apply_wanted_poster(b: Button, offer: Dictionary) -> bool:
	var outlaws: Array = offer.get("outlaws", [])
	if outlaws.is_empty() or not CharacterKit.available():
		return false
	var leader: Dictionary = outlaws[0]
	var reward := int(round(float(offer.min_bet) * float(offer.odds)))
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.size = Vector2(300, 420)
	b.pivot_offset = b.size / 2.0
	# Every head gets a lettered poster from the template (the baked
	# THE OUTLAW card retired with the generic name). The plain
	# template bakes DEAD OR ALIVE; we letter our own red line (gang
	# size, HP), so take the blank-subtitle version.
	var info := CharacterKit.poster_info("card_template")
	var tpl: Texture2D = CharacterKit.tex(String(info.get("no_subtitle",
			info.get("file", ""))))
	if tpl == null:
		return false
	var paper := TextureRect.new()
	paper.texture = tpl
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.size = Vector2(300, 420)
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(paper)
	CharacterKit.add_portrait(b, leader, Rect2(66, 125, 168, 168))
	var sub_text := "GANG OF %d · %d HP EACH · ANTE %d" % [outlaws.size(),
			int(offer.outlaw_hp), int(offer.min_bet)] if outlaws.size() > 1 \
			else "DEAD OR ALIVE · %d HP · ANTE %d" % [int(offer.outlaw_hp),
			int(offer.min_bet)]
	var subtitle := _face_label(b, sub_text, 92.0, 20.0, 13, Color("8a3a30"))
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var who := String(leader.get("name", "THE WANTED MAN"))
	var name_size := 28 if who.length() <= 12 else 20
	var name_l := _face_label(b, who, 322.0 - name_size - 6, name_size + 12.0,
			name_size, UiKit.POSTER_INK)
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if FontLib.display != null:
		name_l.add_theme_font_override("font", FontLib.display)
	var reward_l := _face_label(b, "$%d" % reward, 359.0, 34.0, 26, Color("8a3a30"))
	reward_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if FontLib.display != null:
		reward_l.add_theme_font_override("font", FontLib.display)
	return true


## The round-2 room-offer posters: parchment base, tier ribbon, job
## emblem, stacked under the button's text. Returns the job's tier
## name on success, "" when the kit (or this job's emblem) is absent.
static var _poster_index := {}
static var _poster_index_loaded := false


# The plain tables were renamed after round 2 shipped; their poster
# emblems (chip stacks, scaling with the stakes) keep the old ids.
const POSTER_JOB_ALIASES := {
	"easy_money": "limit_table",
	"fat_pot": "pot_limit",
	"high_stakes": "no_limit",
	"dust_storm": "dust_devil",  # the kit painted the old purge name
}


## "DEALER'S CALL" -> "dealers_call", "CRAZY 8s" -> "crazy_8s".
func _poster_job(tarot_name: String) -> String:
	var job := tarot_name.to_lower().replace("'", "").replace(" ", "_")
	return String(POSTER_JOB_ALIASES.get(job, job))


## The ribbon tells the truth: a table's tier comes from the odds it
## actually posts, not from a fixed per-job list — a 1:1 HIGH NOON is
## STEADY, a 2:1 GOLD MINE is DANGEROUS. Purges and bosses keep their
## own ribbons.
func _offer_tier(offer: Dictionary) -> String:
	if offer.has("boss"):
		return "boss"
	if String(offer.get("goal", "")) == "purge":
		return "purge"
	var odds := float(offer.get("odds", 1.0))
	if odds <= 1.0:
		return "steady"
	if odds <= 1.6:
		return "risky"
	return "dangerous"


func _apply_poster(b: Button, job: String, tier_override := "") -> String:
	if not _poster_index_loaded:
		_poster_index_loaded = true
		var path := "res://assets/art/r2/posters_index.json"
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if typeof(parsed) == TYPE_DICTIONARY:
				_poster_index = parsed
	if _poster_index.is_empty():
		return ""
	var layers: Dictionary = _poster_index.get("layers", {})
	var tier := tier_override if tier_override != "" \
			else String(_poster_index.get("job_tier", {}).get(job, "risky"))
	var files: Array = [
		String(layers.get("base", {}).get("poster", "")),
		String(layers.get("tier", {}).get(tier, ""))]
	# Jobs without a painted emblem (the campfire) draw their own.
	var emblem := String(layers.get("emblem", {}).get(job, ""))
	if emblem != "":
		files.append(emblem)
	elif job != "":
		return ""
	var texes: Array = []
	for f in files:
		var p: String = "res://assets/art/r2/" + String(f)
		if f == "" or not ResourceLoader.exists(p):
			return ""
		texes.append(load(p))
	# The poster replaces the button chrome outright — paper, not oak.
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	# 500x700 canvas at 0.6 = a 300x420 card.
	b.size = Vector2(300, 420)
	b.pivot_offset = b.size / 2.0
	for t in texes:
		var tr := TextureRect.new()
		tr.texture = t
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.position = Vector2.ZERO
		tr.size = Vector2(300, 420)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tr)
	return tier


## Text over a poster, in the manifest's boxes (scaled 500x700 -> 0.6):
## Rye ink title, the tier name on the ribbon, goal and stakes in the
## stats block under the printed divider.
func _poster_face(b: Button, head: String, tier: String, body: String,
		foot: String) -> void:
	# Long job names (LUCK OF THE DRAW, STAGECOACH HAUL) drop a size
	# instead of clipping against the title box.
	var title := _face_label(b, head, 52.0, 58.0,
			26 if head.length() <= 12 else 19, UiKit.POSTER_INK)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if FontLib.display != null:
		title.add_theme_font_override("font", FontLib.display)
	var ribbon := _face_label(b, tier.to_upper(), 128.0, 20.0, 13,
			Color(0.95, 0.93, 0.88))
	ribbon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var bodyl := _face_label(b, body, 302.0, 48.0, 15, UiKit.POSTER_INK)
	bodyl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var footl := _face_label(b, foot, 348.0, 40.0, 13, UiKit.POSTER_INK)
	footl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


## Lays a clean face over a tarot button: gold name, a hairline rule,
## the table type, the wrapped goal (never clipped), and the stakes
## pinned at the foot.
func _tarot_face(b: Button, head: String, sub: String, body: String,
		foot: String, danger := false, body_size := 20) -> void:
	var title := _face_label(b, head, 14.0, 60.0, 24, main.RED if danger else main.GOLD)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var rule := ColorRect.new()
	rule.color = Color(main.GOLD.r, main.GOLD.g, main.GOLD.b, 0.35)
	rule.position = Vector2(50, 84)
	rule.size = Vector2(200, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(rule)
	var subl := _face_label(b, sub, 96.0, 30.0, 19, main.DIM)
	subl.uppercase = true
	var bodyl := _face_label(b, body, 138.0, 160.0, body_size, main.OFFWHITE)
	bodyl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var footl := _face_label(b, foot, 302.0, 66.0, 18, main.GOLD)
	footl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


## One centered, autowrapping, click-transparent label on a card face.
func _face_label(b: Button, text: String, y: float, h: float, size: int,
		col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Autowrap must be on BEFORE size is set: a Label refuses a size
	# below its minimum, and without wrapping the minimum is the full
	# unwrapped line — which is how text escapes the card.
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.clip_text = true
	l.position = Vector2(16, y)
	l.size = Vector2(268, h)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	return l


## One line describing a roundup offer's demand.
func _collect_goal_text(o: Dictionary) -> String:
	if o.has("collect_suit"):
		return "Clear %d %s" % [int(o.collect_need),
				String(PlayingCard.SUIT_NAMES[int(o.collect_suit)]).to_upper()]
	if o.has("collect_rank"):
		return "Bring in %d %s" % [int(o.collect_need),
				_rank_plural(int(o.collect_rank))]
	return "Clear cards of %d different ranks" % int(o.get("collect_need", 0))


func _odds_text(odds: float) -> String:
	if is_equal_approx(odds, 1.5):
		return "3 : 2"
	if is_equal_approx(odds, 2.5):
		return "5 : 2"
	if is_equal_approx(odds, 3.5):
		return "7 : 2"
	return "%d : 1" % maxi(1, int(round(odds)))


func _require_text(req: Array) -> String:
	var parts := PackedStringArray()
	for r in req:
		parts.append("%d× %s" % [int(r[1]), String(r[0]).to_upper()])
	return " + ".join(parts)


func _choose_offer(offer: Dictionary, from_fate: bool) -> void:
	main.transition(func() -> void:
		_choose_offer_now(offer, from_fate))


func _log_stop(offer: Dictionary) -> void:
	var kind := "table"
	if offer.kind == "shop":
		kind = "shop"
	elif offer.kind == "camp":
		kind = "camp"
	elif offer.has("boss"):
		kind = "boss"
	elif String(offer.get("goal", "")) == "outlaw":
		kind = "outlaw"
	while trail_log.size() <= room_index:
		trail_log.append("")
	trail_log[room_index] = kind


func _choose_offer_now(offer: Dictionary, from_fate: bool) -> void:
	if from_fate:
		chips += FATE_KICKER * _cost_mult(room_index)
	current_offer = offer
	tarot_layer.visible = false
	_log_stop(offer)
	if offer.kind == "shop":
		_show_shop()
	elif offer.kind == "camp":
		_show_camp()
	elif offer.has("boss"):
		# The house demands everything at a boss table.
		main.board._play_sound(Board.SFX_REVOLVER_CHARGE, 0.9, -6.0)
		stake = chips
		stake_odds = float(offer.odds)
		chips = 0
		_start_room()
	else:
		_show_bet()


# --- Flow: betting --------------------------------------------------------

## The stakes screen: the blind is forced, the hands are bought.
func _show_bet() -> void:
	_hide_all()
	var o := current_offer
	if o.has("boss"):
		# The house demands everything at a boss table, retry included.
		main.board._play_sound(Board.SFX_REVOLVER_CHARGE, 0.9, -6.0)
		stake = chips
		stake_odds = float(o.odds)
		chips = 0
		_start_room()
		return
	# A pending room bars the way — no backing out to a fresh draw.
	_bet_back_btn.visible = pending_retry.is_empty()
	_bet_amount = int(o.min_bet)
	_refresh_bet_labels()
	bet_layer.visible = true


func _is_timed(o: Dictionary) -> bool:
	return o.get("limit", "hands") == "time"


## Rooms that run on the clock instead of a hand budget.
func room_on_clock() -> bool:
	return room_limit == "time"


func _max_bet() -> int:
	return maxi(int(current_offer.min_bet), chips - int(current_offer.min_bet))


func _bet_goal_text(o: Dictionary) -> String:
	match String(o.get("goal", "")):
		"safe":
			return "Crack the safe"
		"chest":
			return "Open %d chests — a RELIC rides in the strongbox" \
					% int(o.get("chest_count", 1))
		"purge":
			if o.purge_kind == "fire":
				return "Clear %d fire cards — %d to start, it spreads, and more keep catching" \
						% [int(o.get("purge_quota", PURGE_QUOTA_BASE)), o.purge_count]
			return "Clear %d %s cards — %d seeded, more arrive as you play" \
					% [int(o.get("purge_quota", PURGE_QUOTA_BASE)), o.purge_kind, o.purge_count]
		"mine":
			return "Mine the seam dry: break all %d stones (gold in the rubble, more rock rides in as you dig)" % o.stones
		"holdem":
			return "Target %d — pick 2 hole cards, best 5 of 7 with the community" % o.target
		"crazy8":
			return "Target %d — every 8 is WILD, but the board crawls with hazards" % o.target
		"blackjack":
			return "Beat the dealer %d times — a face-down table, blind hits, and a real dealer playing out his hand" % o.wins
		"outlaw":
			var gang: Array = o.get("outlaws", [])
			var who := String(gang[0].name) if not gang.is_empty() else "the wanted man"
			if gang.size() > 1:
				return "Bounty: gun down %s and the gang riding behind — %d heads at %d HP each, one at a time" \
						% [who, gang.size(), o.outlaw_hp]
			return "Bounty: shoot %s %d times — and step around the waiting slugs" \
					% [who, o.outlaw_hp]
		"collect":
			return _collect_goal_text(o)
		"landrush":
			return "Stake a claim on all 25 plots — clear a card from every cell of the grid"
		"hands":
			return "Play " + _require_text(o.require)
		"timed":
			return "Target %d before the clock dies" % o.target
	return "Target %d" % o.target


func _refresh_bet_labels() -> void:
	var o := current_offer
	var retry_line := ""
	if not pending_retry.is_empty():
		retry_line = "\nTHE TABLE STILL BARS THE WAY — beat it or bust." \
				if pending_is_retry else "\nBack to the table you stepped away from."
	var blind := int(o.min_bet)
	var unit := "min" if _is_timed(o) else "hands"
	var reference := int(o.get("minutes", 4)) if _is_timed(o) else int(o.hands)
	_bet_amount = clampi(_bet_amount, blind, _max_bet())
	_bet_info.text = "%s — %s table\n%s   ·   odds %s   ·   %d %s to do it\nAnte %d — the house keeps it\nYour chips: %d%s" % [
		o.tarot, o.label, _bet_goal_text(o), _odds_text(o.odds), reference,
		unit, blind, chips, retry_line]
	_bet_amount_label.text = "BET  %d" % _bet_amount
	_bet_stake_label.text = "Odds ×%.2f      clearing pays back %d" % [
		float(o.odds), _bet_amount + int(_bet_amount * float(o.odds))]


func _confirm_bet() -> void:
	main.board._play_sound(Board.SFX_REVOLVER_CHARGE, 1.0, -8.0)
	var o := current_offer
	var blind := int(o.min_bet)
	stake = clampi(_bet_amount, blind, maxi(blind, chips - blind))
	stake_odds = float(o.odds)
	chips -= blind + stake
	bet_layer.visible = false
	_start_room()


# --- Flow: playing a room -------------------------------------------------

func _start_room() -> void:
	in_room = true
	main.stat_max("deepest_table", room_index + 1)
	sleeve_used = false  # one signature use per table, fresh each sit-down
	_aiming_sleeve = false
	_aiming_sleight = false
	sleight_uses_left = 1 + sleight_level
	_aiming_sleight = false
	laser_used = false
	_aiming_laser = false
	_swap_first = null
	watch_uses_left = 1 + watch_level
	_watch_snapshot = {}
	main.board.undo_state = {}
	main.board.undo_enabled = character == "the_doctor"
	_chest_rewards.clear()  # unopened luck doesn't carry between tables
	_chest_won_cards.clear()
	main.tutor_show("hp")
	# The Chuck Wagon rolls in with supplies at every table.
	if has_relic("chuck_wagon") and provisions.size() < kit_size():
		var ration := _random_provision()
		if gain_provision(ration):
			main._announce("THE CHUCK WAGON PROVIDES — %s"
					% String(PROVISIONS[ration].name).to_upper())
	elif has_relic("chuck_wagon") and int(rv("chuck_wagon", "chips")) > 0:
		# A full kit takes its rations in chips instead.
		var ration_chips := _blind_for(room_index)
		chips += ration_chips
		main._announce("THE CHUCK WAGON PAYS  +%d CHIPS" % ration_chips)
	match character:
		"the_machine":
			main.tutor_show("laser")
		"the_doctor":
			main.tutor_show("watch")
		_:
			main.tutor_show("sleight" if gambler_ability == "sleight" else "sleeve")
	room_score = 0
	room_target = current_offer.target
	room_goal = current_offer.get("goal", "")
	# Legacy saves: the old HIGH NOON room type folds into "" + clock.
	if room_goal == "timed":
		room_goal = ""
		current_offer["limit"] = "time"
	room_limit = current_offer.get("limit", "hands")
	if current_offer.has("boss"):
		room_goal = "boss"
		room_limit = "hands"
	room_combo = []
	room_require = (current_offer.get("require", []) as Array).duplicate(true)
	room_require_total = 0
	for r in room_require:
		room_require_total += int(r[1])
	room_chests_needed = int(current_offer.get("chest_count", 1))
	room_chests_opened = 0
	room_stones_needed = int(current_offer.get("stones", 1))
	room_stones_broken = 0
	room_collect_need = int(current_offer.get("collect_need", 0))
	room_collect_done = 0
	room_collect_kinds = {}
	room_wins_needed = int(current_offer.get("wins", 3))
	room_wins = 0
	room_outlaw_hp = int(current_offer.get("outlaw_hp", 5))
	room_outlaw_max = room_outlaw_hp
	# The posse is on the books before the first card lands, so the
	# HUD names the right head from frame one.
	room_outlaws = current_offer.get("outlaws", [])
	room_outlaw_idx = 0
	if room_outlaws.is_empty() and room_goal == "outlaw" \
			and CharacterKit.available():
		room_outlaws = _roll_posse(int(current_offer.get("posse", 1)))
	room_hands_left = int(current_offer.get("hands_bought", current_offer.hands)) \
			+ (int(rv("horseshoe", "hands")) if has_relic("horseshoe") else 0)
	room_time_left = 0.0
	if room_on_clock():
		# The clock is the budget, not hands.
		room_time_left = 60.0 * int(current_offer.get("minutes_bought",
				current_offer.get("minutes", 3))) \
				+ (float(rv("horseshoe", "secs")) if has_relic("horseshoe") else 0.0)
		room_hands_left = 999
	main.mode_kind = "trail"
	main.mode_label_text = "Trail · %s · %s" % [_table().name.capitalize(),
			character_name()]
	main.board.custom_deck = deck.duplicate(true)
	main.game_started = true
	main.game_over = false
	main.play_music("boss" if current_offer.has("boss") else "room")
	# The ride's backdrop: daylight fades region by region; bosses
	# play under a storm.
	if current_offer.has("boss"):
		main.parallax.set_scene("storm")
	else:
		var looks := ["trail_day", "trail_dusk", "trail_night"]
		main.parallax.set_scene(looks[clampi(room_index / REGION_SIZE, 0, 2)])
	main.board.visible = true
	main.board.reset(room_goal == "blackjack")
	main._begin_countdown()
	_seed_room_specials()


## After the deal settles, put the room's promise on the board: hazards,
## objectives, or (in plain rooms) a surprise ambient bonus.
func _seed_room_specials() -> void:
	while main.board.busy:
		await get_tree().process_frame
	if not in_room:
		return
	# The tarot decided the GOAL; seed it first.
	if current_offer.has("boss"):
		main.board.spawn_boss(current_offer.boss)
		main._announce(String(BOSSES[current_offer.boss].name).to_upper(), main.RED)
	elif room_goal == "safe":
		room_combo = _generate_combo()
		main.board.spawn_safe(room_combo)
	elif room_goal == "chest":
		main.board.spawn_key_and_chest()
	elif room_goal == "purge":
		main.board.apply_room_hazards(String(current_offer.purge_kind),
				int(current_offer.purge_count))
	elif room_goal == "mine":
		# A board choked with rock — but NOT solid: the plain cards
		# between the stones pop and refill, so the mine keeps shifting
		# and the same hand can't just be replayed three times.
		main.board.apply_room_hazards("stone", GOLD_MINE_STONE_SEED)
	elif room_goal == "landrush":
		main.board.landrush_active = true
		main.board.queue_redraw()
	elif room_goal == "holdem":
		main.board.deal_community()
		if randf() < 0.5:
			main.board.spawn_objective("redeal")
	elif room_goal == "crazy8":
		main.board.eights_wild = true
		PlayingCard.eights_wild = true
		main.board.apply_theme()  # repaint so the 8s show their W
	elif room_goal == "blackjack":
		_deal_dealer()
		main.board.set_blackjack_facedown()
	elif room_goal == "outlaw":
		_outlaw_dead_pending = false
		main.outlaw.spec = current_outlaw_spec()
		main.outlaw.appear(room_outlaw_hp)
		main.show_wanted_banner(current_outlaw_spec(), _bounty_subtitle(),
				bounty_reward())
		for i in 2:
			main.board.spawn_objective("bullet")
		for i in 2:
			main.board.spawn_objective("hisbullet")
	elif randf() < AMBIENT_CHANCE * (float(rv("rabbits_foot", "x")) if has_relic("rabbits_foot") else 1.0) \
			and (_avail("room", "safe") or _avail("room", "chest")):
		# Surprise loot in a plain room — only jobs the rider has met.
		var safe_ok := _avail("room", "safe")
		if safe_ok and (not _avail("room", "chest") or randf() < 0.5):
			room_combo = _generate_combo()
			main.board.spawn_safe(room_combo)
		else:
			main.board.spawn_key_and_chest()
	# Storm tables (Crazy 8s, Blackjack) trade the ambient roll for a
	# guaranteed mixed hazard load — the house evening the odds.
	var storm := _hazard_floor()
	for i in storm:
		main.board.apply_room_hazards(HAZARD_KINDS.pick_random(), 1)
	# Hazards are ambient in EVERY other play room — bosses included —
	# and get more frequent and more numerous with depth and stakes.
	# Purge rooms are exempt: their hazards ARE the room.
	if room_goal != "purge" and storm == 0:
		var hz_chance := clampf(HAZARD_BASE_CHANCE + HAZARD_ROOM_STEP * room_index
				+ HAZARD_TIER_STEP * table_tier, 0.0, 0.95)
		if randf() < hz_chance:
			var count := 1 + room_index / HAZARD_COUNT_ROOMS
			if table_tier == 2 and randf() < 0.5:
				count += 1
			count = mini(count, HAZARD_COUNT_MAX)
			for i in count:
				main.board.apply_room_hazards(HAZARD_KINDS.pick_random(), 1)
	# And the deck itself turns mean: every refilled card has a chance
	# to arrive hazarded, climbing the deeper you ride.
	if room_goal != "purge":
		main.board.refill_hazard_chance = clampf(REFILL_HAZARD_BASE
				+ REFILL_HAZARD_STEP * room_index, 0.0, REFILL_HAZARD_MAX)
	# Relic adjustments to freshly-seeded hazards (purge seeds included).
	for p in main.board.grid:
		var card: PlayingCard = main.board.grid[p]
		if card.hazard == "bomb" and has_relic("bomb_badge"):
			card.fuse = Board.BOMB_FUSE + int(rv("bomb_badge", "fuse"))
		elif card.hazard == "stone" and has_relic("chisel"):
			card.stone_hits = Board.STONE_HITS_START - 1
	# Opening seeds fight from hand one — spreading, soaking, burning
	# down, fuses lit. Only mid-room arrivals sit a round out.
	main.board.season_hazards()
	# A heavy seed — the GOLD MINE's rock above all — can bury every
	# move before the first hand. The dead-board reshuffle has to run
	# at the deal too, not just after hands.
	while main.board.busy:
		await get_tree().process_frame
	if in_room and not main.board.has_playable_hand():
		main._announce("NO MOVES — RESHUFFLE")
		for i in 3:
			await main.board.shuffle_board()
			if not in_room or main.board.has_playable_hand():
				break
	_tutor_room_intros()


## Storm tables keep a guaranteed hazard load on the board; every
## other room returns 0 and rides the ordinary ambient roll.
func _hazard_floor() -> int:
	match room_goal:
		"crazy8":
			return CRAZY8_HAZARDS_BASE + room_index / REGION_SIZE
		"blackjack":
			return BLACKJACK_HAZARDS_BASE + room_index / REGION_SIZE
	return 0


## First-encounter popups for whatever this room just put in play.
func _tutor_room_intros() -> void:
	match room_goal:
		"safe":
			main.tutor_show("goal_safe")
		"chest":
			main.tutor_show("goal_chest")
		"purge":
			main.tutor_show("goal_purge")
		"mine":
			main.tutor_show("goal_mine")
		"hands":
			main.tutor_show("goal_hands")
		"holdem":
			main.tutor_show("goal_holdem")
		"crazy8":
			main.tutor_show("goal_crazy8")
		"blackjack":
			main.tutor_show("goal_blackjack")
		"outlaw":
			main.tutor_show("goal_outlaw")
		"collect":
			main.tutor_show("goal_collect")
		"landrush":
			main.tutor_show("goal_landrush")
	if room_on_clock():
		main.tutor_show("goal_timed")
	for p in main.board.grid:
		var card: PlayingCard = main.board.grid[p]
		if card.hazard != "":
			main.tutor_show("hazard_" + card.hazard)
		if card.objective in ["key", "chest"] and room_goal != "chest":
			# Ambient loot in an ordinary room — the lighter popup, not
			# the treasure-room briefing.
			main.tutor_show("loot_chest")
		if card.is_safe:
			main.tutor_show("goal_safe")
		if card.boss != "":
			main.tutor_show("boss_" + card.boss)


## A 4-digit combination drawn from low ranks present on the board.
func _generate_combo() -> Array:
	var max_rank := int(rv("dowsing_rod", "max")) if has_relic("dowsing_rod") else 9
	var pool: Array = []
	for p in main.board.grid:
		var card: PlayingCard = main.board.grid[p]
		if not card.cursed and not card.is_safe and card.rank <= max_rank:
			pool.append(card.rank)
	var combo: Array = []
	for i in 4:
		combo.append(pool.pick_random() if not pool.is_empty() else randi_range(2, max_rank))
	return combo


func on_hand_played(result: Dictionary) -> void:
	# main already added result.score to the run total (main.score).
	chips += result.get("bonus_chips", 0)
	var negs := int(result.get("negatives", 0))
	if negs > 0 and in_room:
		# NEGATIVE cards give the time back — banked before the hand is
		# charged, so a hand that scores one costs nothing.
		if room_on_clock():
			var secs := negs * int(progress.val("finish", "negative", "secs", 10))
			room_time_left += secs
			_announce_after_settle("NEGATIVE  +%d SECONDS" % secs)
		else:
			room_hands_left += negs
			_announce_after_settle("NEGATIVE — HAND BACK" if negs == 1
					else "NEGATIVE — %d HANDS BACK" % negs)
	room_score += result.score
	if int(result.score) > best_hand_score:
		best_hand_score = int(result.score)
		best_hand_name = String(result.get("name", ""))
	# Chip cards SEASON with use: each scoring permanently bumps that
	# deck card's payout a full base step for the rest of the run.
	for cc in result.get("cleared_cards", []):
		if String(cc.get("mod", "")) != "chip" or bool(cc.get("joker", false)):
			continue
		for d in deck:
			if String(d.get("mod", "")) == "chip" and int(d.rank) == int(cc.rank) \
					and int(d.suit) == int(cc.suit) \
					and int(d.get("chip_lv", 0)) == int(cc.get("chip_lv", 0)):
				d["chip_lv"] = int(d.get("chip_lv", 0)) + 1
				break
	var earned := int(result.get("cash_earned", 0))
	if earned > 0:
		# Cash cards pay real money, banked on the spot.
		cash += earned
		_save_meta()
		_announce_after_settle("GOLD  +$%d" % earned)
	if result.get("boss_defeated", false):
		_room_cleared()
		return
	if result.get("jack_shrugged", false):
		_announce_after_settle("THE JACK SCOFFS — BEAT %d TO WOUND HIM"
				% main.board.jack_bar)
	if result.get("chest_opened", false):
		if room_goal == "chest":
			_open_chest()
			room_chests_opened += 1
			if room_chests_opened >= room_chests_needed:
				_room_cleared()
				return
			# The job's not done: the tick's treasure check deals a
			# fresh pair once the board settles.
			_consume_hand()
			return
		# An AMBIENT chest keeps its secret: the reward is rolled now
		# but only cracked open once the table is cleared.
		_defer_chest_reward()
	if room_goal in ["", "timed", "holdem", "crazy8"] and room_score >= room_target:
		_room_cleared()
		return
	if room_goal == "holdem":
		_holdem_upkeep()
	var floor_count := _hazard_floor()
	if floor_count > 0:
		# The storm doesn't blow over: whenever the board calms below
		# its seeded level, a fresh hazard rides in on the next deal.
		var live := 0
		for p in main.board.grid:
			if main.board.grid[p].hazard != "":
				live += 1
		if live < floor_count:
			main.board.queue_refill_hazards(HAZARD_KINDS.pick_random(), 1)
	if room_goal == "blackjack" and result.has("blackjack_outcome"):
		_present_blackjack_round(result)
	if room_goal == "outlaw" and not _outlaw_dead_pending:
		var hits := int(result.get("bullets_you", 0))
		if hits > 0:
			room_outlaw_hp -= hits
			# Each scored bullet forms up and ZOOMS into him — the
			# flinch, the HP tick, and the bang land on impact.
			var points: Array = result.get("bullet_points", [])
			for i in hits:
				var from: Vector2 = points[i] if i < points.size() \
						else main.board.global_position + Vector2(580, 450)
				_fire_bullet(from, 0.18 * i, room_outlaw_hp + (hits - 1 - i),
						i == hits - 1 and room_outlaw_hp <= 0)
		if room_outlaw_hp <= 0:
			_outlaw_dead_pending = true
			return
		# HIS bullets are mines now: no fuse, no countdown. Clear a card
		# carrying one and he shoots you for it — step AROUND them.
		var caught := int(result.get("bullets_his", 0))
		# Weak hands still give him a free shot.
		if result.score < _outlaw_bar():
			caught += 1
		if caught > 0:
			# No more grit: outlaw lead comes straight out of the
			# rider's HP.
			main.outlaw.shoot()
			main.board._play_sound(Board.SFX_REVOLVERS.pick_random(), 0.8, -5.0)
			if not take_damage(caught,
					"YOU CAUGHT HIS BULLET" if int(result.get("bullets_his", 0)) > 0
					else "%s FIRES" % current_outlaw_name(),
					"Shot by %s." % _title_case(current_outlaw_name())):
				return
		_replenish_bullets()
	if room_goal == "purge":
		# Quota met AND the table clean — a wildfire can overshoot its
		# ledger while flames still stand, and those must go out too.
		if purged_count() >= purge_quota() and purge_left() == 0:
			_room_cleared()
			return
		# The infestation keeps coming until the full quota has hit
		# the table — a couple per hand, riding in on the deal.
		var kind := String(current_offer.get("purge_kind", "fire"))
		var add := mini(PURGE_TRICKLE,
				purge_quota() - main.board.spawned_count(kind))
		add = mini(add, PURGE_FLOOR - purge_left())
		if add > 0:
			main.board.queue_refill_hazards(kind, add)
	if room_goal == "mine":
		room_stones_broken += int(result.get("stones_broken", 0))
		# Standing rock, not counting stones crumbling with this hand.
		var standing := 0
		for p in main.board.grid:
			var mc: PlayingCard = main.board.grid[p]
			if mc.hazard == "stone" and mc.stone_hits > 0:
				standing += 1
		if room_stones_broken >= room_stones_needed and standing == 0:
			_room_cleared()
			return
		# The seam runs deep: more rock rides in on the deal until the
		# full count has hit the table.
		var seam: int = room_stones_needed - main.board.spawned_count("stone")
		if seam > 0 and standing < GOLD_MINE_FLOOR:
			main.board.queue_refill_hazards("stone",
					mini(GOLD_MINE_TRICKLE, seam))
	if room_goal == "collect":
		for cc in result.get("cleared_cards", []):
			if current_offer.has("collect_suit"):
				if int(cc.suit) == int(current_offer.collect_suit):
					room_collect_done += 1
			elif current_offer.has("collect_rank"):
				if int(cc.rank) == int(current_offer.collect_rank):
					room_collect_done += 1
			else:
				room_collect_kinds[int(cc.rank)] = true
		if current_offer.has("collect_kinds"):
			room_collect_done = room_collect_kinds.size()
		if room_collect_need > 0 and room_collect_done >= room_collect_need:
			_room_cleared()
			return
	if room_goal == "landrush":
		var newly := false
		for cell in result.get("cleared_cells", []):
			if not main.board.landrush_marks.has(cell):
				main.board.landrush_marks[cell] = true
				newly = true
		if newly:
			main.board.queue_redraw()
		if main.board.landrush_marks.size() >= main.board.cols * main.board.rows:
			_room_cleared()
			return
	if room_goal == "hands":
		for r in room_require:
			if String(r[0]) == String(result.name) and int(r[1]) > 0:
				r[1] = int(r[1]) - 1
				break
		if _require_left() == 0:
			_room_cleared()
			return
	# Lost keys and chests (played without a partner, blown off by
	# wind, burned out) respawn from the hazard tick's settle check —
	# one place, after everything that can remove a card has acted.
	_consume_hand()


## A hand (or a safe crack) is spent; run out and the room is lost.
func _consume_hand() -> void:
	if room_on_clock():
		# Clock rooms never run out of hands — only of seconds.
		_tick_room_hazards()
		return
	if has_relic("lucky_chip") and randf() < float(rv("lucky_chip", "p")):
		_announce_after_settle("LUCKY CHIP — free hand!")
	else:
		room_hands_left -= 1
	if room_hands_left <= 0:
		_last_hand_verdict()
	else:
		_tick_room_hazards()


## The last hand is spent — but that very hand may have WON the
## table (a purge counts the grid, which only empties once the pops
## settle), so the verdict waits for the board before ruling.
func _last_hand_verdict() -> void:
	while main.board.busy:
		await get_tree().process_frame
	if not in_room:
		return  # the hand's own win already closed the table
	if room_goal == "purge" and purged_count() >= purge_quota() \
			and purge_left() == 0:
		_room_cleared()
		return
	_room_failed()


## The ONE treasure respawn, run from the hazard tick after every
## hand settles: however a key or chest left the table — played solo,
## opened as a pair, blown off by a gust, burned out — whatever is
## missing turns up on a fresh card. Plain rooms only reunite ORPHANS
## (an ambient pair that is wholly gone was opened, not lost).
func _replace_lost_treasure() -> void:
	while main.board.busy:
		await get_tree().process_frame
	if not in_room:
		return
	var has_key: bool = main.board.has_objective("key")
	var has_chest: bool = main.board.has_objective("chest")
	if has_key and has_chest:
		return
	if room_goal != "chest" and has_key == has_chest:
		return
	if not has_key:
		main.board.spawn_objective("key")
	if not has_chest:
		main.board.spawn_objective("chest")
	if main.board.has_objective("key") == has_key \
			and main.board.has_objective("chest") == has_chest:
		return  # no clean card to carry it this hand; the next tick retries
	main.board._play_sound(Board.SFX_FLIP, 1.2, -8.0)
	if room_goal == "chest" and not has_key and not has_chest:
		main._announce("ANOTHER KEY, ANOTHER CHEST  (%d / %d)"
				% [room_chests_opened, room_chests_needed])
	else:
		main._announce("A NEW LEAD ON THE LOOT")


func on_safe_cracked() -> void:
	if room_goal == "safe":
		_room_cleared()
		return
	# Ambient safe: bonus loot, but the crack still costs a hand.
	var region := room_index / REGION_SIZE + 1
	var loot := 40 + 20 * region
	chips += loot
	main.board._play_sound(Board.SFX_BELL, 1.0, -8.0)
	main.board._play_sound(Board.SFX_COINS.pick_random(), 1.0, -6.0, 0.3)
	var msg := "SAFE LOOT  +%d CHIPS" % loot
	if randf() < 0.35 and provisions.size() < kit_size():
		# Sometimes the safe holds supplies instead of just coin.
		var pid := _random_provision()
		gain_provision(pid)
		msg += "  ·  %s" % String(PROVISIONS[pid].name).to_upper()
	_announce_after_settle(msg)
	_consume_hand()


## An ambient chest opened mid-room: the reward KIND is rolled now,
## the reveal waits for the winnings screen.
func _defer_chest_reward() -> void:
	var roll := randf()
	if roll < 0.5:
		_chest_rewards.append("chips")
	elif roll < 0.85:
		_chest_rewards.append("card")
	elif _unowned_common_relic() != "":
		_chest_rewards.append("relic")
	else:
		_chest_rewards.append("chips")
	main.board._play_sound(Board.SFX_COINS.pick_random(), 0.8, -8.0)
	_announce_after_settle("CHEST CLAIMED — IT CRACKS OPEN AFTER THE TABLE")


## A random COMMON relic the player doesn't own yet, or "".
func _unowned_common_relic() -> String:
	return _relic_pick([], true)


## Chest reward roll (treasure rooms — ambient chests defer instead).
func _open_chest() -> void:
	var region := room_index / REGION_SIZE + 1
	var roll := randf()
	if roll < 0.45:
		var loot := 30 + 15 * region
		chips += loot
		main.board._play_sound(Board.SFX_COINS.pick_random(), 1.0, -6.0)
		_announce_after_settle("CHEST  +%d CHIPS" % loot)
	elif roll < 0.65:
		# A card for the deck — held back and SHOWN on the victory
		# screen, not narrated mid-heist.
		var card := _random_card_offer(0.25)
		deck.append(card)
		_chest_won_cards.append(card)
		main.board._play_sound(Board.SFX_FLIP, 1.1, -8.0)
	elif roll < 0.80:
		# No loose cash on the trail — the chest holds a GOLD card.
		var gold := {"rank": randi_range(2, 14), "suit": randi_range(0, 3),
				"cursed": false, "mod": "gold", "finish": ""}
		deck.append(gold)
		_chest_won_cards.append(gold)
		main.board._play_sound(Board.SFX_COINS.pick_random(), 1.2, -8.0)
	elif roll < 0.88 and provisions.size() < kit_size():
		var pid := _random_provision()
		gain_provision(pid)
		_announce_after_settle("CHEST  A %s!" % String(PROVISIONS[pid].name).to_upper())
	elif roll < 0.95 and relics.size() < MAX_RELICS and _unowned_relic() != "":
		var id := _unowned_relic()
		_gain_relic(id)
		_announce_after_settle("CHEST  RELIC: %s!" % RELICS[id].name)
	else:
		var enhanced := {"rank": randi_range(2, 14), "suit": randi_range(0, 3),
				"cursed": false, "mod": _random_mod(),
				"finish": _roll_finish()}
		deck.append(enhanced)
		_chest_won_cards.append(enhanced)
		main.board._play_sound(Board.SFX_FLIP, 1.3, -8.0)
	_save_run()


## The round plays out at a human pace: your stand announced, the
## hole card flipped, each dealer hit landing one at a time, then the
## verdict — so the player can follow every beat.
func _present_blackjack_round(result: Dictionary) -> void:
	var outcome := String(result.blackjack_outcome)
	var player := int(result.get("blackjack_player", 0))
	# Every hand turns over a little more of the table.
	main.board.reveal_random_card()
	if outcome == "bust":
		# Nothing for the dealer to do — you handed him the round.
		_announce_after_settle("BUST AT %d — THE DEALER TAKES IT" % player)
		await get_tree().create_timer(2.2).timeout
	else:
		await get_tree().create_timer(1.0).timeout
		if not _blackjack_live():
			return
		main.board.flip_hole()
		main._announce("YOU STAND AT %d — DEALER FLIPS: %d"
				% [player, main.board.blackjack_target], main.OFFWHITE)
		await get_tree().create_timer(1.4).timeout
		while _blackjack_live() \
				and main.board.blackjack_revealed < main.board.blackjack_dealer_cards.size():
			var showing: int = main.board.reveal_dealer_card()
			main._announce("DEALER HITS — %d" % showing, main.OFFWHITE)
			await get_tree().create_timer(1.4).timeout
		if not _blackjack_live():
			return
		var dealer: int = main.board.blackjack_target
		if outcome == "win":
			room_wins += 1
			main.stat_bump("blackjack_rounds")
			main.board._play_sound(Board.SFX_COINS.pick_random(), 1.1, -8.0)
			if room_wins >= room_wins_needed:
				_room_cleared()
				return
			main._announce("DEALER BUSTS AT %d — ROUND WON  %d / %d"
					% [dealer, room_wins, room_wins_needed])
		elif outcome == "push":
			main._announce("PUSH AT %d — NOBODY WINS" % player, main.OFFWHITE)
		else:
			main._announce("DEALER STANDS AT %d — ROUND LOST" % dealer, main.RED)
		await get_tree().create_timer(1.8).timeout
	if _blackjack_live():
		_deal_dealer()


## One scored bullet, made flesh: a gold slug that forms at the card
## it came from, zooms across the table, and slams into the Outlaw —
## flinch, HP tick, and gunshot all landing on impact.
func _fire_bullet(from: Vector2, delay: float, hp_after: int, kills: bool) -> void:
	var slug := Node2D.new()
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-12, -5), Vector2(5, -5), Vector2(13, 0),
		Vector2(5, 5), Vector2(-12, 5)])
	body.color = main.GOLD
	slug.add_child(body)
	var trail_line := Polygon2D.new()
	trail_line.polygon = PackedVector2Array([
		Vector2(-34, -2), Vector2(-12, -3), Vector2(-12, 3), Vector2(-34, 2)])
	trail_line.color = Color(main.GOLD.r, main.GOLD.g, main.GOLD.b, 0.4)
	slug.add_child(trail_line)
	slug.z_index = 60
	slug.visible = false
	main.hud_root.add_child(slug)
	slug.global_position = from
	var to: Vector2 = main.outlaw.global_position + Vector2(4, -18)
	slug.rotation = (to - from).angle()
	var tw := slug.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		slug.visible = true
		main.board._play_sound(Board.SFX_REVOLVERS.pick_random(), 1.15, -8.0))
	tw.tween_property(slug, "global_position", to, 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		slug.queue_free()
		if not in_room or room_goal != "outlaw":
			# The player left the table mid-flight: no impact, no clear.
			_outlaw_dead_pending = false
			return
		main.outlaw.set_hp(hp_after)
		if main.board.fx != null:
			main.board.fx.burst(main.board.fx.to_local(to), "sparks")
		if kills:
			main.outlaw.die()
			outlaws_caught += 1
			_outlaw_dead_pending = false
			if room_outlaw_idx < room_outlaws.size() - 1:
				_next_outlaw()
			else:
				_room_cleared()
		else:
			main.outlaw.flinch())


## Still at this blackjack table? (Guards the paced presentation
## against abandons, busts of the room, and menu exits mid-await.)
func _blackjack_live() -> bool:
	return in_room and room_goal == "blackjack" \
			and not main.board.blackjack_dealer_cards.is_empty()


## Fresh dealer hand for the next blackjack round.
func _deal_dealer() -> void:
	main.board.deal_blackjack_dealer()


## Score an Outlaw hand must reach or he takes a free shot.
func _outlaw_bar() -> int:
	return OUTLAW_BAR_BASE + 15 * (room_index / REGION_SIZE)


## Rolls a bounty posse: a named leader off the wanted wall (presets
## that ride for themselves), then seeded gang members who keep their
## faces for the whole run.
func _roll_posse(n: int) -> Array:
	var out: Array = []
	if not CharacterKit.available():
		return out
	var leader := {}
	var leader_ids: Array = []
	for id in CharacterKit.preset_ids():
		if String(CharacterKit.preset(id).get("sub", "")) == "":
			leader_ids.append(id)
	if not leader_ids.is_empty():
		leader = CharacterKit.preset(leader_ids.pick_random())
	if leader.is_empty():
		leader = CharacterKit.random_spec(randi())
	if String(leader.get("name", "")) == "THE OUTLAW":
		# No generic names on the wanted wall: the old face rides on
		# under a name of his own.
		leader["name"] = "%s %s" % [CharacterKit.FIRST.pick_random(),
				CharacterKit.LAST.pick_random()]
	out.append(leader)
	for i in n - 1:
		var member: Dictionary = CharacterKit.random_spec(randi(),
				"RIDES WITH " + String(leader.name))
		var guard := 0
		while String(member.name) == String(leader.name) and guard < 8:
			member = CharacterKit.random_spec(randi(),
					"RIDES WITH " + String(leader.name))
			guard += 1
		out.append(member)
	return out


## The outlaw currently holding the table (empty when no kit).
func current_outlaw_spec() -> Dictionary:
	if room_outlaw_idx < room_outlaws.size():
		return room_outlaws[room_outlaw_idx]
	return {}


func current_outlaw_name() -> String:
	return String(current_outlaw_spec().get("name", "THE WANTED MAN"))


## The red line on the wanted paper.
func _bounty_subtitle() -> String:
	if room_outlaws.size() > 1:
		return "GANG OF %d · DEAD OR ALIVE" % room_outlaws.size()
	return "DEAD OR ALIVE"


## The bounty figure inked on the poster: the pot this table pays.
func bounty_reward() -> int:
	return int(round(stake * stake_odds))


## One head of the posse down — the next rides in at full strength.
func _next_outlaw() -> void:
	var downed := current_outlaw_name()
	room_outlaw_idx += 1
	room_outlaw_hp = room_outlaw_max
	main._announce("%s DOWN — %s RIDES IN" % [downed, current_outlaw_name()])
	await get_tree().create_timer(0.9).timeout
	if not in_room or room_goal != "outlaw":
		return
	main.outlaw.spec = current_outlaw_spec()
	main.outlaw.appear(room_outlaw_hp)
	_replenish_bullets()


## Keeps two of each bullet kind on the duel board.
func _replenish_bullets() -> void:
	while main.board.busy:
		await get_tree().process_frame
	if not in_room or room_goal != "outlaw":
		return
	for kind in ["bullet", "hisbullet"]:
		var have := 0
		for p in main.board.grid:
			if main.board.grid[p].objective == kind:
				have += 1
		for i in 2 - have:
			main.board.spawn_objective(kind)


## Hold'em housekeeping: the re-deal card has a chance to turn up.
func _holdem_upkeep() -> void:
	while main.board.busy:
		await get_tree().process_frame
	if not in_room or room_goal != "holdem":
		return
	if not main.board.has_objective("redeal") and randf() < 0.35:
		main.board.spawn_objective("redeal")


## Hazard cards still on the board — purge-room progress.
func purge_left() -> int:
	var n := 0
	for p in main.board.grid:
		if main.board.grid[p].hazard != "":
			n += 1
	return n


func _rank_plural(r: int) -> String:
	match r:
		11: return "JACKS"
		12: return "QUEENS"
		13: return "KINGS"
		14: return "ACES"
	return "%ds" % r


## Roundup progress line for the banner.
func collect_status() -> String:
	var o := current_offer
	if o.has("collect_suit"):
		return "CLEAR %s  %d / %d" % [
			String(PlayingCard.SUIT_NAMES[int(o.collect_suit)]).to_upper(),
			room_collect_done, room_collect_need]
	if o.has("collect_rank"):
		return "BRING IN %s  %d / %d" % [_rank_plural(int(o.collect_rank)),
				room_collect_done, room_collect_need]
	# The census names its remaining heads: every rank not yet cleared
	# stays on the list, and each catch strikes one off the banner.
	var left := PackedStringArray()
	for r in range(2, 15):
		if not room_collect_kinds.has(r):
			left.append(String(RANK_CHARS.get(r, str(r))))
	return "RANKS %d/%d · LEFT %s" % [room_collect_done, room_collect_need,
			" ".join(left)]


## The room's total clearing quota.
func purge_quota() -> int:
	return int(current_offer.get("purge_quota", PURGE_QUOTA_BASE))


## Hazards of the room's kind cleared so far, however they left:
## everything ever spawned minus everything still standing.
func purged_count() -> int:
	var kind := String(current_offer.get("purge_kind", ""))
	return maxi(0, main.board.spawned_count(kind) - purge_left())


func _require_left() -> int:
	var left := 0
	for r in room_require:
		left += int(r[1])
	return left


## Remaining demanded hands, for the room banner.
func require_status() -> String:
	var parts := PackedStringArray()
	for r in room_require:
		if int(r[1]) > 0:
			parts.append("%d× %s" % [int(r[1]), String(r[0]).to_upper()])
	return " · ".join(parts)


## Fraction of the demanded hands already played (banner progress bar).
func require_frac() -> float:
	if room_require_total <= 0:
		return 0.0
	return 1.0 - float(_require_left()) / float(room_require_total)


## Matched combo digits on the board's safe (0-4), for the room banner.
func safe_progress() -> int:
	for p in main.board.grid:
		if main.board.grid[p].is_safe:
			return main.board.grid[p].combo_progress
	return 0


func _announce_after_settle(text: String) -> void:
	while main.board.busy:
		await get_tree().process_frame
	main._announce(text)


## After the hand fully resolves, hazards act: fires tick and spread,
## bomb fuses drop. A detonation loses the room. In boss rooms the
## boss takes his turn FIRST — then the hazards act all the same.
func _tick_room_hazards() -> void:
	while main.board.busy:
		await get_tree().process_frame
	if not in_room:
		return
	if room_goal == "boss":
		await main.board.tick_boss()
		if not in_room:
			return
	var tick_fire := true
	if has_relic("fire_blanket"):
		# Fire burns on the 1st hand, then every Nth after it.
		_fire_ticks += 1
		tick_fire = (_fire_ticks - 1) % int(rv("fire_blanket", "every")) == 0
	await main.board.tick_hazards(tick_fire)
	if not in_room:
		return
	# The trail hurts now: flames that burn a card all the way down
	# sear the rider, and dynamite going off is worse — but neither
	# ends the table on its own anymore.
	var burns: int = main.board.last_tick_burned
	var blasts: int = main.board.last_tick_detonated
	if burns > 0 and not take_damage(burns,
			"THE FIRE BURNS DOWN TO YOU" if burns == 1
			else "%d FIRES BURN DOWN TO YOU" % burns,
			"Burned at the table."):
		return
	if blasts > 0 and not take_damage(2 * blasts, "CAUGHT IN THE BLAST",
			"Caught in the blast."):
		return
	if in_room and main.board.board_ablaze():
		# Every card burning: nothing left to save.
		_room_failed("THE WHOLE TABLE'S ABLAZE")
		return
	# Whatever the hand or the hazards carried off, the treasure
	# comes back: the gust can blow the key or chest clean off the
	# table, and the job must stay winnable.
	if in_room:
		_replace_lost_treasure()
	# A fire can burn ITSELF out on the tick — that counts too.
	if room_goal == "purge" and in_room \
			and purged_count() >= purge_quota() and purge_left() == 0:
		_room_cleared()


func _room_cleared() -> void:
	in_room = false
	_room_save = {}  # the photograph is stale the moment the table ends
	_aiming_slot = -1
	_aiming_sleeve = false
	_aiming_sleight = false
	main.board.pending_provision = ""
	pending_retry = {}
	main.stat_bump("tables_cleared")
	if current_offer.has("boss"):
		main.stat_bump("bosses_beaten")
		main.stat_bump("beat_" + String(current_offer.boss))
		run_bosses += 1
	elif room_goal == "outlaw":
		main.stat_bump("duels_won")
	if String(current_offer.get("tarot", "")) == "ROYAL HUNT":
		main.stat_bump("cleared_royal")
	elif room_goal != "" and room_goal != "boss":
		main.stat_bump("cleared_" + room_goal)
	_check_contracts(true)
	main.board.locked = true
	main.board.suppress_refill = true
	if main.board._refill_active:
		main.board._skip_refill()
	_in_chest_pick = false
	# Itemized winnings: the flash is just "TABLE CLEARED" — the full
	# breakdown waits on the pick screen, where the eye has time.
	var pot := stake + int(stake * stake_odds)
	var winnings := pot
	_win_rows = [["THE POT — %d staked at %s : 1" % [stake,
			String.num(stake_odds, 1)], pot]]
	if has_relic("tin_star"):
		# The badge pays a blind, so it keeps pace with the trail.
		var star := roundi(_blind_for(room_index) * float(rv("tin_star", "blinds")))
		winnings += star
		_win_rows.append(["TIN STAR", star])
	# Swift work pays: every spare hand (or every spare 10 seconds on
	# a clock table) converts to chips, scaled to the table's blind.
	var spare := int(room_time_left / 10.0) if room_on_clock() \
			else maxi(room_hands_left, 0)
	var bonus := spare * maxi(_blind_for(room_index) / 5, 1)
	if bonus > 0:
		_win_rows.append([("%d SECONDS TO SPARE" % int(room_time_left))
				if room_on_clock() else ("%d HANDS TO SPARE" % spare), bonus])
	winnings += bonus
	chips += winnings
	main.board._play_sound(Board.SFX_STING_BOSS if current_offer.has("boss")
			else Board.SFX_STING_WIN, 1.0, -6.0)
	main.board._play_sound(Board.SFX_COINS.pick_random(), 1.0, -6.0, 0.4)
	main._announce("TABLE CLEARED")
	main.board.confetti()
	if current_offer.has("boss") and room_index == JACK_ROOM:
		_announce_after_settle("BIG LEAGUE NOW — EVERYTHING COSTS 10× FROM HERE")
	elif current_offer.has("boss") and room_index == QUEEN_ROOM:
		_announce_after_settle("HIGH SOCIETY — PRICES JUMP ANOTHER 10×")
	if room_goal == "chest":
		# The stagecoach strongbox: a relic for the hardest job around,
		# unveiled on its own reward screen after the settle.
		var relic_id := _unowned_relic()
		if relic_id != "" and relics.size() < MAX_RELICS:
			_gain_relic(relic_id)
			_pending_relic_reward = relic_id
			_relic_ambient = false
		else:
			chips += 60
			_win_rows.append(["STRONGBOX (no relic room)", 60])
	# Ambient chests crack open with the winnings: chips join the
	# ledger, a card owes an extra pick round, a relic takes the
	# strongbox screen.
	_chest_card_rounds = 0
	for kind in _chest_rewards:
		match String(kind):
			"chips":
				var region := room_index / REGION_SIZE + 1
				var loot := 30 + 15 * region
				chips += loot
				_win_rows.append(["THE CHEST — coin inside", loot])
			"card":
				_chest_card_rounds += 1
			"relic":
				var rid := _unowned_common_relic()
				if rid != "" and _pending_relic_reward == "":
					_gain_relic(rid)
					_pending_relic_reward = rid
					_relic_ambient = true
				else:
					chips += 60
					_win_rows.append(["THE CHEST — nothing new inside", 60])
	_chest_rewards.clear()
	_after_board_settles(func() -> void:
		room_index += 1
		if room_index >= ROOMS_TOTAL:
			_trail_complete()
		else:
			_save_run()
			# Let the win sink in — confetti, chips, the cleared table —
			# before fate deals the next card.
			await get_tree().create_timer(WIN_LINGER_SECS).timeout
			if main.menu_open:
				return  # stepped out meanwhile; resume picks up from here
			if _pending_relic_reward != "":
				_show_relic_reward()
			else:
				_show_pick())


## The timed table's clock ran dry (driven by main._process).
func on_time_up() -> void:
	if not in_room or not room_on_clock():
		return
	_room_failed("TIME'S UP — THE STAGE ROLLED ON" if room_goal == "chest"
			else "TIME'S UP — THE TABLE WINS")


func _room_failed(reason := "BUSTED — CURSED CARD") -> void:
	in_room = false
	_room_save = {}
	_chest_rewards.clear()  # the chest went down with the table
	_chest_won_cards.clear()
	main.board.locked = true
	# The stake is gone and a curse joins the deck — and the room does
	# NOT clear: the same table must be beaten before the trail continues.
	deck.append({"rank": randi_range(2, 14), "suit": randi_range(0, 3), "cursed": true})
	main.board._play_sound(Board.SFX_CROWS.pick_random(), 1.0, -8.0)
	# Losing a table leaves a mark on the rider too.
	if not take_damage(2, "", "One lost table too many."):
		return
	main._announce(reason, main.RED)
	_after_board_settles(_retry_room)


## Back to the same room's table: re-bet or bust.
func _retry_room() -> void:
	if _short_stacked(_cheapest_seat(room_index)):
		return
	pending_retry = current_offer.duplicate(true)
	pending_is_retry = true
	_save_run()
	_show_bet()


func _after_board_settles(then: Callable) -> void:
	while main.board.busy:
		await get_tree().process_frame
	then.call()


## Player bailed mid-room (M to menu): the stake is already spent, so it
## counts as a fail — scar applied, and the room still awaits on resume.
## The live table as pure data: board photograph plus every room
## counter and the stake on the line. {} when it can't be taken
## (busy board, or a mid-round blackjack pacing itself).
func _capture_room_state() -> Dictionary:
	if main.board.busy:
		return {}
	var snap: Dictionary = main.board.build_state_snapshot()
	if snap.is_empty():
		return {}
	return {
		"board": snap,
		"offer": current_offer.duplicate(true),
		"stake": stake, "stake_odds": stake_odds,
		"room_score": room_score, "room_hands_left": room_hands_left,
		"run_score": main.score,
		"room_time_left": room_time_left, "room_wins": room_wins,
		"room_outlaw_hp": room_outlaw_hp, "room_outlaw_idx": room_outlaw_idx,
		"room_stones_broken": room_stones_broken,
		"room_chests_opened": room_chests_opened,
		"room_collect_done": room_collect_done,
		"room_collect_kinds": room_collect_kinds.duplicate(),
		"room_require": room_require.duplicate(true),
		"room_combo": room_combo.duplicate(),
		"sleeve_used": sleeve_used, "laser_used": laser_used,
		"sleight_uses_left": sleight_uses_left,
		"watch_uses_left": watch_uses_left,
	}


## Sits the rider back down exactly where they stood up: same board,
## same counters, same stake, no scar.
func _restore_room_state() -> void:
	var rs := _room_save
	_room_save = {}
	current_offer = rs.offer.duplicate(true)
	stake = int(rs.stake)
	stake_odds = float(rs.stake_odds)
	room_score = int(rs.room_score)
	# The photograph's score wins: a hand in flight at the save is
	# replayed from the pre-hand board, so it mustn't count twice.
	main.score = int(rs.get("run_score", main.score))
	room_target = int(current_offer.get("target", 0))
	room_goal = String(current_offer.get("goal", ""))
	if room_goal == "timed":
		room_goal = ""
	room_limit = String(current_offer.get("limit", "hands"))
	if current_offer.has("boss"):
		room_goal = "boss"
		room_limit = "hands"
	room_hands_left = int(rs.room_hands_left)
	room_time_left = float(rs.room_time_left)
	room_wins = int(rs.room_wins)
	room_wins_needed = int(current_offer.get("wins", 3))
	room_outlaw_hp = int(rs.room_outlaw_hp)
	room_outlaw_max = int(current_offer.get("outlaw_hp", 5))
	room_outlaws = current_offer.get("outlaws", [])
	room_outlaw_idx = int(rs.room_outlaw_idx)
	room_stones_broken = int(rs.room_stones_broken)
	room_stones_needed = int(current_offer.get("stones", 1))
	room_chests_needed = int(current_offer.get("chest_count", 1))
	room_chests_opened = int(rs.room_chests_opened)
	room_collect_need = int(current_offer.get("collect_need", 0))
	room_collect_done = int(rs.room_collect_done)
	room_collect_kinds = rs.room_collect_kinds.duplicate()
	room_require = rs.room_require.duplicate(true)
	room_require_total = 0
	for r in current_offer.get("require", []):
		room_require_total += int(r[1])
	room_combo = rs.room_combo.duplicate()
	sleeve_used = bool(rs.sleeve_used)
	laser_used = bool(rs.laser_used)
	sleight_uses_left = int(rs.get("sleight_uses_left",
			0 if bool(rs.get("sleight_used", false)) else 1 + sleight_level))
	watch_uses_left = int(rs.watch_uses_left)
	_outlaw_dead_pending = false
	_watch_snapshot = {}
	_aiming_slot = -1
	_aiming_sleeve = false
	_aiming_sleight = false
	_aiming_laser = false
	_swap_first = null
	in_room = true
	main.mode_kind = "trail"
	main.mode_label_text = "Trail · %s · %s" % [_table().name.capitalize(),
			character_name()]
	main.game_started = true
	main.game_over = false
	main.play_music("boss" if current_offer.has("boss") else "room")
	if current_offer.has("boss"):
		main.parallax.set_scene("storm")
	else:
		var looks := ["trail_day", "trail_dusk", "trail_night"]
		main.parallax.set_scene(looks[clampi(room_index / REGION_SIZE, 0, 2)])
	main.board.visible = true
	main.board.locked = false
	main.board.suppress_refill = false
	main.board.custom_deck = deck.duplicate(true)
	main.board.undo_enabled = character == "the_doctor"
	main.board.refill_hazard_chance = 0.0 if room_goal == "purge" \
			else clampf(REFILL_HAZARD_BASE + REFILL_HAZARD_STEP * room_index,
			0.0, REFILL_HAZARD_MAX)
	main.board.apply_state_snapshot(rs.board)
	if room_goal == "crazy8":
		main.board.eights_wild = true
		PlayingCard.eights_wild = true
		main.board.apply_theme()
	elif room_goal == "landrush":
		main.board.landrush_active = true
		main.board.queue_redraw()
	elif room_goal == "outlaw":
		main.outlaw.spec = current_outlaw_spec()
		main.outlaw.appear(room_outlaw_hp)
	main._announce("BACK AT THE TABLE — right where you left it")


## Player bailed mid-room (M to menu): the table is photographed as
## it stands — resume sits you right back down, no scar, no refund
## games. Only an unphotographable table (mid-round blackjack) falls
## back to the old outlay-back fresh sit-down.
func on_abandon_room() -> void:
	if not in_room:
		return
	_room_save = _capture_room_state()
	in_room = false
	_aiming_slot = -1
	_aiming_sleeve = false
	_aiming_sleight = false
	_aiming_laser = false
	_swap_first = null
	main.board.pending_provision = ""
	if _room_save.is_empty():
		if current_offer.has("boss"):
			chips += stake
		else:
			chips += stake + int(current_offer.get("min_bet", 0))
		stake = 0
		pending_retry = current_offer.duplicate(true)
		pending_is_retry = false
	_save_run()


func _trail_complete() -> void:
	main.stat_bump("trail_wins")
	main.stat_bump("trail_wins_tier%d" % table_tier)
	main.stat_bump("trail_wins_" + character)
	main._stats_save()
	main.board._play_sound(Board.SFX_STING_COMPLETE, 1.0, -5.0)
	main.board._play_sound(Board.SFX_COINS.pick_random(), 1.0, -6.0, 0.5)
	var payout := _cashout_value(COMPLETE_RATE_BONUS) + COMPLETE_PURSE * (table_tier + 1)
	cash += payout
	_save_meta()
	_clear_run_save()
	var body := "You rode all %d rooms and the table pays tribute.\nWinnings banked: $%d" % [ROOMS_TOTAL, payout]
	if table_tier == 2:
		body += "\n\nSomewhere past the last saloon, THE DEALER shuffles\na perfect deck and waits. (His table opens soon.)"
	_end_run("TRAIL COMPLETE", body, payout)


## The strongbox opens: the won relic on its own reward screen.
func _show_relic_reward() -> void:
	main.transition(_show_relic_reward_now)


func _show_relic_reward_now() -> void:
	_hide_all()
	main.game_started = false
	main.play_music("tarot")
	_relic_sub.text = ("The chest you cracked along the way held a charm."
			if _relic_ambient else "The stagecoach job pays in more than chips.")
	var r: Dictionary = RELICS.get(_pending_relic_reward, {})
	_relic_icon.relic_id = _pending_relic_reward
	_relic_name.text = String(r.get("name", "")).to_upper()
	_relic_desc.text = relic_desc(_pending_relic_reward)
	main.board._play_sound(Board.SFX_COINS.pick_random(), 0.9, -6.0)
	relic_layer.visible = true


# --- Flow: card pick ------------------------------------------------------

func _show_pick() -> void:
	main.transition(_show_pick_now)


func _show_pick_now() -> void:
	_hide_all()
	main.game_started = false
	main.play_music("tarot")
	if _in_chest_pick:
		_pick_title.text = "FROM THE CHEST"
		_pick_sub.text = "The chest held a card — take it, or leave it in the dust."
		for child in _win_box.get_children():
			child.queue_free()  # the ledger already had its moment
	else:
		_pick_title.text = "TABLE CLEARED"
		_pick_sub.text = "Take a card — one joins your deck, or take none."
		_render_win_ledger()
	for child in _pick_box.get_children():
		child.queue_free()
	var pick_count := 3 if _in_chest_pick \
			else (int(rv("card_sleeve", "picks")) if has_relic("card_sleeve") else 3)
	var start_x := (1920.0 - (pick_count * 220.0 - 50.0)) / 2.0
	for i in pick_count:
		var card_data := _random_card_offer(0.25 if _in_chest_pick else PICK_MOD_CHANCE)
		var holder: Button = main._button(_pick_box, "", Vector2(start_x + i * 220, 0), Vector2(170, 240))
		UiKit.style_shop_slot(holder)
		var pc := PlayingCard.new()
		pc.rank = card_data.rank
		pc.suit = card_data.suit
		pc.mod = card_data.get("mod", "")
		pc.finish = PlayingCard.finish_of(card_data)
		pc.material = Themes.current_material()
		pc.scale = Vector2(1.6, 1.6)
		pc.position = Vector2(85, 120)
		holder.add_child(pc)
		var data := card_data
		holder.pressed.connect(func() -> void:
			deck.append(data)
			main.board._play_sound(Board.SFX_FLIP, 1.1, -8.0)
			_save_run()
			_after_pick())
		# Hover: the card's full story in a tooltip beneath it.
		holder.mouse_entered.connect(func() -> void:
			_pick_tip_label.text = _deck_stat_text(data)
			_pick_tip.reset_size()
			_pick_tip.position = Vector2(
					clampf(holder.position.x + 85.0 - 195.0, 20.0, 1510.0), 620.0)
			_pick_tip.visible = true)
		holder.mouse_exited.connect(func() -> void:
			_pick_tip.visible = false)
	_pick_tip.visible = false
	pick_layer.visible = true


## After a pick (or a skip): any chest-owed card rounds run first,
## then fate deals the next tables.
func _after_pick() -> void:
	if _chest_card_rounds > 0:
		_chest_card_rounds -= 1
		_in_chest_pick = true
		main.transition(_show_pick_now)
		return
	_in_chest_pick = false
	_show_tarot()


## The winnings ledger on the pick screen: every chip the cleared
## table paid, itemized, with the new stack underneath.
func _render_win_ledger() -> void:
	for child in _win_box.get_children():
		child.queue_free()
	if _win_rows.is_empty():
		return
	var rows := _win_rows.size()
	var plate_h := 96 + rows * 34 + 58
	UiKit.plate(_win_box, Rect2(0, 0, 420, plate_h))
	var title := Label.new()
	title.text = "THE TAKE"
	title.position = Vector2(20, 14)
	title.size = Vector2(380, 30)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", main.GOLD)
	_win_box.add_child(title)
	UiKit.hrule(_win_box, Vector2(20, 52), 380)
	var total := 0
	for i in rows:
		var row: Array = _win_rows[i]
		total += int(row[1])
		var name_l := Label.new()
		name_l.text = String(row[0])
		name_l.position = Vector2(20, 66 + i * 34)
		name_l.size = Vector2(290, 30)
		name_l.add_theme_font_size_override("font_size", 17)
		name_l.add_theme_color_override("font_color", main.OFFWHITE)
		_win_box.add_child(name_l)
		var val_l := Label.new()
		val_l.text = "+%d" % int(row[1])
		val_l.position = Vector2(310, 66 + i * 34)
		val_l.size = Vector2(90, 30)
		val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_l.add_theme_font_size_override("font_size", 17)
		val_l.add_theme_color_override("font_color", main.GOLD)
		_win_box.add_child(val_l)
	UiKit.hrule(_win_box, Vector2(20, 74 + rows * 34), 380)
	var total_l := Label.new()
	total_l.text = "WON  +%d" % total
	total_l.position = Vector2(20, 86 + rows * 34)
	total_l.size = Vector2(280, 34)
	total_l.add_theme_font_size_override("font_size", 24)
	total_l.add_theme_color_override("font_color", main.GOLD)
	_win_box.add_child(total_l)
	var stack_l := Label.new()
	stack_l.text = "CHIPS NOW  %d" % chips
	stack_l.position = Vector2(20, 120 + rows * 34)
	stack_l.size = Vector2(380, 28)
	stack_l.add_theme_font_size_override("font_size", 17)
	stack_l.add_theme_color_override("font_color", main.DIM)
	_win_box.add_child(stack_l)
	# Cards the chests coughed up mid-room, shown instead of narrated.
	if not _chest_won_cards.is_empty():
		var head := Label.new()
		head.text = "THE CHESTS HELD"
		head.position = Vector2(20, plate_h + 16)
		head.size = Vector2(380, 28)
		head.add_theme_font_size_override("font_size", 20)
		head.add_theme_color_override("font_color", main.GOLD)
		_win_box.add_child(head)
		for i in mini(_chest_won_cards.size(), 4):
			var d: Dictionary = _chest_won_cards[i]
			var pc := PlayingCard.new()
			pc.rank = int(d.rank)
			pc.suit = int(d.suit)
			pc.mod = Board.migrate_mod(String(d.get("mod", "")))
			pc.finish = PlayingCard.finish_of(d)
			pc.material = Themes.current_material()
			pc.scale = Vector2(0.95, 0.95)
			pc.position = Vector2(62 + i * 100, plate_h + 116)
			_win_box.add_child(pc)


# --- Flow: shop -----------------------------------------------------------

## One shop slot: the card data plus its price tier. The tier is
## stored raw — `_price` runs at render time, so a Snake Oil bought
## mid-shop discounts the rest of the shelf immediately.
func _shop_card_offer() -> Dictionary:
	if randf() < SHOP_MOD_CHANCE:
		return {"data": {"rank": randi_range(2, 14), "suit": randi_range(0, 3),
				"cursed": false, "mod": _random_mod(),
				"finish": _roll_finish()},
				"base": SHOP_MOD_PRICE}
	if randf() < 0.5 and not deck.is_empty():
		var src: Dictionary = deck.pick_random()
		if not src.get("cursed", false):
			return {"data": {"rank": src.rank, "suit": src.suit,
					"cursed": false, "mod": ""}, "base": SHOP_DUP_PRICE}
	return {"data": {"rank": randi_range(2, 14), "suit": randi_range(0, 3),
			"cursed": false, "mod": ""}, "base": SHOP_CARD_PRICE}


## The Hermit's price for the next burn — it climbs with every use.
func _burn_price() -> int:
	return _price(SHOP_REMOVE_PRICE + SHOP_REMOVE_STEP * burns_used)


## Chips that must stay in the pocket while shopping: the cheapest
## seat at the next table. Spending below it is a guaranteed bust.
func _shop_reserve() -> int:
	if room_index + 1 >= ROOMS_TOTAL:
		return 0  # the last shop before the payout — spend it all
	return _cheapest_seat(room_index + 1)


## A refused purchase gets a LOUD reason: error sting plus the message
## in red on both shop info lines (reset on the next re-render).
func _shop_refuse(msg: String) -> void:
	main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
	_shop_info.text = msg
	_shop_info.add_theme_color_override("font_color", main.RED)
	_remove_info.text = msg
	_remove_info.add_theme_color_override("font_color", main.RED)


## Blocks any purchase that would leave the player unable to sit down
## at the next table, and says so.
func _would_bust(price: int) -> bool:
	if chips - price >= _shop_reserve():
		return false
	_shop_refuse("THAT WOULD BUST YOU — the next table's seat costs %d chips (you'd have %d left)" \
			% [_shop_reserve(), chips - price])
	return true


func _shop_chips_line() -> String:
	if _shop_reserve() <= 0:
		return "CHIPS  %d" % chips
	return "CHIPS  %d      (the next table's seat costs %d — spend the rest)" \
			% [chips, _shop_reserve()]


func _show_shop() -> void:
	var re_render := shop_layer.visible
	_hide_all()
	main.game_started = false
	if not re_render:
		main.board._play_sound(Board.SFX_SALOON_DOORS[0], 1.0, -8.0)
	main.play_music("shop")
	# The merchant and their stock are fixed per shop room: no
	# restocking by leaving/burning, no re-rolling the trader.
	if _shop_stock_room != room_index:
		# The tarot card already introduced the merchant — same trader.
		_shop_merchant = MERCHANTS[int(current_offer.get("merchant",
				_random_merchant_index()))]
		_shop_stock = []
		for i in int(_shop_merchant.cards):
			var o := _shop_card_offer()
			o["bought"] = false
			_shop_stock.append(o)
		_shop_stock_relics = []
		for id in _relic_shelf(int(_shop_merchant.relics)):
			_shop_stock_relics.append({"id": id, "bought": false})
		_shop_stock_provisions = []
		for id in _provision_shelf(int(_shop_merchant.get("provisions", 0))):
			_shop_stock_provisions.append({"id": id, "bought": false})
		_shop_burned_here = false
		_shop_stock_room = room_index
	_shop_title.text = _shop_merchant.name
	_shop_flavor.text = _shop_merchant.line
	_shop_info.text = _shop_chips_line()
	_shop_info.add_theme_color_override("font_color", main.GOLD)
	_shop_burn_btn.visible = _shop_merchant.forge
	_shop_burn_btn.text = "BURN A CARD — %d chips" % _burn_price()
	_shop_burn_btn.tooltip_text = "Destroy one card from your deck. One burn per shop."
	_shop_burn_btn.disabled = _shop_burned_here
	if _shop_burned_here:
		_shop_burn_btn.text = "THE FORGE IS COLD"
		_shop_burn_btn.tooltip_text = "One burn per shop — the next merchant's forge is hot."
	UiKit.fit_button_text(_shop_burn_btn, 20)
	_render_shop_relics()
	_render_shop_provisions()
	for child in _shop_box.get_children():
		child.queue_free()
	for i in _shop_stock.size():
		var offer: Dictionary = _shop_stock[i]
		var col := i % 5
		var row := i / 5
		var holder: Button = main._button(_shop_box, "",
				Vector2(265 + col * 220, row * 280), Vector2(170, 250))
		UiKit.style_shop_slot(holder)
		var pc := PlayingCard.new()
		pc.rank = offer.data.rank
		pc.suit = offer.data.suit
		pc.mod = offer.data.mod
		pc.finish = PlayingCard.finish_of(offer.data)
		pc.material = Themes.current_material()
		pc.scale = Vector2(1.3, 1.3)
		pc.position = Vector2(85, 95)
		holder.add_child(pc)
		var price: int = _price(int(offer.base))
		var price_tag: Label = main._label(holder, "%d chips" % price,
				Vector2(0, 212), 18, main.GOLD)
		price_tag.size = Vector2(170, 30)
		price_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if offer.bought:
			holder.disabled = true
			price_tag.text = "SOLD"
		var slot := offer
		holder.pressed.connect(func() -> void:
			if slot.bought:
				return
			var c: int = _price(int(slot.base))
			if chips < c:
				_shop_refuse("NOT ENOUGH CHIPS — that card costs %d" % c)
				return
			if _would_bust(c):
				return
			chips -= c
			slot.bought = true
			deck.append(slot.data)
			main.board._play_sound(Board.SFX_DEALS.pick_random(), 1.0, -8.0)
			_save_run()
			# Full re-render: prices, chips line and disabled states all
			# move with the purchase (a fresh Snake Oil discounts the rest).
			_show_shop())
		# Hover: the same stat breakdown the pick screen gives,
		# floated beside the shelf card.
		holder.mouse_entered.connect(func() -> void:
			_shop_tip_label.text = _deck_stat_text(slot.data)
			_shop_tip.reset_size()
			var r := holder.get_global_rect()
			var tip_size := _shop_tip.get_combined_minimum_size()
			var tx := r.end.x + 10.0
			if tx + tip_size.x > 1890.0:
				tx = r.position.x - tip_size.x - 10.0
			_shop_tip.position = Vector2(tx,
					clampf(r.position.y, 150.0, 1060.0 - tip_size.y))
			_shop_tip.visible = true)
		holder.mouse_exited.connect(func() -> void:
			_shop_tip.visible = false)
	_shop_tip.visible = false
	shop_layer.visible = true


## The merchant's relic shelf: icon, name, effect, and price per slot.
func _render_shop_relics() -> void:
	for child in _shop_relic_box.get_children():
		child.queue_free()
	if _shop_stock_relics.is_empty():
		return
	var header := Label.new()
	header.text = "RELICS"
	header.position = Vector2(0, 0)
	header.size = Vector2(400, 34)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", main.GOLD)
	_shop_relic_box.add_child(header)
	for i in _shop_stock_relics.size():
		var slot: Dictionary = _shop_stock_relics[i]
		var r: Dictionary = RELICS[slot.id]
		var cost := _price(RELIC_PRICES[r.rarity])
		var btn: Button = main._button(_shop_relic_box, "",
				Vector2(0, 44 + i * 172), Vector2(400, 158))
		UiKit.style_shop_slot(btn)
		var icon := RelicIcon.new()
		icon.relic_id = slot.id
		icon.position = Vector2(50, 79)
		btn.add_child(icon)
		var name_l := _face_label(btn, r.name, 14.0, 30.0, 20, main.GOLD)
		name_l.position.x = 96
		name_l.size.x = 292
		var desc_l := _face_label(btn, relic_desc(String(slot.id)), 46.0, 64.0, 16, main.OFFWHITE)
		desc_l.position.x = 96
		desc_l.size.x = 292
		var price_l := _face_label(btn, "%d chips" % cost, 116.0, 30.0, 18, main.GOLD)
		price_l.position.x = 96
		price_l.size.x = 292
		if slot.bought:
			btn.disabled = true
			price_l.text = "SOLD"
		elif relics.has(slot.id):
			btn.disabled = true
			price_l.text = "ALREADY CARRIED"
		var pressed_slot := slot
		btn.pressed.connect(func() -> void:
			if pressed_slot.bought:
				return
			var c := _price(RELIC_PRICES[RELICS[pressed_slot.id].rarity])
			if chips < c:
				_shop_refuse("NOT ENOUGH CHIPS — that relic costs %d" % c)
				return
			if _would_bust(c):
				return
			chips -= c
			pressed_slot.bought = true
			_gain_relic(pressed_slot.id)
			main.board._play_sound(Board.SFX_SHUFFLES.pick_random(), 1.3, -8.0)
			_save_run()
			# Full re-render: a fresh Snake Oil discounts the whole shelf.
			_show_shop())


## The merchant's provision crate: name, effect, and price per slot.
func _render_shop_provisions() -> void:
	for child in _shop_prov_box.get_children():
		child.queue_free()
	if _shop_stock_provisions.is_empty():
		return
	var header := Label.new()
	header.text = "PROVISIONS"
	header.position = Vector2(0, 0)
	header.size = Vector2(210, 30)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", main.GOLD)
	_shop_prov_box.add_child(header)
	for i in _shop_stock_provisions.size():
		var slot: Dictionary = _shop_stock_provisions[i]
		var p: Dictionary = PROVISIONS[slot.id]
		var cost := _price(int(p.price))
		var btn: Button = main._button(_shop_prov_box, "",
				Vector2(0, 40 + i * 140), Vector2(210, 126))
		UiKit.style_shop_slot(btn)
		var picon := TextureRect.new()
		picon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picon.position = Vector2(158, 36)
		picon.size = Vector2(44, 44)
		picon.texture = CardArt.provision_icon(String(slot.id))
		btn.add_child(picon)
		var name_l := _face_label(btn, p.name, 10.0, 26.0, 18, main.GOLD)
		name_l.position.x = 10
		name_l.size.x = 190
		# Keep the blurb clear of the icon in the right column; three
		# short lines fit at 12.
		var desc_l := _face_label(btn, provision_desc(String(slot.id)), 38.0, 58.0, 12, main.OFFWHITE)
		desc_l.position.x = 10
		desc_l.size.x = 142
		var price_l := _face_label(btn, "%d chips" % cost, 96.0, 24.0, 16, main.GOLD)
		price_l.position.x = 10
		price_l.size.x = 190
		if slot.bought:
			btn.disabled = true
			price_l.text = "SOLD"
		elif provisions.size() >= kit_size():
			btn.disabled = true
			price_l.text = "%d chips — KIT FULL" % cost
		var pressed_slot := slot
		btn.pressed.connect(func() -> void:
			if pressed_slot.bought:
				return
			if provisions.size() >= kit_size():
				_shop_refuse("YOUR KIT IS FULL — %d provisions is the limit" % kit_size())
				return
			var c := _price(int(PROVISIONS[pressed_slot.id].price))
			if chips < c:
				_shop_refuse("NOT ENOUGH CHIPS — that costs %d" % c)
				return
			if _would_bust(c):
				return
			chips -= c
			pressed_slot.bought = true
			gain_provision(pressed_slot.id)
			main.board._play_sound(Board.SFX_COINS.pick_random(), 1.1, -8.0)
			_save_run()
			_show_shop())


## A wrapping label built the safe way: autowrap on BEFORE the size is
## set and before it enters the tree, so the rect actually holds.
func _wrap_label(parent: Control, text: String, rect: Rect2, font_size: int,
		col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = rect.position
	l.size = rect.size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## One gold-bordered card-stat tooltip, parented to a screen layer.
## The label is its first (only) child.
func _make_stat_tip(layer: Control) -> PanelContainer:
	var tip := PanelContainer.new()
	tip.add_theme_stylebox_override("panel",
			UiKit.tooltip_box())
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.visible = false
	var lbl := Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(360, 0)
	lbl.add_theme_font_size_override("font_size", 19)
	lbl.add_theme_color_override("font_color", main.OFFWHITE)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.add_child(lbl)
	layer.add_child(tip)
	return tip


func _leave_shop() -> void:
	main.board._play_sound(Board.SFX_SALOON_DOORS[1], 1.0, -8.0)
	room_index += 1
	if room_index >= ROOMS_TOTAL:
		_trail_complete()
	else:
		_save_run()
		_show_tarot()


# --- The campfire: one comfort before the trail calls again ---------------

func _show_camp() -> void:
	_hide_all()
	_camp_mode = ""
	main.tutor_show("campfire")
	_camp_hp_label.text = "HP  %d / %d" % [hp, MAX_HP]
	_camp_rest_btn.disabled = hp >= MAX_HP
	# The chosen rider takes the log by the fire.
	_camp_scene.setup(character)
	main.board._play_sound(Board.SFX_MATCHES.pick_random(), 0.8, -10.0)
	camp_layer.visible = true


## One comfort taken — the fire dies down and the trail calls.
func _leave_camp() -> void:
	main.board._play_sound(Board.SFX_MATCHES.pick_random(), 0.6, -12.0)
	room_index += 1
	if room_index >= ROOMS_TOTAL:
		_trail_complete()
	else:
		_save_run()
		_show_tarot()


func _camp_rest() -> void:
	hp = mini(MAX_HP, hp + CAMP_REST_HP)
	main.stat_bump("campfire_rests")
	main._announce("RESTED BY THE FIRE — HP %d" % hp)
	_save_run()
	_leave_camp()


## TEND or CAST OFF both ride the deck viewer, in a campfire mode.
func _camp_open_deck(mode: String) -> void:
	camp_layer.visible = false
	_camp_mode = mode
	_deck_view_burn = false
	_remove_info.text = "Pick a plain card — the fire brands it with a random enhancement." \
			if mode == "tend" else "Pick a card to cast into the flames — gone for good."
	_remove_info.add_theme_color_override("font_color", main.OFFWHITE)
	_populate_deck_view()


func _camp_pick(idx: int) -> void:
	if idx >= deck.size():
		return
	var d: Dictionary = deck[idx]
	if _camp_mode == "tend":
		if d.get("cursed", false):
			_remove_info.text = "THE FIRE WON'T TAKE A CURSE — cast it off instead."
			_remove_info.add_theme_color_override("font_color", main.RED)
			return
		if String(d.get("mod", "")) != "" or PlayingCard.finish_of(d) != "":
			_remove_info.text = "ALREADY ENHANCED — pick an honest card."
			_remove_info.add_theme_color_override("font_color", main.RED)
			return
		var mod := _random_mod()
		d["mod"] = mod
		main.stat_bump("campfire_tends")
		main._announce("TENDED BY FIRELIGHT — %s" % mod.to_upper())
		main.board._play_sound(Board.SFX_MATCHES.pick_random(), 1.1, -6.0)
	else:
		deck.remove_at(idx)
		main.stat_bump("campfire_burns")
		main._announce("CAST INTO THE FLAMES")
		main.board._play_sound(Board.SFX_MATCHES.pick_random(), 0.9, -6.0)
	_camp_mode = ""
	remove_layer.visible = false
	_save_run()
	_leave_camp()


func _show_remove() -> void:
	shop_layer.visible = false
	_deck_view_burn = true
	_remove_info.text = "Pick a card to burn — %d chips (one per shop)" % _burn_price()
	_remove_info.add_theme_color_override("font_color", main.OFFWHITE)
	_populate_deck_view()


## Read-only deck browser, reachable from the tarot screen.
func _show_deck() -> void:
	main.transition(_show_deck_now)


func _show_deck_now() -> void:
	_hide_all()
	_deck_view_burn = false
	_remove_info.text = "Your deck — %d cards. Hover a card for its story." % deck.size()
	_populate_deck_view()


func _populate_deck_view() -> void:
	_deck_tip.visible = false
	for child in _remove_grid.get_children():
		child.queue_free()
	for i in deck.size():
		var card_data: Dictionary = deck[i]
		var holder := Button.new()
		holder.custom_minimum_size = Vector2(100, 140)
		holder.focus_mode = Control.FOCUS_NONE
		var pc := PlayingCard.new()
		pc.rank = card_data.rank
		pc.suit = card_data.suit
		pc.cursed = card_data.get("cursed", false)
		pc.mod = card_data.get("mod", "")
		pc.finish = PlayingCard.finish_of(card_data)
		pc.chip_level = int(card_data.get("chip_lv", 0))
		pc.material = Themes.current_material()
		pc.position = Vector2(50, 70)
		holder.add_child(pc)
		var idx := i
		holder.mouse_entered.connect(func() -> void:
			if idx >= deck.size():
				return
			_deck_tip_label.text = _deck_stat_text(deck[idx])
			_deck_tip.reset_size()
			# Beside the hovered card: right of it, or left near the edge.
			var r := holder.get_global_rect()
			var tip_size := _deck_tip.get_combined_minimum_size()
			var tx := r.end.x + 10.0
			if tx + tip_size.x > 1890.0:
				tx = r.position.x - tip_size.x - 10.0
			_deck_tip.position = Vector2(tx,
					clampf(r.position.y, 150.0, 1060.0 - tip_size.y))
			_deck_tip.visible = true)
		holder.mouse_exited.connect(func() -> void:
			_deck_tip.visible = false)
		holder.pressed.connect(func() -> void:
			if _camp_mode != "":
				_camp_pick(idx)
				return
			if not _deck_view_burn or _shop_burned_here:
				return
			if chips < _burn_price():
				_shop_refuse("NOT ENOUGH CHIPS — the burn costs %d" % _burn_price())
				return
			if _would_bust(_burn_price()):
				return
			chips -= _burn_price()
			burns_used += 1
			_shop_burned_here = true
			deck.remove_at(idx)
			main.board._play_sound(Board.SFX_MATCHES.pick_random(), 1.0, -6.0)
			_save_run()
			_show_shop())
		_remove_grid.add_child(holder)
	remove_layer.visible = true


## The hover panel: what this card is and what it does.
func _deck_stat_text(d: Dictionary) -> String:
	var rank := int(d.rank)
	var rank_names := {11: "JACK", 12: "QUEEN", 13: "KING", 14: "ACE"}
	var text := "%s OF %s\nPip value  %d\n\n" % [rank_names.get(rank, str(rank)),
			String(PlayingCard.SUIT_NAMES[int(d.suit)]).to_upper(), rank]
	if d.get("cursed", false):
		return text + "CURSED\nDead weight: it can't be played and it blocks chains. Burn it at a shop."
	match String(d.get("mod", "")):
		"chip":
			var lv := int(d.get("chip_lv", 0))
			text += "CHIP\nPays +%d bonus chips when played — and it SEASONS: every score grows the payout +%d for the rest of the run.%s" % [
					main.board.chip_bonus * (1 + lv), main.board.chip_bonus,
					"" if lv == 0 else "\nScored %d time%s so far." % [lv,
					"" if lv == 1 else "s"]]
		"mult":
			text += "MULT\nMultiplies the whole hand's score ×%.1f. Stacks with other mult cards." % main.board.mult_factor
		"gold":
			text += "GOLD\nPays $1 of real, bankable cash when played."
		"plus":
			text += "PLUS\nWhen cleared, the card its arrow points at gains +1 rank. The arrow turns a quarter every hand — time it. Boosting an ACE lifts it into THE JOKER — wild for good, doubling every hand he scores in."
		"minus":
			text += "MINUS\nWhen cleared, the card its arrow points at drops -1 rank — and a 2 ground lower is DESTROYED, unscored. The arrow turns a quarter every hand — time it."
		"bumper":
			text += "BUMPER\nWhen cleared, it shoves the whole line of cards beside it one step in the arrow's direction — a card pushed past the edge is gone. The arrow turns every hand."
		"wild":
			text += "WILD\nCounts as ANY rank and suit — the best possible hand wins. The rarest card on the trail."
		_:
			text += "No enhancement.\nHonest cardboard."
	var fin := PlayingCard.finish_of(d)
	if fin != "":
		text += "\n\n%s\n%s" % [PlayingCard.FINISHES[fin].name, PlayingCard.FINISHES[fin].desc]
	return text


# --- Flow: run end --------------------------------------------------------

func _end_run(title: String, body: String, payout: int, cause := "") -> void:
	_hide_all()
	run_active = false
	_room_save = {}
	main.game_started = false
	if title in ["BUSTED OUT", "BLINDED OUT"]:
		main.stat_bump("trail_busts")
	_grant_run_exp(title == "TRAIL COMPLETE")
	_check_contracts(false)  # the last page lists them
	if title != "TRAIL COMPLETE":
		main.play_music("lost")
		# A lone howl over the sad harmonica.
		main.board._play_sound(Board.SFX_LOSS_HOWLS.pick_random(), 1.0, -8.0, 0.8)
	else:
		main.play_music("menu")
	main._stats_save()
	if title == "BUSTED OUT":
		_clear_run_save()
	var best := "—" if best_hand_score <= 0 \
			else "%s  (%d)" % [best_hand_name.to_upper(), best_hand_score]
	_end_label.text = "%s\n\n%s\n\nTotal run score: %d\nBest hand: %s\nOutlaws caught: %d\nCash: $%d" \
			% [title, body, main.score, best, outlaws_caught, cash]
	if not _last_grant.is_empty():
		_end_label.text += "\n+%d EXP  ·  Level %d" % [int(_last_grant.exp_gain),
				int(_last_grant.level_after)]
		if int(_last_grant.level_after) > int(_last_grant.level_before):
			_end_label.text += "  ·  LEVEL UP! +$%d" % int(_last_grant.purse)
	# The painted last page when the art is installed; the plain
	# text page otherwise.
	var painted: bool = _gameover_scene.show_ending(_ending_data(title, payout, cause))
	_end_label.visible = not painted
	_end_leave_btn.visible = not painted
	end_layer.visible = true


## Contracts finished since the last look get their moment once: a
## notice at the table (or a line on the last page).
func _check_contracts(announce: bool) -> void:
	var fresh: Array = []
	for c in Contracts.LIST:
		var id := String(c.id)
		if progress.contracts_seen.has(id) or progress.contracts_claimed.has(id):
			continue
		if Contracts.is_complete(c, main.stats, main.stats_hands):
			progress.contracts_seen[id] = true
			fresh.append(String(c.name))
	if fresh.is_empty():
		return
	_ride_contracts.append_array(fresh)
	_save_meta()
	if not announce:
		return
	var text := "CONTRACT COMPLETE — %s" % String(fresh[0]).to_upper() if fresh.size() == 1 			else "%d CONTRACTS COMPLETE — claim them from the menu" % fresh.size()
	# After the TABLE CLEARED flash has had its moment.
	get_tree().create_timer(1.8).timeout.connect(func() -> void:
		main._announce(text, main.GOLD))


## Pays a finished contract's reward once. Returns the $ paid (0 if it
## wasn't ready to claim).
func claim_contract(id: String) -> int:
	var c := Contracts.find(id)
	if c.is_empty() or Contracts.state(c, main.stats, main.stats_hands, progress) != "ready":
		return 0
	cash += int(c.reward)
	progress.contracts_claimed[id] = true
	progress.contracts_seen[id] = true
	_save_meta()
	return int(c.reward)


## A fresh id for a ride — the guard against paying its EXP twice.
func _mint_run_uid() -> String:
	return "%d-%d" % [int(Time.get_unix_time_from_system() * 1000.0), randi()]


## Pays the ride that is ending its EXP (once — a ride whose id was
## already paid gets the same report back) along with any level purse.
func _grant_run_exp(complete: bool) -> Dictionary:
	if run_uid != "" and run_uid == progress.last_run_uid:
		return _last_grant
	var reached := ROOMS_TOTAL if complete else mini(room_index + 1, ROOMS_TOTAL)
	_last_grant = _credit_ride(main.score, reached, run_bosses, table_tier,
			complete, run_uid)
	return _last_grant


## EXP, level-ups and the level purse for one ride's numbers.
func _credit_ride(score: int, reached: int, bosses: int, tier: int,
		complete: bool, uid: String) -> Dictionary:
	var earned := Progression.run_exp(score, reached, bosses, tier, complete)
	var exp_before := progress.exp_total
	var gain := progress.add_exp(int(earned.total))
	cash += int(gain.purse)
	if uid != "":
		progress.last_run_uid = uid
	main.stat_bump("rides_ended")
	main.stat_bump("trail_score_total", maxi(score, 0))
	main.stat_max("trail_score_best", score)
	_save_meta()
	main._stats_save()
	return {"exp_gain": int(earned.total), "exp_rows": earned.rows,
			"exp_before": exp_before, "exp_after": progress.exp_total,
			"level_before": int(gain.from), "level_after": int(gain.to),
			"unlocks": gain.unlocks, "purse": int(gain.purse)}


## A saved ride that's being ridden over by a new one never reaches
## the end — credit what it earned before it's lost.
func _credit_abandoned_ride() -> void:
	var cf := ConfigFile.new()
	if cf.load(main.profile_path("trail_run.cfg")) != OK \
			or not cf.get_value("run", "active", false):
		return
	var uid := String(cf.get_value("run", "uid", ""))
	if uid != "" and uid == progress.last_run_uid:
		return
	# Only the tables actually put behind it count — re-saddling a
	# fresh ride over and over earns nothing.
	var reached := mini(int(cf.get_value("run", "room", 0)), ROOMS_TOTAL)
	if reached <= 0 and int(cf.get_value("run", "score", 0)) <= 0:
		return
	var grant := _credit_ride(int(cf.get_value("run", "score", 0)), reached,
			int(cf.get_value("run", "bosses", 0)), int(cf.get_value("run", "tier", 0)),
			false, uid if uid != "" else _mint_run_uid())
	_clear_run_save()
	var text := "LAST RIDE LEFT BEHIND  ·  +%d EXP" % int(grant.exp_gain)
	if int(grant.level_after) > int(grant.level_before):
		text += "  ·  LEVEL %d" % int(grant.level_after)
	main._announce(text)


## Everything the last page shows, gathered while the run still exists.
func _ending_data(title: String, payout: int, cause: String) -> Dictionary:
	var kind := String({"LAID LOW": "laid_low", "BUSTED OUT": "busted_out",
			"BLINDED OUT": "blinded_out"}.get(title, "trail_complete"))
	var reached := ROOMS_TOTAL if kind == "trail_complete" \
			else mini(room_index + 1, ROOMS_TOTAL)
	var rider := character_name()
	if rider.begins_with("The "):
		rider = "the " + rider.substr(4)
	var epitaph := ""
	match kind:
		"laid_low":
			epitaph = "The trail took the last of %s at Table %d." % [rider, reached]
		"busted_out":
			epitaph = "Empty pockets. Empty chair."
		"blinded_out":
			epitaph = "So close. The next seat cost more than you had."
		_:
			epitaph = "King Cobra folds. The Dealer's table is yours — for now." \
					if table_tier == 2 \
					else "King Cobra folds. The trail pays $%d in tribute." % payout
	var stops: Array = []
	for i in ROOMS_TOTAL:
		stops.append(String(trail_log[i]) if i < trail_log.size() else "")
	return {
		"kind": kind, "title": title, "epitaph": epitaph, "cause": cause,
		"rider": character, "score": main.score,
		"best_name": best_hand_name, "best_score": best_hand_score,
		"outlaws": outlaws_caught, "reached": reached, "total": ROOMS_TOTAL,
		"cash": cash, "stake": _title_case(String(TABLES[table_tier].name)),
		"relics": relics.duplicate(), "stops": stops,
		"relic_descs": _relic_descs(),
		"spent": ["second_wind"] if _second_wind_used else [],
		"contracts": _ride_contracts.duplicate(),
		"bosses": BOSS_ROOMS, "region_size": REGION_SIZE, "camp_slot": 3,
	}.merged(_last_grant)


func _relic_descs() -> Dictionary:
	var d := {}
	for id in relics:
		d[id] = relic_desc(String(id))
	return d


## "BLACK JACK MCGREW" -> "Black Jack McGrew".
static func _title_case(s: String) -> String:
	var words: Array = []
	for w in s.to_lower().split(" ", false):
		var word := String(w)
		if word.begins_with("mc") and word.length() > 2:
			word = "Mc" + word.substr(2, 1).to_upper() + word.substr(3)
		else:
			word = word.substr(0, 1).to_upper() + word.substr(1)
		words.append(word)
	return " ".join(words)


# --- UI construction ------------------------------------------------------

func build_ui() -> void:
	# CHOOSE YOUR RIDER — three finished character cards from the kit;
	# the screen only exists when the art is installed.
	select_layer = _layer()
	_screen_title(select_layer, "CHOOSE YOUR RIDER")
	var rider_ids := ["the_gambler", "the_machine", "the_doctor"]
	for i in rider_ids.size():
		var id: String = rider_ids[i]
		var art := "res://assets/art/playable/full/%s.png" % id
		if not ResourceLoader.exists(art):
			continue
		var x := 462.0 + i * 348.0
		var b: Button = main._button(select_layer, "", Vector2(x, 206),
				Vector2(300, 450))
		for state in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var tr := TextureRect.new()
		tr.texture = load(art)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.size = Vector2(300, 450)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tr)
		_select_cards[id] = tr
		var veil := ColorRect.new()
		veil.color = Color(0.04, 0.03, 0.02, 0.72)
		veil.size = Vector2(300, 450)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(veil)
		var lock_l: Label = main._label(veil, "", Vector2(0, 0), 22, main.GOLD)
		lock_l.size = Vector2(300, 450)
		lock_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		veil.visible = false
		_select_locks[id] = veil
		_select_lock_labels[id] = lock_l
		b.pressed.connect(func() -> void:
			_pick_character(id))
		var ch: Dictionary = CHARACTERS[id]
		var ab: Label = main._label(select_layer, String(ch.ability),
				Vector2(x, 668), 18, main.GOLD)
		ab.size = Vector2(300, 26)
		ab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var line := _wrap_label(select_layer, String(ch.line),
				Rect2(x - 10, 698, 320, 70), 15, main.DIM)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if id == "the_gambler":
			# The Gambler picks his trick: two toggles under his card.
			_gambler_ab_label = ab
			_gambler_line_label = line
			var keys := GAMBLER_ABILITIES.keys()
			for k in keys.size():
				var key: String = keys[k]
				var tb: Button = main._button(select_layer,
						String(GAMBLER_ABILITIES[key].short),
						Vector2(x + 4 + k * 150, 774), Vector2(142, 44))
				tb.add_theme_font_size_override("font_size", 17)
				tb.tooltip_text = String(GAMBLER_ABILITIES[key].ability)
				tb.pressed.connect(func() -> void:
					_pick_gambler_ability(key))
				_gambler_ability_btns[key] = tb
	var ride: Button = main._button(select_layer, "RIDE ON",
			Vector2(810, 860), Vector2(300, 64), true)
	ride.add_theme_font_size_override("font_size", 24)
	ride.pressed.connect(open_buyin)
	_back_button(select_layer, back_to_menu, "MENU")

	buyin_layer = _layer()
	_screen_title(buyin_layer, "THE TRAIL")
	_buyin_cash_label = _center(buyin_layer, "", 240, 30, main.GOLD)
	for i in TABLES.size():
		var b: Button = main._button(buyin_layer, _tier_label(i), Vector2(660, 330 + i * 130), Vector2(600, 100))
		b.add_theme_font_size_override("font_size", 24)
		_buyin_tier_btns.append(b)
		var tier := i
		b.pressed.connect(func() -> void:
			_start_run(tier))
	_buyin_resume_btn = main._button(buyin_layer, "RESUME YOUR RIDE", Vector2(660, 740), Vector2(600, 70), true)
	_buyin_new_label = _center(buyin_layer, "or start a new ride", 418, 20, main.DIM)
	_buyin_resume_btn.add_theme_font_size_override("font_size", 24)
	_buyin_resume_btn.pressed.connect(_resume_run)
	# With a ride saved, THE TRAIL lands here; a fresh ride can still
	# saddle someone new.
	_buyin_rider_btn = main._button(buyin_layer, "NEW RIDER", Vector2(810, 852), Vector2(300, 56))
	_buyin_rider_btn.add_theme_font_size_override("font_size", 20)
	_buyin_rider_btn.pressed.connect(open_select)
	_back_button(buyin_layer, back_to_menu)

	# THE OUTFITTER — the level, the catalog of unlocks by tab, and the
	# gear ladders. Rows are rebuilt on every refresh.
	upgrades_layer = _layer()
	_screen_title(upgrades_layer, "THE OUTFITTER")
	_up_level = _center(upgrades_layer, "", 192, 24, main.GOLD)
	var track := Panel.new()
	track.position = Vector2(660, 232)
	track.size = Vector2(600, 14)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_theme_stylebox_override("panel", UiKit.bar_box("track"))
	upgrades_layer.add_child(track)
	_up_fill = Panel.new()
	_up_fill.position = Vector2(660, 232)
	_up_fill.size = Vector2(0, 14)
	_up_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_up_fill.add_theme_stylebox_override("panel", UiKit.bar_box("gold"))
	upgrades_layer.add_child(_up_fill)
	_up_cash = main._label(upgrades_layer, "", Vector2(1500, 66), 30, main.GOLD)
	_up_cash.size = Vector2(360, 40)
	_up_cash.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for i in OUTFITTER_TABS.size():
		var key := String(OUTFITTER_TABS[i][0])
		var tb: Button = main._button(upgrades_layer, String(OUTFITTER_TABS[i][1]),
				Vector2(425 + i * 180, 278), Vector2(170, 50))
		tb.focus_mode = Control.FOCUS_NONE
		tb.pressed.connect(func() -> void:
			_set_up_tab(key))
		_up_tab_btns[key] = tb
		var pip: Label = main._label(upgrades_layer, "NEW", Vector2(425 + i * 180 + 120, 262), 14, main.GOLD)
		pip.size = Vector2(50, 18)
		pip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_up_tab_pips[key] = pip
	_up_scroll = ScrollContainer.new()
	_up_scroll.position = Vector2(430, 346)
	_up_scroll.size = Vector2(1070, 600)
	_up_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	upgrades_layer.add_child(_up_scroll)
	_up_list = VBoxContainer.new()
	_up_list.add_theme_constant_override("separation", 10)
	_up_list.custom_minimum_size = Vector2(1040, 0)
	_up_scroll.add_child(_up_list)
	_back_button(upgrades_layer, _close_upgrades, "MENU")

	# THE CAMPFIRE — one comfort per stop: rest, tend, or cast off.
	# With the design kit in: the living night camp behind baked
	# choice cards on the right (per the mock); flat plates otherwise.
	camp_layer = _layer()
	_camp_scene = CampScene.new()
	camp_layer.add_child(_camp_scene)
	_screen_title(camp_layer, "THE CAMPFIRE")
	_center(camp_layer, "The fire crackles low. One comfort before the trail calls again.", 200, 22, main.DIM)
	_camp_hp_label = _center(camp_layer, "", 246, 30, main.GOLD)
	var camp_art := ResourceLoader.exists(
			"res://assets/art/campfire/choices/full_rest_normal.png")
	if camp_art:
		var camp_ids := ["rest", "tend", "cast"]
		for i in camp_ids.size():
			var id: String = camp_ids[i]
			var tb := TextureButton.new()
			tb.texture_normal = load(
					"res://assets/art/campfire/choices/full_%s_normal.png" % id)
			tb.texture_hover = load(
					"res://assets/art/campfire/choices/full_%s_hover.png" % id)
			tb.texture_pressed = load(
					"res://assets/art/campfire/choices/full_%s_selected.png" % id)
			if id == "rest":
				tb.texture_disabled = load(
						"res://assets/art/campfire/choices/full_rest_disabled.png")
			tb.ignore_texture_size = true
			tb.stretch_mode = TextureButton.STRETCH_SCALE
			tb.position = Vector2(1012.0 + i * 300.0, 335)
			tb.size = Vector2(272, 346)
			tb.focus_mode = Control.FOCUS_NONE
			camp_layer.add_child(tb)
			match i:
				0:
					_camp_rest_btn = tb
					tb.pressed.connect(_camp_rest)
				1:
					tb.pressed.connect(func() -> void:
						_camp_open_deck("tend"))
				2:
					tb.pressed.connect(func() -> void:
						_camp_open_deck("burn"))
		var camp_leave: Button = main._button(camp_layer, "BACK ON THE TRAIL",
				Vector2(1110, 745), Vector2(590, 86))
		camp_leave.add_theme_font_size_override("font_size", 28)
		camp_leave.pressed.connect(_leave_camp)
	else:
		var camp_opts := [
			["REST", "Sleep off the road.\nRecover %d HP." % CAMP_REST_HP],
			["TEND A CARD", "Hold a plain card to the light —\nit takes a random enhancement."],
			["CAST ONE OFF", "Feed a card to the flames.\nGone from the deck for good."],
		]
		for i in camp_opts.size():
			var opt: Array = camp_opts[i]
			var cb: Button = main._button(camp_layer, "",
					Vector2(340.0 + i * 430.0, 360), Vector2(380, 240))
			var head: Label = main._label(camp_layer, String(opt[0]),
					Vector2(340.0 + i * 430.0, 392), 30, main.GOLD)
			head.size = Vector2(380, 40)
			head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			head.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var body := _wrap_label(camp_layer, String(opt[1]),
					Rect2(370.0 + i * 430.0, 452, 320, 110), 18, main.OFFWHITE)
			body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			body.mouse_filter = Control.MOUSE_FILTER_IGNORE
			match i:
				0:
					_camp_rest_btn = cb
					cb.pressed.connect(_camp_rest)
				1:
					cb.pressed.connect(func() -> void:
						_camp_open_deck("tend"))
				2:
					cb.pressed.connect(func() -> void:
						_camp_open_deck("burn"))
		var camp_leave: Button = main._button(camp_layer, "BACK ON THE TRAIL",
				Vector2(760, 740), Vector2(400, 60))
		camp_leave.add_theme_font_size_override("font_size", 20)
		camp_leave.pressed.connect(_leave_camp)

	tarot_layer = _layer()
	_screen_title(tarot_layer, "FATE DEALS")
	_tarot_info = _center(tarot_layer, "", 230, 24, main.OFFWHITE)
	_tarot_cards_box = Control.new()
	_tarot_cards_box.position = Vector2(0, 330)
	tarot_layer.add_child(_tarot_cards_box)
	_tarot_relics = _center(tarot_layer, "", 268, 16, main.GOLD)
	# Unlimited carry: the trophy line can get long, so let it wrap.
	_tarot_relics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tarot_relics.size = Vector2(1500, 76)
	_tarot_relics.position.x = 210
	_center(tarot_layer, "No cashing out mid-ride: reach the end of the trail, or play GOLD cards for $cash along the way.", 850, 18, main.DIM)
	_back_button(tarot_layer, back_to_menu, "MENU")
	var deck_btn: Button = main._button(tarot_layer, "VIEW DECK", Vector2(1660, 970), Vector2(200, 54))
	deck_btn.add_theme_font_size_override("font_size", 20)
	deck_btn.pressed.connect(_show_deck)

	bet_layer = _layer()
	_screen_title(bet_layer, "THE STAKES")
	_bet_info = _center(bet_layer, "", 240, 26, main.OFFWHITE)
	# The info block runs four lines (five on a retry) — the bet row
	# sits well below so nothing ever overlaps it.
	_bet_amount_label = _center(bet_layer, "", 468, 36, main.OFFWHITE)
	# Poker presets: MIN sits at the blind, RAISE doubles the bet each
	# press, ALL IN shoves the whole stack.
	var bet_min: Button = main._button(bet_layer, "MIN", Vector2(640, 524), Vector2(200, 60))
	bet_min.add_theme_font_size_override("font_size", 24)
	bet_min.pressed.connect(func() -> void:
		_bet_amount = int(current_offer.min_bet)
		_refresh_bet_labels())
	var bet_raise: Button = main._button(bet_layer, "RAISE ×2", Vector2(860, 524), Vector2(200, 60))
	bet_raise.add_theme_font_size_override("font_size", 24)
	bet_raise.pressed.connect(func() -> void:
		_bet_amount = mini(_bet_amount * 2, _max_bet())
		_refresh_bet_labels())
	var bet_allin: Button = main._button(bet_layer, "ALL IN", Vector2(1080, 524), Vector2(200, 60))
	bet_allin.add_theme_font_size_override("font_size", 24)
	bet_allin.pressed.connect(func() -> void:
		_bet_amount = _max_bet()
		_refresh_bet_labels())
	_bet_stake_label = _center(bet_layer, "", 622, 36, main.GOLD)
	_bet_deal_btn = main._button(bet_layer, "DEAL ME IN", Vector2(760, 720), Vector2(400, 70), true)
	_bet_deal_btn.add_theme_font_size_override("font_size", 28)
	_bet_deal_btn.pressed.connect(_confirm_bet)
	var bet_back := func() -> void:
		bet_layer.visible = false
		_show_tarot()
	_bet_back_btn = _back_button(bet_layer, bet_back, "BACK")

	pick_layer = _layer()
	_pick_title = _center(pick_layer, "TABLE CLEARED", 100, 64, main.GOLD)
	_pick_sub = _center(pick_layer, "Take a card — one joins your deck, or take none.", 240, 22, main.DIM)
	# The winnings ledger sits at the left; the card offers keep the floor.
	_win_box = Control.new()
	_win_box.position = Vector2(120, 330)
	pick_layer.add_child(_win_box)
	_pick_box = Control.new()
	_pick_box.position = Vector2(0, 360)
	pick_layer.add_child(_pick_box)
	var skip: Button = main._button(pick_layer, "SKIP", Vector2(835, 740), Vector2(250, 60))
	skip.add_theme_font_size_override("font_size", 24)
	skip.pressed.connect(func() -> void:
		_after_pick())
	# Hover tooltip for the offered cards: stats, mods, and what they do.
	_pick_tip = _make_stat_tip(pick_layer)
	_pick_tip_label = _pick_tip.get_child(0) as Label

	shop_layer = _layer()
	shop_layer.add_child(ShopBackdrop.new())
	_shop_title = _center(shop_layer, "", 100, 64, main.GOLD)
	_shop_flavor = _center(shop_layer, "", 170, 20, main.DIM)
	_shop_info = _center(shop_layer, "", 200, 26, main.GOLD)
	_shop_box = Control.new()
	_shop_box.position = Vector2(0, 240)
	shop_layer.add_child(_shop_box)
	_shop_relic_box = Control.new()
	_shop_relic_box.position = Vector2(1480, 250)
	shop_layer.add_child(_shop_relic_box)
	_shop_prov_box = Control.new()
	_shop_prov_box.position = Vector2(30, 250)
	shop_layer.add_child(_shop_prov_box)
	# Hover tooltip for the shelves, floated beside the hovered card.
	_shop_tip = _make_stat_tip(shop_layer)
	_shop_tip_label = _shop_tip.get_child(0) as Label
	_shop_burn_btn = main._button(shop_layer, "", Vector2(555, 850), Vector2(380, 56))
	_shop_burn_btn.clip_text = true
	_shop_burn_btn.add_theme_font_size_override("font_size", 20)
	_shop_burn_btn.pressed.connect(_show_remove)
	var leave: Button = main._button(shop_layer, "BACK ON THE TRAIL", Vector2(985, 850), Vector2(380, 56))
	leave.add_theme_font_size_override("font_size", 20)
	leave.pressed.connect(_leave_shop)

	relic_layer = _layer()
	_screen_title(relic_layer, "THE STRONGBOX")
	_relic_sub = _center(relic_layer, "The stagecoach job pays in more than chips.", 210, 22, main.DIM)
	# The hero strongbox — open, padlock off the hasp, glow baked in —
	# with the leather plate as the no-art fallback.
	var strongbox: Texture2D = null
	if ResourceLoader.exists("res://assets/art/r2/hero/strongbox_600x480.png"):
		strongbox = load("res://assets/art/r2/hero/strongbox_600x480.png")
	if strongbox != null:
		var sb_rect := TextureRect.new()
		sb_rect.texture = strongbox
		sb_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sb_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sb_rect.position = Vector2(660, 250)
		sb_rect.size = Vector2(600, 480)
		sb_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		relic_layer.add_child(sb_rect)
		_relic_icon = RelicIcon.new()
		# The prize floats in the glow above the open lid.
		_relic_icon.position = Vector2(960, 400)
		_relic_icon.scale = Vector2(2.6, 2.6)
		relic_layer.add_child(_relic_icon)
		_relic_name = _center(relic_layer, "", 745, 40, main.GOLD)
		_relic_desc = _center(relic_layer, "", 802, 24, main.OFFWHITE)
	else:
		UiKit.plate(relic_layer, Rect2(660, 300, 600, 480))
		_relic_icon = RelicIcon.new()
		_relic_icon.position = Vector2(960, 440)
		_relic_icon.scale = Vector2(2.6, 2.6)
		relic_layer.add_child(_relic_icon)
		_relic_name = _center(relic_layer, "", 560, 40, main.GOLD)
		_relic_desc = _center(relic_layer, "", 630, 24, main.OFFWHITE)
	var take: Button = main._button(relic_layer, "TAKE IT", Vector2(810, 850), Vector2(300, 64))
	take.add_theme_font_size_override("font_size", 26)
	take.pressed.connect(func() -> void:
		_pending_relic_reward = ""
		_show_pick())

	remove_layer = _layer()
	_screen_title(remove_layer, "THE DECK")
	_remove_info = _center(remove_layer, "", 210, 24, main.OFFWHITE)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(240, 270)
	scroll.size = Vector2(1100, 620)
	remove_layer.add_child(scroll)
	_remove_grid = GridContainer.new()
	_remove_grid.columns = 10
	scroll.add_child(_remove_grid)
	_deck_tip = _make_stat_tip(remove_layer)
	_deck_tip_label = _deck_tip.get_child(0) as Label
	var remove_back := func() -> void:
		remove_layer.visible = false
		if _camp_mode != "":
			_camp_mode = ""
			_show_camp()
		elif _deck_view_burn:
			_show_shop()
		else:
			_show_tarot()
	_back_button(remove_layer, remove_back, "BACK")

	end_layer = _layer()
	_end_label = Label.new()
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_end_label.add_theme_font_size_override("font_size", 34)
	_end_label.add_theme_color_override("font_color", main.OFFWHITE)
	_end_label.size = main.VIEW
	end_layer.add_child(_end_label)
	_end_leave_btn = main._button(end_layer, "LEAVE THE TABLE", Vector2(760, 860), Vector2(400, 64))
	_end_leave_btn.add_theme_font_size_override("font_size", 24)
	_end_leave_btn.pressed.connect(back_to_menu)
	_gameover_scene = GameOverScene.new()
	_gameover_scene.host = main
	end_layer.add_child(_gameover_scene)
	_gameover_scene.ride_again.connect(open_select)
	_gameover_scene.to_menu.connect(back_to_menu)


func _layer() -> ColorRect:
	var l := ColorRect.new()
	l.color = main.BG
	l.size = main.VIEW
	l.visible = false
	main.ui_root.add_child(l)
	return l


func _hide_all() -> void:
	for l in [select_layer, buyin_layer, upgrades_layer, tarot_layer, bet_layer,
			pick_layer, shop_layer, camp_layer, remove_layer, relic_layer,
			end_layer]:
		if l:
			l.visible = false


func _screen_title(parent: Control, text: String) -> void:
	var t := _center(parent, text, 100, 64, UiKit.BRASS_HI)
	t.add_theme_color_override("font_color", UiKit.BRASS_HI)


func _center(parent: Control, text: String, y: float, font_size: int, color: Color) -> Label:
	var l: Label = main._label(parent, text, Vector2(0, y), font_size, color)
	l.size = Vector2(main.VIEW.x, font_size * 2.2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Chunky, casino-visible slider: thick gold-rimmed track, gold fill,
## and a fat round knob (drawn to a texture in code — no assets).
func _back_button(parent: Control, action: Callable, text := "BACK") -> Button:
	var b: Button = main._button(parent, text, Vector2(60, 970), Vector2(200, 54))
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(action)
	return b
