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
| **The Trail** | A set number per table (or a clock) | You bet your chips on every table, and losing costs HP | Your own deck, shaped as you play |
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

**The Trail** is the roguelike mode. You pick a rider, buy in for a stack
of chips, and ride a 30-stop trail split into three regions. Each region
has seven tables, two merchants and a campfire, and it ends with a
**boss**: the Jack of All Trades, the Queen Bee, and finally King Cobra.
At every table you pick from a few offers and bet chips on it. Win and
you're paid at the table's odds, then you get to add a card to your deck
(duplicates are what make Five of a Kind possible). Lose and you're out
the stake, you take a hit to your 10 HP, and a cursed card can sneak into
your deck.

Tables come in lots of flavors: hazard tables with bombs on a fuse, fire
that spreads, wind, stones and flood water, plus bounties, heists, a gold
mine, blackjack and hold'em rounds. Merchants sell cards, relics and
provisions, and the campfire lets you rest or work on your deck. Your
chips only turn into real cash if you reach the end of the trail (or
play Gold cards along the way).

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
