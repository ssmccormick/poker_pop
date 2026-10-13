class_name Leaderboard
extends Node

## The online seed boards: a small REST client for the Supabase table in
## docs/LEADERBOARDS.md. Every call is skipped until SupabaseConfig holds
## real keys, and every failure is quiet. The local seed book is always
## there to fall back on.

signal fetched(board_key: String, rows: Array)
signal fetch_failed(board_key: String)
signal submitted(board_key: String, ok: bool)
signal ranked(board_key: String, rank: int, of: int)

const TIMEOUT := 6.0
const CACHE_MS := 30000

var _cache := {}   # board_key -> {"rows": Array, "at": int}


static func configured() -> bool:
	return SupabaseConfig.URL.begins_with("https://") and SupabaseConfig.KEY.length() > 20


## Off in screenshots and tests: they must never post to the real boards.
static func live() -> bool:
	return configured() and OS.get_environment("POKERPOP_SHOT") == "" \
			and OS.get_environment("POKERPOP_PROFILE") == ""


func _headers(extra: Array = []) -> PackedStringArray:
	var h := PackedStringArray(["apikey: " + SupabaseConfig.KEY, "Content-Type: application/json"])
	if SupabaseConfig.KEY.begins_with("eyJ"):
		h.append("Authorization: Bearer " + SupabaseConfig.KEY)  # a legacy anon key
	for e in extra:
		h.append(String(e))
	return h


func _request() -> HTTPRequest:
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT
	add_child(req)
	return req


func _base() -> String:
	return SupabaseConfig.URL.trim_suffix("/") + "/rest/v1/"


## Posts one finished game. `row` holds the columns of public.scores.
func submit(row: Dictionary, retries := 1) -> void:
	var key := String(row.get("board_key", ""))
	if not live():
		submitted.emit(key, false)
		return
	var req := _request()
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		req.queue_free()
		var ok := result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300
		if not ok and retries > 0:
			submit(row, retries - 1)
			return
		if not ok:
			push_warning("Leaderboard: posting failed (%d / HTTP %d)" % [result, code])
		_cache.erase(key)
		submitted.emit(key, ok))
	if req.request(_base() + "scores", _headers(["Prefer: return=minimal"]),
			HTTPClient.METHOD_POST, JSON.stringify(row)) != OK:
		req.queue_free()
		submitted.emit(key, false)


## The board's top ten (each player's best), newest fetch cached briefly.
func fetch_top(board_key: String) -> void:
	if not live():
		fetch_failed.emit(board_key)
		return
	var c: Dictionary = _cache.get(board_key, {})
	if not c.is_empty() and Time.get_ticks_msec() - int(c.at) < CACHE_MS:
		fetched.emit(board_key, c.rows)
		return
	var req := _request()
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		var rows = JSON.parse_string(body.get_string_from_utf8()) \
				if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
		if not rows is Array:
			fetch_failed.emit(board_key)
			return
		_cache[board_key] = {"rows": rows, "at": Time.get_ticks_msec()}
		fetched.emit(board_key, rows))
	var url := _base() + "best_scores?select=player_id,player_name,score,rider,ascension,tables" \
			+ "&board_key=eq." + board_key.uri_encode() + "&order=score.desc,created_at.asc&limit=10"
	if req.request(url, _headers()) != OK:
		req.queue_free()
		fetch_failed.emit(board_key)


## Where `score` stands on the board: 1 + the players with a better best.
func fetch_rank(board_key: String, score: int) -> void:
	if not live():
		return
	var req := _request()
	req.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, _b: PackedByteArray) -> void:
		req.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code >= 300:
			return
		var above := _count_from(headers)
		if above >= 0:
			ranked.emit(board_key, above + 1, -1))
	var url := _base() + "best_scores?select=player_id&board_key=eq." + board_key.uri_encode() \
			+ "&score=gt." + str(score) + "&limit=1"
	if req.request(url, _headers(["Prefer: count=exact"])) != OK:
		req.queue_free()


## The total from a "Content-Range: 0-0/42" (or "*/0") header.
static func _count_from(headers: PackedStringArray) -> int:
	for h in headers:
		if h.to_lower().begins_with("content-range:"):
			var total := h.get_slice("/", 1).strip_edges()
			return int(total) if total.is_valid_int() else -1
	return -1
