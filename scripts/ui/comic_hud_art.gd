class_name RallyComicHUDArt
extends RefCounted

const ATLAS: Texture2D = preload("res://assets/ui/comic_hud/atlas.png")
# Regions in the original generated RGBA atlas: pixels stay unmodified.
const REGIONS := [Rect2(24,72,338,273),Rect2(378,198,374,92),Rect2(766,198,382,92),Rect2(1150,78,268,280),Rect2(116,397,185,298),Rect2(427,399,245,296),Rect2(756,397,294,298),Rect2(1124,397,284,298),Rect2(57,725,288,292),Rect2(406,731,290,285),Rect2(755,735,315,281),Rect2(1191,710,171,306)]
static var cache: Dictionary = {}

static func sprite(index: int) -> AtlasTexture:
 if not cache.has(index):
  var texture := AtlasTexture.new()
  texture.atlas=ATLAS
  texture.region=REGIONS[index]
  texture.filter_clip=true
  cache[index]=texture
 return cache[index]

static func turn(code: String,degrees: float = -1) -> Dictionary:
 var angle := degrees if degrees>=0 else (90.0 if code.ends_with("TIGHT") else 45.0)
 var slot := 4
 for bound: float in [30,50,75,110,150]:
  if angle>bound: slot+=1
 # The fifth generated corner has too similar a tangent to 90 degrees;
 # use the clearly hooked and hairpin silhouettes for the final two bins.
 if slot>=8: slot+=1
 return {"sprite":slot,"right":code.begins_with("RIGHT"),"degrees":angle}
