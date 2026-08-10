# Poker Pop — Game Feel & Polish Plan

Working checklist for the polish pass. Ordered so each phase builds on
the previous one; items within a phase are roughly by impact.

## Phase 1 — Audio foundation

The single biggest feel upgrade. Add a small audio manager that
auto-loads whatever files exist so recordings can be dropped in
incrementally.

### Announcer voice lines (self-recorded)
Drop files into `assets/voice/` with these names (`.ogg`, `.mp3`, or
`.wav`) and the game will pick them up; missing lines just don't play:

| File | Line said when |
| --- | --- |
| `pair` | Pair played |
| `two_pair` | Two Pair played |
| `three_of_a_kind` | Three of a Kind played |
| `straight` | Straight played |
| `flush` | Flush played |
| `full_house` | Full House played |
| `four_of_a_kind` | Four of a Kind played |
| `five_of_a_kind` | Five of a Kind played |
| `straight_flush` | Straight Flush played |
| `royal_flush` | Royal Flush played |
| `flushed_five` | Flushed Five played |
| `ready` | Countdown "Ready..." |
| `pop` | Countdown "POP!" |
| `level_clear` | Arcade level cleared |
| `game_over` | Any run ends in a loss |
| `perfect_clear` | Single Deck full clear |
| `reshuffle` | Arcade dead-board reshuffle |

### Sound effects (synthesized like the pop, or from a pack)
- [ ] Card select tick — pitch rises with chain position (1..5)
- [ ] Card deselect / chain truncate (lower tick)
- [ ] Invalid play attempt (soft buzz when pressing play on No Hand)
- [ ] Card deal/land thock for the fall animation (small, per column)
- [ ] UI button hover + press click
- [ ] Meter warning heartbeat when the arcade bar is under 25%
- [ ] Level-clear fanfare sting
- [ ] Reshuffle swish
- [ ] Game-over sting
- [ ] Score tally tick during count-up

### Music behavior
- [ ] Crossfade menu <-> game tracks instead of hard stop + fade-in
- [ ] Duck music ~4 dB while a voice line plays

## Phase 2 — Transitions & level flow

- [ ] Level-clear sequence with breathing room: freeze input, "LEVEL N
      CLEAR" holds ~1.5s, score tally rolls up, remaining cards fly off
      the board, background crossfades to the next level's image, new
      deal, then Ready...POP
- [ ] Background crossfade (two stacked TextureRects, alpha tween)
      instead of an instant swap
- [ ] Game-over screen: final score counts up from 0, show run stats
      (levels reached, best hand, biggest single score)
- [ ] Menu <-> game fade transition (0.3s black dip)
- [ ] Splash fades out instead of vanishing

## Phase 3 — Card & board juice

- [ ] Scale punch on card select (1.0 -> 1.08 spring)
- [ ] Invalid selection shake (chain-breaking click wiggles the card)
- [ ] Played cards fly together toward the hand's centroid before
      popping (read as "the hand" being collected)
- [ ] Pop particles (theme-colored confetti burst per card)
- [ ] Screen shake scaled to hand tier (none for Pair, big for Royal)
- [ ] Announcer text scale-punch on appear; color by hand tier
      (off-white for small, gold for big, red-gold for the top three)
- [ ] Floating score size scales with points
- [ ] Meter pulses bright when refilled; heartbeat flash under 25%
- [ ] Card hover lift (subtle raise under the cursor)
- [ ] Score number rolls up instead of snapping

## Phase 4 — Backgrounds & theming

- [ ] Real background art in `assets/backgrounds/` (auto-loaded,
      rotates per arcade level; random per run elsewhere)
- [ ] Slow drift/zoom on backgrounds (Ken Burns) for life
- [ ] Per-theme background tint so themes and backgrounds compose

## Phase 5 — Meta & QoL

- [ ] High score persistence per mode (user:// save file)
- [ ] Pause menu (Esc): resume / restart / menu / volume sliders
- [ ] Settings: separate music / SFX / voice volumes, fullscreen toggle
- [ ] "Best hand this run" tracking shown on game over
- [ ] itch page assets: cover image, screenshots, GIF
