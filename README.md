# Poker Pop

A grid puzzle game about building poker hands, made in Godot 4.7.

You're dealt a 5×5 board of playing cards from a shuffled deck. Chain up
to 5 **adjacent** cards (diagonals count) into the best poker hand you
can find, then play it. The cards pop, everything above them falls down,
and new cards are dealt in from the top.

When the deck reshuffles, duplicate cards start showing up. That's why
**Five of a Kind** is a legal hand here.

## Modes

| Mode | Hands | Pressure | Deck |
| --- | --- | --- | --- |
| **The Trail** | A set number per table (or a clock) | Losing a table costs HP, and dying loses your trail cash | Your own deck, shaped as you play |
| **Time Trial** | Unlimited | 1:00 / 3:00 / 5:00 countdown | Reshuffles |
| **Single Deck** | Unlimited | None | One 52-card deck, played until no hands are left |
| **Arcade** | Unlimited | A bar that's always draining | Reshuffles |
| **Zen** | Unlimited | None | Reshuffles |

**Arcade** is the campaign. Each level sets a score target (600, then
150 more per level), and a meter beside the board drains the whole time,
a little faster each level. Scoring hands fills the meter back up, so
the challenge is making matches quickly enough to keep it from running
dry. Hit the target and you move on to a new board. Let the meter empty
and the run is over. If the board ever has no playable hand, Arcade
reshuffles it and you keep going (the bar keeps draining, though).

Refills play out the way a dealer would do it. The cards that are left
settle first, then new cards are flicked in from the deck one at a time.
Click during the animation to skip it.

**The Trail** is the roguelike mode. You pick a rider and ride a 30-stop
trail split into three regions. Each region has seven tables, two
merchants and a campfire, and it ends with a **boss**: the Jack of All
Trades, the Queen Bee, and finally King Cobra. Tables are free to sit.
Clear one and it pays **trail cash** (more at higher odds and deeper on
the trail), then you pick an **ability card**. Ability cards go on your
poker hands (a Pair has 2 slots, a Flush 5) and kick in every time you
play that hand. Lose a table and you take a hit to your 10 HP, a cursed
card can sneak into your deck, and you try the table again.

Before you set out you can ride for free, bring cash from the bank to
spend on the way, or **bet** bank cash on how far you'll get: the Jack
(1.5 : 1), the Queen (3 : 1) or King Cobra (6 : 1). A winning bet is
banked the moment that boss falls.

Every table has one objective (reach the target, crack a safe, collect a
bounty, work a gold mine, beat the dealer at blackjack, play hold'em...)
and can stack **twists** on top: bombs on a fuse, fire that spreads, wind,
stones and flood water, a random wild rank, a shorter hand count, or rules
about which hands play or score. Each twist makes the table harder and
raises its odds. Merchants take trail cash for cards, relics, abilities
and provisions, and buy your spare provisions back at half price. The
campfire lets you rest or work on your deck. Safes, chests, bounties and
Cash and Gold cards all pay trail cash too, but it only comes home to the
bank if you reach the end of the trail, along with the finishing purse.

Every ride earns EXP, whether you win or bust. Leveling up unlocks new
relics, cards and gear, and you spend your cash on them and on upgrades
at the Outfitter. Beat the trail with a rider to unlock the next one and
that rider's next **Ascension** level. There are 20, each adding one more
rule to make things harder. **SEEDED PLAY** lets you replay any seed on a
standard loadout and race other players' scores, and there's a **Daily
Ride** that everyone plays on the same seed. The original design notes
are in [TRAIL_MODE.md](TRAIL_MODE.md).

In Single Deck, the board stops refilling once the deck runs out, and
the run ends when there's no playable hand left. Clearing the whole
board is a Perfect Clear. In any mode that reshuffles, a board with no
playable hand is a loss. It's rare, but the exact-hand rule makes it
possible.

## Rules

- A selection is an ordered chain. Each card after the first has to be
  adjacent (in any of 8 directions) to the card you picked before it.
  Click cards one at a time, or hold the button and drag across them.
  Dragging back over the previous card undoes a step, and clicking a
  selected card removes it along with everything you picked after it.
- **Every selected card has to be part of the hand.** Two kings, two
  queens and a jack isn't Two Pair, because the jack is a kicker, and a
  kicker makes the selection unplayable. It also means you can't link
  two pairs that are apart, since the cards in between wouldn't be part
  of the hand.
- **The minimum is a Pair.** You can't play a single High Card.
- Hands with fewer than 5 cards are fine (two kings make a Pair).
  Straights and flushes need exactly 5 cards.
- A straight just needs five ranks in a row, and you can pick them in
  any order (the ace can go low for A-2-3-4-5). The **YOUR HAND** panel
  shows your current selection sorted by rank, so runs are easy to
  spot.
- A hand scores its base payout plus the pip total of the cards played
  (J=11, Q=12, K=13, A=14).

The game starts in fullscreen. The OPTIONS screen on the menu has a
fullscreen toggle, window-size presets, and music and SFX volume
sliders, all saved to `user://settings.cfg`.

## Controls

| Input | Action |
| --- | --- |
| Left click / drag | Chain adjacent cards (up to 5) |
| Enter / Space / PLAY HAND | Play the selected hand |
| C / Right click / CLEAR | Clear selection |
| Esc | Pause |
| R | Restart current mode |
| M | Back to the main menu |
| T | Cycle visual theme |

### On a phone

The web build works in phone and tablet browsers. When the window is
taller than it is wide, the game switches to its portrait layout: the
board fills the width, with the stats above it and CLEAR, PLAY HAND and
PAYS along the bottom. Every screen has a one-column version.

| Touch | Action |
| --- | --- |
| Tap / drag | Chain adjacent cards |
| Hold a finger on anything | Read what it does |
| PAYS | Show what each hand pays |
| II | Pause |
| Drag a list | Scroll it |

In the shop, a tap picks an item and BUY buys it. Turn the phone sideways
and the game switches to the desktop layout, picking a ride back up where
you left it. Short browser windows get a wider canvas, so for the
biggest type, add the page to your home screen or go fullscreen.

To force a layout for testing, add `?form=phone`, `?form=tablet_p` or
`?form=desktop` to the page's URL, or set the `POKERPOP_FORM` environment
variable on a desktop build.

## Payouts

| Hand | Base |
| --- | --- |
| Flushed Five | 3000 |
| Royal Flush | 2500 |
| Five of a Kind | 1500 |
| Straight Flush | 1200 |
| Four of a Kind | 600 |
| Full House | 350 |
| Flush | 250 |
| Straight | 200 |
| Three of a Kind | 100 |
| Two Pair | 60 |
| Pair | 25 |

A Flushed Five is five cards of the same rank **and** suit. You can only
get one after the deck has reshuffled enough times for exact duplicates
to end up on the board together.

## Backgrounds & reskinning

The backgrounds are procedural parallax scenes (`scripts/parallax_bg.gd`).
They're layered silhouettes that drift, and they lurch forward with
every hand you score. On the trail, each region moves from day to dusk
to night, bosses are fought under a storm, and every mode has its own
scene. To reskin the other art:

- `assets/cards/`: drop in a card-face PNG and point a theme's
  `face_texture` at it (`scripts/themes.gd`).
- `assets/fonts/display.ttf` is the western display font for titles,
  banners and the announcer, and `assets/fonts/card.ttf` is used for the
  rank numerals on cards. If either file is missing, the game falls back
  to the engine font.

See [POLISH.md](POLISH.md) for the full polish roadmap.

## Themes

There are four visual themes (Classic, Felt Table, Sketchbook and
Crosshatch Noir), and T cycles through them. The pattern textures in
`assets/patterns/` come from the UltimateToon shader pack. Its 3D toon
shader doesn't work in a 2D game, so `shaders/card_pattern.gdshader` is
a small canvas_item version that lays the patterns over the cards drawn
in code.

## Development

Open the project folder in Godot 4.7 or later. Apart from the pattern
textures, everything is drawn and synthesized in code, including the
pop sound. To run the headless tests:

```
godot --headless --path . --script res://tests/test_poker.gd
godot --headless --path . --script res://tests/test_board.gd
```
