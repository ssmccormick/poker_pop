# Poker Pop

A grid puzzle game about building poker hands, made in Godot 4.7.

A 5×5 board of playing cards is dealt from a shuffled deck. Chain up to
5 **adjacent** cards (diagonals count) to build the best poker hand you
can, play it, and the cards pop — everything above falls down and fresh
cards deal in from the top.

When the deck reshuffles, duplicate cards appear — which is why **Five
of a Kind** is a legal hand here.

## Modes

| Mode | Hands | Pressure | Deck |
| --- | --- | --- | --- |
| **Time Trial** | Unlimited | 1:00 / 3:00 / 5:00 countdown | Reshuffles |
| **Single Deck** | Unlimited | None | One 52-card deck — play until no hands remain |
| **Arcade** | Unlimited | Always-draining bar | Reshuffles |
| **Zen** | Unlimited | None | Reshuffles |

**Arcade** is the campaign: each level sets a score target (600, then
+150 per level) while a meter beside the board drains constantly —
faster every level. Scoring hands refills the meter; the challenge is
making matches quickly enough to keep the bar up. Hit the target to
advance to a fresh board; let the meter empty and the run is over. If
the board ever has no playable hand, Arcade reshuffles it and play
continues (the bar keeps draining, though).

Refills play out as a dealer would: surviving cards settle first, then
new cards are flicked in one at a time from the deck. Click during the
animation to skip it.

In Single Deck the board stops refilling when the deck is spent and the
run ends when no playable hand remains — clearing the entire board is a
Perfect Clear. In any reshuffling mode, a board with no playable hand
is a loss (rare, but the exact-hand rule makes it possible).

## Rules

- A selection is an ordered chain: each card after the first must be
  adjacent (8 directions) to the previous pick. Click cards one by one
  or hold and drag across them; dragging back over the previous card
  undoes a step, and clicking a selected card removes it and everything
  picked after it.
- **Every selected card must be part of the hand.** Two kings and two
  queens plus a jack is not Two Pair — the jack is a kicker, and kickers
  make the selection unplayable. This also means separated pairs can't
  be bridged: the cards in between would not participate.
- **Pair minimum** — a single High Card can't be submitted.
- Hands with fewer than 5 cards are legal (two kings are a Pair).
  Straights and flushes require exactly 5 cards.
- Straights just need the five consecutive ranks — pick them in any
  order (the ace can go low for A-2-3-4-5). The **YOUR HAND** panel
  shows your current selection sorted by rank, so runs are easy to
  spot.
- Score for a hand = base payout + the pip total of the cards played
  (J=11, Q=12, K=13, A=14).

The game starts fullscreen; the menu's OPTIONS screen has a fullscreen
toggle, window-size presets, and music/SFX volume sliders (persisted to
`user://settings.cfg`).

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

Flushed Five is five cards of the same rank **and** suit — only
possible once the deck has reshuffled enough for identical duplicates
to meet on the board.

## Backgrounds

The play area sits on a background image that rotates every arcade
level (random per run in other modes). Drop `.png`/`.jpg` images into
`assets/backgrounds/` and they're auto-loaded; with none present the
game generates gradient placeholders. See [POLISH.md](POLISH.md) for
the full polish roadmap.

## Themes

Four visual themes (Classic, Felt Table, Sketchbook, Crosshatch Noir),
cycled with T. The pattern textures in `assets/patterns/` come from the
UltimateToon shader pack; its 3D toon shader doesn't apply to a 2D game,
so `shaders/card_pattern.gdshader` is a small canvas_item adaptation
that overlays the patterns on the code-drawn cards.

## Development

Open the project folder in Godot 4.7+. Apart from the pattern textures,
everything is drawn and synthesized in code (including the pop sound).
Run the headless tests with:

```
godot --headless --path . --script res://tests/test_poker.gd
godot --headless --path . --script res://tests/test_board.gd
```
