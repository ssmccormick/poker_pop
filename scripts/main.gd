extends Node2D

## Game flow and UI for Poker Pop.

const BG := Color("1a1a1a")
const GOLD := Color("e8c547")
const OFFWHITE := Color("e8e0c8")
const RED := Color("c23b3b")
const DIM := Color("8a836e")

const START_HANDS := 20
const PANEL_X := 672.0

var board: Board
var score := 0
var hands_left := START_HANDS
var game_over := false

var score_label: Label
var hands_label: Label
var deck_label: Label
var preview_label: Label
var announcer: Label
var over_layer: ColorRect
var over_label: Label
var _announce_tween: Tween


func _ready() -> void:
	get_window().title = "Poker Pop"
	RenderingServer.set_default_clear_color(BG)

	board = Board.new()
	board.position = Vector2(40, 56)
	board.hand_played.connect(_on_hand_played)
	add_child(board)

	_build_ui()

	if OS.get_environment("POKERPOP_SHOT") != "":
		_take_screenshot(OS.get_environment("POKERPOP_SHOT"))


func _process(_delta: float) -> void:
	score_label.text = "SCORE  %d" % score
	hands_label.text = "HANDS LEFT  %d" % hands_left
	deck_label.text = "DECK  %d" % board.deck.size()
	_update_preview()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if not game_over:
					board.play_hand()
			KEY_ESCAPE:
				if not game_over:
					board.clear_selection()
			KEY_R:
				_restart()


func _update_preview() -> void:
	if game_over:
		preview_label.text = "Game over — press R to deal a new run."
		preview_label.add_theme_color_override("font_color", RED)
		return
	var data := board.get_selected_data()
	if data.is_empty():
		preview_label.text = "Select up to 5 cards to build a poker hand."
		preview_label.add_theme_color_override("font_color", DIM)
	else:
		var result := Poker.evaluate(data)
		preview_label.text = "%s  —  %d pts   (base %d + pips %d)" % \
				[result.name, result.score, result.base, result.pips]
		preview_label.add_theme_color_override("font_color", GOLD)


func _on_hand_played(result: Dictionary) -> void:
	score += result.score
	hands_left -= 1
	_announce("%s  +%d" % [String(result.name).to_upper(), result.score])
	if hands_left <= 0:
		game_over = true
		board.locked = true
		_show_game_over()


func _show_game_over() -> void:
	# Let the last pop/refill animation play out before covering the board.
	await get_tree().create_timer(1.4).timeout
	if not game_over:
		return
	over_label.text = "GAME OVER\n\nFinal score: %d\n\nPress R to play again" % score
	over_layer.visible = true


func _restart() -> void:
	if board.busy:
		return
	score = 0
	hands_left = START_HANDS
	game_over = false
	over_layer.visible = false
	board.reset()


func _announce(text: String) -> void:
	announcer.text = text
	announcer.modulate = Color(1, 1, 1, 1)
	if _announce_tween and _announce_tween.is_valid():
		_announce_tween.kill()
	_announce_tween = create_tween()
	_announce_tween.tween_interval(0.9)
	_announce_tween.tween_property(announcer, "modulate:a", 0.0, 0.5)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	_label(root, "POKER", Vector2(PANEL_X, 20), 40, RED)
	_label(root, "POP", Vector2(PANEL_X + 158, 20), 40, OFFWHITE)

	score_label = _label(root, "", Vector2(PANEL_X, 92), 26, GOLD)
	hands_label = _label(root, "", Vector2(PANEL_X, 132), 20, OFFWHITE)
	deck_label = _label(root, "", Vector2(PANEL_X, 162), 20, OFFWHITE)

	var play_btn := _button(root, "PLAY HAND", Vector2(PANEL_X, 208), Vector2(158, 44))
	play_btn.pressed.connect(func() -> void:
		if not game_over:
			board.play_hand())
	var clear_btn := _button(root, "CLEAR", Vector2(PANEL_X + 166, 208), Vector2(96, 44))
	clear_btn.pressed.connect(func() -> void:
		if not game_over:
			board.clear_selection())

	_label(root, "PAYOUTS", Vector2(PANEL_X, 282), 16, DIM)
	var names: Array = Poker.BASE_SCORES.keys()
	names.reverse()
	var lines := PackedStringArray()
	for hand_name in names:
		lines.append("%s   %d" % [hand_name, Poker.BASE_SCORES[hand_name]])
	var payouts := _label(root, "\n".join(lines), Vector2(PANEL_X, 312), 14, OFFWHITE)
	payouts.add_theme_constant_override("line_spacing", 6)

	_label(root, "Click cards to select (up to 5)\nEnter / Space — play hand\nEsc / Right click — clear\nR — restart",
			Vector2(PANEL_X, 616), 13, DIM)

	preview_label = _label(root, "", Vector2(40, 668), 20, DIM)

	announcer = Label.new()
	announcer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	announcer.add_theme_font_size_override("font_size", 52)
	announcer.add_theme_color_override("font_color", GOLD)
	announcer.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	announcer.add_theme_constant_override("shadow_offset_x", 3)
	announcer.add_theme_constant_override("shadow_offset_y", 3)
	announcer.modulate = Color(1, 1, 1, 0)
	root.add_child(announcer)
	announcer.set_anchors_preset(Control.PRESET_FULL_RECT)
	announcer.offset_right = -290  # center over the board, not the panel

	over_layer = ColorRect.new()
	over_layer.color = Color(0, 0, 0, 0.78)
	over_layer.visible = false
	root.add_child(over_layer)
	over_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_label = Label.new()
	over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	over_label.add_theme_font_size_override("font_size", 34)
	over_label.add_theme_color_override("font_color", OFFWHITE)
	over_layer.add_child(over_label)
	over_label.set_anchors_preset(Control.PRESET_FULL_RECT)


func _label(parent: Control, text: String, pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, pos: Vector2, btn_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = btn_size
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("2a2a2a")
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.bg_color = Color("3d3a2c")
	b.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = sb.duplicate()
	pressed.bg_color = Color("55503a")
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", OFFWHITE)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_font_size_override("font_size", 17)
	parent.add_child(b)
	return b


## Debug helper: POKERPOP_SHOT=<path> captures the board after the deal
## settles, then quits. Used for automated visual checks.
func _take_screenshot(path: String) -> void:
	await get_tree().create_timer(1.6).timeout
	for cell in [Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4)]:
		if board.grid.has(cell):
			board._toggle_select(board.grid[cell])
	await get_tree().create_timer(0.6).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	get_tree().quit()
