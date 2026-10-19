class_name RallyScreenprintStyle
extends Resource

@export var ink := Color("20252b")
@export var ivory := Color("eee2c5")
@export var teal := Color("246263")
@export var mustard := Color("d6a83c")
@export var brick := Color("ae4e36")
@export var plum := Color("493e5c")
@export var shadow_steps := Vector3(.30,.63,1.0)
@export var outline_pixels: float = 2.0
@export var print_strength: float = .035
@export var biome_palettes: Dictionary = {
 "autumn":[Color("9a7836"),Color("d6b54e"),Color("aeb2c4"),Color("efc59b")],
 "coast":[Color("8d9675"),Color("d7c895"),Color("b6d1ce"),Color("eee2c5")],
 "highland":[Color("777d69"),Color("bcb786"),Color("a8bdc8"),Color("e3dac2")]
}
static func current() -> RallyScreenprintStyle:
 return load("res://resources/visual/screenprint.tres") as RallyScreenprintStyle

static func theme() -> Theme:
 var s := current()
 var result := Theme.new()
 result.default_font=RallyFonts.regular()
 result.default_font_size=18
 result.set_color("font_color","Label",s.ivory)
 for type: String in ["Button","OptionButton"]:
  for state: String in ["normal","hover","pressed","focus","disabled","hover_pressed"]:
   var box := StyleBoxFlat.new()
   box.bg_color=s.teal if state=="normal" else s.plum
   box.border_color=s.mustard
   box.border_width_bottom=3 if state in ["hover","pressed","hover_pressed"] else 1
   if state=="focus":
    box.bg_color=Color.TRANSPARENT
    box.border_color=s.ivory
    box.set_border_width_all(3)
   if state=="disabled": box.bg_color=s.ink.lightened(.10)
   box.content_margin_left=20
   box.content_margin_right=20
   box.content_margin_top=12
   box.content_margin_bottom=12
   result.set_stylebox(state,type,box)
  result.set_color("font_color",type,s.ivory)
  result.set_color("font_disabled_color",type,s.ivory.darkened(.45))
 return result
