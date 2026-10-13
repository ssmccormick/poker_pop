extends SceneTree

## A LIVE check against the real Supabase board (not part of the suites):
## posts to the hidden test|SETUP| board, reads it back, ranks it.
## Run: godot --headless --path . --script res://tests/live_leaderboard.gd

func _initialize() -> void:
	_run()


func _run() -> void:
	var lb := Leaderboard.new()
	# POKERPOP_TLS_UNSAFE=1 skips certificate checks, for machines whose
	# antivirus re-signs HTTPS (Avast Web Shield); a diagnostic only.
	if OS.get_environment("POKERPOP_TLS_UNSAFE") != "":
		lb.tls_override = TLSOptions.client_unsafe()
	root.add_child(lb)
	await process_frame
	print("live: ", Leaderboard.live())
	var key := "test|SETUP|"
	lb.submit({"board_key": key, "mode": "test", "seed": "SETUP", "variant": "",
			"player_id": "setup-check-godot", "player_name": "Godot", "score": 2222,
			"rider": "", "ascension": 0, "tables": 0})
	var sub: Array = await lb.submitted
	print("submitted: ", sub)
	lb.fetch_top(key)
	var got: Array = await lb.fetched
	print("top: ", got[1])
	lb.fetch_rank(key, 2000)
	var rk: Array = await lb.ranked
	print("rank for 2000: ", rk[1])
	quit(0)
