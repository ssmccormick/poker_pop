extends SceneTree

## Form factors and the mobile layout table: which form a window gets,
## the reference canvases, and that every layout box sits on its canvas.
## Run: godot --headless --path . --script res://tests/test_form.gd

var failures := 0


func _initialize() -> void:
	_check(Form.detect(Vector2(1080, 2340)) == Form.PHONE, "a 1080×2340 window is a phone")
	_check(Form.detect(Vector2(390, 844)) == Form.PHONE, "so is a 390×844 browser")
	_check(Form.detect(Vector2(1536, 2048)) == Form.TABLET_P, "a 1536×2048 window is a portrait tablet")
	_check(Form.detect(Vector2(2048, 1536)) == Form.DESKTOP, "a landscape tablet keeps the desktop layout")
	_check(Form.detect(Vector2(1920, 1080)) == Form.DESKTOP, "a 1920×1080 window is desktop")
	_check(Form.detect(Vector2(0, 0)) == Form.DESKTOP, "an empty window falls back to desktop")
	_check(Form.choose(Vector2(1080, 2340)) == (Form.PHONE if Form.ENABLED else Form.DESKTOP),
			"with the switch off, phones still get the desktop layout")
	_check(Form.REF[Form.PHONE] == Vector2(1080, 2340) and Form.REF[Form.TABLET_P] == Vector2(1536, 2048),
			"the reference canvases match the spec")
	# Every box sits on its canvas.
	var inside := true
	for f in MobileLayout.RECTS:
		var canvas := Rect2(Vector2.ZERO, Form.REF[f])
		for screen in MobileLayout.RECTS[f]:
			for el in MobileLayout.RECTS[f][screen]:
				var r: Rect2 = MobileLayout.RECTS[f][screen][el]
				if not canvas.encloses(r):
					inside = false
					print("  off canvas: %s/%s/%s %s" % [f, screen, el, r])
	_check(inside, "every mobile layout box sits on its canvas")
	if failures == 0:
		print("ALL FORM TESTS PASSED")
	else:
		print("%d FORM TEST(S) FAILED" % failures)
	quit(failures)


func _check(cond: bool, label: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: " + label)
