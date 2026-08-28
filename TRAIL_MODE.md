# TRAIL MODE — Design Doc

Status: **v1 skeleton SHIPPED** (scripts/trail.gd): buy-in tables,
tarot room draws with risk tiers (Sun/Wheel/Tower), full betting loop
with presets + slider, cash-out, fail-forward with Cursed scars,
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
wager, and your shop wallet. **Cash out between rooms** to bank chips
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
  | Table | Cost | Starting chips | Cash-out rate | Difficulty mods |
  | --- | --- | --- | --- | --- |
  | Penny Ante | Free | 100 | ×1 | none |
  | Table Stakes | $50 cash | 250 | ×1.5 | +1 modifier |
  | High Roller | $200 cash | 500 | ×2.5 | +2 modifiers |
- **Per-room wager**: each tarot card prints the room's target, rules,
  **odds**, and its **minimum buy-in**. Bet UI is chip presets
  (**Min / 2× / 5× / ALL IN**) plus a **free slider** for exact
  amounts. Clear → stake × odds returned. Fail → stake lost, ride on.
- **Odds by room risk** (draft): Normal 1:1 · Timed/Tight 3:2 ·
  Constraint rooms 2:1 · Elite 3:1 · Boss 4:1.
- **Blinds escalate**: the minimum bet rises each region (poker blinds
  structure) — late trail, you can't limp. Can't cover the min bet =
  busted = run over.
- **Cash out**: between any two rooms, walk away — convert remaining
  chips to cash at the buy-in's rate. Finishing the whole trail (beating
  the Dealer) cashes out at a premium multiplier plus a completion purse.
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

## The tarot trail (room selection)

At each junction, fate deals **three face-up tarot cards** — each is
the next room, showing its type, rules, odds, and min bet. A fourth,
face-down option: **"Let Fate Decide"** — a random different room,
sweetened with a small chip kicker for trusting the cards.

Draft Major Arcana → room mapping (flavor pass later):
| Card | Room |
| --- | --- |
| The Sun | Normal |
| Wheel of Fortune | Timed |
| The Hanged Man | Tight Hands |
| The Moon | Suit Locked |
| The Magician | Hand Locked |
| The Tower | Pressure (drain bar) |
| The Hermit | Shop |
| Death | Elite |
| The Devil | Cursed bargain event (take a cursed card for chips?) |

## Room types

| Room | Rule | Notes |
| --- | --- | --- |
| Normal | Score target within N hands | The baseline; N generous |
| Timed | Score target before the clock | Reuses Time Trial machinery |
| Tight Hands | Target with very few hands (4–6) | Efficiency puzzle |
| Suit Locked | Only 1–2 suits score | e.g. "red room": hearts/diamonds only |
| Hand Locked | Only listed hand types score | e.g. "pairs are worthless tonight" |
| Pressure | The arcade drain bar, one room's worth | Reuses meter machinery |
| Shop | Spend chips: cards, modifiers, card **removal** | No challenge, no reward |
| Elite | Harder target + a room modifier stacked | Better card choices + more chips |
| Event? | Mystery choice (risk/reward text event) | Post-v1 candidate |
| Boss | Rule-warping challenge capping a region | See Bosses |

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

## Card modifiers (drafts — need our own names/flavor)

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
- **Cash** — the meta: earned ONLY by cashing out chips (or the
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

## Bosses — the Court

Region bosses are the court cards (reviving the old GameMaker-era
concepts), with the old doc's final dealer capping the trail:
- **Jack of All Trades** (region 1) — every hand type may only be
  scored once
- **Queen Bee** (region 2) — honeycombed board: some cells locked/cursed
- **King Cobra** (region 3) — fast drain bar plus a big target
- **THE DEALER** (finale) — the old design's final boss, now a
  **heads-up duel with mirror rules**: you and the Dealer alternate
  turns scoring hands on the SAME board — beat his total. His table
  rules also counter your build: your most-scored hand type pays half,
  your most-common suit is restricted. One-trick decks get punished;
  flexible builds shine. Beating him = premium cash-out + purse.
  (The duel — Dealer AI picking hands on the board — is the single
  largest build item in this mode; the mirror rules are cheap.)

## Failure & stakes — fail forward, scarred

Failing a room does NOT end the run. It costs you three ways:
1. Your **stake** is lost.
2. The room's **reward is gone** — fate deals a fresh set of tarot
   cards and the trail moves on (no grinding retries).
3. A **Cursed card** is shuffled into your deck — dead weight that
   can't be selected, clogging board texture until you pay a shop to
   burn it. Losses hurt the build, not just the bankroll.

The run ends only by **bankruptcy** (can't cover the minimum bet) or by
choosing to **cash out**. Banked cash is always safe. The player sets
their own stakes every room; the game only escalates the floor.

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
- Bet UX → presets (Min/2×/5×/ALL IN) + free slider; per-room min bets
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
