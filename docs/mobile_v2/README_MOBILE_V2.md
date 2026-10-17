# Poker Pop: Mobile layouts v2

This replaces the round-2 mobile pack, updated for everything since then: the suit backgrounds, five UI themes, the abilities and posse system, ability rewards, the new campfire choice, game over, rider select with signatures, the 30-stop trail map, and the new card types (cash, hazard bases, honey, metal, prism, Joker).

## Form factors
These use the same reference resolutions as before:

| Form factor | Reference size |
|---|---|
| Phone portrait | 1080×2340 |
| Tablet portrait | 1536×2048 |
| Tablet landscape | 2048×1536 |

Use Godot `canvas_items` stretch with `aspect=expand`.

## Screens
There are 8, each in all 3 form factors and all 5 themes, giving 120 mockups:

1. **table**: phone has the 5×5 board, 4 stat cells, the kit row with the Sleeve button, and CLEAR / PLAY HAND / PAYS.
2. **shop**: phone has a 3-column grid and a detail sheet.
3. **abilities**: hand rows with sockets and equipped tiles, the posse line, and the collection drawer.
4. **ability_reward**: three ability cards with reveal rays, then TAKE / SKIP.
5. **campfire**: the scene cropped to the rider and fire, the three choice cards (with the new Tend text), and confirm.
6. **game_over**: title, epitaph, fallen portrait with the ledger, relics, and the trail strip. On phone and tablet portrait the strip is 3 rows.
7. **rider_select**: a swipe carousel on phone and three in a row on tablets. Gambler shows the two-option signature selector; Machine and Doctor show their single signature.
8. **trail_map**: a winding path of 30 stops (21 tables, 3 outlaws, 3 shops, 3 campfires) with boss cards, the current-position flag, and a next-stop panel.

## Themes
These were set in the earlier theme packs; they're listed here so the mockups can be matched up.

| Theme | 9-slice folder | Background | Fonts |
|---|---|---|---|
| Classic | `ui/` | Kaleidoscope | Rye |
| Modern | `ui_modern/` | Kaleidoscope | Oswald |
| Casino | `ui_casino/` | Clubs | Old Standard TT |
| Machine | `ui_machine/` | Spades | Oswald |
| Doctor | `ui_doctor/` | Hearts | Old Standard TT |

Layouts are identical across themes; only the 9-slice folder, fonts and colours change. The Machine and Doctor mockups show their own rider on rider select, game over and campfire.

## Files
- **`mobile_layout_spec_v2.json`**: the source of truth for the build.
  - `screens_px[form_factor][screen][element] = [x, y, w, h]` in reference pixels.
  - Global safe areas, touch rules (110 px minimum target on phone, long-press for detail), theme folders and the default background per theme.
  - A short behaviour note per screen.
- **`mockups/<theme>/<form_factor>_<screen>.jpg`**: the full-size mockups.
- **`sheets/<theme>_all_screens.jpg`**: overview of every screen for that theme. `sheets/themes_phone_compare.jpg` compares the themes on phone.
- **`bg/<background>_<form_factor>.jpg`**: still frames of each background shader at every form factor, as a low-end fallback.

## Notes for the build
- On phone, scale 9-slice texture margins by 1.3–1.6× so rims and rivets don't look thin at 1080 px wide.
- Long-press (350 ms) any card or relic to open the detail sheet. This replaces hover tooltips.
- No new art is needed for mobile: the cards, ability frames, glyphs, campfire choices and Game Over pieces are all reused at the sizes in the spec.
