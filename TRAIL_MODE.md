# TRAIL MODE — Design Doc

Status: **v1 skeleton SHIPPED** (scripts/trail.gd): buy-in tables,
tarot room draws with risk tiers (Sun/Wheel/Tower), forced stakes by
difficulty, cash-out, fail-forward with Cursed scars,
1-of-3 card picks with duplicate weighting, Hermit shops (buy/burn),
bankruptcy/complete/cash-out endings, run + cash persistence.
Still to build: bosses (court + Dealer duel), room-rule variety
(timed / suit-locked / hand-locked / pressure), card modifier families,
the Outfitter (permanent upgrades). This doc accretes decisions;
open threads at the bottom.

## Pitch

A Slay the Spire / Balatro-style run mode built on **betting**. Buy in
to a table, get a chip stack, and ride a trail of rooms — each a board
challenge revealed as a tarot card. Before every room you **wager
chips on yourself**: clear the room and the bet pays out at odds; fail
and the stake is gone. Chips are simultaneously your health, your
wager, and your shop wallet. **Ride to the END of the trail** to bank chips
as permanent cash — or push deeper for bigger blinds and bigger
payouts. Bankruptcy ends the run. Cash buys premium buy-ins and
permanent upgrades between runs.

Theme: a card sharp working saloons along a trail; tarot deals your
fate, poker pays your way. Western/saloon flavor colors room names,
bosses, regions.

## The betting core (the heart of the mode)

- **Buy-in tiers** — premium tables are **harder AND richer**
  (Balatro-stakes style): bigger starting stack and better cash-out
  conversion, but difficulty modifiers stack on (steeper targets,
  faster blind escalation, meaner cursed-card injections, pricier
  shops — exact modifier list TBD). Names/numbers draft:
  | Table | Cost | Starting chips | Cash-out rate | Difficulty |
  | --- | --- | --- | --- | --- |
  | Penny Ante | Free | 100 | ×1 | baseline |
  | Table Stakes | $250 cash | 250 | ×1.5 | steeper targets/blinds, +hazards |
  | High Roller | $1000 cash | 500 | ×2.5 | steepest, most hazards, Dealer finale |
  **Boss rooms are ALL-IN**: no bet choice — the whole stack rides at
  3:1. Shops never restock within a room, and the burn service costs
  more with every use (once per shop).
- **Per-room wager — ante, bet, and promised hands**: every room
  costs its **ante** (25 chips at the first table, climbing with depth
  and table stakes — the house keeps it, win or lose). Then you **bet
  chips on yourself** (minimum one ante, stepped in ante increments).
  **Hands are free — they're what you're betting ON**: effective odds
  = base odds × the tier's reference hands ÷ the hands you take
  (1–12). Promise a 4-hand clear on a 7-hand Dangerous table and 2:1
  becomes ×3.5; take 12 lazy hands and the odds shrink below base.
  Clearing pays bet + bet × effective odds; failing loses ante and
  bet. Timed tables sell MINUTES instead of hands — hands are
  unlimited there, and promising fewer minutes fattens the odds the
  same way. Bosses ignore all this: ALL IN at base odds, fixed hand
  budget.
- **Odds by room**: Steady 1:1 · Risky/Treasure/soft-Purge 3:2 ·
  Dangerous/Heist/hard-Purge/Called-Hands 2:1 · Royal Hunt 5:1 ·
  Boss 3:1.
- **Blinds escalate**: the blind rises each room (poker blinds
  structure) — late trail, you can't limp. Can't cover a table's
  **cheapest seat** (ante + minimum bet) = **BLINDED OUT**: the run is
  over and the house keeps everything — chips only turn to cash at
  the end of the trail.
- **No cashing out mid-ride**: chips become permanent $cash ONLY by
  finishing all 21 tables (premium multiplier + completion purse) —
  or $1 at a time by playing GOLD cards during the run (banked
  instantly, and kept even if the run later busts). All-or-nothing:
  the ride itself is the bet.
- Shops charge the same chips you bet with — every purchase shrinks the
  stack that keeps you alive. That tension is the design.

## Run structure

- A **trail** of rooms, escalating; the final room is the Dealer
  (see Bosses). Clearing it wins the run.
- Draft shape: ~12–15 rooms, 3 regions ("towns"?), each region capped
  by a court-card boss, min bet rising per region.
- Run length is variable BY DESIGN: cashing out early is a short run;
  riding to the Dealer is the long one (~20–60 min naturally).
- Every room clear: **pick 1 of 3 cards** to add to the deck
  (skippable); removal exists in shops to manage bloat.

## The trail draw (room selection)

At each junction, fate deals **three face-up room cards** — each is
the next room, showing its type, rules, odds, and ante. A fourth,
face-down option: **LUCK OF THE DRAW** — a random different room,
sweetened with a small chip kicker for trusting the cards.

Rooms are named for poker and the West (the tarot naming retired):
| Card | Room |
| --- | --- |
| LIMIT TABLE | Normal, steady tier 1:1 (shipped) |
| POT LIMIT | Normal, risky tier 3:2 (shipped) |
| NO LIMIT | Normal, dangerous tier 2:1 (shipped) |
| GENERAL STORE | Shop (shipped) |
| POWDER KEG | Purge room: bombs (shipped) |
| WILDFIRE | Purge room: fire (shipped) |
| DUST STORM | Purge room: wind (shipped) |
| FLASH FLOOD | Purge room: water (shipped) |
| GOLD MINE | Board of solid stone; break N to clear, gold cards turn up in the rubble (shipped) |
| BANK JOB | Heist room (crack the safe — shipped) |
| STAGECOACH HAUL | Treasure room (key + chest pairs, 2–4 by depth — shipped) |
| DEALER'S CALL | Called Hands: play the demanded hands (shipped) |
| ROYAL HUNT | Make a Royal Flush, 5:1 (shipped, rare) |
| HIGH NOON | Timed table: score the target before the clock dies (shipped) |
| TEXAS HOLD'EM | Variant room (Stage C — designed below) |
| CRAZY 8s | Variant room (Stage C — designed below) |
| BLACKJACK | Variant room (Stage C — designed below) |
| SHOWDOWN | The Outlaw duel (Stage C — designed below) |

## Room types

| Room | Rule | Notes |
| --- | --- | --- |
| Normal | Score target within the hands you bought | The baseline |
| Purge | Board seeded with 3–6 of ONE hazard kind (bomb/fire/wind/water); remove them all (no score target) | Shipped. Fire that spreads must be put out too; a gust that blows hazards off the board counts; a fire burning itself out counts. No ambient extras — the hazards ARE the room |
| Gold Mine | EVERY card is stone; break N stones (3 + region) to clear | Shipped. Each destroyed stone has a 35% chance to leave a GOLD card in the refill (plays for $1 real cash, room-local) |
| Called Hands | Play the exact demanded hands (e.g. 2× Flush + 1× Pair; scales per region) | Shipped (JUDGEMENT). Exact composition only — a Full House is not three Pairs |
| Royal Hunt | Make one Royal Flush | Shipped (THE WORLD): rare, region 2+, odds 5:1 |
| Timed | Score target before the clock; hands unlimited | Shipped (THE HANGED MAN, 2:1 base). The promise dial is MINUTES (1–6, reference 4→2 by region): fewer minutes promised = fatter odds. Hazards still tick per hand |
| Tight Hands | Target with very few hands (4–6) | Efficiency puzzle |
| Suit Locked | Only 1–2 suits score | e.g. "red room": hearts/diamonds only |
| Hand Locked | Only listed hand types score | e.g. "pairs are worthless tonight" |
| Pressure | The arcade drain bar, one room's worth | Reuses meter machinery |
| Shop | Spend chips: cards, modifiers, card **removal** | No challenge, no reward |
| Elite | Harder target + a room modifier stacked | Better card choices + more chips |
| Event? | Mystery choice (risk/reward text event) | Post-v1 candidate |
| Boss | Rule-warping challenge capping a region | See Bosses |

## NEXT — Stage B: the poker economy (user-designed, queued)

- **Score rooms go on the clock**: plain LIMIT/POT LIMIT/NO LIMIT
  tables become TIME-limited (unlimited hands), merging HIGH NOON into
  the standard tables. CONDITION rooms (purges, mine, heist, treasure,
  called hands, variants, Outlaw) stay HAND-limited.
- **CALL / RAISE / ALL IN** replaces the free bet + promise dials:
  each room has a SET bet amount. CALL = play the room as offered.
  RAISE = bigger bet AND the room gains an extra complication (a
  second modifier — extra hazards, a mixed second mode, tighter
  budget) for better odds. ALL IN = the raise, betting everything.
- **Pickup cards**: "+30s EXTRA TIME" and "+1 EXTRA HAND" cards can
  be dealt ambiently (~6% per refill) in rooms of the matching limit
  type; clear them in any scoring hand to collect.

## NEXT — Stage C: variant rooms (user-designed, queued)

- **TEXAS HOLD'EM**: 5 community cards displayed beside the board and
  PERSIST all room. Select exactly 2 adjacent board cards as hole
  cards; the hand is the best 5 of the 7 (kickers allowed here — it's
  hold'em). A RE-DEAL card has a chance to be dealt to the board;
  scoring it refreshes the community 5.
- **CRAZY 8s**: every 8 on the board is WILD (counts as any rank and
  suit). Otherwise a normal score room.
- **BLACKJACK**: poker hands OFF; you play against the house. Each
  round the dealer draws a total (17–21); select a chain whose PIP SUM
  (faces 10, ace 11/1) beats the dealer without exceeding 21 to win
  the round. Bust = rejected. Beat the dealer N times to clear.
- **SHOWDOWN — the Outlaw**: an Outlaw portrait with HP beside the
  board. YOUR bullet cards and HIS bullet cards spawn among the deals.
  Clear YOUR bullets in scoring hands → shots that damage him. Clear
  HIS bullets → he shoots YOU. He also shoots if your scored hand is
  below a posted threshold. Shots cost DUEL HP (separate, ~3 grit for
  the room; 0 = room failed). Kill him to clear — a puzzle fight where
  you'll trade some blood.

Technical wrinkle flagged early: constraint rooms (Suit/Hand Locked)
change what counts as a playable hand, so `Board.has_playable_hand()`
must respect the active room constraints or dead-board
detection/reshuffles will lie.

## Deckbuilding

- Start: standard 52. The deck IS the draw pile for the board (board
  shows 25 at once; deck composition directly shapes board texture).
- **Adding duplicates is a real archetype**: a 5th+ copy of a rank turns
  Five of a Kind / Flushed Five from luck into strategy. Suit-stacking
  makes flush chains dense. Rank-thinning (via shop removal) makes
  straights and pairs consistent. Three broad build archetypes fall out
  for free: *Stacker* (duplicates), *Monochrome* (suit density),
  *Slim* (thin deck consistency).
- Card choices after rooms: mix of plain cards (including exact
  duplicates of cards you own — the Flushed Five enabler) and modified
  cards (below). Skipping is always allowed.
- Shops sell removal ("burn a card") — pricier than buying. Deck size
  has no cap; bloat is self-punishing.

## Hazard cards (SHIPPED — reworked after playtest round 1)

Hazards are AMBIENT: the tarot decides only a room's GOAL (target /
heist / treasure / boss), while hazards seed randomly into EVERY play
room — bosses included — with no warning and no odds compensation.
Chance = 20% + 4%/room + 15%/buy-in tier (cap 95%); count = 1 + 1 per
region (High Roller adds another half the time, cap 4), with mixed
hazard types coexisting. The old hazard tarot cards (DEATH etc.) are
retired. Hazards are states on normal rank/suit cards, one per card;
refill-dealt cards are never hazarded; ticks happen only on scoring
hands, after the board settles.

| Hazard | Tarot | Rule | Counterplay |
| --- | --- | --- | --- |
| Bomb | DEATH | Fuse (5) drops per scoring hand; 0 = room LOST (fail-forward) | Include it in any scoring hand to defuse |
| Fire | THE DEVIL | Every hand it SPREADS to one adjacent card that isn't burning, and its rank ticks −1; below 2 it burns up (unscored) | Play it (scores at current rank) to extinguish — every hand you wait, the fire claims another card |
| Wind | THE CHARIOT | When played, every card from its cell to the edge in its arrow direction is blown off (unscored). Safes are too heavy to move | It's a tool as much as a hazard — aim it at junk, or at a BOSS: blowing one off the table counts as the kill (a gusted tail segment wounds the cobra) |
| Stone | STRENGTH | Must be in 3 scoring hands; scores each time; cracks visibly; 3rd use pops it | Chip away; it squats on its cell meanwhile |
| Water | — | It DRIPS: every scoring hand, an uncleared water card soaks one random orthogonal neighbor — that card's rank and suit are WASHED AWAY, hidden until played. It still is what it was; you just have to remember | Play the water card to stop the leak (clearing it is a clean disposal, like every other hazard) |

Design calls: fire spreads 4-way (8-way wipes 5×5 boards); spread skips
hazarded/cursed cards; hazards don't persist in the run save.
Water calls: washed cards play normally (the evaluator knows the truth —
the player doesn't); while a washed card is selected the preview shows
"???" and the valid-hand green border is suppressed so you can't probe
for free; the splash only lands on plain cards (never hazarded, cursed,
objective, or already-washed ones); washing is room-local.

## Objective cards (SHIPPED)

**The Safe (heist).** A safe card sits on the board showing a 4-digit
combination (ranks 2–9, duplicates possible), e.g. **3·9·5·2**. Crack
it by chaining the combo cards IN PRINTED ORDER (any suits, normal
adjacency) and ending the chain on the safe itself — no poker hand
required. Cracking costs a hand like any play and scores no points.
- **Heist room (THE MOON, odds 2.0)**: the safe IS the goal — crack it
  within the hand budget to clear the room. No score target.
- **Ambient safes**: random chance in normal rooms — cracking pays
  bonus chips. Optional loot; the score target still rules the room.
- The safe acts as a wall for normal chains (like cursed); it only
  accepts selection as the final pick of a matching combo chain.

**Key + Chest (treasure).** A key card and a chest card (both normal
rank/suit cards with overlays) are on the board. Make a VALID poker
hand containing BOTH — the hand scores normally and the chest opens.
Rewards: a new card for the deck, bonus chips, cash, or (later) a
modified card.
- **Treasure room (THE STAR, odds 1.5)**: the room demands **2–4
  pairs by depth** — each opened chest pays its reward roll AND
  respawns a fresh key + chest on the board until the count is met.
  Losing the key (played without its chest, burned, gusted) still
  fails the room.
- **Ambient chests**: random chance in normal rooms as optional loot.
- v1: objective spawns don't mix with hazard rooms.

## Deck modifiers (SHIPPED)

Enhancements on cards YOU own, acquired via card picks, shops, and
chests, triggering every time the card is played. Stored on the deck
entry, drawn as overlays. The deck viewer (VIEW DECK on the tarot
screen; the shop's burn picker is the same screen) shows every
overlay and a hover panel explaining the hovered card.

| Modifier | Effect |
| --- | --- |
| Chip card | Pays bonus chips every time it's played in a scoring hand |
| Mult card | Multiplies the score of any hand it's part of (×1.5; multiple mults stack multiplicatively) |
| Gold card | Pays $1 of real, bankable cash every time it's played (gold nugget glyph) |
| Plus card | When cleared, the card its arrow points at gains +1 rank (cap 14). The arrow turns a quarter clockwise every hand — time the clear to aim it |
| Minus card | Mirror of Plus: the aimed card drops −1 rank (floor 2) — sculpt a King down to match your Queens |
| Wild card | Counts as ANY rank and suit; the evaluator takes the best assignment. The rarest roll (~3%) |
| EXPLOSIVE (rider) | Not a mod — a rare extra (~15%) on ANY enhanced card. When cleared, the card spreads its own mod to every adjacent (8-way) unmodified card. Old "Chip Explosion" = Chip + Explosive |

Roll weights: Mult 28% · Chip 28% · Plus 16% · Minus 12% · Gold 13% ·
Wild 3%, with the Explosive rider rolled separately on top.

## Relic system (SHIPPED — all 15 below are in)

Run-wide passive items, Balatro-joker/StS-relic style. Held for the
run (max 5 — visible as a row on the tarot screen and a line in-room),
saved with the run, gone when it ends. Acquired from the shop's relic
slot, chest rewards, and eventually bosses. Rarity sets price:
Common ~60 chips · Rare ~120 · Legendary ~250.

Starter catalog (names/numbers draft):
| Relic | Rarity | Effect |
| --- | --- | --- |
| Horseshoe | C | +1 hand in every room's budget |
| Card Sleeve | C | Card picks offer 4 choices |
| Snake Oil | C | Shop prices −25% |
| Tin Star | C | +10 chips every cleared room |
| Rabbit's Foot | C | Ambient safes/chests twice as likely |
| Bomb Squad Badge | C | Bombs start with +2 fuse |
| Chisel | C | Stones need one fewer use |
| Fire Blanket | R | Fire ticks every 2nd hand |
| Magnifying Glass | R | Washed cards still show their suit |
| Gold Tooth | R | Chip cards pay double |
| Mirror Shades | R | Mult cards ×2 instead of ×1.5 |
| Second Wind | R | First failed room each run adds no cursed card |
| Bankroll Clip | R | Cash-out rate +0.25× |
| Dowsing Rod | R | Safe combos use only ranks 2–6 |
| Lucky Chip | L | 10% chance a played hand costs no hand |

## Shop v2 (SHIPPED)

The Hermit sells **10 cards** (2 rows of 5): plain cards 40 chips,
duplicates-of-owned 50, modified (chip/mult) 80 — plus **1 relic slot**
and the burn-a-card service (30). No reroll in v1.

## Card modifiers (further drafts — need our own names/flavor)

| Modifier | Effect (draft) | Notes |
| --- | --- | --- |
| Gilded | +N chips every time it's played | Economy engine |
| Marked | +15 pips when scored | Simple power |
| Wild | Counts as any suit | Revives the old blank-card idea; flush grease |
| Glass | ×2 hand score when included; 1-in-4 to shatter (removed) after scoring | Risk/reward |
| Lucky | 20%: double chips from this hand | Gambler flavor |
| Heavy | Counts as two cards of its rank for hand-making? | Spicy; maybe too warping — discuss |
| Cursed | Dead weight: can't be selected at all | From events/bosses; removal fodder |

Rendering note: modifiers need to read at a glance on the code-drawn
cards — border tints / corner gems / face patterns per modifier (theme
system already supports per-card materials).

## Economy

Two currencies, one flow:
- **Chips** — the run: your buy-in stack, grown by winning bets, spent
  on shops and lost to failed rooms. Bankruptcy = run over (banked cash
  is safe; unconverted chips die with the run).
- **Cash** — the meta: earned ONLY by finishing the trail with chips
  or playing GOLD cards mid-run (or the
  completion purse), persists forever, spent on premium buy-ins and the
  between-runs **Outfitter** (permanent upgrades).
- One conversion point (cash-out) keeps the currencies honest: chips
  never trickle into cash automatically, so walking away is always an
  active, felt decision.

Draft permanent upgrades (Outfitter):
- +1 hand in every limited-hands room
- Card picks offer 4 choices instead of 3
- Shops 20% cheaper / shops carry a removal slot always
- Start each run with one random modified card
- One free board reshuffle per room (button)
- Slower drain in Pressure rooms / +15s in Timed rooms
- Starting deck variants (unlocks): e.g. "Stacked Deck" (44 cards,
  extra kings), "Flush Times" (suit-skewed) — big-ticket items

## Bosses — the Court (SHIPPED — Dealer duel still to come)

**The trail is 21 rooms; every 7th room is a forced boss** (no tarot
choice — fate deals a court card): room 7 = Jack, 14 = Queen Bee,
21 = King Cobra. Boss rooms have no score target — defeat the boss
within the hand budget to clear, at 3:1 odds. Bosses are LIVING CARDS
on the board, participating in hands with their current identity —
which makes deck sculpting the boss prep (stock queens before room 14).

- **JACK OF ALL TRADES** (room 7) — a boss card with **10 HP**
  (blackjack Jack). Every submitted hand — including ones that clear
  him — makes him teleport and re-roll his rank AND suit. Pin him into
  a scoring hand to deal 1 damage; do it ten times. HP badge on the
  card. (Hand budget ~18 — needs playtest tuning, 10 pins is a chase.)
- **QUEEN BEE** (room 14) — **3 stripes** (HP); she and her honey can
  only be caught in **2–3 card hands** (the honey is sticky, and so is
  she — she's a Queen, so catching her means pairing queens). Her
  rhythm alternates: one turn she MOVES (steps into an adjacent cell),
  the next she HONEYS a card adjacent to her. Honey keeps its
  rank/suit, falls normally, and STAYS honeyed until cleared. Each
  catch removes a stripe.
- **KING COBRA** (room 21) — the boss card is his HEAD, spawning with
  a random identity and a **2-segment body**. Each hand he SLITHERS
  like a real snake: the head eats an adjacent card (taking its cell
  and full identity), the body follows the head's path, and the cell
  the tail tip vacates is refilled by a fresh deal. Body segments
  block the board like walls, and he prefers slithering toward open
  space. Clear his head using its CURRENT identity → he's **stunned**
  for a hand, the tail tip crumbles, and his identity reverts to the
  previous meal. **Kill = clear the head with no body left.**
- **THE DEALER** (bonus, room 22 — HIGH ROLLER RUNS ONLY) — the true
  finale exists only at the highest stakes: a **heads-up duel with
  mirror rules**. You and the Dealer alternate scoring hands on the
  SAME board — beat his total; his table rules counter your build
  (your most-scored hand type pays half, your most-common suit
  restricted). Beating him = premium cash-out + purse + (someday) the
  credits. The duel AI is the single largest build item in this mode.

Trail restructure that comes with this: ROOMS_TOTAL 21, regions of 7,
shops offered at region positions 3 and 6, target/blind curves
recalibrated across 21 rooms, boss tarot cards drawn as court cards.

## Failure & stakes — the room bars the way

Failing a room does NOT clear it. It costs you three ways:
1. Your **stake** is lost.
2. A **Cursed card** is shuffled into your deck — dead weight that
   blocks chains until you pay a shop to burn it.
3. **You must play the same room again** — straight back to its bet
   screen (no backing out, no cash-out) with a fresh board, re-staking
   from what's left. Beat it or bleed out.

The run ends by **bankruptcy** (a failed room leaves you at zero),
by being **blinded out** (any table — next room or retry — whose seat
your chips can't cover; the house keeps what's left), or by
**finishing the trail**. There is no early cash-out.
Bosses are all-in, so a boss loss IS bankruptcy. Banked cash is always
safe. Quitting mid-room counts as a fail, and the barred room is saved
with the run — resuming drops you back at its table.

## Technical skeleton (build phases)

- **T1 — Run skeleton**: linear trail, Normal rooms only, target+hands,
  fail = run over, 1-of-3 plain card picks, run-state save
  (user://run.cfg), trail progress UI. Proves the loop.
- **T2 — Variety**: room modifier engine (timed / tight / suit / hand
  locked / pressure), shop rooms + chips, constraint-aware
  has_playable_hand.
- **T3 — Card modifiers** + Elite rooms + bosses.
- **T4 — Meta**: cash, Outfitter screen, permanent upgrades, starting
  deck unlocks, run stats screen.

Existing machinery that carries over: mode system in main.gd (Trail is
a 5th mode), board flags (single_deck-style flags per room), arcade
meter (Pressure rooms), Time Trial clock (Timed rooms), theme/material
system (modifier rendering), ConfigFile save pattern (run + meta
saves).

## Decided (brainstorm rounds 1–2)

- Fail state → betting: stake lost + cursed-card scar, fate moves on;
  run ends only on bankruptcy or cash-out.
- Trail shape → tarot draws (3 face-up + "Let Fate Decide").
- Run length → 20–60 min, player-controlled via cash-out.
- Card picks → after every room, skippable, removal in shops.
- Premium buy-ins → harder AND richer (stake-style modifiers).
- Bet UX → ante + free bet + promised hands: the ante is sunk, the bet
  is chosen, and the hand count scales the odds (fewer hands promised
  = fatter payout). Replaced bought-hands, which replaced forced
  stakes, which replaced the free slider; per-room min bets
  printed on the tarot cards.
- Bosses → court cards revived (JoAT/Queen Bee/King Cobra) + Dealer
  finale as heads-up duel with mirror counter-rules.

## Open threads (next brainstorm sessions)

1. **Odds table tuning** — per room type, and do odds scale with how
   much of the stack is wagered (all-in bonus?)?
2. **Cash-out curve** — flat rate per buy-in, or a rate that grows the
   deeper you cash out (rewarding the ride itself)?
3. **Blind schedule** — exact min-bet escalation per region/table.
4. **Cursed card variety** — one flavor, or a family (unplayable /
   drains chips when drawn onto the board / blocks its cell)?
5. **Shop inventory design** — slots, pricing, reroll cost, does
   removal price scale with deck size?
6. **Dealer duel AI** — how strong is his hand-finding, does he obey
   the same chain-adjacency rules, does he get better at higher tables?
7. **Elite rooms** — guaranteed modified-card picks as their reward?
8. **Does Trail sit beside Arcade or become the flagship** (menu
   ordering, what a new player sees first)?
9. **Seeded/daily runs** — same tarot sequence for everyone once
   leaderboards exist (ties into tabled Supabase plan).
10. "Heavy" modifier (counts as two of its rank) — too rule-warping?
