# Poker Pop

A grid puzzle game about building poker hands, made in Godot 4.7.

A 7×5 board of playing cards is dealt from a shuffled deck. Click up to
5 cards anywhere on the board to build the best poker hand you can, play
it, and the cards pop — everything above falls down and fresh cards deal
in from the top. You get **20 hands** per run; chase the highest score.

The deck reshuffles when it runs out, so late in a run duplicate cards
appear — which is why **Five of a Kind** is a legal hand here.

## Controls

| Input | Action |
| --- | --- |
| Left click | Select / deselect a card (up to 5) |
| Enter / Space / PLAY HAND | Play the selected hand |
| Esc / Right click / CLEAR | Clear selection |
| R | Restart |

## Hands & payouts

Hands with fewer than 5 cards are legal (a lone ace is a High Card, two
kings are a Pair). Straights and flushes require exactly 5 cards.

Score for a hand = base payout + the pip total of the cards played
(J=11, Q=12, K=13, A=14).

| Hand | Base |
| --- | --- |
| Royal Flush | 2000 |
| Straight Flush | 1200 |
| Five of a Kind | 900 |
| Four of a Kind | 600 |
| Full House | 350 |
| Flush | 250 |
| Straight | 200 |
| Three of a Kind | 100 |
| Two Pair | 60 |
| Pair | 25 |
| High Card | 5 |

## Development

Open the project folder in Godot 4.7+. Everything is drawn in code — no
art assets. Run the evaluator tests headless with:

```
godot --headless --path . --script res://tests/test_poker.gd
```
