class_name RallyPlateText
extends RefCounted

const MAX_LENGTH := 10
const DEFAULT_TEXT := "ART-RALLY"


static func font() -> Font:
	return RallyFonts.bold()


static func valid(value: Variant, allow_empty: bool = false) -> bool:
	if value is not String or value.length() > MAX_LENGTH or value != value.strip_edges(): return false
	if value.is_empty(): return allow_empty
	for i: int in range(value.length()):
		var code: int = value.unicode_at(i)
		if code < 32 or code == 127 or code == 0xfeff: return false
		if (code >= 0x200b and code <= 0x200f) or (code >= 0x2028 and code <= 0x202f) or (code >= 0x2060 and code <= 0x206f): return false
		if not font().has_char(code): return false
	return true


static func display(value: String) -> String:
	return value if valid(value) else DEFAULT_TEXT
