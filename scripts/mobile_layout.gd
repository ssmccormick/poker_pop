class_name MobileLayout
extends RefCounted

## Where things go on the mobile canvases: form → screen → element →
## Rect2 in reference pixels (phone 1080×2340, tablet portrait 1536×2048).
## Rider select and game over come straight from the design spec
## (docs/mobile_v2/mobile_layout_spec_v2.json); the rest are measured off
## the mockups as each screen is converted. Screens read their boxes with
## MobileLayout.rect(screen, element), so tuning a layout is data only.

const RECTS := {
	"phone": {
		"rider_select": {
			"card_focused": Rect2(160, 272, 760, 1140),
			"page_dots": Rect2(490, 1442, 100, 20),
			"signature_toggles": Rect2(36, 1542, 1008, 120),
			"ride": Rect2(36, 2110, 1008, 130),
		},
		"game_over": {
			"title_plate": Rect2(36, 132, 1008, 180),
			"portrait": Rect2(36, 472, 344, 494),
			"ledger": Rect2(404, 462, 640, 520),
			"relics_row": Rect2(36, 1056, 1008, 112),
			"trail_strip": Rect2(70, 1242, 940, 444),
			"ride_again": Rect2(36, 1960, 1008, 130),
			"menu": Rect2(36, 2110, 1008, 110),
		},
	},
	"tablet_p": {},
}


## Both portrait forms use the phone's boxes (see Form.canvas).
static func _form() -> String:
	return Form.PHONE if Form.is_mobile() else Form.current


## The box for `element` on `screen` in the current form, or `fallback`;
## centered when the canvas runs wider than the phone's 1080.
static func rect(screen: String, element: String, fallback := Rect2()) -> Rect2:
	var by_screen: Dictionary = RECTS.get(_form(), {})
	var els: Dictionary = by_screen.get(screen, {})
	if not els.has(element):
		return fallback
	var r: Rect2 = els[element]
	r.position.x += Form.center_x()
	return r


static func has(screen: String, element: String) -> bool:
	return (RECTS.get(_form(), {}) as Dictionary).get(screen, {}).has(element)
