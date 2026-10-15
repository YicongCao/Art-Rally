class_name RallyFonts
extends RefCounted

const TEXT: FontFile = preload("res://assets/fonts/NotoSansSC-Variable.ttf")
const MONO: FontFile = preload("res://assets/fonts/NotoSansMono-Variable.ttf")
static var _bold: FontVariation
static var _mono_bold: FontVariation


static func bold() -> FontVariation:
	if _bold==null:
		_bold = FontVariation.new()
		_bold.base_font = TEXT
		_bold.variation_opentype = {"wght":700}
	return _bold


static func mono_bold() -> FontVariation:
	if _mono_bold==null:
		_mono_bold = FontVariation.new()
		_mono_bold.base_font = MONO
		_mono_bold.variation_opentype = {"wght":700}
	return _mono_bold
