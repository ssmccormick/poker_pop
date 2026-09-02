class_name FontLib
extends RefCounted

## Load-if-present custom fonts. Drop OFL-licensed .ttf files into
## assets/fonts/ to reskin the game's type:
##   display.ttf — menu title, screen titles, announcer, banners
##   card.ttf    — card rank numerals
## Missing files fall back to the engine default font everywhere.

static var display: FontFile
static var card: FontFile


static func setup() -> void:
	display = _try("res://assets/fonts/display.ttf")
	card = _try("res://assets/fonts/card.ttf")


static func _try(path: String) -> FontFile:
	if ResourceLoader.exists(path):
		var f := load(path)
		if f is FontFile:
			return f
	return null
