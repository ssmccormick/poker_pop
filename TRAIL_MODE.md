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
- **Per-room wager — ante and bet at posted odds**: every room costs
  its **ante** (25 chips at the first table, climbing with depth and
  table stakes — the house keeps it, win or lose). Then you **bet
  chips on yourself** at the table's posted odds (MIN / RAISE ×2 /
  ALL IN). The hand budget (or minute budget on clock tables) is
  FIXED by the table and tightens as the trail deepens — no haggling
  over it. Clearing pays bet + bet × odds, PLUS a swiftness bonus:
  every spare hand (or every spare 10 seconds on a clock table) pays
  blind÷5 chips. Failing loses ante and bet. Bosses are ALL IN at
  base odds, fixed hand budget.
  *(The old promise dial — trading fewer hands/minutes for fatter
  odds — was removed 2026-09-12; difficulty now comes purely from
  progression.)*
- **Odds by room**: Steady 1:1 · Risky/Treasure/soft-Purge 3:2 ·
  Dangerous/Heist/hard-Purge/Called-Hands 2:1 · Royal Hunt 5:1 ·
  Boss 3:1.
- **The big league**: beyond the Jack (table 8 on), EVERY cost runs
  10× — antes, bets, shop cards, relics, the forge, the Fool's
  kicker — and beyond the Queen (table 15 on) it jumps 10× AGAIN
  (100× frontier prices). An all-in rider clears each region with a
  stack that keeps pace.
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
| TRAVELING MERCHANT | Shop — Peddler / Collector / Card Sharp, rolled per stop (shipped) |
| POWDER KEG | Purge room: bombs (shipped) |
| WILDFIRE | Purge room: fire (shipped) |
| DUST STORM | Purge room: wind (shipped) |
| FLASH FLOOD | Purge room: water (shipped) |
| GOLD MINE | Board choked with stone; break N to clear, gold cards turn up in the rubble (shipped) |
| BANK JOB | Heist room (crack the safe — shipped) |
| STAGECOACH HAUL | Treasure room: 3–5 key+chest pairs ON THE CLOCK (unlimited hands, ~1 min per pair, fixed by the table) — the hardest job on the trail, but clearing it awards a RELIC (shipped) |
| DEALER'S CALL | Called Hands: play the demanded hands (shipped) |
| ROYAL HUNT | Make a Royal Flush, 5:1 (shipped, rare) |
| HIGH NOON | Timed table: score the target before the clock dies (shipped) |
| TEXAS HOLD'EM | Variant: persistent 5-card community, pick 2 hole cards, best playable subset of the 7 scores; RE-DEAL card refreshes the community (shipped) |
| CRAZY 8s | Variant: every 8 is WILD, but the board crawls with a mixed hazard storm (8 + region seeded, replenished each hand); score target (shipped) |
| BLACKJACK | Variant: poker off — the table is dealt FACE-DOWN (corners up); chain blind hits, then the dealer flips his hole card and draws out his hand like a real dealer; 3+region wins to clear; hazard storm of 5 + region, replenished (shipped) |
| SHOWDOWN | The Outlaw duel: clear YOUR gold bullets to shoot him (6+region HP). HIS red bullets are LIT with a 3-hand fuse — at zero one fires and costs GRIT; clearing one in a scoring hand defuses it penalty-free. Weak hands under the posted score give him free shots; 3 GRIT (shipped) |

**Goal vs limit**: every non-boss room now rolls its challenge type
independently — 50% a HAND BUDGET, 50% ON THE CLOCK (plain score
tables drawing the clock take the HIGH NOON name). Minutes default to
~0.4 × the hand reference. The old dedicated timed room is folded in.
Any directional card (wind, plus, minus, bumper) turns its arrow a
quarter clockwise every hand.

## Room types

| Room | Rule | Notes |
| --- | --- | --- |
| Normal | Score target within the hands you bought | The baseline |
| Purge | A QUOTA hunt: 4 of ONE hazard kind (bomb/fire/wind/water) seeded at the deal, clear 10 (+3 per region) total AND leave the table clean; up to 2 more trickle in per hand keeping ≥4 on the table until the quota is spawned (no score target) | Shipped. Cleared = spawned − standing, so ANY exit counts: played, gusted off, shoved off, burned out, blown up. Fire spread adds to the spawned ledger, so WILDFIRE can overshoot its quota while flames still stand — the room isn't won until every last fire is out (and all-ablaze still loses the table). No ambient extras — the hazards ARE the room |
| Gold Mine | Mine the seam DRY: 20 stones total — 12 seeded, the rest riding in on the deal (≤2/hand, keeping ≥6 standing until all 20 have spawned); the table clears only when every stone is broken (chip by clearing cards beside them, 3 chips each); 12 hands | Shipped. NOT a solid board — the plain cards between stones pop and refill so the mine shifts every hand. Each destroyed stone has a 35% chance to leave a GOLD card in the refill (plays for $1 real cash) |
| THE ROUNDUP / WANTED / THE CENSUS | Roundup family (goal "collect"): clear 12+3·region cards of one SUIT, or 5+region of one RANK (WANTED, 2:1), or cards of 11+region DIFFERENT ranks, capped at 13 (CENSUS) — only cards actually cleared in scoring hands count; 10+region hands to do it (shipped) |
| LAND RUSH | Claim every plot: clear a card from each of the 25 cells; claimed plots wear a gold ring under the card; 12 hands, 2:1 (shipped) |
| Called Hands | Play the exact demanded hands (e.g. 2× Flush + 1× Pair; scales per region) | Shipped (JUDGEMENT). Exact composition only — a Full House is not three Pairs |
| Royal Hunt | Make one Royal Flush | Shipped (THE WORLD): rare, region 2+, odds 5:1 |
| Timed | Score target before the clock; hands unlimited | Shipped (THE HANGED MAN, 2:1 base). The minute budget is fixed by the table (4→2 by region). Hazards still tick per hand |
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
- **CALL / RAISE / ALL IN** replaces the free bet dial:
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
  suit) — and the house evens the odds with a TON of hazards: a mixed
  storm of 8 (+1 per region) seeded at the deal, and whenever clears
  drop the board below that level, a fresh hazard rolls in on the
  next hand. Exempt from the normal ambient hazard roll (the storm IS
  the roll).
- **BLACKJACK**: poker hands OFF; you play against the house at a
  FACE-DOWN table. The whole board is dealt face-down except the four
  corner cards; refills arrive face-down; every submitted hand turns
  one more random card face-up. Chains must START from a face-up
  card. Each face-down card you select is a HIT: it flips ON THE SPOT
  and its pips join your running sum. Hits are BINDING — no deselect,
  no clear (the clear button/right-click are refused mid-chain) — and
  if a flip carries the sum past 21 the round busts immediately, no
  submit needed. PLAY HAND (any 1+ cards) is standing: the dealer
  reveals his hole card (one is face-down in the panel, real
  blackjack style) and DRAWS until he beats you, ties you (push), or
  busts over 21. His played-out hand lingers ~2s, then a fresh round
  is dealt. Beat the dealer N times (3 + region) to clear. Hazards
  burn through the card backs (a hazarded card is always face-up),
  and the storm rules still apply — 5 + region, replenished, no
  ambient roll.
- **SHOWDOWN — the Outlaw**: an Outlaw portrait with HP beside the
  board. YOUR bullet cards and HIS bullet cards spawn among the deals.
  Clear YOUR bullets in scoring hands → shots that damage him. Clear
  HIS bullets → he shoots YOU. He also shoots if your scored hand is
  below a posted threshold. Shots cost DUEL HP (separate, ~3 grit for
  the room; 0 = room failed). Kill him to clear — a puzzle fight where
  you'll trade some blood. His health lives in the banner as a RED
  SEGMENTED HEALTH BAR (one notch per life), the same bar the bosses
  wear — no more bare numbers at the top.

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
Chance = 20% + 8%/room + 15%/buy-in tier (cap 95%); count = 1 + 1 per
4 tables (High Roller adds another half the time, cap 6), with mixed
hazard types coexisting. On top of the seed, THE DECK TURNS MEAN:
every refilled card has a chance to arrive already hazarded — 3% +
0.8%/room per card (cap 20%) — so deep tables never stay calm. Purge
rooms are exempt from both (their hazards ARE the room); storm tables
(Crazy 8s / Blackjack) swap the seed roll for their guaranteed floor
but keep the mean deck. EVERY mid-room hazard (storm replenish,
purge trickle, mean-deck roll) arrives ON a freshly dealt card —
never stamped onto a card already sitting at the table — and lands
with a burst of its element (splash, embers, sparks, rubble, dust)
so new trouble is unmistakable. The card fire or water will strike
next ALWAYS wears a faint preview of the effect creeping in at its
bottom edge (spreaders aim only at hittable neighbors, re-aiming
after every tick, seed, and refill). The old hazard tarot cards
(DEATH etc.) are retired. Hazards are states on normal rank/suit
cards, one per card; ticks happen only on scoring hands, after the
board settles. A hazard that arrives mid-room sits out the round it
landed — no spread, soak, rank burn, or fuse tick until the next
hand. Hazards on the table from the deal get no such mercy: they
spread, soak, burn down, and count down from hand one.

| Hazard | Tarot | Rule | Counterplay |
| --- | --- | --- | --- |
| Bomb | DEATH | Fuse (5) drops per scoring hand; 0 = room LOST (fail-forward) | Include it in any scoring hand to defuse |
| Fire | WILDFIRE | Every hand it SPREADS to one adjacent card that isn't burning, and its rank ticks −1; below 2 it burns up (unscored). The FLAMES GROW as the rank falls — barely above the bottom edge on an Ace, all but consuming the card at rank 2. If EVERY card on the table catches fire, the table is LOST | Play it (scores at current rank) to extinguish — every hand you wait, the fire claims another card. The next card to catch wears small flames licking its bottom edge |
| Wind | THE CHARIOT | When played, every card from its cell to the edge in the wind's direction is blown off (unscored); the direction turns each hand and is HIDDEN by default — only the Weathervane relic shows the arrow. Safes are too heavy to move | Still a tool for the bold — a blind gust can kill a BOSS (blowing one off the table counts; a gusted tail segment wounds the cobra), and the Weathervane turns it back into a precision weapon |
| Stone | STRENGTH | A BLOCKER: no rank, no suit, unplayable, and chains can't pass through it. Every card cleared orthogonally beside it chips it (3 chips = crumble); broken rock has a 35% chance of baring a GOLD card in the refill — everywhere, not just mines | Mine around it: build hands that clear its neighbors, and cash the gold it leaves behind |
| Water | — | The FLOOD: a water card FILLS 1/4 per hand (translucent, its face stays readable). At the brim it POURS — all four orthogonal neighbors start filling, 4 hands each, opaque water climbing their faces. A victim at the brim DROWNS (face hidden) and pours onward itself | Play the source at any level to stop the leak; clear filling victims before they go under; a canteen bails out any one card. Drowned cards still play blind — if you remember what they were |

Design calls: fire spreads 4-way (8-way wipes 5×5 boards); spread skips
hazarded/cursed cards; hazards don't persist in the run save.
Water calls: drowned (washed) cards play normally (the evaluator knows
the truth — the player doesn't); while one is selected the preview
shows "???" and the valid-hand green border is suppressed so you can't
probe for free; water only pours into plain cards (never hazarded,
cursed, objective, or already-damp ones); damp cards can't catch fire;
flooding is room-local.

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
- **Treasure room (STAGECOACH HAUL, odds 2.0)**: the room demands
  **3–5 pairs by depth**, and it runs **on the clock** — unlimited
  hands, reference ~1 minute per pair + 1, with minutes as the odds
  promise like HIGH NOON. Each opened chest pays its reward roll AND
  respawns a fresh key + chest until the count is met; clearing the
  room awards a RELIC. A piece cleared WITHOUT its partner DROPS off
  its carrier to the card below in the same column — and past the
  bottom edge it wraps, falling in from the top onto that column's
  first card (skipping stones/safes/bosses/other pieces; if nothing
  in the column can catch it, it respawns on a fresh card). Pieces
  lost off the board entirely (burned, gusted, bumped) respawn on a
  fresh card — it just cost you seconds.
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
| Gold card | Pays $1 of real, bankable cash every time it's played. Drawn SOLID GOLD, face and all |
| Plus card | When cleared, the card its arrow points at gains +1 rank. Boosting an ACE wraps it into a LUCKY 2+ (green-framed deuce) that DOUBLES any hand it scores in (stacking). The arrow turns a quarter clockwise every hand — time the clear to aim it |
| Minus card | Mirror of Plus: the aimed card drops −1 rank — and a 2 ground lower is DESTROYED, removed from the table unscored. Sculpt a King down to match your Queens, or grind junk to nothing |
| Bumper card | When cleared, shoves the contiguous line of cards beside it one step along its arrow (turns each hand) — the push lands FIRST, while the bumper still sits on the felt, then the scored cards pop and the board settles. A gap absorbs the push; safes and cobra coils block it; a card pushed past the edge is removed unscored. The Jack and Queen ride the shove like anyone else: off the edge costs the boss one life (a Queen stripe, or 1,000 of the Jack's score pool), and he storms back onto the vacated cell |
| Wild card | Counts as ANY rank and suit; the evaluator takes the best assignment. The rarest roll (~3%) |
| EXPLOSIVE (rider) | Not a mod — a rare extra (~15%) on ANY enhanced card. When cleared, the card spreads its own mod to every adjacent (8-way) unmodified card. Old "Chip Explosion" = Chip + Explosive |

Enhanced cards wear their power as their identity: a full-face color
wash + frame in the mod's color, and the mod's emblem drawn LARGE in
the center where the suit pip normally sits (suit stays readable in
the corner). Gold cards are solid gold head to toe.

Roll weights: Mult 26% · Chip 26% · Plus 14% · Minus 10% · Bumper 11%
· Gold 10% · Wild 3%, with the Explosive rider rolled separately.

## Relic system (SHIPPED — all 17 below are in)

Run-wide passive items, Balatro-joker/StS-relic style. Held for the
run — NO carry limit; the price is the gate — shown as a (wrapping)
line on the tarot screen, saved with the run, gone when it ends.
Acquired from the shop's relic slot and chest rewards. Rarity sets
price: Common 150 chips · Rare 300 · Legendary 600 (×league
multiplier, Snake Oil −25%).

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
| Weathervane | R | Wind cards show their direction arrow (hidden otherwise) |
| Magnifying Glass | R | Washed cards still show their suit |
| Gold Tooth | R | Chip cards pay double |
| Mirror Shades | R | Mult cards ×2 instead of ×1.5 |
| Second Wind | R | First failed room each run adds no cursed card |
| Bankroll Clip | R | Cash-out rate +0.25× |
| Dowsing Rod | R | Safe combos use only ranks 2–6 |
| Saddlebags | R | A 4th slot in the provision kit |
| Lucky Chip | L | 10% chance a played hand costs no hand |

## Provisions (SHIPPED)

One-shot consumables in a 3-slot KIT (right HUD column, trail rooms
only; the Saddlebags relic opens a 4th slot). Using one is a FREE action — it never costs a hand; the
provision itself is the price. Two kinds: TARGETED (click the kit
button, then a card on the table; right-click or press again to
holster) and INSTANT (fires on the spot). Refusals explain themselves;
saved with the run.

| Provision | Kind | Price | Effect |
| --- | --- | --- | --- |
| Canteen | Targeted | 45 | Douses one card — removes any hazard or soak (not stone) |
| Dynamite Stick | Targeted | 60 | Destroys one card outright, unscored — stones and curses included (bosses, safes, and cobra coils are too big). Blasted mine stones still count toward the seam; a blasted treasure carrier respawns its piece |
| Branding Iron | Targeted | 70 | Brands a plain, dry card with a random enhancement |
| Barber's Razor | Targeted | 50 | Re-rolls one card's rank and suit (mods survive the cut) |
| Gold Pan | Targeted | 65 | Turns one plain card solid GOLD |
| Fresh Deck | Instant | 55 | Re-deals every plain and enhanced card; anchored things (hazards, bosses, safes, treasure, curses, backs) hold their ground |
| Pocket Flask | Instant | 60 | +2 hands at this table (+20 seconds on a timed one) |
| Rattlesnake Tonic | Instant | 70 | The next scored hand counts DOUBLE (the preview shows it) |

Sources: merchants stock a crate (Peddler 2 · Collector 2 · Sharp 1,
prices ×league mult, Snake Oil applies), ambient safes add one to the
loot 35% of the time, and the chest reward table rolls one in its
0.80–0.88 band. Tutor popup fires on the first one found.

## Shop v3 — traveling merchants (SHIPPED)

Each shop stop is a different trader, rolled when the tarot offer is
drawn — the selector card names the merchant and lists their wares
before you commit (stock and merchant fixed per room — no re-rolling
by leaving):

| Merchant | Cards | Relics | Forge |
| --- | --- | --- | --- |
| THE PEDDLER'S WAGON | 8 | 2 | yes |
| THE COLLECTOR | 0 | 4 | no |
| THE CARD SHARP | 10 | 0 | yes |

Card prices: plain 40 chips, duplicates-of-owned 50, modified 80.
Relic prices by rarity: C 150 / R 300 / L 600 (Snake Oil still −25%).
Prices are computed at display time, so buying Snake Oil re-prices
the rest of that same shop on the spot. Every purchase re-renders
the shelves, and a refused purchase says WHY, loud and in red: not
enough chips, satchel full, or "that would bust you" (spending below
the next table's cheapest seat is blocked as a guaranteed bust).
Relic slots show a code-drawn icon (RelicIcon), name, effect, and
price; burn-a-card starts at 30 and climbs per use, one per shop.
The screen is dressed as a roadside camp (ShopBackdrop): covered
wagon, lantern rope, crates, packed dirt. Hover any shelf card for
the standard stat tooltip.

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

- **JACK OF ALL TRADES** (room 7) — his life is a **10,000-point
  SCORE POOL**, fought over **30 hands**. Every submitted hand —
  including ones that hit him — makes him teleport and re-roll his
  rank AND suit. Pin him into a scoring hand that **beats his bar**
  (starts 30, **+25 per hit**, shown in the banner) and the hand's
  WHOLE SCORE bleeds off him; weaker hands make him scoff and stay.
  The card badge shows thousands left ("7K"); the banner bar carries
  the exact count in ten notches. A gust off the table is still an
  instant kill; a bumper shove off the edge drains 1,000 — and he
  storms back on.
- **Boss feedback** — every wound lands as a visible SLUG: the scored
  hand's pieces gather into a gold bullet that zooms from the hand's
  center into the boss card (flinch + sparks + table shake). Boss
  health is a RED SEGMENTED BAR in the banner slot (jack 10 notches,
  queen 3 stripes, cobra tail+head), shared with the Outlaw duel.
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
safe. Quitting mid-room is NOT a fail: the whole outlay is refunded,
the room is saved with the run, and resuming sits you back down at its
stakes screen like a fresh visit (fresh board — no scumming penalty,
by design).

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
- Bet UX → ante + free bet at posted odds: the ante is sunk, the bet
  is chosen, the table fixes the hand/minute budget. Replaced promised
  hands (odds dial, removed 2026-09-12 — difficulty comes from
  progression instead), which replaced bought-hands, which replaced
  forced stakes, which replaced the free slider; per-room min bets
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
