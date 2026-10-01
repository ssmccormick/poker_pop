class_name FontLib
extends RefCounted

## Load-if-present custom fonts. Drop OFL-licensed .ttf files into
## assets/fonts/ to reskin the game's type:
##   display.ttf — menu title, screen titles, announcer, banners
##   card.ttf    — card rank numerals
## Missing files fall back to the engine default font everywhere.

static var display: FontFile
static var card: FontFile
static var numbers: FontFile  # Oswald SemiBold: UI numerals, safe combo digits
static var label: FontFile    # Oswald Regular: eyebrows, stat labels, small strings
static var body: FontFile     # Old Standard TT: prose at 20px+ only
static var body_bold: FontFile


static func setup() -> void:
	display = _try("res://assets/fonts/display.ttf")
	card = _try("res://assets/fonts/card.ttf")
	numbers = _try("res://assets/fonts/brand/Oswald-SemiBold.woff2")
	label = _try("res://assets/fonts/brand/Oswald-Regular.woff2")
	body = _try("res://assets/fonts/brand/OldStandardTT-Regular.woff2")
	body_bold = _try("res://assets/fonts/brand/OldStandardTT-Bold.woff2")


static func _try(path: String) -> FontFile:
	if ResourceLoader.exists(path):
		var f := load(path)
		if f is FontFile:
			return f
	return null
