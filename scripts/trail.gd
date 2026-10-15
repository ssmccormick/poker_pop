class_name TrailMode
extends Node

## Trail mode: a roguelike run of 21 tables. Bet bank cash at the start
## on how far you'll get, carry trail cash for the merchants, sculpt
## your deck as you go. Trail cash only comes home if you finish.
## v1 scope: risk-tiered Normal rooms + shops. Bosses, room-rule
## variety, and card modifiers beyond Cursed come later (TRAIL_MODE.md).

const ROOMS_TOTAL := 30         # stops on the trail: 21 tables, 6 shops, 3 campfires
const REGION_SIZE := 10
# Every region runs the same road: the merchants and the campfire are
# fixed stops BETWEEN the tables (never a card on the wall that skips
# one), and the region's boss waits at its end.
const STOP_LAYOUT := ["table", "table", "shop", "table", "table", "camp",
		"table", "table", "shop", "boss"]
const TABLES_PER_REGION := 7
const STOPS_LAYOUT_VERSION := 2  # run saves before 2 used 7-stop regions
# Every 7th room is a boss; the tarot deals a single court card.
const BOSS_ROOMS := {9: "jack", 19: "queen", 29: "cobra"}
const JACK_ROOM := 9
const QUEEN_ROOM := 19
const BOSSES := {
	"jack": {"tarot": "THE JACK", "name": "Jack of All Trades", "hands": 30},
	"queen": {"tarot": "THE QUEEN", "name": "Queen Bee", "hands": 14},
	"cobra": {"tarot": "THE KING", "name": "King Cobra", "hands": 14},
}

# One buy-in: the difficulty dial is ASCENSION 0-20 (scripts/ascension.gd),
# climbed per rider. Ascension 0 is the plain trail.

# Room risk tiers offered by the draw, named for what they pay — a
# safe grind, a sweetened pot, a rich table that'll bleed you.
# "hands" is the budget the table deals you — it shrinks as the
# trail deepens; the player doesn't haggle over it.
const RISKS := [
	{"tarot": "EASY MONEY", "label": "Steady", "target_scale": 0.85, "odds": 1.0, "hands": 12},
	{"tarot": "FAT POT", "label": "Risky", "target_scale": 1.15, "odds": 1.5, "hands": 10},
	{"tarot": "HIGH STAKES", "label": "Dangerous", "target_scale": 1.4, "odds": 2.0, "hands": 9},
]

# A table is free to sit and pays trail cash when you clear it, more
# at higher odds. The hand (or minute) budget is fixed by the table and
# tightens with depth.
const MAX_HANDS_BUY := 12
const WIN_LINGER_SECS := 2.5  # savour a cleared table before the pick

# Hazards are AMBIENT: any play room (bosses included) can be seeded,
# with the chance and count climbing with depth and table stakes. The
# tarot decides only the room's GOAL.
const HAZARD_KINDS := ["bomb", "fire", "wind", "stone", "water"]
const HAZARD_BASE_CHANCE := 0.10
const HAZARD_ROOM_STEP := 0.04   # + per room index — deep tables always bite
const HAZARD_COUNT_ROOMS := 5    # seed count grows every N tables
const HAZARD_COUNT_MAX := 6
# Every refill can deal danger: chance per fresh card, climbing with
# depth. Purge rooms are exempt (extra hazards would warp the goal).
const REFILL_HAZARD_BASE := 0.015
const REFILL_HAZARD_STEP := 0.004  # + per room index
const REFILL_HAZARD_MAX := 0.10
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
	"hands": REQUIRE_CHANCE, "holdem": HOLDEM_CHANCE,
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

const BASE_TARGET := 850          # table 1 target before scaling
const TARGET_STEP := 140          # + per table (21-table curve)
const SHOP_CARD_PRICE := 4       # plain card
const SHOP_DUP_PRICE := 5        # exact duplicate of a card you own
const SHOP_MOD_PRICE := 8        # chip/mult enhanced card
const SHOP_REMOVE_PRICE := 3     # first burn; climbs every use
const SHOP_REMOVE_STEP := 2      # + per burn used this run
const CHEST_MOD_CHANCE := 0.25    # chest cards: chance of an enhanced one
const SHOP_MOD_CHANCE := 0.35     # shop slots: chance of an enhanced card
const FATE_KICKER := 2            # $ for trusting The Fool (× the region scale)
const TABLE_PAY_BASE := 3.0       # what a first table pays, before odds
const TABLE_PAY_STEP := 1.0 / 3.0 # added per table of depth
const REGION_SCALE := [1.0, 1.5, 2.0]   # pay and prices climb region by region
const BET_ODDS := {"jack": 1.5, "queen": 3.0, "king": 6.0}
const BET_ROOMS := {"jack": JACK_ROOM, "queen": QUEEN_ROOM, "king": ROOMS_TOTAL - 1}
const BET_NAMES := {"jack": "the Jack", "queen": "the Queen", "king": "King Cobra"}
const BANKROLL_CASH := 5          # $ of free trail cash per Bankroll level
const COMPLETE_PURSE := 100       # cash on finishing, x Ascension.purse_mult

# Meta and run saves live under the active profile (main.profile_path).

# The Outfitter's shelves: GEAR holds the upgrade ladders, the rest list
# the catalog by kind.
const OUTFITTER_TABS := [["gear", "GEAR"], ["riders", "RIDERS"], ["relics", "RELICS"],
		["provisions", "PROVISIONS"], ["cards", "CARDS"], ["abilities", "ABILITIES"],
		["merchants", "MERCHANTS"]]
const TAB_KINDS := {"riders": ["rider", "trick"], "relics": ["relic"],
		"provisions": ["provision"], "cards": ["mod", "finish"],
		"abilities": ["ability"], "merchants": ["merchant"]}
# [ladder id, title, blurb, owner kind, owner id]
const LADDERS := [
	["sleeve", "ACE UP THE SLEEVE — THE GAMBLER",
		"Once per table, he can trade the card up his sleeve for any plain card on the felt. Each upgrade raises its starting rank, up to an Ace.",
		"rider", "the_gambler"],
	["sleight", "SLEIGHT OF HAND — THE GAMBLER",
		"His other trick lets him swap two cards that sit side by side. Each upgrade adds one more swap per table.",
		"trick", "sleight"],
	["laser", "THE LASER — THE MACHINE",
		"Once per table, the laser burns a card clean off the felt. Each upgrade adds one more card to the beam, until it hits a full cross.",
		"rider", "the_machine"],
	["watch", "THE POCKET WATCH — THE DOCTOR",
		"Undoes your last hand: the cards, the score, the hand you spent, all of it. Each upgrade gives you one more undo per table.",
		"rider", "the_doctor"],
	["bankroll", "BANKROLL",
		"Each level adds $5 to the cash you carry onto the trail, free.",
		"gear", "bankroll"],
	["provisions", "PACKED KIT",
		"Each level puts one random provision in your kit at the start of every ride.",
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
	"mod:mult": "Multiplies the hand's score by ×1.5.",
	"mod:chip": "A Cash card: pays a little trail cash when played, and more each time it scores.",
	"mod:gold": "Pays $3 in trail cash every time you play it.",
	"mod:plus": "Raises the card it points at by one rank. An Ace becomes THE JOKER, which is wild and doubles the hand.",
	"mod:minus": "Lowers the card it points at by one rank. A 2 breaks.",
	"mod:bumper": "When you clear it, it shoves the line it points at one step.",
	"mod:wild": "Any rank, any suit. The rarest card on the trail.",
	"room:plain": "Hit the target score before you run out of hands.",
	"room:clock": "High Noon: you play against a countdown clock instead of a set number of hands.",
	"room:safe": "Bank Job: play the safe's combination in order, then crack it open.",
	"room:outlaw": "Bounty: clear your bullets and dodge his. Outdraw a wanted outlaw, or his whole posse.",
	"room:hands": "Dealer's Call: play exactly the hands the table calls for.",
	"room:chest": "Stagecoach Haul: match keys to chests. The strongbox holds a relic.",
	"room:purge": "Powder Keg, Wildfire, Dust Storm and Flash Flood: clear a set number of one kind of hazard.",
	"room:mine": "Gold Mine: break the stones off the cards. Some of those cards are gold.",
	"room:collect": "The Roundup and The Census: clear the suit or rank the table calls, or one of every rank.",
	"room:crazy8": "A random rank is wild at this table.",
	"room:landrush": "Stake a claim on every plot by clearing a card from all 25 spaces.",
	"room:blackjack": "Make chains that add up to 21 and beat the dealer, round after round.",
	"room:holdem": "Five community cards everyone shares, plus two hole cards of your own.",
	"room:royal": "Make one Royal Flush before the clock runs out.",
	"room:dealer": "Past the last saloon, THE DEALER is waiting with a perfect deck.",
}

# Relics: run-wide passives, max 5, bought at shops / found in chests.
const MAX_RELICS := 999  # no satchel limit — the price is the gate
const RELIC_PRICES := [15, 30, 60, 100]  # by rarity C/R/EPIC/L — carry is unlimited, so they cost dear

# Traveling merchants: each shop stop is a different trader, rolled
# per room, with their own stock — some deal only in relics.
const MERCHANTS := [
	{"id": "peddler", "name": "THE PEDDLER'S WAGON",
		"line": "A little of everything, friend. Cards, trinkets, a hot forge, and a trick or two.",
		"cards": 5, "relics": 2, "provisions": 2, "abilities": 2, "forge": true},
	{"id": "collector", "name": "THE COLLECTOR",
		"line": "I don't deal in playing cards. Just trinkets and tricks with real power in them.",
		"cards": 0, "relics": 4, "provisions": 2, "abilities": 3, "forge": false},
	{"id": "sharp", "name": "THE CARD SHARP",
		"line": "Finest cards on the trail, and a forge to burn the ones you regret.",
		"cards": 10, "relics": 0, "provisions": 1, "abilities": 0, "forge": true},
]

# Provisions: one-shot consumables in a 3-slot kit. "target" ones are
# aimed at a card on the table; "instant" ones fire on the spot. Using
# one is a free action — the provision itself is the price.
const PROVISIONS := {
	"canteen": {"name": "Canteen", "kind": "target", "price": 5,
		"desc": "Douse one card to wash off any hazard or water"},
	"dynamite": {"name": "Dynamite Stick", "kind": "target", "price": 6,
		"desc": "Blow up any card, even a curse. On a stone, it blasts the stone off"},
	"branding_iron": {"name": "Branding Iron", "kind": "target", "price": 7,
		"desc": "Brand a plain card with a random enhancement"},
	"razor": {"name": "Barber's Razor", "kind": "target", "price": 5,
		"desc": "Give one card a new random rank and suit"},
	"gold_pan": {"name": "Gold Pan", "kind": "target", "price": 6,
		"desc": "Turn one plain card solid GOLD"},
	"shell_game": {"name": "Shell Game", "kind": "target", "price": 5,
		"desc": "Swap two cards that sit side by side: pick one, then its neighbor"},
	"fresh_deck": {"name": "Fresh Deck", "kind": "instant", "price": 5,
		"desc": "Re-deal every plain and enhanced card on the table"},
	"pocket_flask": {"name": "Pocket Flask", "kind": "instant", "price": 6,
		"desc": "+2 hands at this table, or +20 seconds on a timed one"},
	"tonic": {"name": "Rattlesnake Tonic", "kind": "instant", "price": 7,
		"desc": "Your next scored hand counts DOUBLE"},
}
const MAX_PROVISIONS := 3
const RELICS := {
	"horseshoe": {"name": "Horseshoe", "rarity": 0, "desc": "+1 hand at every table"},
	"card_sleeve": {"name": "Card Sleeve", "rarity": 0, "desc": "Ability offers give you 4 to choose from"},
	"snake_oil": {"name": "Snake Oil", "rarity": 0, "desc": "Shop prices are 25% lower"},
	"tin_star": {"name": "Tin Star", "rarity": 0, "desc": "Every table you clear pays one extra blind"},
	"rabbits_foot": {"name": "Rabbit's Foot", "rarity": 0, "desc": "Surprise safes and chests turn up twice as often on plain tables"},
	"bomb_badge": {"name": "Bomb Squad Badge", "rarity": 0, "desc": "Bombs start with 2 more turns on the fuse"},
	"chisel": {"name": "Chisel", "rarity": 0, "desc": "Stones take one fewer play to break"},
	"fire_blanket": {"name": "Fire Blanket", "rarity": 1, "desc": "Fire only ticks down every 2nd hand"},
	"swimming_goggles": {"name": "Swimming Goggles", "rarity": 1, "desc": "Water-filled cards still show their suit"},
	"gold_tooth": {"name": "Gold Tooth", "rarity": 1, "desc": "Chip cards pay double"},
	"mirror_shades": {"name": "Mirror Shades", "rarity": 1, "desc": "Mult cards multiply by 0.5 more (x1.5 becomes x2)"},
	"second_wind": {"name": "Second Wind", "rarity": 1, "desc": "One free life: when the trail would finish you off, you get back up with 5 HP. Works once"},
	"bankroll_clip": {"name": "Bankroll Clip", "rarity": 1, "desc": "Finishing the trail pays +0.25x"},
	"dowsing_rod": {"name": "Dowsing Rod", "rarity": 1, "desc": "Safe combinations only use ranks 2-6"},
	"saddlebags": {"name": "Saddlebags", "rarity": 1, "desc": "A 4th slot in your provision kit"},
	"lucky_chip": {"name": "Lucky Chip", "rarity": 3, "desc": "10% chance a hand you play doesn't use up a hand"},
	"chuck_wagon": {"name": "Chuck Wagon", "rarity": 2, "desc": "A random provision at the start of every table"},
}

var main: Node2D  # set by main.gd before build()

# Meta (persists forever) — everything the OUTFITTER sells for $cash.
var cash := 0
var sleeve_rank := 2     # ACE UP THE SLEEVE: the starting rank, up to an Ace
var meta_bankroll := 0   # +$5 of free trail cash per level on every ride (max 5)
var meta_provisions := 0 # random provisions in the kit at run start (max 2)
# Levels, unlocks, purchases and contracts (scripts/progression.gd).
var progress := Progression.new()
var _last_grant := {}    # the last ride's EXP payout, for the game-over page
var _ride_contracts: Array = []  # contract names completed this ride

# Run state
var run_active := false
var run_uid := ""        # one id per ride, so it's only ever paid EXP once
var run_bosses := 0      # boss tables beaten this ride
# Table types played this ride (ROOM_TABLE keys, "plain" included). A
# played type isn't dealt again until every type has had its turn —
# then the rotation starts over.
var tables_played: Array = []
# SEEDS: the ride's seed, and the stream every gameplay roll draws from.
# _rng is re-derived from the seed at each stop (the wall, the table, the
# shop, the pick, the rewards, the fire), so what a seed deals at a stop
# never depends on anything but the seed and the stop. rng_room is the
# table's own stream (saved with the table's photograph).
var run_seed := ""
var room_attempt := 0            # retries of this table (a fresh, seeded deal each)
var _attempt_room := -1
var next_seed := ""              # the seed the next ride starts on ("" = random)
# A SEEDED RIDE (chosen from SEEDED PLAY, or the daily) plays the
# STANDARD LOADOUT — every item on the trail at base power, no Outfitter
# gear — so everyone on a seed plays the same game. It banks no cash
# and opens no Ascension; its score goes on that seed's board.
var standard_loadout := false
var run_daily := false
var run_practice := false        # a daily ride after the day's scored one
var next_standard := false
var next_daily := false
var _seed_result := {}           # {key, pb, best, practice} for the last page
var _seed_recorded_uid := ""
var _rng := RandomNumberGenerator.new()
var rng_room := RandomNumberGenerator.new()
var _pick_round := 0
var ascension := 0       # this ride's Ascension (0-20)
# TRAIL CASH ($): what you carry and earn on the ride. Shops take it,
# tables pay it, and it only comes home if you finish the trail.
var trail_cash := 0
var cash_brought := 0           # how much of it came from the bank
# The starting BET: bank cash on how far the ride gets (the Jack, the
# Queen, or King Cobra). Paid into the bank the moment it comes in.
var bet: Dictionary = {}        # {target: "jack"/"queen"/"king", stake, odds, paid}
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
# ABILITY CARDS, won this ride: one id per copy (duplicates allowed).
# The loadout puts them on poker hands: hand name -> [indices into
# abilities]. A copy sits on one hand at most, and a hand never holds two
# of the same ability. It only changes between tables.
var abilities: Array = []
var loadout: Dictionary = {}
var pending_reward: Dictionary = {}   # an ability offer not yet settled (resumable)
var room_ability_counts: Dictionary = {}  # per-table counters (Borrowed Time; "_played", "_last_stand")
var hand_plays: Dictionary = {}           # poker hand -> times played this ride (Notches on the Gun)
var rng_ability := RandomNumberGenerator.new()  # in-table ability rolls
var _time_granted := 0.0         # seconds handed back at this table (watch rewinds it)
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
			"line": "Once per table, burn a card clean off the felt. Upgrades widen the beam into a cross."},
	"the_doctor": {"name": "The Doctor", "ability": "THE POCKET WATCH",
			"line": "Undo your last hand as if it never happened. Upgrades give you extra uses."},
}
## The Gambler picks one signature when he saddles up.
const GAMBLER_ABILITIES := {
	"sleeve": {"ability": "ACE UP THE SLEEVE", "short": "SLEEVE",
			"line": "Once per table, trade the card up his sleeve for any plain card on the felt."},
	"sleight": {"ability": "SLEIGHT OF HAND", "short": "SLEIGHT",
			"line": "Once per table, swap two cards that sit side by side. Upgrades give you more swaps."},
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
const MAX_HP := 10                # at Ascension 0; see max_hp()
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
var _buyin_saddle_btn: Button
var _asc_pick := 0               # the Ascension the dial is on
var _asc_box: Control
var _asc_prev: Button
var _asc_next: Button
var _asc_label: Label
var _asc_sub: Label
var _asc_rule: Label
var _asc_rest: Label
var _asc_reward: Label
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
var _camp_tend_mod := ""         # the brand picked at the fire, waiting for its card
var tend_layer: Control          # the fire's three brands
var _tend_box: Control
var _tend_scene: CampScene
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
var _chest_rewards: Array = []   # ambient chests opened this room: "chips" (coin)/"card"/"relic"
var _chest_won_cards: Array = [] # deck cards won from chests, shown on the victory screen
var _chest_card_rounds := 0      # extra ability offer rounds owed by chests
var _in_chest_pick := false      # the pick screen is showing a chest round
var _relic_ambient := false      # the strongbox screen shows chest loot, not the stagecoach job
var _tarot_info: Label
var _tarot_cards_box: Control
var _bet_info: Label
var _bet_stake_label: Label
var _bet_deal_btn: Button
var _deck_view_burn := true   # deck viewer doubles as the shop's burn picker
var abilities_screen: AbilitiesScreen
var _bet_twists: Label    # the table's twists, spelled out under the bet
var _bet_chips: CenterContainer   # and as chips above that
var _shop_stock_abilities: Array = []   # [{id, bought}] on the merchant's shelf
var _shop_saved := {}    # what a saved ride already bought at this stop's merchant
var _tarot_ab_btn: Button
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
var _shop_sell_box: Control      # your own kit, each provision with a SELL price
# The buy-in's wager: cash to bring along and the starting bet. They
# stay set between rides (clamped to the bank each time).
var buyin_bring := 0
var buyin_stake := 0
var buyin_target := ""           # "", "jack", "queen", "king"
var _wager_box: Control
var _bring_label: Label
var _stake_label: Label
var _bet_pays_label: Label
var _wager_note: Label
var _bet_target_btns := {}
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
	progress.stats = main.stats
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
	cf.set_value("run", "ascension", ascension)
	cf.set_value("run", "trail_cash", trail_cash)
	cf.set_value("run", "cash_brought", cash_brought)
	cf.set_value("run", "bet", bet)
	cf.set_value("run", "econ_ver", 2)
	cf.set_value("run", "room", room_index)
	cf.set_value("run", "uid", run_uid)
	cf.set_value("run", "score", main.score)
	cf.set_value("run", "bosses", run_bosses)
	cf.set_value("run", "tables_played", PackedStringArray(tables_played))
	cf.set_value("run", "layout", STOPS_LAYOUT_VERSION)
	cf.set_value("run", "seed", run_seed)
	cf.set_value("run", "standard", standard_loadout)
	cf.set_value("run", "daily", run_daily)
	cf.set_value("run", "practice", run_practice)
	cf.set_value("run", "attempt", room_attempt)
	cf.set_value("run", "attempt_room", _attempt_room)
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
	cf.set_value("run", "abilities", PackedStringArray(abilities))
	cf.set_value("run", "loadout", loadout)
	cf.set_value("run", "hand_plays", hand_plays)
	cf.set_value("run", "pending_reward", pending_reward)
	cf.set_value("run", "ability_ver", 1)
	if _shop_stock_room == room_index and shop_layer != null:
		var sold := {"room": room_index, "burned": _shop_burned_here}
		for pair in [["cards", _shop_stock], ["relics", _shop_stock_relics],
				["provisions", _shop_stock_provisions], ["abilities", _shop_stock_abilities]]:
			var idx: Array = []
			for i in (pair[1] as Array).size():
				if bool(pair[1][i].get("bought", false)):
					idx.append(i)
			sold[pair[0]] = idx
		cf.set_value("run", "shop_sold", sold)
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


## A ride saved on the old 21-stop road (7-stop regions, shops and
## campfires on the wall) is re-seated on the 30-stop road at the same
## table; the wall it was looking at is dealt fresh.
const OLD_SLOT_TO_STOP := [0, 1, 3, 4, 6, 7, 9]


static func migrate_room(old_room: int) -> int:
	var region := old_room / 7
	return region * REGION_SIZE + int(OLD_SLOT_TO_STOP[clampi(old_room % 7, 0, 6)])


func _migrate_stops() -> void:
	room_index = migrate_room(room_index)
	var moved: Array = []
	moved.resize(ROOMS_TOTAL)
	moved.fill("")
	for i in trail_log.size():
		var to := migrate_room(i)
		if to < ROOMS_TOTAL:
			moved[to] = trail_log[i]
	while not moved.is_empty() and String(moved[-1]) == "":
		moved.pop_back()
	trail_log = moved
	_offers_room = -1
	_offers = []


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
	ascension = Ascension.clamp_a(int(cf.get_value("run", "ascension", 0)))  # stake-era saves ride at 0
	if int(cf.get_value("run", "econ_ver", 1)) >= 2:
		trail_cash = int(cf.get_value("run", "trail_cash", 0))
	else:
		# A ride saved in the chip days: its stack comes along as cash.
		trail_cash = int(cf.get_value("run", "chips", 0)) / 10
	cash_brought = int(cf.get_value("run", "cash_brought", 0))
	bet = cf.get_value("run", "bet", {})
	room_index = int(cf.get_value("run", "room", 0))
	run_uid = String(cf.get_value("run", "uid", ""))
	if run_uid == "":
		run_uid = _mint_run_uid()  # a ride saved before EXP existed
	main.score = int(cf.get_value("run", "score", 0))
	run_bosses = int(cf.get_value("run", "bosses", 0))
	tables_played = Array(cf.get_value("run", "tables_played", PackedStringArray()))
	run_seed = String(cf.get_value("run", "seed", ""))
	if not SeedRng.is_valid(run_seed):
		run_seed = SeedRng.random_seed()  # a ride saved before seeds
	standard_loadout = bool(cf.get_value("run", "standard", false))
	run_daily = bool(cf.get_value("run", "daily", false))
	run_practice = bool(cf.get_value("run", "practice", false))
	room_attempt = int(cf.get_value("run", "attempt", 0))
	_attempt_room = int(cf.get_value("run", "attempt_room", -1))
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
		deck.append({"rank": 0 if curses[i] == 1 else ranks[i], "suit": 0 if curses[i] == 1 else suits[i],
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
	abilities.clear()
	var ab_map := {}   # saved index -> kept index, so retired ids drop cleanly
	var saved_ab: PackedStringArray = cf.get_value("run", "abilities", PackedStringArray())
	for i in saved_ab.size():
		if Abilities.has(String(saved_ab[i])):
			ab_map[i] = abilities.size()
			abilities.append(String(saved_ab[i]))
	loadout = {}
	var saved_lo: Dictionary = cf.get_value("run", "loadout", {})
	for hand in saved_lo:
		var kept: Array = []
		for i in saved_lo[hand]:
			if ab_map.has(int(i)):
				kept.append(int(ab_map[int(i)]))
		loadout[String(hand)] = kept
	_validate_loadout()
	hand_plays = (cf.get_value("run", "hand_plays", {}) as Dictionary).duplicate()
	pending_reward = cf.get_value("run", "pending_reward", {})
	_shop_saved = cf.get_value("run", "shop_sold", {})
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
	hp = clampi(int(cf.get_value("run", "hp", max_hp())), 1, max_hp())
	outlaws_caught = int(cf.get_value("run", "outlaws_caught", 0))
	best_hand_score = int(cf.get_value("run", "best_hand_score", 0))
	best_hand_name = String(cf.get_value("run", "best_hand_name", ""))
	trail_log = Array(cf.get_value("run", "trail_log", PackedStringArray()))
	_second_wind_used = cf.get_value("run", "second_wind_used", false)
	burns_used = int(cf.get_value("run", "burns_used", 0))
	pending_retry = _migrate_offer(cf.get_value("run", "pending", {}))
	pending_is_retry = cf.get_value("run", "pending_hard", true)
	_offers = cf.get_value("run", "offers", [])
	for i in _offers.size():
		_offers[i] = _migrate_offer(_offers[i])
	_fate_offer = _migrate_offer(cf.get_value("run", "fate", {}))
	_offers_room = int(cf.get_value("run", "offers_room", -1))
	_room_save = cf.get_value("run", "room_state", {})
	if _room_save.has("offer"):
		_room_save["offer"] = _migrate_offer(_room_save.offer)
	tables_played.erase("crazy8")
	if int(cf.get_value("run", "layout", 1)) < STOPS_LAYOUT_VERSION:
		_migrate_stops()
	_shop_stock_room = -1  # resumed runs sit at a tarot or a retry bet
	run_active = true
	return true


# --- Run math -------------------------------------------------------------

## The rider's most HP on this ride.
func max_hp() -> int:
	return Ascension.max_hp(ascension)


## The highest Ascension this rider may start at.
func ascension_open(rider := "") -> int:
	if progress.unlock_all:
		return Ascension.MAX
	return progress.asc_max(rider if rider != "" else character)


func has_relic(id: String) -> bool:
	return relics.has(id)


## Pay and prices climb gently, region by region.
func _region_scale(room: int) -> float:
	return float(REGION_SCALE[clampi(room / REGION_SIZE, 0, REGION_SCALE.size() - 1)])


## A merchant's price in $, with the region, Ascension and Snake Oil.
func _price(base: int) -> int:
	var p := float(base) * _region_scale(room_index) * Ascension.shop_mult(ascension)
	if has_relic("snake_oil"):
		p *= 1.0 - float(rv("snake_oil", "off"))
	return maxi(1, roundi(p))


## What a table pays in trail cash when you clear it: grows with depth
## and the region, multiplied by the table's odds (twists raise them).
func _table_pay(offer: Dictionary, room := -1) -> int:
	var r := room_index if room < 0 else room
	var pay := (TABLE_PAY_BASE + TABLE_PAY_STEP * table_depth(r)) * float(offer.get("odds", 1.0)) \
			* _region_scale(r) * Ascension.pay_mult(ascension)
	if has_relic("bankroll_clip"):
		pay *= 1.0 + float(rv("bankroll_clip", "pay"))
	return maxi(1, roundi(pay))


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
# --- Ability cards: the collection and the loadout ------------------------

## The ability ids on a hand, in the order they were equipped.
func equipped_on(hand: String) -> Array:
	var out: Array = []
	for i in loadout.get(hand, []):
		if int(i) >= 0 and int(i) < abilities.size():
			out.append(String(abilities[int(i)]))
	return out


## Whether any copy of this ability (at any level) is in the collection.
func owns_ability(id: String) -> bool:
	for k in abilities:
		if Abilities.base(String(k)) == Abilities.base(id):
			return true
	return false


## Another copy at the same level as `idx` ("" partner: -1). A loose one
## is preferred, so combining disturbs the loadout as little as it can.
func combine_partner(idx: int) -> int:
	if idx < 0 or idx >= abilities.size() or Abilities.combined(String(abilities[idx])) == "":
		return -1
	var best := -1
	for j in abilities.size():
		if j != idx and String(abilities[j]) == String(abilities[idx]):
			if hand_of(j) == "":
				return j
			if best < 0:
				best = j
	return best


## Two copies at the same level become one a level up: stronger, a
## rarity higher, and only one card's slots. The copy at `idx` keeps
## its hand; its partner leaves the collection. Returns the upgraded
## copy's new index (or -1 when there was nothing to combine).
func combine(idx: int) -> int:
	var j := combine_partner(idx)
	if j < 0:
		return -1
	abilities[idx] = Abilities.combined(String(abilities[idx]))
	unequip(j)
	abilities.remove_at(j)
	var fixed := {}
	for hand in loadout:
		var on: Array = []
		for i in loadout[hand]:
			on.append(int(i) - 1 if int(i) > j else int(i))
		fixed[hand] = on
	loadout = fixed
	_validate_loadout()
	_push_loadout()
	main.stat_bump("abilities_combined")
	return idx - 1 if j < idx else idx


func used_slots(hand: String) -> int:
	var n := 0
	for id in equipped_on(hand):
		n += Abilities.slots(id)
	return n


## The hand a copy is equipped to ("" when it's loose).
func hand_of(idx: int) -> String:
	for hand in loadout:
		if (loadout[hand] as Array).has(idx):
			return String(hand)
	return ""


## Why this copy can't go on this hand right now ("" when it can).
func can_equip(idx: int, hand: String) -> String:
	if idx < 0 or idx >= abilities.size():
		return "That ability isn't in your collection."
	var id := String(abilities[idx])
	var reason := Abilities.misfit_reason(id, hand)
	if reason != "":
		return reason
	if hand_of(idx) == hand:
		return ""
	if used_slots(hand) + Abilities.slots(id) > int(Abilities.HAND_SLOTS[hand]):
		return "There isn't room. Take something off the %s first." % hand
	return ""


func equip(idx: int, hand: String) -> bool:
	if can_equip(idx, hand) != "":
		return false
	unequip(idx)
	var on: Array = loadout.get(hand, [])
	on.append(idx)
	loadout[hand] = on
	_push_loadout()
	return true


func unequip(idx: int) -> void:
	for hand in loadout.keys():
		var on: Array = loadout[hand]
		on.erase(idx)
		if on.is_empty():
			loadout.erase(hand)
	_push_loadout()


## Drops anything a save or a change left impossible: bad indices,
## retired ids, over-full hands, broken restrictions. (Two copies of the
## same ability may share a hand: they stack.)
func _validate_loadout() -> void:
	var fixed := {}
	var seen := {}
	for hand in loadout:
		if not Abilities.HAND_SLOTS.has(String(hand)):
			continue
		var used := 0
		var keep: Array = []
		var ids_here: Array = []
		for i in loadout[hand]:
			var idx := int(i)
			if idx < 0 or idx >= abilities.size() or seen.has(idx):
				continue
			var id := String(abilities[idx])
			if not Abilities.fits(id, String(hand)) \
					or used + Abilities.slots(id) > int(Abilities.HAND_SLOTS[hand]):
				continue
			used += Abilities.slots(id)
			keep.append(idx)
			ids_here.append(id)
			seen[idx] = true
		if not keep.is_empty():
			fixed[String(hand)] = keep
	loadout = fixed


## The board sees the loadout as hand -> [ids] for its scoring abilities,
## and asks _ability_ctx for the ride around them on every score.
func _push_loadout() -> void:
	var out := {}
	for hand in loadout:
		out[hand] = equipped_on(String(hand))
	main.board.ability_loadout = out
	main.board.ability_ctx = _ability_ctx


## What the scoring abilities read off the ride: posse sizes, cash,
## curses, bounties brought in, how often each hand has been played,
## and whether this is the last hand at the table.
func _ability_ctx() -> Dictionary:
	var curses := 0
	for d in deck:
		if bool(d.get("cursed", false)):
			curses += 1
	var last := false
	if in_room:
		last = room_time_left <= 30.0 if room_on_clock() else room_hands_left <= 1
	return {"posse": Abilities.posse_counts(all_equipped()), "trail_cash": trail_cash,
			"curses": curses, "caught": outlaws_caught, "hand_plays": hand_plays,
			"room_played": int(room_ability_counts.get("_played", 0)),
			"last_hand": last, "bounty": room_goal == "outlaw"}


## Every ability equipped anywhere (passives act from any hand).
func all_equipped() -> Array:
	var out: Array = []
	for hand in loadout:
		out.append_array(equipped_on(String(hand)))
	return out


func _apply_relic_effects() -> void:
	var chip := float(mv("chip", "cash")) \
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
	return {"rank": ride_lv("sleeve"), "suit": _rng.randi_range(0, 3),
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
		main._announce("SLEEVE ALREADY USED — one swap per table", main.RED)
		return
	_aiming_slot = -1  # only one thing aims at a time
	_aiming_sleeve = true
	main.board.pending_provision = "sleeve"
	main._announce("PICK A CARD TO SWAP FOR THE %s — right-click to cancel"
			% sleeve_label(), main.GOLD)


## Why this card can't be traded up the sleeve — "" when it can.
func _sleeve_refusal(card: PlayingCard) -> String:
	if card.face_down:
		return "IT'S FACE DOWN — you can't trade blind"
	if card.boss != "" or card.is_safe or card.snake_tail:
		return "THAT WON'T FIT UP A SLEEVE"
	if card.cursed or card.hazard != "" or card.washed or card.water_level > 0:
		return "NO CURSED, WET OR HAZARD CARDS UP THE SLEEVE"
	if card.objective != "":
		return "PIECES OF THE JOB STAY ON THE TABLE"
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
		card.boost_dir = SeedRng.pick(_rng, Board.HAZARD_DIRS)
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
	main._announce("PICK A CARD, THEN ONE BESIDE IT — right-click to cancel", main.GOLD)


## Two picks for a side-by-side swap: returns the first card once
## `card` completes a neighboring pair, null while still choosing.
func _swap_pair_pick(card: PlayingCard, anywhere := false) -> PlayingCard:
	if _swap_first == null or not is_instance_valid(_swap_first) \
			or not main.board.grid.has(_swap_first.grid_pos) \
			or main.board.grid[_swap_first.grid_pos] != _swap_first:
		_swap_first = card
		main.board._play_sound(Board.SFX_FLIP, 1.3, -10.0)
		main.board._fx(card.position, "pop", main.GOLD)
		main._announce("NOW PICK %s — right-click to cancel"
				% ("ANY OTHER CARD" if anywhere else "A CARD BESIDE IT"), main.GOLD)
		return null
	if card == _swap_first:
		_swap_first = null
		main._announce("DESELECTED — pick your first card again", main.DIM)
		return null
	var dp: Vector2i = card.grid_pos - _swap_first.grid_pos
	if absi(dp.x) + absi(dp.y) != 1 and not anywhere:
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		main._announce("THE CARDS HAVE TO BE SIDE BY SIDE", main.RED)
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
		main._announce("LASER ALREADY FIRED — one shot per table", main.RED)
		return
	_aiming_slot = -1  # only one thing aims at a time
	_aiming_sleeve = false
	_aiming_sleight = false
	_aiming_laser = true
	main.board.pending_provision = "laser"
	main._announce("PICK A TARGET — right-click to cancel", main.GOLD)


## The beam: the target plus one more card per unlocked arm (up,
## right, down, left). Safes, bosses and coils deflect it; job
## pieces caught in the burn resurface, dynamite-style.
func _do_laser(target: PlayingCard) -> void:
	laser_used = true
	var cells: Array = [target.grid_pos]
	for i in mini(ride_lv("laser"), LASER_DIRS.size()):
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
			main._announce("THE %s TURNS UP SOMEWHERE ELSE" % String(piece).to_upper())


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
		main._announce("THE WATCH HAS RUN DOWN — no more undos at this table", main.RED)
		return
	if room_goal == "blackjack":
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		main._announce("NO UNDOING AT BLACKJACK — the dealer won't allow it", main.RED)
		return
	if _watch_snapshot.is_empty() or not main.board.has_undo():
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		main._announce("NOTHING TO UNDO — play a hand first", main.RED)
		return
	if not main.board.restore_state():
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		return
	room_score = int(_watch_snapshot.room_score)
	main.score = int(_watch_snapshot.get("run_score", main.score))
	if _watch_snapshot.has("rng_room"):
		rng_room.state = int(_watch_snapshot.rng_room)
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
	trail_cash = int(_watch_snapshot.trail_cash)
	cash = int(_watch_snapshot.cash)
	outlaws_caught = int(_watch_snapshot.get("outlaws_caught", outlaws_caught))
	best_hand_score = int(_watch_snapshot.get("best_hand_score", best_hand_score))
	best_hand_name = String(_watch_snapshot.get("best_hand_name", best_hand_name))
	if _watch_snapshot.has("rng_ability"):
		rng_ability.state = int(_watch_snapshot.rng_ability)
	room_ability_counts = (_watch_snapshot.get("ability_counts", {}) as Dictionary).duplicate()
	hand_plays = (_watch_snapshot.get("hand_plays", hand_plays) as Dictionary).duplicate()
	# Seconds that hand gave back go back too (the clock itself keeps running).
	var given: float = _time_granted - float(_watch_snapshot.get("time_granted", _time_granted))
	if given > 0.0:
		room_time_left = maxf(1.0, room_time_left - given)
	_time_granted = float(_watch_snapshot.get("time_granted", _time_granted))
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
		"rng_room": rng_room.state,
		"room_wins": room_wins, "hp": hp,
		"room_outlaw_hp": room_outlaw_hp, "room_outlaw_idx": room_outlaw_idx,
		"room_stones_broken": room_stones_broken,
		"room_chests_opened": room_chests_opened,
		"room_collect_done": room_collect_done,
		"room_collect_kinds": room_collect_kinds.duplicate(),
		"room_require": room_require.duplicate(true),
		"deck": deck.duplicate(true),
		"trail_cash": trail_cash, "cash": cash,
		"outlaws_caught": outlaws_caught,
		"best_hand_score": best_hand_score, "best_hand_name": best_hand_name,
		"rng_ability": rng_ability.state,
		"ability_counts": room_ability_counts.duplicate(),
		"hand_plays": hand_plays.duplicate(),
		"time_granted": _time_granted,
	}


## The in-room HUD's money line: trail cash, what this table pays, and
## the starting bet.
func hud_cash_line() -> String:
	var line := "CASH $%d" % trail_cash
	if in_room and not current_offer.is_empty():
		line += "   PAYS $%d" % _table_pay(current_offer)
	if not bet.is_empty():
		var who := String({"jack": "JACK", "queen": "QUEEN", "king": "KING COBRA"}.get(
				String(bet.get("target", "")), ""))
		line += "   BET WON" if bool(bet.get("paid", false)) else "   BET: %s" % who
	return line


## Second Wind still has its one free life in it.
func second_wind_ready() -> bool:
	return has_relic("second_wind") and not _second_wind_used


## The free life: back up with at least 5 HP. The relic stays in the
## satchel, spent, so no merchant sells a second one.
func _second_wind_revive() -> void:
	_second_wind_used = true
	hp = mini(max_hp(), maxi(hp, int(rv("second_wind", "hp"))))
	main.stat_bump("second_winds")
	main.board._play_sound(Board.SFX_STING_WIN, 0.9, -6.0)
	main.board._play_sound(Board.SFX_WINDS.pick_random(), 1.0, -8.0)
	_save_run()
	# Let the blow (or the lost table's verdict) land first.
	var text := "SECOND WIND — BACK ON YOUR FEET  ·  HP %d" % hp
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
			"%s\nThe trail finally got the better of you.\n%s won't finish this ride." \
			% [why if why != "" else "That last hit was too much.", character_name()], 0,
			cause if cause != "" else "That last hit was too much.")
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
	main._announce("PICK A CARD FOR THE %s — right-click to cancel"
			% String(p.name).to_upper(), main.GOLD)


func _spend_provision(slot: int) -> void:
	var id: String = provisions[slot]
	# Upgraded tools sometimes survive the job.
	if _rng.randf() < float(pv(id, "keep", 0.0)):
		main._announce("THE %s HELD UP — it's still in your kit" % String(PROVISIONS[id].name).to_upper())
	else:
		provisions.remove_at(slot)
	_aiming_slot = -1
	main.board.pending_provision = ""
	main.stat_bump("provisions_used")
	_save_run()


func _apply_instant_provision(id: String) -> void:
	match id:
		"fresh_deck":
			main._announce("FRESH DECK — NEW CARDS ON THE TABLE")
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
			main._announce("THE BEAM BOUNCES OFF — pick another card", main.RED)
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
				return "TOO BIG TO BLOW UP — pick something smaller"
		"branding_iron", "gold_pan":
			if card.boss != "" or card.is_safe or card.snake_tail \
					or card.cursed or card.hazard != "" or card.washed \
					or card.mod != "" or card.water_level > 0:
				return "THIS NEEDS A PLAIN, DRY CARD"
		"razor":
			if card.boss != "" or card.is_safe or card.snake_tail \
					or card.cursed or card.hazard == "stone":
				return "THE RAZOR CAN'T WORK ON THAT"
		"shell_game":
			if card.is_safe or card.boss != "" or card.snake_tail:
				return "TOO HEAVY TO MOVE — pick an ordinary card"
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
				main._announce("THE %s TURNS UP SOMEWHERE ELSE" % piece.to_upper())
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
	var id := progress.pick("provision", w, exclude, _rng)
	return id if id != "" else "canteen"


## `n` different provisions for a shelf (fewer if the pool runs dry).
func _provision_shelf(n: int) -> Array:
	var out: Array = []
	var w := {}
	for id in PROVISIONS:
		w[id] = 1.0
	for i in n:
		var id := progress.pick("provision", w, out, _rng)
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
	return progress.pick("relic", w, exclude, _rng)


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
	var id := progress.pick("merchant", w, [], _rng)
	for i in MERCHANTS.size():
		if String(MERCHANTS[i].id) == id:
			return i
	return 0


## A random relic id the player doesn't own yet, or "" if none left.
func _unowned_relic() -> String:
	return _relic_pick()


## What kind of stop `room` is: "table", "shop", "camp" or "boss".
static func stop_kind(room: int) -> String:
	return String(STOP_LAYOUT[posmod(room, REGION_SIZE)])


## How many tables lie before `room` on the trail (a shop or campfire
## counts as the table after it). Targets, blinds and hazards climb on
## this, so the stops in between don't make the trail harder.
static func table_depth(room: int) -> int:
	var slot := posmod(room, REGION_SIZE)
	var d := (room / REGION_SIZE) * TABLES_PER_REGION
	for i in slot:
		if String(STOP_LAYOUT[i]) in ["table", "boss"]:
			d += 1
	return d


## The first table or boss at or after `room`.
static func next_table(room: int) -> int:
	var r := room
	while r < ROOMS_TOTAL and stop_kind(r) in ["shop", "camp"]:
		r += 1
	return mini(r, ROOMS_TOTAL - 1)


func _target_for(room: int, risk: Dictionary) -> int:
	var base := BASE_TARGET + TARGET_STEP * table_depth(room)
	return int(base * risk.target_scale * Ascension.target_mult(ascension))


func _fresh_deck() -> Array:
	var d: Array = []
	for s in 4:
		for r in range(2, 15):
			d.append({"rank": r, "suit": s, "cursed": false})
	return d


## Ascension's rules for the board this table.
func _apply_ascension_to_board() -> void:
	main.board.boss_hp_mult = Ascension.boss_mult(ascension)
	main.board.jack_bar_bonus = Ascension.jack_bar_bonus(ascension)
	main.board.cobra_start_tail = Ascension.cobra_tail(ascension, Board.COBRA_START_TAIL)


## The chance a refilled card arrives hazarded at this table.
func _refill_chance() -> float:
	return clampf((REFILL_HAZARD_BASE + REFILL_HAZARD_STEP * table_depth(room_index))
			* Ascension.refill_mult(ascension), 0.0, REFILL_HAZARD_MAX * Ascension.refill_mult(ascension))


## Weighted enhancement roll over the ones on the trail (MOD_WEIGHTS).
func _random_mod() -> String:
	var id := progress.pick("mod", MOD_WEIGHTS, [], _rng)
	return id if id != "" else "chip"


## FINISHES ride along as a rare extra on any enhanced card, one of
## them (Prism or Metal) at random.
const FINISH_CHANCE := 0.2


func _roll_finish() -> String:
	if _rng.randf() >= FINISH_CHANCE:
		return ""
	var w := {}
	for id in PlayingCard.FINISHES:
		w[id] = 1.0
	return progress.pick("finish", w, [], _rng)


func _random_card_offer(mod_chance := CHEST_MOD_CHANCE) -> Dictionary:
	var mod := ""
	var finish := ""
	if _rng.randf() < mod_chance:
		mod = _random_mod()
		finish = _roll_finish()
	# Half the time, offer an exact duplicate of a card already owned
	# (the Five of a Kind / Flushed Five enabler).
	if _rng.randf() < 0.5 and not deck.is_empty():
		var src: Dictionary = SeedRng.pick(_rng, deck)
		if not src.get("cursed", false):
			return {"rank": src.rank, "suit": src.suit, "cursed": false,
					"mod": mod, "finish": finish}
	return {"rank": _rng.randi_range(2, 14), "suit": _rng.randi_range(0, 3),
			"cursed": false, "mod": mod, "finish": finish}


# --- Flow: entry ----------------------------------------------------------

## THE TRAIL's first stop: pick your rider. Falls straight through
## to the buy-in when the character art isn't installed.
## THE TRAIL from the menu: a ride in progress comes first, straight to
## the buy-in with RESUME on top; otherwise saddle a rider.
func open_trail() -> void:
	# A fresh profile is asked about the tutorial before its first ride.
	if main.tutor_needs("core"):
		main.offer_tutorial(open_trail)
		return
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
		return _unlock_rule(r)
	return "BUY AT THE OUTFITTER — $%d" % int(r.price)


## How a locked row opens: a level, or a full ride won by another rider.
func _unlock_rule(r: Dictionary) -> String:
	var after := String(r.get("after_win", ""))
	if after != "":
		return "COMPLETE THE TRAIL AS %s" % String(CHARACTERS[after].name).to_upper()
	return "UNLOCKS AT LEVEL %d" % int(r.get("gate", r.level))


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
	# A brand-new profile is asked about the tutorial first (THE TRAIL
	# asks already; this catches any other way in).
	if main.tutor_needs("core"):
		main.offer_tutorial(open_buyin)
		return
	main.tutor_show("mode_trail")
	main.menu_layer.visible = false
	main.menu_open = false
	_hide_all()
	main.tutor_show("the_bet")
	# The dial opens on the highest Ascension this rider has earned.
	_asc_pick = ascension_open()
	# A ride in progress takes top billing; a fresh saddle moves down.
	var riding := _has_saved_run() or preview_riding
	_buyin_resume_btn.visible = riding
	_buyin_rider_btn.visible = riding and not _select_cards.is_empty()
	_buyin_new_label.visible = riding
	var dy := 120.0 if riding else 0.0
	_buyin_resume_btn.position = Vector2(660, 300)
	_buyin_new_label.position.y = 388
	_asc_box.position = Vector2(0, dy)
	_buyin_saddle_btn.position = Vector2(660 if riding else 810, 860 + dy)
	_buyin_saddle_btn.size = Vector2(290 if riding else 300, 66)
	_buyin_rider_btn.position = Vector2(970, 860 + dy)
	_buyin_rider_btn.size = Vector2(290, 66)
	_render_ascension()
	_render_wager()
	buyin_layer.visible = true


## The wager rows: cash to bring, which boss to bet on, and the stake.
## Seeded rides carry neither, so everyone starts the same.
func _render_wager() -> void:
	var seeded := next_standard
	buyin_bring = clampi(buyin_bring, 0, maxi(cash, 0))
	buyin_stake = clampi(buyin_stake, 0, maxi(cash - buyin_bring, 0))
	if buyin_target == "":
		buyin_stake = 0
	for k in _wager_box.get_children():
		(k as CanvasItem).visible = not seeded
	_wager_note.visible = true
	_buyin_cash_label.text = "BANK  $%d" % (cash - buyin_bring - buyin_stake) if not seeded \
			else "BANK  $%d" % cash
	if seeded:
		_wager_note.text = "Seeded rides start the same for everyone: no bet and no cash brought."
		return
	_bring_label.text = "$%d" % buyin_bring
	_stake_label.text = "$%d" % buyin_stake
	for key in _bet_target_btns:
		var on := String(key) == buyin_target
		var tb := _bet_target_btns[key] as Button
		tb.button_pressed = on
		# The picked target stands out; the rest sit back.
		tb.modulate = Color(1.15, 1.05, 0.8) if on else Color(0.6, 0.6, 0.6)
	if buyin_target == "":
		_bet_pays_label.text = "No bet. The ride is free."
	elif buyin_stake <= 0:
		_bet_pays_label.text = "Set a stake to bet on %s." % BET_NAMES[buyin_target]
	else:
		var odds := float(BET_ODDS[buyin_target]) * Ascension.bet_mult(_asc_pick)
		_bet_pays_label.text = "Pays $%d if you beat %s." % [
				buyin_stake + roundi(buyin_stake * odds), BET_NAMES[buyin_target]]
	_wager_note.text = "Cash you bring is lost if the trail gets you. A bet pays the moment its boss falls."


## Stepper sizes: fine steps for small sums, bigger past $50.
func _wager_step(amount: int, up: bool) -> int:
	var step := 25 if (amount >= 50 if up else amount > 50) else 5
	return amount + (step if up else -step)


## The Ascension dial: the level, its newest rule, every rule below it,
## and what the climb pays.
func _render_ascension() -> void:
	var top := ascension_open()
	_asc_pick = clampi(_asc_pick, 0, top)
	_asc_prev.disabled = _asc_pick <= 0
	_asc_next.disabled = _asc_pick >= top
	_asc_label.text = "ASCENSION %d" % _asc_pick
	_asc_sub.text = "%s  ·  highest unlocked: %d" % [character_name().to_upper(), top] \
			if top < Ascension.MAX else "%s  ·  every level unlocked" % character_name().to_upper()
	if _asc_pick == 0:
		_asc_rule.text = "The trail with no extra rules. A good first ride."
		_asc_rest.text = "Beat the trail to unlock Ascension 1 for this rider."
	else:
		var row: Dictionary = Ascension.LEVELS[_asc_pick - 1]
		_asc_rule.text = "%d · %s — %s" % [_asc_pick, String(row.name).to_upper(), String(row.desc)]
		var below := PackedStringArray()
		for pair in Ascension.active(_asc_pick - 1):
			below.append(String(pair[1].name))
		_asc_rest.text = "Also in effect: " + ", ".join(below) + "." if not below.is_empty() \
				else "The first rung of the ladder."
	_asc_reward.text = "EXP ×%s   ·   bet odds ×%s   ·   finish purse $%d" % [
			String.num(Ascension.exp_mult(_asc_pick), 2),
			String.num(Ascension.bet_mult(_asc_pick), 2),
			roundi(COMPLETE_PURSE * Ascension.purse_mult(_asc_pick))]


func _step_ascension(d: int) -> void:
	var was := _asc_pick
	_asc_pick = clampi(_asc_pick + d, 0, ascension_open())
	if _asc_pick != was:
		main.board._play_sound(Board.SFX_FLIP, 1.1 + 0.02 * _asc_pick, -10.0)
	_render_ascension()
	_render_wager()


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
			st = "Starts every ride as a %s in a random suit" \
					% String(RANK_CHARS.get(sleeve_rank, str(sleeve_rank)))
			bt = "FULLY UPGRADED — AN ACE" if cost <= 0 \
					else "RAISE TO %s — $%d" % [String(RANK_CHARS.get(
							sleeve_rank + 1, str(sleeve_rank + 1))), cost]
		"laser":
			st = "Beam burns %d card%s%s" % [1 + laser_level,
					"" if laser_level == 0 else "s",
					"" if laser_level == 0 else " in a cross"]
			bt = "EXTEND THE BEAM — $%d" % cost if cost > 0 \
					else "A FULL CROSS"
		"watch":
			st = "Level %d / 2  ·  %d undo%s per table" \
					% [watch_level, 1 + watch_level,
					"" if watch_level == 0 else "s"]
			bt = "ONE MORE UNDO — $%d" % cost if cost > 0 \
					else "FULLY UPGRADED"
		"sleight":
			st = "Level %d / 2  ·  %d swap%s per table" \
					% [sleight_level, 1 + sleight_level,
					"" if sleight_level == 0 else "s"]
			bt = "ONE MORE SWAP — $%d" % cost if cost > 0 \
					else "QUICKEST HANDS ON THE TRAIL"
		"bankroll":
			st = "Level %d / 5  ·  +$%d of trail cash on every ride" \
					% [meta_bankroll, BANKROLL_CASH * meta_bankroll]
			bt = "MORE TRAIL CASH — $%d" % cost if cost > 0 \
					else "FULLY UPGRADED"
		"provisions":
			st = "Level %d / 2  ·  %d provision%s at the start" \
					% [meta_provisions, meta_provisions,
					"" if meta_provisions == 1 else "s"]
			bt = "PACK ANOTHER — $%d" % cost if cost > 0 \
					else "FULLY UPGRADED"
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
		if String(r.get("after_win", "")) != "":
			return "WIN A RIDE AS %s" % String(CHARACTERS[String(r.after_win)].name).to_upper()
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
		_row_status(row, _unlock_rule(r))
		return row
	if int(r.get("gate", r.level)) > progress.seen_level and r.get("after_win", "") == "":
		var pip: Label = main._label(row, "NEW", Vector2(966, 8), 15, main.GOLD)
		pip.size = Vector2(60, 20)
		pip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if not progress.is_available(kind, id):
		var cost := progress.buy_cost(kind, id)
		_row_status(row, "UNLOCKED")
		var b := _row_button(row, "BUY — $%d" % cost, Vector2(700, 46), Vector2(324, 40), true)
		b.disabled = cash < cost
		b.pressed.connect(func() -> void:
			_buy_catalog(kind, id))
		return row
	var fl := progress.find_level(kind, id)
	var note := "ON THE TRAIL"
	if kind in ["rider", "trick"]:
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
		"ability":
			var face := AbilityCard.new()
			face.ability_id = id
			face.position = Vector2(56, 48)
			face.scale = Vector2(0.42, 0.42)
			row.add_child(face)
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
		"ability":
			var limit := Abilities.restriction_line(id)
			return "%s (%d slot%s%s)" % [Abilities.describe(id), Abilities.slots(id),
					"" if Abilities.slots(id) == 1 else "s",
					(", " + limit.to_lower()) if limit != "" else ""]
		"rider":
			return "%s — %s" % [String(CHARACTERS[id].ability), String(CHARACTERS[id].line)]
		"trick":
			return String(GAMBLER_ABILITIES[id].line)
		"merchant":
			for m in MERCHANTS:
				if String(m.id) == id:
					return String(m.line)
	return String(CATALOG_DESCS.get("%s:%s" % [kind, id], ""))


func _has_saved_run() -> bool:
	var cf := ConfigFile.new()
	return cf.load(main.profile_path("trail_run.cfg")) == OK and cf.get_value("run", "active", false)


func _start_run(asc: int) -> void:
	# The seeded-ride flags land first: the standard loadout opens every
	# rider for the checks just below.
	standard_loadout = next_standard
	run_daily = next_daily and standard_loadout
	next_standard = false
	next_daily = false
	run_active = true
	_apply_loadout()
	run_active = false
	if run_daily:
		asc = 0  # everyone rides the daily at Ascension 0
	if not _avail("rider", character):
		character = "the_gambler"
	if not _avail("trick", gambler_ability):
		gambler_ability = "sleeve"
	if asc < 0 or asc > ascension_open():
		main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
		return
	# A ride left saddled up is paid its EXP before the new one starts.
	_credit_abandoned_ride()
	main.stat_bump("trail_runs")
	_save_meta()
	main.menu_open = false
	run_uid = _mint_run_uid()
	run_bosses = 0
	tables_played = []
	run_seed = next_seed if SeedRng.is_valid(next_seed) else SeedRng.random_seed()
	next_seed = ""
	if run_daily:
		run_seed = SeedRng.daily_seed()
		# The day's first daily ride is the scored one; later ones practice.
		run_practice = main.seed_book.daily_used(run_seed)
		if not run_practice:
			main.seed_book.mark_daily(run_seed)
	else:
		run_practice = false
	_seed_result = {}
	room_attempt = 0
	_attempt_room = -1
	_stream("run", 0)
	_ride_contracts = []
	ascension = asc
	trail_cash = 0
	hand_plays = {}
	deck = _fresh_deck()
	for i in Ascension.cursed_start(asc):
		deck.append(cursed_card())
	room_index = 0
	# The Outfitter's gear rides along: free trail cash, and
	# provisions already in the kit.
	trail_cash += BANKROLL_CASH * ride_lv("bankroll")
	# The wager leaves the bank now: brought cash rides at risk, and the
	# bet waits on its boss. Seeded rides carry neither.
	cash_brought = 0
	bet = {}
	if not standard_loadout:
		var bring := clampi(buyin_bring, 0, maxi(cash, 0))
		var stake := clampi(buyin_stake, 0, maxi(cash - bring, 0)) \
				if BET_ODDS.has(buyin_target) else 0
		cash -= bring + stake
		trail_cash += bring
		cash_brought = bring
		if stake > 0:
			bet = {"target": buyin_target, "stake": stake, "paid": false,
					"odds": float(BET_ODDS[buyin_target]) * Ascension.bet_mult(asc)}
			main.stat_bump("bets_placed")
		_save_meta()
	relics.clear()
	provisions.clear()
	abilities.clear()
	loadout = {}
	pending_reward = {}
	for i in (ride_lv("provisions") if _avail("gear", "provisions") else 0):
		provisions.append(_random_provision())
	_aiming_slot = -1
	sleeve_card = _fresh_sleeve()
	sleeve_used = false
	_aiming_sleeve = false
	_aiming_sleight = false
	hp = max_hp()
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
	_apply_loadout()
	main.score = 0
	_apply_relic_effects()
	_save_run()
	_show_tarot()


func _resume_run() -> void:
	if _load_run():
		_apply_loadout()
		_apply_relic_effects()
		if not _room_save.is_empty():
			# The photographed table: back to the exact stage you
			# stood up from.
			main.menu_open = false
			main.menu_layer.visible = false
			_hide_all()
			_restore_room_state()
			return
		if not pending_reward.is_empty():
			# Stood up on the reward screen: the same offer is waiting.
			main.menu_open = false
			main.menu_layer.visible = false
			_hide_all()
			_win_rows = (pending_reward.get("ledger", []) as Array).duplicate(true)
			_pending_relic_reward = String(pending_reward.get("relic", ""))
			_relic_ambient = bool(pending_reward.get("relic_ambient", false))
			if _pending_relic_reward != "":
				_show_relic_reward()
			else:
				_show_pick()
			return
		if not pending_retry.is_empty():
			# A failed room still bars the way — back to its table.
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
	if _tarot_ab_btn != null:
		_tarot_ab_btn.disabled = abilities.is_empty()
		_tarot_ab_btn.tooltip_text = "You'll earn ability cards by clearing tables." \
				if abilities.is_empty() else "Put your ability cards on your poker hands."
	# Merchants and campfires are stops on the road, not cards to pick.
	var fixed := stop_kind(room_index)
	if fixed in ["shop", "camp"]:
		if _offers_room != room_index or _offers.is_empty():
			_stream("wall")
			_offers = [_make_shop_offer() if fixed == "shop"
					else {"kind": "camp", "tarot": "THE CAMPFIRE"}]
			_fate_offer = {}
			_offers_room = room_index
			_save_run()
		_choose_offer_now(_offers[0], false)
		return
	# Fate deals each room's offers ONCE: peeking at the deck, the
	# menu, or a saved game never reshuffles the wall.
	if _offers_room != room_index or _offers.is_empty():
		_stream("wall")
		_offers = _make_offers()
		_fate_offer = _make_one_offer(true, {}, _wall_types(_offers))
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
			"boss": kind,
		}]
	var offers: Array = []
	var risk_pool := RISKS.duplicate()
	SeedRng.shuffle(_rng, risk_pool)
	for i in 3:
		if room_index == 0:
			# The first table: three plain seats, one per risk.
			offers.append(_make_one_offer(false, risk_pool[i % risk_pool.size()]))
		else:
			# Only types not yet played this ride — if fewer are left
			# than seats, the wall deals fewer cards.
			var goal := _roll_room_goal(_wall_types(offers), true)
			if goal == "":
				continue
			offers.append(_make_one_offer(false, risk_pool[i % risk_pool.size()],
					[], goal))
	return offers


## The table types already dealt onto this wall.
func _wall_types(offers: Array) -> Array:
	var out: Array = []
	for o in offers:
		if o.get("kind", "") == "play":
			out.append(table_type(o))
	return out


## A shop offer names its merchant up front, so the tarot card shows
## WHO is waiting before you commit to the stop.
func _make_shop_offer() -> Dictionary:
	return {"kind": "shop", "tarot": "TRAVELING MERCHANT",
			"merchant": _random_merchant_index()}


## Which kind of table the draw deals (ROOM_TABLE over the goals on
## the trail); "plain" is the ordinary score table. Types played this
## ride and types already on this wall are skipped. `strict` returns ""
## when none are left (the wall deals fewer cards); otherwise a played
## type comes back as a last resort (the face-down Fool).
func _roll_room_goal(on_wall: Array = [], strict := false) -> String:
	var goal := progress.pick("room", ROOM_TABLE, tables_played + on_wall, _rng)
	if goal == "" and not strict:
		goal = progress.pick("room", ROOM_TABLE, tables_played, _rng)
		if goal == "":
			goal = progress.pick("room", ROOM_TABLE, [], _rng)
	if goal == "" and strict:
		return ""
	return goal if goal != "" else "plain"


## The rotation type of a play offer: its goal, or "plain".
static func table_type(offer: Dictionary) -> String:
	var goal := String(offer.get("goal", ""))
	return "plain" if goal in ["", "timed", "crazy8"] else goal


## A table was sat down at: its type leaves the rotation until every
## type has been played, then the rotation resets.
func _mark_table_played(offer: Dictionary) -> void:
	if offer.get("kind", "") != "play" or offer.has("boss"):
		return
	var t := table_type(offer)
	if not tables_played.has(t):
		tables_played.append(t)
	for k in ROOM_TABLE:
		if not tables_played.has(k):
			return
	tables_played = []  # every type has had its turn


func _make_one_offer(random_risk: bool, risk: Dictionary = {}, on_wall: Array = [],
		forced_goal := "") -> Dictionary:
	if random_risk:
		risk = SeedRng.pick(_rng, RISKS)
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
	}
	var goal := forced_goal if forced_goal != "" 			else (_roll_room_goal(on_wall) if room_index >= 1 else "plain")
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
					else String(SeedRng.pick(_rng, ["bomb", "fire", "wind", "water"]))
			if kind == "stone":
				# GOLD MINE: a board of stones. Break them off, and some of
				# the cards underneath are gold.
				offer.tarot = "GOLD MINE"
				offer.label = "Gold Mine"
				offer.odds = 2.0
				offer["goal"] = "mine"
				offer["stones"] = GOLD_MINE_QUOTA
				offer.hands = MAX_HANDS_BUY
				# The seam always runs on the clock (set below), and the
				# full seam earns a longer clock than the formula.
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
			if region >= 1 and _rng.randf() < ROYAL_CHANCE and _avail("room", "royal"):
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
				offer["require"] = (SeedRng.pick(_rng, pool) as Array).duplicate(true)
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
			var posse := 1 + _rng.randi() % mini(region + 1, 3)
			offer.tarot = "BOUNTY"
			offer.label = "Bounty"
			offer.odds = 2.0 + 0.5 * posse
			offer["goal"] = "outlaw"
			offer["outlaw_hp"] = 5 + region + Ascension.outlaw_hp_plus(ascension)
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
			match _rng.randi() % 3:
				0:
					# A real drive: most hands must be built around the
					# called suit to land the count in time.
					offer.tarot = "THE ROUNDUP"
					offer.label = "Roundup"
					offer["collect_suit"] = _rng.randi_range(0, 3)
					offer["collect_need"] = 12 + 3 * region
				1:
					# The rank drive is a ROUNDUP too — WANTED belongs
					# to the bounty posters now.
					offer.tarot = "THE ROUNDUP"
					offer.label = "Roundup"
					offer.odds = 2.0
					offer["collect_rank"] = _rng.randi_range(2, 14)
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
			or (_rng.randf() < 0.5 and _avail("room", "clock")):
		offer["limit"] = "time"
		if not offer.has("minutes"):
			offer["minutes"] = clampi(roundi(int(offer.hands) * 0.35), 2,
					TIMED_MAX_MINUTES)
		if offer.get("goal", "") == "":
			offer.tarot = "HIGH NOON"
	else:
		offer["limit"] = "hands"
	# The objective is set; now the TWISTS. The clock and the blackjack
	# storm come with their tables (a chosen clock pays a little extra);
	# the rest roll by risk and region, last of all, so the objective a
	# seed deals never depends on them.
	var forced_clock := String(offer.get("goal", "")) in ["safe", "chest", "mine"] \
			or String(offer.get("tarot", "")) == "ROYAL HUNT"
	var twists: Array = []
	if offer.limit == "time":
		twists.append({"id": "clock", "forced": forced_clock})
		if not forced_clock:
			offer.odds = float(offer.odds) + float(TableMods.TWISTS.clock.odds)
	if offer.get("goal", "") == "blackjack":
		twists.append({"id": "storm", "forced": true})
	offer["objective"] = table_type(offer)
	offer["twists"] = twists
	_roll_twists(offer, TableMods.twist_count(room_index, maxi(RISKS.find(risk), 0),
			region, _rng))
	offer.odds = snappedf(float(offer.odds), 0.05)
	return offer


## Adds `n` twists that fit the table, each with its own detail, and
## raises the odds for each.
func _roll_twists(offer: Dictionary, n: int) -> void:
	for i in n:
		var pool: Array = []
		for id in TableMods.ROLLABLE:
			if TableMods.fits(id, offer):
				pool.append(id)
		if pool.is_empty():
			return
		var id := String(SeedRng.pick(_rng, pool))
		var tw := {"id": id}
		match id:
			"wild":
				tw["rank"] = _rng.randi_range(2, 14)
				if int(offer.target) > 0:
					offer.target = int(int(offer.target) * 1.25)
			"short":
				if offer.limit == "time":
					offer["minutes"] = maxi(2, int(offer.get("minutes", 3)) - 1)
				else:
					offer.hands = maxi(4, int(offer.hands) - 2)
			"tough":
				offer.target = int(int(offer.target) * 1.2)
			"play_only":
				var extra: Array = TableMods.PLAY_ONLY_EXTRA.duplicate()
				SeedRng.shuffle(_rng, extra)
				var hands: Array = ["Pair"] + extra.slice(0, _rng.randi_range(1, 2))
				tw["hands"] = _hand_order(hands)
			"score_only":
				var low: Array = TableMods.SCORE_ONLY_LOW.duplicate()
				var high: Array = TableMods.SCORE_ONLY_HIGH.duplicate()
				SeedRng.shuffle(_rng, low)
				SeedRng.shuffle(_rng, high)
				tw["hands"] = _hand_order(low.slice(0, 1) + high.slice(0, _rng.randi_range(1, 2)))
		(offer.twists as Array).append(tw)
		offer.odds = float(offer.odds) + float(TableMods.TWISTS[id].odds)


func _hand_order(hands: Array) -> Array:
	var out: Array = []
	for h in Abilities.HAND_ORDER:
		if hands.has(h):
			out.append(h)
	return out


## The twists in words, one sentence each (for the bet screen and tips).
func twist_sentences(o: Dictionary) -> String:
	var out: Array = []
	for tw in o.get("twists", []):
		var d := TableMods.twist_desc(tw)
		if d != "":
			out.append(d)
	return " ".join(PackedStringArray(out))


## The twists as short badges ("WILD 5s  +  BRUSHFIRE").
func twist_badges(o: Dictionary) -> String:
	var out: Array = []
	for tw in o.get("twists", []):
		var badge := TableMods.twist_name(tw).to_upper()
		if String(tw.get("id", "")) == "wild" and int(tw.get("rank", 0)) <= 10:
			badge = "WILD %ds" % int(tw.rank)  # "WILD 5s", not "WILD 5S"
		out.append(badge)
	return "  +  ".join(PackedStringArray(out))


## Older rides saved before twists: Crazy 8s becomes a plain table with
## wild 8s, and a timed or blackjack table gets its clock or storm.
func _migrate_offer(o: Dictionary) -> Dictionary:
	if o.is_empty() or o.get("kind", "") != "play" or o.has("twists") or o.has("boss"):
		return o
	var twists: Array = []
	if String(o.get("goal", "")) == "crazy8":
		o["goal"] = ""
		twists.append({"id": "wild", "rank": 8})
	if String(o.get("goal", "")) == "timed":
		o["goal"] = ""
		o["limit"] = "time"
	if String(o.get("limit", "hands")) == "time":
		twists.append({"id": "clock", "forced": true})
	if String(o.get("goal", "")) == "blackjack":
		twists.append({"id": "storm", "forced": true})
	o["twists"] = twists
	o["objective"] = table_type(o)
	o["legacy_ambient"] = true  # keeps the old hidden hazard roll
	return o


func _render_tarot() -> void:
	for child in _tarot_cards_box.get_children():
		child.queue_free()
	var is_boss := BOSS_ROOMS.has(room_index)
	var region := room_index / REGION_SIZE + 1
	_tarot_info.text = "TABLE %d / %d   ·   REGION %d   ·   CASH $%d   ·   DECK %d cards" \
			% [room_index + 1, ROOMS_TOTAL, region, trail_cash, deck.size()]
	if relics.is_empty():
		_tarot_relics.text = ""
	else:
		var names := PackedStringArray()
		for id in relics:
			var relic_name := String(RELICS[id].name)
			if id == "second_wind" and _second_wind_used:
				relic_name += " (used)"
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
			_poster_face(fool, "LUCK OF THE DRAW", fool_tier, "A blind pick",
					"Let fate decide\n+$%d" % _fate_kicker())
		else:
			_tarot_face(fool, "LUCK OF THE DRAW", "A blind pick", "?",
					"Let fate decide\n+$%d" % _fate_kicker(),
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
					"%s\nFree to browse" % "  ·  ".join(wares))
		else:
			_tarot_face(b, String(m.name), "Safe haven", String(m.line),
					"%s\nFree to browse" % "  ·  ".join(wares))
	elif offer.kind == "camp":
		if _apply_camp_poster(b):
			_poster_face(b, "CAMPFIRE", "rest stop",
					"Rest up, enhance a card, or throw one in the fire",
					"Pick one comfort\nHP %d / %d" % [hp, max_hp()])
		else:
			_tarot_face(b, "THE CAMPFIRE", "Rest stop",
					"Rest, enhance a card, or burn one",
					"Pick one comfort\nHP %d / %d" % [hp, max_hp()])
	else:
		var goal_line := "Target  %d" % offer.target
		if offer.has("boss"):
			goal_line = "BOSS FIGHT"
		elif offer.get("goal", "") == "safe":
			goal_line = "Crack the safe"
		elif offer.get("goal", "") == "chest":
			goal_line = "Open %d chests to win a RELIC" % int(offer.get("chest_count", 1))
		elif offer.get("goal", "") == "purge":
			goal_line = "Clear %d %s cards. %d to start, and more keep coming" % [
					int(offer.get("purge_quota", PURGE_QUOTA_BASE)),
					String(offer.purge_kind).to_upper(), offer.purge_count]
		elif offer.get("goal", "") == "mine":
			goal_line = "Break all %d stones. Some have gold cards under them" % offer.stones
		elif offer.get("goal", "") == "holdem":
			goal_line = "Target %d — HOLD'EM rules" % offer.target
		elif offer.get("goal", "") == "blackjack":
			goal_line = "Beat the dealer %d times, with hazards in play" % offer.wins
		elif offer.get("goal", "") == "outlaw":
			var gang: Array = offer.get("outlaws", [])
			if gang.size() > 1:
				goal_line = "Hunt down a gang of %d, %d HP each" % [
						gang.size(), offer.outlaw_hp]
			else:
				goal_line = "Gun down %s (%d HP)" % [
						String(gang[0].name) if not gang.is_empty()
						else "the wanted man", offer.outlaw_hp]
		elif offer.get("goal", "") == "collect":
			goal_line = _collect_goal_text(offer)
		elif offer.get("goal", "") == "landrush":
			goal_line = "Claim all 25 plots by clearing a card from every space"
		elif offer.get("goal", "") == "hands":
			goal_line = "Play " + _require_text(offer.require)
		elif offer.get("goal", "") == "timed":
			goal_line = "Target %d — beat the clock" % offer.target
		var bet_line := "Pays $%d  ·  ~%d hands" % [_table_pay(offer), offer.hands]
		if offer.get("limit", "hands") == "time":
			bet_line = "Pays $%d  ·  on the clock, ~%d min" % [_table_pay(offer),
					offer.get("minutes", 4)]
		var badges := twist_badges(offer)
		if badges != "":
			goal_line += "\n" + badges
			b.tooltip_text = twist_sentences(offer)
		if offer.get("goal", "") == "outlaw" and _apply_wanted_poster(b, offer):
			_add_twist_strip(b, offer)
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


## Where in each region a kind of stop sits (STOP_LAYOUT indices).
static func _layout_slots(kind: String) -> Array:
	var out: Array = []
	for i in STOP_LAYOUT.size():
		if String(STOP_LAYOUT[i]) == kind:
			out.append(i)
	return out


## The wanted poster has no room for the goal line, so its twists ride
## on a little strip under it.
func _add_twist_strip(b: Button, offer: Dictionary) -> void:
	var badges := twist_badges(offer)
	if badges == "":
		return
	var l: Label = main._label(b, badges, Vector2(0, b.size.y + 4), 14, main.GOLD)
	l.size = Vector2(b.size.x, 40)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE


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
	var reward := _table_pay(offer)
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
	var sub_text := "GANG OF %d · %d HP EACH" % [outlaws.size(),
			int(offer.outlaw_hp)] if outlaws.size() > 1 \
			else "DEAD OR ALIVE · %d HP" % int(offer.outlaw_hp)
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
	if is_equal_approx(odds, round(odds)):
		return "%d : 1" % maxi(1, int(round(odds)))
	# Twists push the odds off the round numbers: show them as they are.
	return "%s : 1" % String.num(odds, 2)


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
		trail_cash += _fate_kicker()
	current_offer = offer
	tarot_layer.visible = false
	_log_stop(offer)
	_mark_table_played(offer)
	if offer.kind == "shop":
		_show_shop()
	elif offer.kind == "camp":
		_show_camp()
	elif offer.has("boss"):
		main.board._play_sound(Board.SFX_REVOLVER_CHARGE, 0.9, -6.0)
		_start_room()
	else:
		_show_bet()


# --- Flow: the table screen -----------------------------------------------

## THE TABLE: what the job is, what it pays, its twists. Bosses go
## straight in.
func _show_bet() -> void:
	_hide_all()
	var o := current_offer
	if o.has("boss"):
		main.board._play_sound(Board.SFX_REVOLVER_CHARGE, 0.9, -6.0)
		_start_room()
		return
	# A pending room bars the way — no backing out to a fresh draw.
	_bet_back_btn.visible = pending_retry.is_empty()
	_refresh_bet_labels()
	bet_layer.visible = true


## The Fool's purse for trusting fate.
func _fate_kicker() -> int:
	return roundi(FATE_KICKER * _region_scale(room_index))


func _is_timed(o: Dictionary) -> bool:
	return o.get("limit", "hands") == "time"


## Rooms that run on the clock instead of a hand budget.
func room_on_clock() -> bool:
	return room_limit == "time"


func _bet_goal_text(o: Dictionary) -> String:
	match String(o.get("goal", "")):
		"safe":
			return "Crack the safe"
		"chest":
			return "Open %d chests. The strongbox holds a RELIC" \
					% int(o.get("chest_count", 1))
		"purge":
			if o.purge_kind == "fire":
				return "Clear %d fire cards. %d to start, it spreads, and more keep catching" \
						% [int(o.get("purge_quota", PURGE_QUOTA_BASE)), o.purge_count]
			return "Clear %d %s cards. %d to start, and more arrive as you play" \
					% [int(o.get("purge_quota", PURGE_QUOTA_BASE)), o.purge_kind, o.purge_count]
		"mine":
			return "Break all %d stones. Some have gold cards under them, and more stones drop in as you dig" % o.stones
		"holdem":
			return "Target %d. Pick 2 hole cards and score the best 5 of 7 with the community" % o.target
		"blackjack":
			return "Beat the dealer %d times. The table's face down, you hit blind, and the dealer plays his hand" % o.wins
		"outlaw":
			var gang: Array = o.get("outlaws", [])
			var who := String(gang[0].name) if not gang.is_empty() else "the wanted man"
			if gang.size() > 1:
				return "Bounty: gun down %s and his gang, %d outlaws at %d HP each, one at a time" \
						% [who, gang.size(), o.outlaw_hp]
			return "Bounty: shoot %s %d times, and don't clear any of his bullets" \
					% [who, o.outlaw_hp]
		"collect":
			return _collect_goal_text(o)
		"landrush":
			return "Stake a claim on all 25 plots by clearing a card from every space"
		"hands":
			return "Play " + _require_text(o.require)
		"timed":
			return "Target %d before the clock runs out" % o.target
	return "Target %d" % o.target


func _refresh_bet_labels() -> void:
	var o := current_offer
	var retry_line := ""
	if not pending_retry.is_empty():
		retry_line = "\nThis table still blocks the way. You have to beat it to ride on." \
				if pending_is_retry else "\nBack to the table you stepped away from."
	var unit := "min" if _is_timed(o) else "hands"
	var reference := int(o.get("minutes", 4)) if _is_timed(o) else int(o.hands)
	_bet_info.text = "%s — %s table\n%s\n%d %s to do it\nYour trail cash: $%d%s" % [
		o.tarot, o.label, _bet_goal_text(o), reference, unit, trail_cash, retry_line]
	var twist_line := twist_sentences(o)
	_bet_twists.text = twist_line
	for ch in _bet_chips.get_children():
		ch.queue_free()
	if twist_line != "":
		_bet_chips.add_child(main.twist_chips(o))
	_bet_stake_label.text = "THIS TABLE PAYS  $%d" % _table_pay(o)


## Sitting down: nothing to pay, straight to the table.
func _confirm_bet() -> void:
	main.board._play_sound(Board.SFX_REVOLVER_CHARGE, 1.0, -8.0)
	bet_layer.visible = false
	_start_room()


# --- Flow: playing a room -------------------------------------------------

func _start_room() -> void:
	in_room = true
	# A retry of a lost table deals fresh — but still from the seed.
	room_attempt = room_attempt + 1 if _attempt_room == room_index else 0
	_attempt_room = room_index
	rng_room = SeedRng.stream(run_seed, "room", room_index, room_attempt)
	_rng = rng_room
	main.board.rng = SeedRng.stream(run_seed, "board", room_index, room_attempt)
	rng_ability = SeedRng.stream(run_seed, "ability", room_index, room_attempt)
	room_ability_counts = {}
	_time_granted = 0.0
	_push_loadout()
	main.stat_max("deepest_table", room_index + 1)
	sleeve_used = false  # one signature use per table, fresh each sit-down
	_aiming_sleeve = false
	_aiming_sleight = false
	sleight_uses_left = 1 + ride_lv("sleight")
	_aiming_sleight = false
	laser_used = false
	_aiming_laser = false
	_swap_first = null
	watch_uses_left = 1 + ride_lv("watch")
	_watch_snapshot = {}
	main.board.undo_state = {}
	main.board.undo_enabled = character == "the_doctor"
	_apply_ascension_to_board()
	_chest_rewards.clear()  # unopened luck doesn't carry between tables
	_chest_won_cards.clear()
	_chest_card_rounds = 0
	main.tutor_show("hp")
	# The Chuck Wagon rolls in with supplies at every table.
	if has_relic("chuck_wagon") and provisions.size() < kit_size():
		var ration := _random_provision()
		if gain_provision(ration):
			main._announce("CHUCK WAGON DELIVERY — %s"
					% String(PROVISIONS[ration].name).to_upper())
	elif has_relic("chuck_wagon") and int(rv("chuck_wagon", "cash")) > 0:
		# A full kit takes its rations in cash instead.
		var ration_chips := _table_pay(current_offer)
		trail_cash += ration_chips
		main._announce("THE CHUCK WAGON PAYS  +$%d" % ration_chips)
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
	room_hands_left = maxi(1, int(current_offer.hands)
			- Ascension.hands_minus(ascension)) \
			+ (int(rv("horseshoe", "hands")) if has_relic("horseshoe") else 0)
	room_time_left = 0.0
	if room_on_clock():
		# The clock is the budget, not hands.
		room_time_left = maxf(60.0, 60.0 * int(current_offer.get("minutes", 3))
				- Ascension.clock_minus_secs(ascension)) \
				+ (float(rv("horseshoe", "secs")) if has_relic("horseshoe") else 0.0)
		room_hands_left = 999
	var horn := int(_ability_passive("extra_hands", 0.0))
	# Posse Up: a hand for every few Sheriffs riding along (per copy).
	var sheriffs := int(Abilities.posse_counts(all_equipped()).sheriff)
	for id in all_equipped():
		var every := int(Abilities.fx(id).get("posse_hands", 0))
		if every > 0:
			horn += sheriffs / every
	if horn > 0 and room_goal != "blackjack":
		if room_on_clock():
			room_time_left += SADDLE_HORN_SECS * horn
		else:
			room_hands_left += horn
	main.mode_kind = "trail"
	main.mode_label_text = "Trail · A%d · %s · Seed %s" % [ascension,
			character_name().trim_prefix("The "), SeedRng.pretty(run_seed)]
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
	var first := _ability_passive("first_mult", 1.0)
	if first > 1.0:
		# Fastest Gun: the opening hand at every table counts extra.
		main.board.next_hand_mult = maxf(main.board.next_hand_mult, first)
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
		if _rng.randf() < 0.5:
			main.board.spawn_objective("redeal")
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
	elif _rng.randf() < AMBIENT_CHANCE * (float(rv("rabbits_foot", "x")) if has_relic("rabbits_foot") else 1.0) \
			and (_avail("room", "safe") or _avail("room", "chest")):
		# Surprise loot in a plain room — only jobs the rider has met.
		var safe_ok := _avail("room", "safe")
		if safe_ok and (not _avail("room", "chest") or _rng.randf() < 0.5):
			room_combo = _generate_combo()
			main.board.spawn_safe(room_combo)
		else:
			main.board.spawn_key_and_chest()
	_apply_twist_rules()
	# Storm tables (Blackjack) trade the ambient roll for a guaranteed
	# mixed hazard load — the house evening the odds.
	var storm := _hazard_floor()
	for i in storm:
		main.board.apply_room_hazards(SeedRng.pick(_rng, HAZARD_KINDS), 1)
	# Hazard TWISTS put their hazard on the table up front (and keep it
	# topped up). Tables dealt with twists show their danger, so the old
	# hidden hazard roll only runs for bosses and older saved tables.
	for kind in TableMods.HAZARD_TWISTS:
		if TableMods.has_twist(current_offer, String(TableMods.HAZARD_TWISTS[kind])):
			main.board.apply_room_hazards(String(kind), _hazard_twist_floor())
	var hidden_roll := current_offer.has("boss") or not current_offer.has("twists") \
			or bool(current_offer.get("legacy_ambient", false))
	if room_goal != "purge" and storm == 0 and hidden_roll:
		var hz_chance := clampf(HAZARD_BASE_CHANCE + HAZARD_ROOM_STEP * table_depth(room_index)
				+ Ascension.hazard_bonus(ascension), 0.0, 0.95)
		if _rng.randf() < hz_chance:
			var count := 1 + table_depth(room_index) / HAZARD_COUNT_ROOMS + Ascension.extra_seed(ascension)
			count = mini(count, HAZARD_COUNT_MAX)
			for i in count:
				main.board.apply_room_hazards(SeedRng.pick(_rng, HAZARD_KINDS), 1)
	# And the deck itself turns mean: every refilled card has a chance
	# to arrive hazarded, climbing the deeper you ride.
	if room_goal != "purge":
		main.board.refill_hazard_chance = _refill_chance() * _ability_passive("refill_hazard_mult", 1.0)
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
		"blackjack":
			return BLACKJACK_HAZARDS_BASE + room_index / REGION_SIZE
	return 0


## How many of its hazard a hazard twist keeps on the table.
func _hazard_twist_floor() -> int:
	return 2 + room_index / REGION_SIZE


## The board takes the table's twists: the wild rank and any hand rules.
## Runs at the sit-down and when a photographed table is restored.
func _apply_twist_rules() -> void:
	var wr := TableMods.wild_rank(current_offer)
	main.board.wild_rank = wr
	PlayingCard.wild_rank = wr
	main.board.play_only = PackedStringArray(TableMods.twist(current_offer, "play_only").get("hands", []))
	main.board.score_only = PackedStringArray(TableMods.twist(current_offer, "score_only").get("hands", []))
	if wr > 0:
		main.board.apply_theme()  # repaint so the wild cards show their W


## After every hand, each hazard twist tops its hazard back up to its
## floor, one card at a time on the deal.
func _hazard_twist_upkeep() -> void:
	for kind in TableMods.HAZARD_TWISTS:
		if not TableMods.has_twist(current_offer, String(TableMods.HAZARD_TWISTS[kind])):
			continue
		var live := 0
		for p in main.board.grid:
			var c: PlayingCard = main.board.grid[p]
			if c.hazard == String(kind):
				live += 1
		if live < _hazard_twist_floor():
			main.board.queue_refill_hazards(String(kind), 1)


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
	for tw in current_offer.get("twists", []):
		if not bool(tw.get("forced", false)):
			main.tutor_show("twists")
	if TableMods.wild_rank(current_offer) > 0:
		main.tutor_show("goal_crazy8")
	if TableMods.has_twist(current_offer, "play_only") or TableMods.has_twist(current_offer, "score_only"):
		main.tutor_show("twist_hands")
	for p in main.board.grid:
		var card: PlayingCard = main.board.grid[p]
		if card.hazard != "":
			main.callout_card(card, "hazard_" + card.hazard)
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
		combo.append(SeedRng.pick(_rng, pool) if not pool.is_empty() else _rng.randi_range(2, max_rank))
	return combo


func on_hand_played(result: Dictionary) -> void:
	# main already added result.score to the run total (main.score).
	var negs := int(result.get("negatives", 0))
	if negs > 0 and in_room:
		# NEGATIVE cards give the time back — banked before the hand is
		# charged, so a hand that scores one costs nothing.
		if room_on_clock():
			var secs := negs * int(progress.val("finish", "negative", "secs", 10))
			room_time_left += secs
			_time_granted += secs
			_announce_after_settle("NEGATIVE  +%d SECONDS" % secs)
		else:
			room_hands_left += negs
			_announce_after_settle("NEGATIVE — HAND BACK" if negs == 1
					else "NEGATIVE — %d HANDS BACK" % negs)
	if in_room:
		_fire_play_abilities(result)
		# The ride remembers how often each hand has been played (Notches
		# on the Gun), and the table how many hands it has seen (True Grit).
		var played := String(result.get("name", ""))
		if Abilities.HAND_SLOTS.has(played):
			hand_plays[played] = int(hand_plays.get(played, 0)) + 1
		room_ability_counts["_played"] = int(room_ability_counts.get("_played", 0)) + 1
	var spent := int(result.get("cash_spent", 0))
	if spent > 0:
		# Desperado bought his triple with trail cash.
		trail_cash = maxi(0, trail_cash - spent)
	room_score += result.score
	if int(result.score) > best_hand_score:
		best_hand_score = int(result.score)
		best_hand_name = String(result.get("name", ""))
	# Cash cards SEASON with use: each scoring permanently bumps that
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
		# Cash and Gold cards pay trail cash: spend it on the road, and
		# it comes home if you finish.
		trail_cash += earned
		_announce_after_settle("TRAIL CASH  +$%d" % earned)
	if result.get("boss_defeated", false):
		_room_cleared()
		return
	if result.get("jack_shrugged", false):
		_announce_after_settle("THE JACK SHRUGS IT OFF — SCORE %d TO HURT HIM"
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
			main.board.queue_refill_hazards(SeedRng.pick(_rng, HAZARD_KINDS), 1)
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
	_hazard_twist_upkeep()
	# Lost keys and chests (played without a partner, blown off by
	# wind, burned out) respawn from the hazard tick's settle check —
	# one place, after everything that can remove a card has acted.
	_consume_hand()


const SADDLE_HORN_SECS := 15


## A passive ability's strength across the whole loadout: extra hands
## add up; multipliers take the strongest one (1.0 or 0.0 when none).
func _ability_passive(key: String, none: float) -> float:
	var out := none
	for id in all_equipped():
		var fx: Dictionary = Abilities.fx(id)
		if not fx.has(key):
			continue
		match key:
			"extra_hands":
				out += float(fx[key])
			"refill_hazard_mult":
				out = minf(out, float(fx[key]))
			_:
				out = maxf(out, float(fx[key]))
	return out


## The abilities on the hand just played act on the table. They fire
## before the hand is charged and before any goal check, so a refund
## covers this very hand and cleared hazards count toward a purge.
## Random picks use the table's own ability stream.
func _fire_play_abilities(result: Dictionary) -> void:
	var hand := String(result.get("name", ""))
	if not Abilities.HAND_SLOTS.has(hand):
		return  # blackjack rounds and the like carry no abilities
	var fired: Array = []
	var refunded := false
	var popping: Array = result.get("cleared_cells", [])
	for id in equipped_on(hand):
		var fx: Dictionary = Abilities.fx(id)
		var hit := false
		if fx.has("enhance"):
			for n in int(fx.get("enhance_n", 1)):
				if main.board.enhance_next_draw(String(fx.enhance)):
					hit = true
		if fx.has("clear") or fx.has("douse"):
			var fire_only := fx.has("douse")
			var n := int(fx.get("douse", fx.get("clear", 0)))
			var targets: Array = []
			for p in main.board.grid:
				var c: PlayingCard = main.board.grid[p]
				if popping.has(p):
					continue
				var dirty := (c.hazard != "" and c.hazard != "stone") or (c.honey and not fire_only)
				if not dirty or (fire_only and c.hazard != "fire"):
					continue
				targets.append(c)
			targets.sort_custom(func(a: PlayingCard, b: PlayingCard) -> bool:
				return a.grid_pos.y * 10 + a.grid_pos.x < b.grid_pos.y * 10 + b.grid_pos.x)
			SeedRng.shuffle(rng_ability, targets)
			for i in mini(n, targets.size()):
				targets[i].honey = false  # honey counts as a hazard to sweep
				main.board.provision_clean(targets[i])
				main.board._fx(targets[i].position, "smoke")
				hit = true
		if fx.has("fuse"):
			for p in main.board.grid:
				var c: PlayingCard = main.board.grid[p]
				if c.hazard == "bomb" and not popping.has(p):
					c.fuse += int(fx.fuse)
					hit = true
		if fx.has("time") and room_on_clock():
			room_time_left += float(fx.time)
			_time_granted += float(fx.time)
			hit = true
		elif fx.has("hand_every") and not room_on_clock():
			var count := int(room_ability_counts.get(id, 0)) + 1
			room_ability_counts[id] = count
			if count % int(fx.hand_every) == 0 and not refunded:
				room_hands_left += 1
				refunded = true
				hit = true
		if fx.has("free") and not refunded:
			if room_on_clock():
				room_time_left += float(fx.free)
				_time_granted += float(fx.free)
			else:
				room_hands_left += 1
			refunded = true
			hit = true
		if fx.has("next_mult"):
			main.board.next_hand_mult = maxf(main.board.next_hand_mult, float(fx.next_mult))
			hit = true
		if fx.has("next_flat"):
			main.board.next_hand_flat += int(fx.next_flat)
			hit = true
		if fx.has("extra_hit") and room_goal == "outlaw" and int(result.get("bullets_you", 0)) > 0:
			result["bullets_you"] = int(result.bullets_you) + int(fx.extra_hit)
			hit = true
		if fx.has("brand"):
			for n in int(fx.get("brand_n", 1)):
				if _brand_from_hand(result, String(fx.brand)):
					hit = true
		if hit and not fired.has(Abilities.ability_name(id)):
			fired.append(Abilities.ability_name(id))
	# Reward Money counts the hits once every Hired Gun has added his.
	var hits := int(result.get("bullets_you", 0)) if room_goal == "outlaw" else 0
	for id in equipped_on(hand):
		var per := int(Abilities.fx(id).get("cash_per_hit", 0))
		if per > 0 and hits > 0:
			trail_cash += per * hits
			if not fired.has(Abilities.ability_name(id)):
				fired.append(Abilities.ability_name(id))
	for n in result.get("abilities", []):
		if not fired.has(n):
			fired.append(n)
	if not fired.is_empty():
		main.stat_bump("abilities_fired", fired.size())
		_announce_after_settle(", ".join(PackedStringArray(fired)).to_upper())


## Branded for Life: one plain card from the hand becomes an enhanced
## card in the deck for the rest of the ride.
func _brand_from_hand(result: Dictionary, mod: String) -> bool:
	var plain: Array = []
	for cc in result.get("cleared_cards", []):
		if String(cc.get("mod", "")) == "" and not bool(cc.get("cursed", false)) \
				and not bool(cc.get("joker", false)):
			plain.append(cc)
	if plain.is_empty():
		return false
	var pick: Dictionary = SeedRng.pick(rng_ability, plain)
	for d in deck:
		if int(d.rank) == int(pick.rank) and int(d.suit) == int(pick.suit) \
				and String(d.get("mod", "")) == "" and not bool(d.get("cursed", false)):
			d["mod"] = mod
			return true
	return false


## A hand (or a safe crack) is spent; run out and the room is lost.
func _consume_hand() -> void:
	if room_on_clock():
		# Clock rooms never run out of hands — only of seconds.
		_tick_room_hazards()
		return
	if has_relic("lucky_chip") and _rng.randf() < float(rv("lucky_chip", "p")):
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
	if _last_stand():
		return
	_room_failed()


## Rio Bravo: once at every table, running out buys a last stand.
func _last_stand() -> bool:
	var more := int(_ability_passive("last_stand", 0.0))
	if more <= 0 or room_ability_counts.has("_last_stand") or room_goal == "blackjack":
		return false
	room_ability_counts["_last_stand"] = 1
	if room_on_clock():
		room_time_left += 15.0 * more
		_time_granted += 15.0 * more
		main._announce("RIO BRAVO — %d MORE SECONDS" % (15 * more), main.GOLD)
	else:
		room_hands_left += more
		main._announce("RIO BRAVO — %d MORE HANDS" % more, main.GOLD)
	main.board._play_sound(Board.SFX_REVOLVER_CHARGE, 1.0, -6.0)
	return true


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
		main._announce("A NEW KEY OR CHEST TURNS UP")


func on_safe_cracked() -> void:
	if room_goal == "safe":
		_room_cleared()
		return
	# Ambient safe: bonus loot, but the crack still costs a hand.
	var region := room_index / REGION_SIZE + 1
	var loot := roundi((4 + 2 * region) * Ascension.pay_mult(ascension))
	trail_cash += loot
	main.board._play_sound(Board.SFX_BELL, 1.0, -8.0)
	main.board._play_sound(Board.SFX_COINS.pick_random(), 1.0, -6.0, 0.3)
	var msg := "SAFE LOOT  +$%d" % loot
	if _rng.randf() < 0.35 and provisions.size() < kit_size():
		# Sometimes the safe holds supplies instead of just coin.
		var pid := _random_provision()
		gain_provision(pid)
		msg += "  ·  %s" % String(PROVISIONS[pid].name).to_upper()
	_announce_after_settle(msg)
	_consume_hand()


## An ambient chest opened mid-room: the reward KIND is rolled now,
## the reveal waits for the winnings screen.
func _defer_chest_reward() -> void:
	var roll := _rng.randf()
	if roll < 0.5:
		_chest_rewards.append("chips")
	elif roll < 0.85:
		_chest_rewards.append("ability")
	elif _unowned_common_relic() != "":
		_chest_rewards.append("relic")
	else:
		_chest_rewards.append("chips")
	main.board._play_sound(Board.SFX_COINS.pick_random(), 0.8, -8.0)
	_announce_after_settle("CHEST CLAIMED — YOU'LL OPEN IT AFTER THE TABLE")


## A random COMMON relic the player doesn't own yet, or "".
func _unowned_common_relic() -> String:
	return _relic_pick([], true)


## Chest reward roll (treasure rooms — ambient chests defer instead).
func _open_chest() -> void:
	var region := room_index / REGION_SIZE + 1
	var roll := _rng.randf()
	if roll < 0.45:
		var loot := roundi((3 + 1.5 * region) * Ascension.pay_mult(ascension))
		trail_cash += loot
		main.board._play_sound(Board.SFX_COINS.pick_random(), 1.0, -6.0)
		_announce_after_settle("CHEST  +$%d" % loot)
	elif roll < 0.65:
		# An ability card, offered on its own round after the table.
		_chest_card_rounds += 1
		main.board._play_sound(Board.SFX_FLIP, 1.1, -8.0)
		_announce_after_settle("CHEST  AN ABILITY CARD (YOU'LL PICK IT AFTER THE TABLE)")
	elif roll < 0.80:
		# No loose cash on the trail — the chest holds a GOLD card.
		var gold := {"rank": _rng.randi_range(2, 14), "suit": _rng.randi_range(0, 3),
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
		var enhanced := {"rank": _rng.randi_range(2, 14), "suit": _rng.randi_range(0, 3),
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
	return OUTLAW_BAR_BASE + 15 * (room_index / REGION_SIZE) + Ascension.outlaw_bar_plus(ascension)


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
		leader = CharacterKit.preset(SeedRng.pick(_rng, leader_ids))
	if leader.is_empty():
		leader = CharacterKit.random_spec(_rng.randi())
	if String(leader.get("name", "")) == "THE OUTLAW":
		# No generic names on the wanted wall: the old face rides on
		# under a name of his own.
		leader["name"] = "%s %s" % [SeedRng.pick(_rng, CharacterKit.FIRST),
				SeedRng.pick(_rng, CharacterKit.LAST)]
	out.append(leader)
	for i in n - 1:
		var member: Dictionary = CharacterKit.random_spec(_rng.randi(),
				"RIDES WITH " + String(leader.name))
		var guard := 0
		while String(member.name) == String(leader.name) and guard < 8:
			member = CharacterKit.random_spec(_rng.randi(),
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
	return _table_pay(current_offer)


func _old_bounty_reward() -> int:
	return 0


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
	if not main.board.has_objective("redeal") and _rng.randf() < 0.35:
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
			"THE FIRE REACHED YOU" if burns == 1
			else "%d FIRES REACHED YOU" % burns,
			"Burned at the table."):
		return
	if blasts > 0 and not take_damage(Ascension.bomb_hp(ascension) * blasts, "CAUGHT IN THE BLAST",
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
	_stream("reward")
	_pick_round = 0
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
	if TableMods.wild_rank(current_offer) > 0:
		main.stat_bump("cleared_crazy8")  # the Crazy Eights contract: any wild table
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
	var pay := _table_pay(current_offer)
	var winnings := pay
	_win_rows = [["THE TABLE PAYS", pay]]
	if has_relic("tin_star"):
		var star := int(rv("tin_star", "cash"))
		winnings += star
		_win_rows.append(["TIN STAR", star])
	# Swift work pays: $1 for every two spare hands (or every 20 spare
	# seconds on a clock table).
	var spare := int(room_time_left / 10.0) if room_on_clock() \
			else maxi(room_hands_left, 0)
	var bonus := spare / 2
	if bonus > 0:
		_win_rows.append([("%d SECONDS TO SPARE" % int(room_time_left))
				if room_on_clock() else ("%d HANDS TO SPARE" % spare), bonus])
	winnings += bonus
	trail_cash += winnings
	main.board._play_sound(Board.SFX_STING_BOSS if current_offer.has("boss")
			else Board.SFX_STING_WIN, 1.0, -6.0)
	main.board._play_sound(Board.SFX_COINS.pick_random(), 1.0, -6.0, 0.4)
	main.table_banner("TABLE CLEARED")
	main.board.confetti()
	_settle_bet(room_index)
	if room_goal == "chest":
		# The stagecoach strongbox: a relic for the hardest job around,
		# unveiled on its own reward screen after the settle.
		var relic_id := _unowned_relic()
		if relic_id != "" and relics.size() < MAX_RELICS:
			_gain_relic(relic_id)
			_pending_relic_reward = relic_id
			_relic_ambient = false
		else:
			trail_cash += 6
			_win_rows.append(["STRONGBOX (no new relics)", 6])
	# Ambient chests crack open with the winnings: coins join the
	# ledger, an ability owes an extra offer round, a relic takes the
	# strongbox screen.
	for kind in _chest_rewards:
		match String(kind):
			"chips":
				var region := room_index / REGION_SIZE + 1
				var loot := roundi((3 + 1.5 * region) * Ascension.pay_mult(ascension))
				trail_cash += loot
				_win_rows.append(["THE CHEST — it held coins", loot])
			"card", "ability":
				_chest_card_rounds += 1
			"relic":
				var rid := _unowned_common_relic()
				if rid != "" and _pending_relic_reward == "":
					_gain_relic(rid)
					_pending_relic_reward = rid
					_relic_ambient = true
				else:
					trail_cash += 6
					_win_rows.append(["THE CHEST — nothing new inside", 6])
	_chest_rewards.clear()
	var cleared := room_index
	var source := "boss" if current_offer.has("boss") else "table"
	_after_board_settles(func() -> void:
		room_index += 1
		if room_index >= ROOMS_TOTAL:
			_trail_complete()
		else:
			# The reward is rolled now and saved with the ride, so quitting
			# on the reward screen comes back to the very same offer.
			pending_reward = {"room": cleared, "source": source, "round": 0,
					"offers": _roll_ability_offer(cleared, 0, source),
					"chest_rounds": _chest_card_rounds,
					"relic": _pending_relic_reward, "relic_ambient": _relic_ambient,
					"ledger": _win_rows.duplicate(true)}
			_chest_card_rounds = 0
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
	if _last_stand():
		return
	_room_failed("TIME'S UP — THE STAGECOACH LEFT" if room_goal == "chest"
			else "TIME'S UP — THE TABLE WINS")


## A curse joins the deck as an extra card with no rank and no suit.
static func cursed_card() -> Dictionary:
	return {"rank": 0, "suit": 0, "cursed": true}


func _room_failed(reason := "BUSTED — CURSE ADDED TO DECK") -> void:
	in_room = false
	_room_save = {}
	_chest_rewards.clear()  # the chest went down with the table
	_chest_won_cards.clear()
	main.board.locked = true
	# The stake is gone and a curse joins the deck — and the room does
	# NOT clear: the same table must be beaten before the trail continues.
	deck.append(cursed_card())
	main.board._play_sound(Board.SFX_CROWS.pick_random(), 1.0, -8.0)
	# Losing a table leaves a mark on the rider too.
	if not take_damage(Ascension.lost_table_hp(ascension), "", "One lost table too many."):
		return
	main.table_banner(reason, main.RED)
	_after_board_settles(_retry_room)


## Back to the same room's table: it still blocks the way.
func _retry_room() -> void:
	pending_retry = current_offer.duplicate(true)
	pending_is_retry = true
	_save_run()
	_show_bet()


func _after_board_settles(then: Callable) -> void:
	while main.board.busy:
		await get_tree().process_frame
	then.call()


## The live table as pure data: board photograph plus every room
## counter. {} when it can't be taken
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
		"rng_room": rng_room.state,
		"room_attempt": room_attempt,
		"rng_ability": rng_ability.state,
		"ability_counts": room_ability_counts.duplicate(),
		"time_granted": _time_granted,
		"chest_rewards": _chest_rewards.duplicate(),
		"chest_rounds": _chest_card_rounds,
	}


## Sits the rider back down exactly where they stood up: same board,
## same counters, no scar.
func _restore_room_state() -> void:
	var rs := _room_save
	_room_save = {}
	current_offer = rs.offer.duplicate(true)
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
	room_attempt = int(rs.get("room_attempt", room_attempt))
	_attempt_room = room_index
	rng_room = SeedRng.stream(run_seed, "room", room_index, room_attempt)
	if rs.has("rng_room"):
		rng_room.state = int(rs.rng_room)
	_rng = rng_room
	rng_ability = SeedRng.stream(run_seed, "ability", room_index, room_attempt)
	if rs.has("rng_ability"):
		rng_ability.state = int(rs.rng_ability)
	room_ability_counts = (rs.get("ability_counts", {}) as Dictionary).duplicate()
	_time_granted = float(rs.get("time_granted", 0.0))
	if rs.has("chest_rewards"):
		_chest_rewards = (rs.chest_rewards as Array).duplicate()
	_chest_card_rounds = int(rs.get("chest_rounds", _chest_card_rounds))
	_push_loadout()
	sleight_uses_left = int(rs.get("sleight_uses_left",
			0 if bool(rs.get("sleight_used", false)) else 1 + ride_lv("sleight")))
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
	main.mode_label_text = "Trail · A%d · %s · Seed %s" % [ascension,
			character_name().trim_prefix("The "), SeedRng.pretty(run_seed)]
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
	_apply_ascension_to_board()
	main.board.refill_hazard_chance = 0.0 if room_goal == "purge" \
			else _refill_chance() * _ability_passive("refill_hazard_mult", 1.0)
	main.board.apply_state_snapshot(rs.board)
	_apply_twist_rules()
	if room_goal == "landrush":
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
		pending_retry = current_offer.duplicate(true)
		pending_is_retry = false
	_save_run()


## The starting bet comes in when its boss falls: stake plus winnings,
## straight to the bank, safe whatever happens after.
func _settle_bet(room: int) -> void:
	if bet.is_empty() or bool(bet.get("paid", false)) or standard_loadout:
		return
	var target := String(bet.get("target", ""))
	if not BET_ROOMS.has(target) or int(BET_ROOMS[target]) != room:
		return
	var stake := int(bet.get("stake", 0))
	var won := stake + roundi(stake * float(bet.get("odds", 1.0)))
	bet["paid"] = true
	bet["won"] = won
	cash += won
	main.stat_bump("bets_won")
	_save_meta()
	_save_run()
	main.board._play_sound(Board.SFX_COINS.pick_random(), 1.1, -4.0, 0.3)
	_announce_after_settle("YOUR BET CAME IN — $%d BANKED" % won)


func _trail_complete() -> void:
	main.stat_bump("trail_wins")
	# A seeded ride can saddle any rider, so its win doesn't open the
	# next one (or count as an Ascension record).
	if not standard_loadout:
		main.stat_bump("trail_wins_" + character)
		if ascension >= 1:
			main.stat_max("ascension_best", ascension)
	var opened := false if standard_loadout else progress.open_ascension(character, ascension + 1)
	main._stats_save()
	main.board._play_sound(Board.SFX_STING_COMPLETE, 1.0, -5.0)
	main.board._play_sound(Board.SFX_COINS.pick_random(), 1.0, -6.0, 0.5)
	_settle_bet(ROOMS_TOTAL - 1)
	var payout := 0 if standard_loadout else trail_cash \
			+ roundi(COMPLETE_PURSE * Ascension.purse_mult(ascension))
	cash += payout
	_save_meta()
	_clear_run_save()
	var body := "You rode all %d stops and beat the trail.\nYour trail cash and the purse come home: $%d" % [ROOMS_TOTAL, payout]
	if standard_loadout:
		body = "You rode all %d stops on a seeded ride.\nYour score goes on the seed's board. Seeded rides don't bank cash." % ROOMS_TOTAL
	if opened:
		body += "\n\nASCENSION %d is now unlocked for %s." % [ascension + 1, character_name()]
	if ascension >= Ascension.MAX:
		body += "\n\nSomewhere past the last saloon, THE DEALER is waiting\nwith a perfect deck. (His table opens soon.)"
	_end_run("TRAIL COMPLETE", body, payout)


## The strongbox opens: the won relic on its own reward screen.
func _show_relic_reward() -> void:
	main.transition(_show_relic_reward_now)


func _show_relic_reward_now() -> void:
	_hide_all()
	main.game_started = false
	main.play_music("tarot")
	_relic_sub.text = ("The chest you opened along the way held a relic."
			if _relic_ambient else "The stagecoach job pays in more than cash.")
	var r: Dictionary = RELICS.get(_pending_relic_reward, {})
	_relic_icon.relic_id = _pending_relic_reward
	_relic_name.text = String(r.get("name", "")).to_upper()
	_relic_desc.text = relic_desc(_pending_relic_reward)
	main.board._play_sound(Board.SFX_COINS.pick_random(), 0.9, -6.0)
	relic_layer.visible = true


# --- Flow: the ability reward ----------------------------------------------

# Rarity odds by where an offer comes from (Common, Rare, Epic, Legendary).
const ABILITY_WEIGHTS := {
	"region1": [70, 25, 5, 0], "region2": [55, 32, 11, 2], "region3": [45, 35, 16, 4],
	"chest": [50, 35, 15, 0], "boss": [0, 0, 75, 25],
}
const ABILITY_OFFER := 3


## Rolls an ability offer from the "pick" stream for (room, round).
## Each card rolls a rarity first, then an available ability of that
## rarity; abilities you already hold come up 1.5 times as often, since
## a second copy can be combined into a stronger one.
func _roll_ability_offer(room: int, round: int, source: String) -> Array:
	_stream("pick", room, round)
	var count := ABILITY_OFFER
	if source != "chest" and has_relic("card_sleeve"):
		count = int(rv("card_sleeve", "picks"))
	var key := source if source in ["chest", "boss"] \
			else "region%d" % clampi(room / REGION_SIZE + 1, 1, 3)
	var weights: Array = ABILITY_WEIGHTS[key]
	var offer: Array = []
	for i in count:
		var roll := _rng.randf() * float(weights[0] + weights[1] + weights[2] + weights[3])
		var r := 0
		while r < 3 and roll >= float(weights[r]):
			roll -= float(weights[r])
			r += 1
		var id := _ability_pick(Abilities.ids_of_rarity(r), offer)
		if id == "":
			# Nothing left at that rarity: any available ability will do.
			id = _ability_pick(Abilities.DEFS.keys(), offer)
		if id != "":
			offer.append(id)
	return offer


func _ability_pick(ids: Array, exclude: Array) -> String:
	var w := {}
	for id in ids:
		w[id] = 1.5 if owns_ability(String(id)) else 1.0
	return progress.pick("ability", w, exclude, _rng)


func _show_pick() -> void:
	main.transition(_show_pick_now)


func _show_pick_now() -> void:
	_hide_all()
	if pending_reward.is_empty():
		_show_tarot_now()
		return
	main.game_started = false
	main.play_music("tarot")
	var round := int(pending_reward.get("round", 0))
	_in_chest_pick = round > 0
	if _in_chest_pick:
		_pick_title.text = "FROM THE CHEST"
		_pick_sub.text = "The chest held an ability card. Take one, or leave them all."
		for child in _win_box.get_children():
			child.queue_free()  # the ledger already had its moment
	else:
		_pick_title.text = "TABLE CLEARED"
		_pick_sub.text = ("The house pays its best for that one. Pick an ability to keep, or take none."
				if String(pending_reward.get("source", "")) == "boss"
				else "Pick an ability to keep, or take none.")
		_render_win_ledger()
	for child in _pick_box.get_children():
		child.queue_free()
	var offers: Array = pending_reward.get("offers", [])
	var start_x := (1920.0 - (offers.size() * 220.0 - 50.0)) / 2.0
	for i in offers.size():
		var id := String(offers[i])
		var holder: Button = main._button(_pick_box, "", Vector2(start_x + i * 220, 0), Vector2(170, 240))
		UiKit.style_shop_slot(holder)
		holder.tooltip_text = "%s (%s, %s)\n%s" % [Abilities.display_name(id),
				Abilities.side_name(id), Abilities.RARITY_NAMES[Abilities.rarity(id)],
				Abilities.describe(id)]
		var face := AbilityCard.new()
		face.ability_id = id
		face.position = Vector2(85, 120)
		face.scale = Vector2(1.08, 1.08)
		holder.add_child(face)
		if (OS.get_environment("POKERPOP_SHOT") == "" or OS.get_environment("POKERPOP_REVEAL") != "") \
				and CardArt.tex("ability_frame", "back") != null:
			face.reveal(0.25 + 0.06 * i)  # each card flips over a beat after the last
		# What it does, in words, right under the card.
		var what := Label.new()
		what.text = Abilities.describe(id)
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		what.position = Vector2(start_x + i * 220 - 15, 252)
		what.custom_minimum_size = Vector2(200, 0)
		what.size = Vector2(200, 110)
		what.add_theme_font_size_override("font_size", 15)
		what.add_theme_color_override("font_color", main.OFFWHITE)
		if FontLib.label != null:
			what.add_theme_font_override("font", FontLib.label)
		_pick_box.add_child(what)
		holder.pressed.connect(func() -> void:
			_take_ability(id)
			_after_pick())
	_pick_tip.visible = false
	pick_layer.visible = true


## The ABILITIES screen, between tables only; `back` re-shows the
## screen it was opened from.
func open_abilities(back: Callable) -> void:
	if in_room:
		return  # the loadout is locked once you sit down
	abilities_screen.open(back)


## A new ability joins the collection. The very first one goes straight
## onto the smallest hand it fits, so it works from the next table on.
func _take_ability(id: String) -> void:
	abilities.append(id)
	main.stat_bump("abilities_taken")
	main.board._play_sound(Board.SFX_FLIP, 1.1, -8.0)
	if loadout.is_empty():
		var hand := Abilities.smallest_fit(id)
		if hand != "" and equip(abilities.size() - 1, hand):
			_announce_after_settle("%s IS ON YOUR %s" % [Abilities.ability_name(id).to_upper(),
					hand.to_upper()])
	main.tutor_show("abilities")
	if combine_partner(abilities.size() - 1) >= 0:
		# A twin: say once that two copies combine into a stronger one.
		main.tutor_show("combine")
		_announce_after_settle("TWO %s — COMBINE THEM ON THE ABILITIES SCREEN"
				% Abilities.ability_name(id).to_upper())


## After a pick (or a skip): any chest-owed ability rounds run first,
## then fate deals the next tables.
func _after_pick() -> void:
	if not pending_reward.is_empty() and int(pending_reward.get("chest_rounds", 0)) > 0:
		pending_reward["chest_rounds"] = int(pending_reward.chest_rounds) - 1
		pending_reward["round"] = int(pending_reward.get("round", 0)) + 1
		pending_reward["offers"] = _roll_ability_offer(int(pending_reward.room),
				int(pending_reward.round), "chest")
		_save_run()
		main.transition(_show_pick_now)
		return
	_in_chest_pick = false
	pending_reward = {}
	_save_run()
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
		val_l.text = "+$%d" % int(row[1])
		val_l.position = Vector2(310, 66 + i * 34)
		val_l.size = Vector2(90, 30)
		val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_l.add_theme_font_size_override("font_size", 17)
		val_l.add_theme_color_override("font_color", main.GOLD)
		_win_box.add_child(val_l)
	UiKit.hrule(_win_box, Vector2(20, 74 + rows * 34), 380)
	var total_l := Label.new()
	total_l.text = "WON  +$%d" % total
	total_l.position = Vector2(20, 86 + rows * 34)
	total_l.size = Vector2(280, 34)
	total_l.add_theme_font_size_override("font_size", 24)
	total_l.add_theme_color_override("font_color", main.GOLD)
	_win_box.add_child(total_l)
	var stack_l := Label.new()
	stack_l.text = "TRAIL CASH NOW  $%d" % trail_cash
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
	if _rng.randf() < SHOP_MOD_CHANCE:
		return {"data": {"rank": _rng.randi_range(2, 14), "suit": _rng.randi_range(0, 3),
				"cursed": false, "mod": _random_mod(),
				"finish": _roll_finish()},
				"base": SHOP_MOD_PRICE}
	if _rng.randf() < 0.5 and not deck.is_empty():
		var src: Dictionary = SeedRng.pick(_rng, deck)
		if not src.get("cursed", false):
			return {"data": {"rank": src.rank, "suit": src.suit,
					"cursed": false, "mod": ""}, "base": SHOP_DUP_PRICE}
	return {"data": {"rank": _rng.randi_range(2, 14), "suit": _rng.randi_range(0, 3),
			"cursed": false, "mod": ""}, "base": SHOP_CARD_PRICE}


## The Hermit's price for the next burn — it climbs with every use.
func _burn_price() -> int:
	return _price(SHOP_REMOVE_PRICE + SHOP_REMOVE_STEP * burns_used)


## A refused purchase gets a LOUD reason: error sting plus the message
## in red on both shop info lines (reset on the next re-render).
func _shop_refuse(msg: String) -> void:
	main.board._play_sound(Board.SFX_ERROR, 1.0, -8.0)
	_shop_info.text = msg
	_shop_info.add_theme_color_override("font_color", main.RED)
	_remove_info.text = msg
	_remove_info.add_theme_color_override("font_color", main.RED)


func _shop_chips_line() -> String:
	return "TRAIL CASH  $%d" % trail_cash


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
		_stream("shop")
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
		_shop_stock_abilities = []
		for id in _ability_shelf(int(_shop_merchant.get("abilities", 0))):
			_shop_stock_abilities.append({"id": id, "bought": false})
		_shop_burned_here = false
		_shop_stock_room = room_index
		if int(_shop_saved.get("room", -1)) == room_index:
			# Resumed at this merchant: what you bought stays sold.
			for pair in [["cards", _shop_stock], ["relics", _shop_stock_relics],
					["provisions", _shop_stock_provisions], ["abilities", _shop_stock_abilities]]:
				for i in _shop_saved.get(pair[0], []):
					if int(i) < (pair[1] as Array).size():
						pair[1][int(i)]["bought"] = true
			_shop_burned_here = bool(_shop_saved.get("burned", false))
		_shop_saved = {}
	_shop_title.text = _shop_merchant.name
	_shop_flavor.text = _shop_merchant.line
	_shop_info.text = _shop_chips_line()
	_shop_info.add_theme_color_override("font_color", main.GOLD)
	_shop_burn_btn.visible = _shop_merchant.forge
	_shop_burn_btn.text = "BURN A CARD — $%d" % _burn_price()
	_shop_burn_btn.tooltip_text = "Destroy one card from your deck. One burn per shop."
	_shop_burn_btn.disabled = _shop_burned_here
	if _shop_burned_here:
		_shop_burn_btn.text = "THE FORGE IS COLD"
		_shop_burn_btn.tooltip_text = "One burn per shop. Try the next merchant's forge."
	UiKit.fit_button_text(_shop_burn_btn, 20)
	_render_shop_relics()
	_render_shop_provisions()
	_render_shop_sell()
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
		var price_tag: Label = main._label(holder, "$%d" % price,
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
			if trail_cash < c:
				_shop_refuse("NOT ENOUGH CASH — that card costs $%d" % c)
				return
			trail_cash -= c
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
	_render_shop_abilities()
	_shop_tip.visible = false
	shop_layer.visible = true


## Ability cards on the middle shelf, after the playing cards.
func _render_shop_abilities() -> void:
	var first := _shop_stock.size()
	for i in _shop_stock_abilities.size():
		var slot: Dictionary = _shop_stock_abilities[i]
		var id := String(slot.id)
		var col := (first + i) % 5
		var row := (first + i) / 5
		var holder: Button = main._button(_shop_box, "",
				Vector2(265 + col * 220, row * 280), Vector2(170, 250))
		UiKit.style_shop_slot(holder)
		holder.tooltip_text = "%s (%s, %s, %d slot%s)\n%s" % [Abilities.display_name(id),
				Abilities.side_name(id), Abilities.RARITY_NAMES[Abilities.rarity(id)], Abilities.slots(id),
				"" if Abilities.slots(id) == 1 else "s", Abilities.describe(id)]
		var face := AbilityCard.new()
		face.ability_id = id
		face.scale = Vector2(0.95, 0.95)
		face.position = Vector2(85, 104)
		holder.add_child(face)
		var cost := _price(int(Abilities.PRICES[Abilities.rarity(id)]))
		var price_tag: Label = main._label(holder, "$%d" % cost, Vector2(0, 212), 18, main.GOLD)
		price_tag.size = Vector2(170, 30)
		price_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if slot.bought:
			holder.disabled = true
			price_tag.text = "SOLD"
		var pressed_slot := slot
		holder.pressed.connect(func() -> void:
			if pressed_slot.bought:
				return
			var c := _price(int(Abilities.PRICES[Abilities.rarity(String(pressed_slot.id))]))
			if trail_cash < c:
				_shop_refuse("NOT ENOUGH CASH — that ability costs $%d" % c)
				return
			trail_cash -= c
			pressed_slot.bought = true
			_take_ability(String(pressed_slot.id))
			_save_run()
			_show_shop())


## The merchant's ability shelf, rolled on the shop stream after
## everything else, with the region's rarity odds.
func _ability_shelf(n: int) -> Array:
	var out: Array = []
	var weights: Array = ABILITY_WEIGHTS["region%d" % clampi(room_index / REGION_SIZE + 1, 1, 3)]
	for i in n:
		var roll := _rng.randf() * float(weights[0] + weights[1] + weights[2] + weights[3])
		var r := 0
		while r < 3 and roll >= float(weights[r]):
			roll -= float(weights[r])
			r += 1
		var id := _ability_pick(Abilities.ids_of_rarity(r), out)
		if id == "":
			id = _ability_pick(Abilities.DEFS.keys(), out)
		if id != "":
			out.append(id)
	return out


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
		var price_l := _face_label(btn, "$%d" % cost, 116.0, 30.0, 18, main.GOLD)
		price_l.position.x = 96
		price_l.size.x = 292
		if slot.bought:
			btn.disabled = true
			price_l.text = "SOLD"
		elif relics.has(slot.id):
			btn.disabled = true
			price_l.text = "ALREADY OWNED"
		var pressed_slot := slot
		btn.pressed.connect(func() -> void:
			if pressed_slot.bought:
				return
			var c := _price(RELIC_PRICES[RELICS[pressed_slot.id].rarity])
			if trail_cash < c:
				_shop_refuse("NOT ENOUGH CASH — that relic costs $%d" % c)
				return
			trail_cash -= c
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
		var price_l := _face_label(btn, "$%d" % cost, 96.0, 24.0, 16, main.GOLD)
		price_l.position.x = 10
		price_l.size.x = 190
		if slot.bought:
			btn.disabled = true
			price_l.text = "SOLD"
		elif provisions.size() >= kit_size():
			btn.disabled = true
			price_l.text = "$%d — KIT FULL" % cost
		var pressed_slot := slot
		btn.pressed.connect(func() -> void:
			if pressed_slot.bought:
				return
			if provisions.size() >= kit_size():
				_shop_refuse("YOUR KIT IS FULL — it holds %d provisions" % kit_size())
				return
			var c := _price(int(PROVISIONS[pressed_slot.id].price))
			if trail_cash < c:
				_shop_refuse("NOT ENOUGH CASH — that costs $%d" % c)
				return
			trail_cash -= c
			pressed_slot.bought = true
			gain_provision(pressed_slot.id)
			main.board._play_sound(Board.SFX_COINS.pick_random(), 1.1, -8.0)
			_save_run()
			_show_shop())


## A [−] $N [+] stepper at row `y`; `step` gets true for up. Returns
## the amount label.
func _stepper(parent: Control, y: float, step: Callable) -> Label:
	var minus: Button = main._button(parent, "◀", Vector2(740, y - 4), Vector2(76, 48))
	minus.add_theme_font_size_override("font_size", 20)
	minus.pressed.connect(func() -> void:
		step.call(false))
	var amount := main._label(parent, "$0", Vector2(820, y), 24, main.OFFWHITE) as Label
	amount.size = Vector2(120, 40)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var plus: Button = main._button(parent, "▶", Vector2(944, y - 4), Vector2(76, 48))
	plus.add_theme_font_size_override("font_size", 20)
	plus.pressed.connect(func() -> void:
		step.call(true))
	return amount


## What a merchant pays for one of your provisions: half its price here.
func sell_price(id: String) -> int:
	return maxi(1, _price(int(PROVISIONS[id].price)) / 2)


## Your kit along the bottom of the shop, each provision with a SELL button.
func _render_shop_sell() -> void:
	for child in _shop_sell_box.get_children():
		child.queue_free()
	if provisions.is_empty():
		return
	var head := main._label(_shop_sell_box, "YOUR KIT", Vector2(0, 12), 18, main.GOLD) as Label
	head.size = Vector2(110, 30)
	for i in provisions.size():
		var id := String(provisions[i])
		var btn: Button = main._button(_shop_sell_box,
				"Sell %s  $%d" % [String(PROVISIONS[id].name), sell_price(id)],
				Vector2(120 + i * 290, 0), Vector2(280, 54))
		btn.add_theme_font_size_override("font_size", 16)
		UiKit.fit_button_text(btn, 16)
		btn.tooltip_text = provision_desc(id)
		var slot := i
		btn.pressed.connect(func() -> void:
			sell_provision(slot))


## Sells a provision from the kit back to the merchant for trail cash.
func sell_provision(slot: int) -> void:
	if slot < 0 or slot >= provisions.size():
		return
	var id := String(provisions[slot])
	var pay := sell_price(id)
	provisions.remove_at(slot)
	trail_cash += pay
	main.board._play_sound(Board.SFX_COINS.pick_random(), 0.95, -8.0)
	main._announce("SOLD THE %s  +$%d" % [String(PROVISIONS[id].name).to_upper(), pay])
	_save_run()
	if shop_layer.visible:
		_show_shop()


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
	_stream("camp")
	_camp_mode = ""
	main.tutor_show("campfire")
	_camp_hp_label.text = "HP  %d / %d" % [hp, max_hp()]
	if Ascension.camp_rest(ascension) != 5:
		_camp_hp_label.text += "   ·   rest heals %d" % Ascension.camp_rest(ascension)
	_camp_rest_btn.disabled = hp >= max_hp()
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
	hp = mini(max_hp(), hp + Ascension.camp_rest(ascension))
	main.stat_bump("campfire_rests")
	main._announce("RESTED BY THE FIRE — HP %d" % hp)
	_save_run()
	_leave_camp()


## The three brands the fire offers at this stop. Rolled from the stop's
## own stream, so backing out and coming back shows the same three.
func camp_tend_choices() -> Array:
	_stream("camp_tend", room_index)
	var out: Array = []
	for i in 3:
		var id := progress.pick("mod", MOD_WEIGHTS, out, _rng)
		if id == "":
			break
		out.append(id)
	return out


## TEND A CARD: pick one of three brands, then the card it goes on.
func _show_tend() -> void:
	camp_layer.visible = false
	_tend_scene.setup(character)
	for child in _tend_box.get_children():
		child.queue_free()
	var choices := camp_tend_choices()
	var x0: float = (main.VIEW.x - choices.size() * 340.0 + 40.0) / 2.0
	for i in choices.size():
		var id := String(choices[i])
		var btn: Button = main._button(_tend_box, "", Vector2(x0 + i * 340.0, 0), Vector2(300, 470))
		UiKit.style_shop_slot(btn)
		var pc := PlayingCard.new()
		pc.rank = 7
		pc.suit = 3
		pc.mod = id
		pc.boost_dir = Vector2i.UP
		pc.material = Themes.current_material()
		pc.scale = Vector2(1.6, 1.6)
		pc.position = Vector2(150, 150)
		btn.add_child(pc)
		var name_l := _face_label(btn, _mod_title(id).to_upper(), 290.0, 34.0, 24, main.GOLD)
		name_l.position.x = 10
		name_l.size.x = 280
		var desc_l := _wrap_label(btn, mod_desc(id), Rect2(20, 334, 260, 120), 16, main.OFFWHITE)
		desc_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.pressed.connect(func() -> void:
			_camp_tend_mod = id
			main.board._play_sound(Board.SFX_FLIP, 1.0, -8.0)
			tend_layer.visible = false
			_camp_open_deck("tend"))
	tend_layer.visible = true


func _mod_title(id: String) -> String:
	var r := Progression.row("mod", id)
	return String(r.get("name", id.capitalize()))


func mod_desc(id: String) -> String:
	var d := progress.pdesc("mod", id)
	return d if d != "" else String(CATALOG_DESCS.get("mod:" + id, ""))


## TEND or CAST OFF both ride the deck viewer, in a campfire mode.
func _camp_open_deck(mode: String) -> void:
	camp_layer.visible = false
	_camp_mode = mode
	_deck_view_burn = false
	_remove_info.text = "Pick a plain card for the %s brand." % _mod_title(_camp_tend_mod) \
			if mode == "tend" else "Pick a card to throw in the fire. It's gone for good."
	_remove_info.add_theme_color_override("font_color", main.OFFWHITE)
	_populate_deck_view()


func _camp_pick(idx: int) -> void:
	if idx >= deck.size():
		return
	var d: Dictionary = deck[idx]
	if _camp_mode == "tend":
		if d.get("cursed", false):
			_remove_info.text = "CURSED CARDS CAN'T BE TENDED — cast it off instead."
			_remove_info.add_theme_color_override("font_color", main.RED)
			return
		if String(d.get("mod", "")) != "" or PlayingCard.finish_of(d) != "":
			_remove_info.text = "ALREADY ENHANCED — pick a plain card."
			_remove_info.add_theme_color_override("font_color", main.RED)
			return
		var mod := _camp_tend_mod if _camp_tend_mod != "" else _random_mod()
		_camp_tend_mod = ""
		d["mod"] = mod
		main.stat_bump("campfire_tends")
		main._announce("BRANDED BY THE FIRE — %s" % _mod_title(mod).to_upper())
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
	_remove_info.text = "Pick a card to burn for $%d (one per shop)." % _burn_price()
	_remove_info.add_theme_color_override("font_color", main.OFFWHITE)
	_populate_deck_view()


## Read-only deck browser, reachable from the tarot screen.
func _show_deck() -> void:
	main.transition(_show_deck_now)


func _show_deck_now() -> void:
	_hide_all()
	_deck_view_burn = false
	_remove_info.text = "Your deck: %d cards. Hover over a card to see what it does." % deck.size()
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
			if trail_cash < _burn_price():
				_shop_refuse("NOT ENOUGH CASH — the burn costs $%d" % _burn_price())
				return
			trail_cash -= _burn_price()
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
	if d.get("cursed", false):
		return "A CURSED CARD\nIt has no rank or suit. It can't be played and it blocks chains, and it's only dealt once a table. A Bumper or the wind can push it off the board. Burn it at a forge or cast it off at a campfire to lose it for good."
	var rank := int(d.rank)
	var rank_names := {11: "JACK", 12: "QUEEN", 13: "KING", 14: "ACE"}
	var text := "%s OF %s\nPip value  %d\n\n" % [rank_names.get(rank, str(rank)),
			String(PlayingCard.SUIT_NAMES[int(d.suit)]).to_upper(), rank]
	if d.get("cursed", false):
		return text + "CURSED\nDead weight: it can't be played and it blocks chains. Burn it at a shop."
	match String(d.get("mod", "")):
		"chip":
			var lv := int(d.get("chip_lv", 0))
			text += "CASH\nPays $%d in trail cash when played. It gets better with use: every time it scores, it pays $%d more for the rest of the ride.%s" % [
					main.board.chip_bonus * (1 + lv), main.board.chip_bonus,
					"" if lv == 0 else "\nScored %d time%s so far." % [lv,
					"" if lv == 1 else "s"]]
		"mult":
			text += "MULT\nMultiplies the whole hand's score ×%.1f. Stacks with other mult cards." % main.board.mult_factor
		"gold":
			text += "GOLD\nPays $%d in trail cash when played." % main.board.gold_pay
		"plus":
			text += "PLUS\nWhen you clear it, the card its arrow points at goes up one rank. The arrow turns a quarter turn every hand, so time it right. Raising an ACE turns it into THE JOKER: wild for good, and it doubles every hand it scores in."
		"minus":
			text += "MINUS\nWhen you clear it, the card its arrow points at drops one rank. A 2 that drops is DESTROYED without scoring. The arrow turns a quarter turn every hand, so time it right."
		"bumper":
			text += "BUMPER\nWhen you clear this card, the whole line of cards beside it slides one step the way the arrow points. A card pushed off the edge is lost. The arrow turns after every hand."
		"wild":
			text += "WILD\nCounts as ANY rank and suit, whichever makes the best hand. The rarest card on the trail."
		_:
			text += "No enhancement.\nJust a plain card."
	var fin := PlayingCard.finish_of(d)
	if fin != "":
		text += "\n\n%s\n%s" % [PlayingCard.FINISHES[fin].name, PlayingCard.FINISHES[fin].desc]
	return text


# --- Flow: run end --------------------------------------------------------

func _end_run(title: String, body: String, payout: int, cause := "") -> void:
	_hide_all()
	run_active = false
	_apply_loadout()  # unlocks and EXP read the real profile again
	_room_save = {}
	main.game_started = false
	if title in ["BUSTED OUT", "BLINDED OUT"]:
		main.stat_bump("trail_busts")
	_grant_run_exp(title == "TRAIL COMPLETE")
	_record_seed_score(title)
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
	_end_label.text = "%s\n\n%s\n\nTotal run score: %d\nBest hand: %s\nOutlaws caught: %d\nCash: $%d\nSeed: %s" \
			% [title, body, main.score, best, outlaws_caught, cash, SeedRng.pretty(run_seed)]
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


## The board this ride's score belongs to (seeded rides only).
func seed_board_key() -> String:
	if run_daily:
		return SeedBook.key("daily", run_seed, character)
	return SeedBook.key("trail", run_seed, SeedBook.trail_variant(character, ascension))


## A seeded ride's score goes on its seed's board (a daily practice
## ride doesn't count).
func _record_seed_score(title: String) -> void:
	if _seed_recorded_uid == run_uid and run_uid != "":
		return  # this ride's score is already on the board
	_seed_result = {}
	if not standard_loadout:
		return
	_seed_recorded_uid = run_uid
	var k := seed_board_key()
	if run_practice:
		_seed_result = {"key": k, "practice": true, "best": main.seed_book.best(k)}
		return
	var reached := ROOMS_TOTAL if title == "TRAIL COMPLETE" else mini(room_index + 1, ROOMS_TOTAL)
	var pb: bool = main.seed_book.record(k, main.score,
			{"outcome": title, "tables": reached, "rider": character, "ascension": ascension})
	_seed_result = {"key": k, "pb": pb, "best": main.seed_book.best(k), "practice": false,
			"tables": reached}
	main.seed_score_recorded(k, main.score, character, ascension, reached)


## The seed line on the last page.
func seed_line() -> String:
	if _seed_result.is_empty():
		return "" if standard_loadout else "Played on your own gear. Replay as a SEEDED RIDE to get on the board."
	if bool(_seed_result.get("practice", false)):
		return "Practice — you've already played today's scored daily ride."
	if bool(_seed_result.get("pb", false)):
		return "NEW BEST ON THIS SEED!"
	return "Your best on this seed: %d" % int(_seed_result.get("best", 0))


## An Outfitter level as this ride sees it: the base on a seeded ride.
func ride_lv(which: String) -> int:
	match which:
		"sleeve":
			return 2 if standard_loadout else sleeve_rank
		"laser":
			return 0 if standard_loadout else laser_level
		"watch":
			return 0 if standard_loadout else watch_level
		"sleight":
			return 0 if standard_loadout else sleight_level
		"bankroll":
			return 0 if standard_loadout else meta_bankroll
		"provisions":
			return 0 if standard_loadout else meta_provisions
	return 0


## Tells Progression whether this ride plays the standard loadout.
func _apply_loadout() -> void:
	progress.standard = standard_loadout and run_active


## Points _rng at the stream for `purpose` at this stop.
func _stream(purpose: String, a := -1, b := 0) -> RandomNumberGenerator:
	_rng = SeedRng.stream(run_seed, purpose, room_index if a < 0 else a, b)
	return _rng


## A fresh id for a ride — the guard against paying its EXP twice.
func _mint_run_uid() -> String:
	return "%d-%d" % [int(Time.get_unix_time_from_system() * 1000.0), randi()]


## Pays the ride that is ending its EXP (once — a ride whose id was
## already paid gets the same report back) along with any level purse.
func _grant_run_exp(complete: bool) -> Dictionary:
	if run_uid != "" and run_uid == progress.last_run_uid:
		return _last_grant
	var reached := ROOMS_TOTAL if complete else mini(room_index + 1, ROOMS_TOTAL)
	_last_grant = _credit_ride(main.score, reached, run_bosses, ascension,
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
			int(cf.get_value("run", "bosses", 0)), int(cf.get_value("run", "ascension", 0)),
			false, uid if uid != "" else _mint_run_uid())
	_clear_run_save()
	var text := "UNFINISHED RIDE CREDITED  ·  +%d EXP" % int(grant.exp_gain)
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
					if ascension >= Ascension.MAX \
					else "King Cobra folds. The trail pays out $%d." % payout
	var stops: Array = []
	for i in ROOMS_TOTAL:
		stops.append(String(trail_log[i]) if i < trail_log.size() else "")
	return {
		"kind": kind, "title": title, "epitaph": epitaph, "cause": cause,
		"rider": character, "score": main.score,
		"best_name": best_hand_name, "best_score": best_hand_score,
		"outlaws": outlaws_caught, "reached": reached, "total": ROOMS_TOTAL,
		"cash": cash, "stake": "Ascension %d" % ascension, "seed": run_seed,
		"trail_cash": trail_cash, "cash_brought": cash_brought, "bet": bet.duplicate(),
		"seed_line": seed_line(), "seeded": standard_loadout,
		"relics": relics.duplicate(), "stops": stops,
		"relic_descs": _relic_descs(),
		"spent": ["second_wind"] if _second_wind_used else [],
		"contracts": _ride_contracts.duplicate(),
		"bosses": BOSS_ROOMS, "region_size": REGION_SIZE, "camp_slot": STOP_LAYOUT.find("camp"),
		"shop_slots": _layout_slots("shop"),
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
	# The Ascension dial, in one box so a saved ride can push it down.
	_asc_box = Control.new()
	_asc_box.size = Vector2(1920, 1080)
	_asc_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buyin_layer.add_child(_asc_box)
	_asc_prev = main._button(_asc_box, "◀", Vector2(660, 300), Vector2(80, 76))
	_asc_prev.add_theme_font_size_override("font_size", 28)
	_asc_prev.pressed.connect(func() -> void:
		_step_ascension(-1))
	_asc_next = main._button(_asc_box, "▶", Vector2(1180, 300), Vector2(80, 76))
	_asc_next.add_theme_font_size_override("font_size", 28)
	_asc_next.pressed.connect(func() -> void:
		_step_ascension(1))
	_asc_label = main._label(_asc_box, "", Vector2(740, 304), 40, main.GOLD)
	_asc_label.size = Vector2(440, 50)
	_asc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_asc_sub = main._label(_asc_box, "", Vector2(740, 352), 16, main.DIM)
	_asc_sub.size = Vector2(440, 24)
	_asc_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.plate(_asc_box, Rect2(560, 400, 800, 250))
	_asc_rule = _wrap_label(_asc_box, "", Rect2(600, 420, 720, 64), 22, main.GOLD)
	_asc_rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_asc_rest = _wrap_label(_asc_box, "", Rect2(600, 490, 720, 100), 16, main.OFFWHITE)
	_asc_rest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_asc_reward = main._label(_asc_box, "", Vector2(600, 604), 17, main.GOLD)
	_asc_reward.size = Vector2(720, 26)
	_asc_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The wager rows sit under the dial, in its box so they move with it.
	_wager_box = Control.new()
	_wager_box.size = Vector2(1920, 1080)
	_wager_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_asc_box.add_child(_wager_box)
	var bring_t := main._label(_wager_box, "BRING CASH", Vector2(560, 672), 22, main.GOLD) as Label
	bring_t.size = Vector2(200, 40)
	_bring_label = _stepper(_wager_box, 672, func(up: bool) -> void:
		buyin_bring = maxi(0, _wager_step(buyin_bring, up))
		_render_wager())
	var bet_t := main._label(_wager_box, "BET ON", Vector2(560, 730), 22, main.GOLD) as Label
	bet_t.size = Vector2(200, 40)
	var targets := [["", "NO BET"], ["jack", "THE JACK"], ["queen", "THE QUEEN"], ["king", "KING COBRA"]]
	for t in targets.size():
		var key: String = targets[t][0]
		var tb: Button = main._button(_wager_box, String(targets[t][1]),
				Vector2(740 + t * 156, 726), Vector2(150, 48))
		tb.toggle_mode = true
		tb.add_theme_font_size_override("font_size", 16)
		tb.pressed.connect(func() -> void:
			buyin_target = key
			if key != "" and buyin_stake <= 0:
				buyin_stake = 10
			main.board._play_sound(Board.SFX_FLIP, 1.0, -10.0)
			_render_wager())
		_bet_target_btns[key] = tb
	var stake_t := main._label(_wager_box, "STAKE", Vector2(560, 788), 22, main.GOLD) as Label
	stake_t.size = Vector2(200, 40)
	_stake_label = _stepper(_wager_box, 788, func(up: bool) -> void:
		buyin_stake = maxi(0, _wager_step(buyin_stake, up))
		_render_wager())
	_bet_pays_label = main._label(_wager_box, "", Vector2(1040, 792), 18, main.OFFWHITE)
	_bet_pays_label.size = Vector2(330, 32)
	_wager_note = main._label(_asc_box, "", Vector2(460, 836), 15, main.DIM)
	_wager_note.size = Vector2(1000, 22)
	_wager_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buyin_saddle_btn = main._button(buyin_layer, "SADDLE UP", Vector2(810, 860), Vector2(300, 66), true)
	_buyin_saddle_btn.add_theme_font_size_override("font_size", 26)
	_buyin_saddle_btn.pressed.connect(func() -> void:
		_start_run(_asc_pick))
	_buyin_resume_btn = main._button(buyin_layer, "RESUME YOUR RIDE", Vector2(660, 300), Vector2(600, 70), true)
	_buyin_new_label = _center(buyin_layer, "or start a new ride", 418, 20, main.DIM)
	_buyin_resume_btn.add_theme_font_size_override("font_size", 24)
	_buyin_resume_btn.pressed.connect(_resume_run)
	# With a ride saved, THE TRAIL lands here; a fresh ride can still
	# saddle someone new.
	_buyin_rider_btn = main._button(buyin_layer, "NEW RIDER", Vector2(970, 790), Vector2(290, 66))
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
				Vector2(411 + i * 158, 278), Vector2(150, 50))
		tb.focus_mode = Control.FOCUS_NONE
		tb.pressed.connect(func() -> void:
			_set_up_tab(key))
		_up_tab_btns[key] = tb
		var pip: Label = main._label(upgrades_layer, "NEW", Vector2(411 + i * 158 + 100, 262), 14, main.GOLD)
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
	_center(camp_layer, "The fire's burning low. There's time for one thing before you ride on.", 200, 22, main.DIM)
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
						_show_tend())
				2:
					tb.pressed.connect(func() -> void:
						_camp_open_deck("burn"))
		var camp_leave: Button = main._button(camp_layer, "BACK ON THE TRAIL",
				Vector2(1110, 745), Vector2(590, 86))
		camp_leave.add_theme_font_size_override("font_size", 28)
		camp_leave.pressed.connect(_leave_camp)
	else:
		var camp_opts := [
			["REST", "Sleep off the road.\nRecover %d HP." % Ascension.camp_rest(0)],
			["TEND A CARD", "The fire offers three brands.\nPick one, then the card it goes on."],
			["CAST ONE OFF", "Throw a card in the fire.\nIt's gone from your deck for good."],
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
						_show_tend())
				2:
					cb.pressed.connect(func() -> void:
						_camp_open_deck("burn"))
		var camp_leave: Button = main._button(camp_layer, "BACK ON THE TRAIL",
				Vector2(760, 740), Vector2(400, 60))
		camp_leave.add_theme_font_size_override("font_size", 20)
		camp_leave.pressed.connect(_leave_camp)

	tend_layer = _layer()
	_tend_scene = CampScene.new()
	tend_layer.add_child(_tend_scene)
	_screen_title(tend_layer, "TEND A CARD")
	_center(tend_layer, "The fire offers three brands. Pick one, then pick the plain card it goes on.", 200, 22, main.DIM)
	_tend_box = Control.new()
	_tend_box.position = Vector2(0, 290)
	tend_layer.add_child(_tend_box)
	_back_button(tend_layer, func() -> void:
		tend_layer.visible = false
		_show_camp(), "BACK")

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
	_center(tarot_layer, "You can't cash out partway. Reach the end of the trail, or play GOLD cards to earn cash along the way.", 850, 18, main.DIM)
	_back_button(tarot_layer, back_to_menu, "MENU")
	var deck_btn: Button = main._button(tarot_layer, "VIEW DECK", Vector2(1660, 970), Vector2(200, 54))
	deck_btn.add_theme_font_size_override("font_size", 20)
	deck_btn.pressed.connect(_show_deck)
	_tarot_ab_btn = main._button(tarot_layer, "ABILITIES", Vector2(1440, 970), Vector2(200, 54))
	_tarot_ab_btn.add_theme_font_size_override("font_size", 20)
	_tarot_ab_btn.pressed.connect(func() -> void:
		open_abilities(_show_tarot_now))

	bet_layer = _layer()
	_screen_title(bet_layer, "THE TABLE")
	_bet_chips = CenterContainer.new()
	_bet_chips.position = Vector2(0, 812)
	_bet_chips.size = Vector2(main.VIEW.x, 36)
	_bet_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bet_layer.add_child(_bet_chips)
	_bet_twists = main._label(bet_layer, "", Vector2(310, 856), 19, main.GOLD)
	_bet_twists.size = Vector2(1300, 120)
	_bet_twists.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bet_twists.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bet_info = _center(bet_layer, "", 240, 26, main.OFFWHITE)
	_bet_stake_label = _center(bet_layer, "", 560, 40, main.GOLD)
	_bet_deal_btn = main._button(bet_layer, "DEAL ME IN", Vector2(760, 720), Vector2(400, 70), true)
	_bet_deal_btn.add_theme_font_size_override("font_size", 28)
	_bet_deal_btn.pressed.connect(_confirm_bet)
	var bet_back := func() -> void:
		bet_layer.visible = false
		_show_tarot()
	_bet_back_btn = _back_button(bet_layer, bet_back, "BACK")

	pick_layer = _layer()
	_pick_title = _center(pick_layer, "TABLE CLEARED", 100, 64, main.GOLD)
	_pick_sub = _center(pick_layer, "Pick an ability to keep, or take none.", 240, 22, main.DIM)
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
	var pick_ab: Button = main._button(pick_layer, "ABILITIES", Vector2(1660, 970), Vector2(200, 54))
	pick_ab.add_theme_font_size_override("font_size", 20)
	pick_ab.tooltip_text = "See your ability cards and which hands they're on."
	pick_ab.pressed.connect(func() -> void:
		open_abilities(_show_pick_now))
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
	_shop_sell_box = Control.new()
	_shop_sell_box.position = Vector2(300, 970)
	shop_layer.add_child(_shop_sell_box)
	# Hover tooltip for the shelves, floated beside the hovered card.
	_shop_tip = _make_stat_tip(shop_layer)
	_shop_tip_label = _shop_tip.get_child(0) as Label
	_shop_burn_btn = main._button(shop_layer, "", Vector2(555, 850), Vector2(380, 56))
	_shop_burn_btn.clip_text = true
	_shop_burn_btn.add_theme_font_size_override("font_size", 20)
	_shop_burn_btn.pressed.connect(_show_remove)
	var shop_ab: Button = main._button(shop_layer, "ABILITIES", Vector2(60, 970), Vector2(200, 54))
	shop_ab.add_theme_font_size_override("font_size", 20)
	shop_ab.tooltip_text = "See your ability cards and which hands they're on."
	shop_ab.pressed.connect(func() -> void:
		open_abilities(_show_shop))
	var leave: Button = main._button(shop_layer, "BACK ON THE TRAIL", Vector2(985, 850), Vector2(380, 56))
	leave.add_theme_font_size_override("font_size", 20)
	leave.pressed.connect(_leave_shop)

	relic_layer = _layer()
	_screen_title(relic_layer, "THE STRONGBOX")
	_relic_sub = _center(relic_layer, "The stagecoach job pays in more than cash.", 210, 22, main.DIM)
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
		if not pending_reward.is_empty():
			pending_reward["relic"] = ""
			_save_run()
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

	abilities_screen = AbilitiesScreen.new()
	main.ui_root.add_child(abilities_screen)
	abilities_screen.setup(self)

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
	_gameover_scene.seed_action.connect(func(kind: String) -> void:
		if kind == "copy":
			DisplayServer.clipboard_set(SeedRng.pretty(run_seed))
			main._announce("SEED COPIED")
		else:
			_hide_all()
			main.open_seeds("trail", run_seed, character, ascension))


func _layer() -> ColorRect:
	var l := ColorRect.new()
	l.color = main.BG
	l.size = main.VIEW
	l.visible = false
	main.ui_root.add_child(l)
	return l


func _hide_all() -> void:
	for l in [select_layer, buyin_layer, upgrades_layer, tarot_layer, bet_layer,
			pick_layer, shop_layer, camp_layer, tend_layer, remove_layer, relic_layer,
			end_layer, abilities_screen]:
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
