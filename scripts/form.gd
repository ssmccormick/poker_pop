class_name Form
extends RefCounted

## The device's form factor, and the canvas each one is laid out on.
## DESKTOP is the 1920×1080 game everyone plays today (tablets held
## landscape use it too, as the mobile spec asks). PHONE and TABLET_P are
## the portrait layouts from docs/mobile_v2: 1080×2340 and 1536×2048
## reference canvases, stretched with aspect=expand so a taller or wider
## screen just gets more room. Screens ask is_mobile() / is_phone() and
## build their mobile layout from MobileLayout.
##
## Portrait windows get the mobile layouts automatically (ENABLED). A
## developer can still force a form with the POKERPOP_FORM env var, or
## ?form=phone / ?form=tablet_p / ?form=desktop on the web build's URL.
##
## Portrait tablets lay out on the phone canvas for now: every mobile screen
## is drawn for it, and the expand aspect just gives a tablet more width.
## The canvas grows to the window's shape, never shrinks below the
## reference, so view() is the real visible size: wider than 1080 on a
## stubby browser window, taller than 2340 on a tall phone.

const ENABLED := true

const DESKTOP := "desktop"
const PHONE := "phone"
const TABLET_P := "tablet_p"
const REF := {DESKTOP: Vector2(1920, 1080), PHONE: Vector2(1080, 2340), TABLET_P: Vector2(1536, 2048)}
# Room kept clear for notches, status bars and home indicators (spec px).
const SAFE := {DESKTOP: {"top": 0, "bottom": 0}, PHONE: {"top": 132, "bottom": 100},
		TABLET_P: {"top": 48, "bottom": 40}}
const PHONE_ASPECT := 1.6   # taller than this (height ÷ width) is a phone

static var current := DESKTOP
static var _view := Vector2(1920, 1080)
# Set just before a rotation reloads the scene (statics outlive it): the
# rebuilt game skips the splash, and goes straight back into the ride.
static var rotated := false
static var resume_ride := false


## The form a window of this size gets: landscape is desktop; portrait is
## a phone when it's tall and narrow, a portrait tablet otherwise.
static func detect(window_size: Vector2) -> String:
	if window_size.y <= window_size.x or window_size.x <= 0.0:
		return DESKTOP
	return PHONE if window_size.y / window_size.x > PHONE_ASPECT else TABLET_P


## A forced form from the environment or the web URL ("" when none).
static func override() -> String:
	var f := OS.get_environment("POKERPOP_FORM")
	if f == "" and OS.has_feature("web"):
		var v: Variant = JavaScriptBridge.eval(
				"new URLSearchParams(window.location.search).get('form') || ''", true)
		f = String(v) if v != null else ""
	return f if REF.has(f) else ""


## The form this window should use right now.
static func choose(window_size: Vector2) -> String:
	var forced := override()
	if forced != "":
		return forced
	return detect(window_size) if ENABLED else DESKTOP


## The canvas a form is laid out on: the phone's for both portrait forms.
static func canvas(form: String) -> Vector2:
	return REF[DESKTOP] if form == DESKTOP else REF[PHONE]


## What a window of `window_size` shows of `base` with the expand aspect:
## the base, grown along whichever side the window has extra room.
static func expanded(base: Vector2, window_size: Vector2) -> Vector2:
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return base
	var k := minf(window_size.x / base.x, window_size.y / base.y)
	return (window_size / k).floor().max(base)


## Picks the form for `window` and sets its canvas to match. Call once,
## before any UI is built.
static func setup(window: Window) -> void:
	current = choose(Vector2(window.size))
	_view = canvas(current)
	if current != DESKTOP:
		window.content_scale_size = Vector2i(_view)
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		_view = expanded(_view, Vector2(window.size))
	else:
		# Turned back to landscape after a portrait start.
		window.content_scale_size = Vector2i(_view)
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


## The visible canvas for the current form (layouts are drawn on it).
static func view() -> Vector2:
	return _view


## How far a layout drawn for the 1080-wide phone canvas shifts right to sit
## centered on a wider one.
static func center_x() -> float:
	return 0.0 if current == DESKTOP else floorf((_view.x - REF[PHONE].x) / 2.0)


static func is_mobile() -> bool:
	return current != DESKTOP


static func is_phone() -> bool:
	return current == PHONE


## Touch play: the mobile layouts. (A touchscreen laptop on the desktop
## layout keeps its mouse hover tips.)
static func is_touch() -> bool:
	return is_mobile()


static func safe_top() -> float:
	return float(SAFE[current].top)


static func safe_bottom() -> float:
	return float(SAFE[current].bottom)
