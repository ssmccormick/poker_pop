# Online seed boards (Supabase)

Poker Pop keeps a highscore board for every seed. Local bests always
work (they live in each profile's `pN_seeds.cfg`). The **online** boards
are a free [Supabase](https://supabase.com) project that the game talks
to over plain REST, so it works on desktop and in the web build alike.

Until the keys below are filled in, every online call is skipped and the
SEEDED PLAY page's board reads "Offline", so nothing breaks.

## One-time setup

1. Create a free project at <https://supabase.com/dashboard>.
2. Open **SQL Editor → New query**, paste the SQL below, and **Run** it.
3. Open **Project Settings → API Keys** and copy:
   - the **Project URL** (`https://xxxx.supabase.co`), and
   - the **publishable** key (`sb_publishable_…`), or the legacy
     **anon public** key (`eyJ…`). Either one works.
4. Paste them into `scripts/supabase_config.gd` in place of `PASTE_ME`.
5. Re-export the game.

The publishable/anon key is meant to ship inside the game. The table's
row-level security only lets it **read** scores and **add** new ones. It
can never edit or delete a score.

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

- **Posting:** when a game ends, `POST /rest/v1/scores` with that
  game's board key, score, rider, Ascension and tables. Seeded trail
  rides, Time Trial, Single, Arcade and Zen all post. A daily-practice
  ride does not, and neither does a trail ride on your own loadout.
- **Reading:** the SEEDED PLAY page and the game-over pages read
  `GET /rest/v1/best_scores?board_key=eq.<key>&order=score.desc&limit=10`.
- **Board keys:** `mode|seed|variant`, for example:
  - `trail|K7QX2M9P|the_gambler-a3` (rider and Ascension);
  - `daily|D20261012|the_doctor` (the daily seed is the UTC date);
  - `time|ABCDEFGH|180` (seconds on the clock);
  - `arcade|QWERTY23|`.
- **Who's who:** each profile makes a random `player_id` once and keeps
  it. The name is the **NAME** field on the SEEDED PLAY page (up to 12
  characters; blank posts as "Stranger" and a short tag). Two players can share a name and still have separate
  rows.

## Troubleshooting

- **Check the board from a terminal:**
  `godot --headless --path . --script res://tests/live_leaderboard.gd`
  posts to the hidden `test|SETUP|` board, reads it back and ranks it.
  Delete its rows afterwards in the Table Editor.
- **"TLS handshake error -9984" on a desktop build** means antivirus
  HTTPS scanning (Avast or AVG Web Shield, and some others) is re-signing
  the connection with its own certificate, and Godot's TLS rejects it.
  The board then just reads Offline. Turn off the antivirus's HTTPS
  scanning, or add an exception for the game. The web build is
  unaffected because the browser handles HTTPS. To test the rest of the
  client anyway, set `POKERPOP_TLS_UNSAFE=1` for the live script only;
  it never applies in play.

## Honest limits

Scores come from the player's own game, and nothing checks them on the
server. A determined cheater can post a fake one. If that ever matters:

- delete rows from the **Table Editor** (the dashboard login can do
  that; the game's key can't);
- or add a check such as `score < 5000000`.
