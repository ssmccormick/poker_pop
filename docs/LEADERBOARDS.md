# Online seed boards (Supabase)

Poker Pop keeps a high-score board for every seed. Local bests always
work, since they're stored in each profile's `pN_seeds.cfg`. The
**online** boards run on a free [Supabase](https://supabase.com) project
that the game talks to over plain REST, so they work the same on desktop
and in the web build.

Until you fill in the keys below, the game skips every online call and
the board on the SEEDED PLAY page just reads "Offline", so nothing
breaks.

## One-time setup

1. Create a free project at <https://supabase.com/dashboard>.
2. Open **SQL Editor → New query**, paste the SQL below, and **Run** it.
3. Open **Project Settings → API Keys** and copy:
   - the **Project URL** (`https://xxxx.supabase.co`), and
   - the **publishable** key (`sb_publishable_…`), or the legacy
     **anon public** key (`eyJ…`). Either one works.
4. Paste them into `scripts/supabase_config.gd` in place of `PASTE_ME`.
5. Re-export the game.

The publishable/anon key is meant to ship inside the game, so it's fine
for players to have it. The table's row-level security only lets that
key **read** scores and **add** new ones. It can't edit or delete a
score.

```sql
-- Every score posted from the game.
create table public.scores (
  id          bigint generated always as identity primary key,
  board_key   text not null check (char_length(board_key) between 3 and 80),
  mode        text not null check (char_length(mode) <= 12),
  seed        text not null check (char_length(seed) <= 16),
  variant     text not null default '' check (char_length(variant) <= 32),
  player_id   text not null check (char_length(player_id) between 8 and 40),
  player_name text not null check (char_length(player_name) between 1 and 12),
  score       integer not null check (score > 0 and score < 1000000000),
  rider       text not null default '' check (char_length(rider) <= 24),
  ascension   integer not null default 0 check (ascension between 0 and 20),
  tables      integer not null default 0 check (tables between 0 and 30),
  created_at  timestamptz not null default now()
);

create index scores_board_score on public.scores (board_key, score desc);

alter table public.scores enable row level security;

create policy "anyone can read scores"
  on public.scores for select to anon, authenticated using (true);

create policy "anyone can post a score"
  on public.scores for insert to anon, authenticated with check (true);

grant select, insert on public.scores to anon, authenticated;

-- Each player's best on each board: what the top ten reads.
create view public.best_scores with (security_invoker = true) as
  select distinct on (board_key, player_id)
         board_key, player_id, player_name, score, rider, ascension, tables, created_at
    from public.scores
   order by board_key, player_id, score desc, created_at asc;

grant select on public.best_scores to anon, authenticated;
```

## How the game uses it

- **Posting:** when a game ends, the game sends `POST /rest/v1/scores`
  with that game's board key, score, rider, Ascension and tables. Seeded
  trail rides, Time Trial, Single, Arcade and Zen all post scores. A
  daily ride played as practice doesn't, and neither does a trail ride
  on your own loadout.
- **Reading:** the SEEDED PLAY page and the game-over pages load the
  top ten with
  `GET /rest/v1/best_scores?board_key=eq.<key>&order=score.desc&limit=10`.
- **Board keys:** these look like `mode|seed|variant`. For example:
  - `trail|K7QX2M9P|the_gambler-a3` (the rider and Ascension);
  - `daily|D20261012|the_doctor` (the daily seed is the UTC date);
  - `time|ABCDEFGH|180` (the seconds on the clock);
  - `arcade|QWERTY23|`.
- **Who's who:** each profile makes up a random `player_id` once and
  keeps it. The name comes from the **NAME** field on the SEEDED PLAY
  page (up to 12 characters). If it's blank, the score posts as
  "Stranger" plus a short tag. Two players can have the same name and
  still get separate rows.

## Troubleshooting

- **Check the board from a terminal:**
  `godot --headless --path . --script res://tests/live_leaderboard.gd`
  posts a score to the hidden `test|SETUP|` board, reads it back and
  checks its rank. Delete those rows in the Table Editor afterward.
- **"TLS handshake error -9984" on a desktop build** means your
  antivirus is scanning HTTPS traffic (Avast or AVG Web Shield do this,
  and so do some others). It re-signs the connection with its own
  certificate, Godot's TLS rejects it, and the board just reads Offline.
  Turn off the antivirus's HTTPS scanning, or add an exception for the
  game. The web build isn't affected, because the browser handles HTTPS.
  If you want to test the rest of the client anyway, set
  `POKERPOP_TLS_UNSAFE=1` for the live script only. It never applies
  during play.

## Honest limits

Scores come from the player's own copy of the game, and nothing on the
server checks them, so a determined cheater can post a fake one. If that
ever becomes a problem, you can:

- delete rows in the **Table Editor** (your dashboard login can do that,
  but the game's key can't);
- or add a check such as `score < 5000000`.
