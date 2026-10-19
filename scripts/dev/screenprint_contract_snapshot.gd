extends SceneTree
var reports: Dictionary = {}
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
 var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
 app.profile.path="user://screenprint-contract/profile.json"
 root.add_child(app)
 for id: String in RallyContentCatalog.STAGES:
  app.chosen_stage=id
  await app.start_race()
  var shapes: Array[String]=[]
  _collect(app.race,shapes)
  shapes.sort()
  reports[id]={"collision_sha256":"\n".join(shapes).sha256_text(),"collision_components":shapes.size(),"route_points":var_to_bytes(app.race.generator.route.points).hex_encode().sha256_text(),"challenge_keys":[]}
  for car: String in RallyContentCatalog.VEHICLES:
   for tier: int in range(3): reports[id].challenge_keys.append(RallyContentCatalog.challenge(id,car,tier).key())
  await app.leave_race()
  await process_frame
 FileAccess.open("res://logs/screenprint-contract.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
 print("SCREENPRINT CONTRACT SNAPSHOT COMPLETE")
 app.queue_free()
 await process_frame
 quit()
func _collect(node: Node,items: Array[String]) -> void:
 if node is CollisionShape3D and node.get_parent() is StaticBody3D:
  var shape: Shape3D=node.shape
  var pose: Transform3D=node.global_transform
  if shape is ConcavePolygonShape3D:
   var faces: PackedVector3Array=shape.get_faces()
   # Canonical triangles ignore how render meshes are split into static bodies.
   for i: int in range(0,faces.size(),3):
    var vertices: Array[String]=[]
    for j: int in range(3): vertices.append(_point(pose*faces[i+j]))
    vertices.sort()
    items.append("triangle:"+"/".join(vertices))
  else:
   var values: Array[String]=[shape.get_class(),str(pose)]
   for p: Dictionary in shape.get_property_list():
    if p.usage & PROPERTY_USAGE_STORAGE and p.name not in ["resource_name","resource_local_to_scene","script"]: values.append(str(p.name)+":"+str(shape.get(p.name)))
   items.append("|".join(values))
 for child: Node in node.get_children(): _collect(child,items)
func _point(v: Vector3) -> String: return "%.5f,%.5f,%.5f"%[v.x,v.y,v.z]
