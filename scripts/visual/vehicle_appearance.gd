class_name RallyVehicleAppearance
extends Resource

# Visual revision is deliberately independent of physics/challenge/ghost versions.
@export var visual_revision: String = "screenprint-1"
@export var model_directory: String = "res://assets/screenprint/vehicles"
@export var lod_distances := Vector3(35,85,250)
static var material_cache: Dictionary = {}

static func build(definition: Resource) -> Node3D:
 var result := Node3D.new()
 result.name="VehicleAppearance"
 var appearance: Resource = definition.appearance
 for level: int in range(3):
  var path: String = appearance.model_directory+"/"+definition.vehicle_id+"-lod%d.glb"%level
  if not ResourceLoader.exists(path):
   if level==0 and ResourceLoader.exists(definition.model_path): return load(definition.model_path).instantiate()
   continue
  var part: Node3D=load(path).instantiate()
  part.name="LOD%d"%level
  result.add_child(part)
  _style(part,level,appearance.lod_distances)
 return result

static func _style(node: Node,level: int,distances: Vector3) -> void:
 if node is MeshInstance3D:
  var item := node as MeshInstance3D
  item.visibility_range_begin=0 if level==0 else distances[level-1]
  item.visibility_range_end=distances[level] if level<2 else 0
  item.visibility_range_begin_margin=0
  item.visibility_range_end_margin=0
  if str(item.name).begins_with("Outline_"):
   var outline := ShaderMaterial.new()
   outline.shader=preload("res://assets/shaders/screenprint_outline.gdshader")
   outline.set_shader_parameter("width_px",RallyScreenprintStyle.current().outline_pixels)
   item.material_override=outline
   item.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  else:
   for index: int in range(item.mesh.get_surface_count()):
    var original := item.mesh.surface_get_material(index) as StandardMaterial3D
    if original==null: continue
    var color := original.albedo_color
    var glass := "glass" in original.resource_name.to_lower() or "glass" in str(item.name).to_lower() or "screen" in str(item.name).to_lower()
    var key := color.to_html()+str(glass)
    if not material_cache.has(key):
     var shader := ShaderMaterial.new()
     shader.shader=preload("res://assets/shaders/screenprint_vehicle.gdshader")
     shader.set_shader_parameter("paint",color)
     shader.set_shader_parameter("shadow_ink",RallyScreenprintStyle.current().plum)
     shader.set_shader_parameter("shade_steps",RallyScreenprintStyle.current().shadow_steps)
     shader.set_shader_parameter("glass",1.0 if glass else 0.0)
     material_cache[key]=shader
    item.set_surface_override_material(index,material_cache[key])
 for child: Node in node.get_children(): _style(child,level,distances)

static func mount(body: Node3D,name_id: String,fallback: Vector3) -> Vector3:
 var target := body.find_child(name_id,true,false) as Node3D
 if target==null: return fallback
 # Local transforms work before the preview/body enters the SceneTree.
 var point := target.position
 var parent := target.get_parent()
 while parent!=body and parent is Node3D:
  point=(parent as Node3D).transform*point
  parent=parent.get_parent()
 return point
