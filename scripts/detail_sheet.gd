class_name DetailSheet
extends Control

## The touch stand-in for hover tooltips: hold a finger still on a card,
## a relic or any button for HOLD_SECS and this sheet slides up from the
## bottom on the theme's poster card, with the same words the hover tip
## shows on desktop. Tap anywhere to close it.

const HOLD_SECS := 0.35
const MOVE_SLOP := 28.0      # a finger that drifts further is dragging, not holding

var main
var _panel: Panel
var _title: Label
var _body: Label
var _hold_at := Vector2.ZERO
var _hold_time := -1.0       # < 0 when no finger is down
var _fired := false          # the current touch opened the sheet; swallow its release


func setup(owner_main) -> void:
	main = owner_main
	size = main.VIEW
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 120
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", UiKit.poster_box())
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 44)
	_title.add_theme_color_override("font_color", main.RED)
	if FontLib.display != null:
		_title.add_theme_font_override("font", FontLib.display)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_title)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 34)
	if FontLib.body != null:
		_body.add_theme_font_override("font", FontLib.body)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.track_ink(_body)
	_panel.add_child(_body)


## Opens the sheet with "TITLE\nbody…" text (the hover tip's format).
func show_text(text: String) -> void:
	if text.strip_edges() == "":
		return
	var lines := text.split("\n", true, 1)
	_title.text = String(lines[0]).to_upper()
	_body.text = String(lines[1]) if lines.size() > 1 else ""
	var w: float = main.VIEW.x - 72.0
	_title.position = Vector2(36, 34)
	_title.size = Vector2(w - 72.0, 60)
	_body.position = Vector2(48, 108)
	_body.size = Vector2(w - 96.0, 0)
	_body.custom_minimum_size = Vector2(w - 96.0, 0)
	var body_h := _body.get_combined_minimum_size().y
	var h := maxf(260.0, body_h + 160.0)
	_panel.size = Vector2(w, h)
	_panel.position = Vector2(36, main.VIEW.y - Form.safe_bottom() - h - 24.0)
	visible = true
	move_to_front()


func close() -> void:
	visible = false


## Fed every input event by main._input. Returns true when the event
## belongs to the sheet (it opened or closed it) and must go no further.
func handle(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if visible:
				close()
				_fired = true  # this tap only closes the sheet
				return true
			_hold_at = t.position
			_hold_time = 0.0
			_fired = false
		else:
			_hold_time = -1.0
			if _fired:
				return true
	elif event is InputEventScreenDrag:
		if _hold_time >= 0.0 and (event as InputEventScreenDrag).position.distance_to(_hold_at) > MOVE_SLOP:
			_hold_time = -1.0
	elif event is InputEventMouseButton and _fired:
		# The mouse events Godot makes from the touch: the press or release
		# that went with opening or closing the sheet goes no further.
		if not (event as InputEventMouseButton).pressed:
			_fired = false
		return true
	return false


## Counts the hold down; when it's long enough, asks main what's under the
## finger and shows it.
func tick(delta: float) -> void:
	if _hold_time < 0.0 or _fired:
		return
	_hold_time += delta
	if _hold_time < HOLD_SECS:
		return
	_hold_time = -1.0
	var text: String = main.detail_text_at(_hold_at)
	if text != "":
		_fired = true
		main.cancel_touch_select(_hold_at)
		show_text(text)
