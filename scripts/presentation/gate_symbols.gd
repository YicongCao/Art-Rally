class_name RallyGateSymbols
extends RefCounted

static var _textures: Dictionary = {}


static func texture(kind: String) -> Texture2D:
	if not _textures.has(kind): _textures[kind] = load("res://assets/ui/icons/gate_" + kind + ".svg")
	return _textures[kind]


static func create(parent: Node3D,kind: String,at: Vector3) -> Sprite3D:
	var symbol := Sprite3D.new()
	symbol.name = "GateSymbol"
	symbol.texture = texture(kind)
	symbol.pixel_size = .010
	symbol.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	symbol.position = at
	symbol.no_depth_test = false
	symbol.visibility_range_end = 180
	symbol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(symbol)
	return symbol
