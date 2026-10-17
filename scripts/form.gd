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
## The mobile layouts stay switched off (ENABLED) until every screen has
## one. Until then a developer can force them with the POKERPOP_FORM env
## var, or ?form=phone / ?form=tablet_p on the web build's URL.

const ENABLED := false

const DESKTOP := "desktop"
const PHONE := "phone"
const TABLET_P := "tablet_p"
const REF := {DESKTOP: Vector2(1920, 1080), PHONE: Vector2(1080, 2340), TABLET_P: Vector2(1536, 2048)}
# Room kept clear for notches, status bars and home indicators (spec px).
const SAFE := {DESKTOP: {"top": 0, "bottom": 0}, PHONE: {"top": 132, "bottom": 100},
		TABLET_P: {"top": 48, "bottom": 40}}
const PHONE_ASPECT := 1.6   # taller than this (height ÷ width) is a phone

static var current := DESKTOP


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


## Picks the form for `window` and sets its canvas to match. Call once,
## before any UI is built.
static func setup(window: Window) -> void:
	current = choose(Vector2(window.size))
	if current != DESKTOP:
		window.content_scale_size = Vector2i(REF[current])
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND


## The reference canvas for the current form (layouts are drawn on it).
static func view() -> Vector2:
	return REF[current]


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
