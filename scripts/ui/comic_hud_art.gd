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
 var number := code.get_slice("_",1).to_int()
 var fallback: float = [170.0,130.0,90.0,60.0,40.0,20.0][number-1] if number in range(1,7) else (90.0 if code.ends_with("TIGHT") else 45.0)
 var angle := degrees if degrees>=0 else fallback
 var slot := 4
 for bound: float in [30,50,75,110,150]:
  if angle>bound: slot+=1
 # The fifth generated corner has too similar a tangent to 90 degrees;
 # use the clearly hooked and hairpin silhouettes for the final two bins.
 if slot>=8: slot+=1
 # Numeric codes are the shared route/audio contract. Legacy recordings keep
 # their old three/tight interpretation and bundled voice clips.
 var suffix := code.get_slice("_",1)
 var grade := clampi(suffix.to_int(),1,6) if suffix.is_valid_int() else (1 if suffix=="TIGHT" else 3)
 var colors := [Color("ed6545"),Color("f39850"),Color("e9bc58"),Color("bfd477"),Color("6ed4bb"),Color("79cbe3")]
 return {"sprite":slot,"right":code.begins_with("RIGHT"),"degrees":angle,"grade":grade,"color":colors[grade-1]}
