extends "res://tests/test_suite.gd"

func _run() -> void:
 var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/art-direction/screenprint/baseline/content-hashes.json"))
 var mechanics: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/vehicle-mechanics-hashes.json"))
 var approved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v040-mechanics-hashes.json"))
 var brushline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/brushline-mechanics-hashes.json"))
 for path: String in baseline:
  var actual := FileAccess.get_sha256("res://"+path)
  var expected: String=baseline[path]
  if mechanics.has(path):
   # Baseline captured before reference-car presentation edits. All other fields
   # (including camera, wheel, identity and version data) remain protected.
   var mechanical_text := ""
   for line: String in FileAccess.get_file_as_string("res://"+path).trim_suffix("\n").split("\n"):
    if line.begins_with("title =") or line.begins_with("description =") or line.begins_with("paint =") or line.begins_with("accent ="): continue
    mechanical_text+=line+"\n"
   actual=mechanical_text.sha256_text()
   expected=mechanics[path]
  # 0.4.0 deliberately raises F160 power and versions only its nine challenges.
  if approved.has(path): expected=approved[path]
  # Approved twilight/cliff revision changes highland only. Vehicle mechanics remain protected.
  if brushline.has(path): expected=brushline[path]
  check(actual==expected,"Approved mechanical resource: "+path)
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/screenprint/manifest.json"))
 for path: String in manifest:
  var item: Dictionary=manifest[path]
  check(ResourceLoader.exists("res://"+path),"Authored asset imports: "+path)
  if "/vehicles/" in path: check(int(item.triangles)<=40000,"Vehicle triangle budget: "+path)
 for id: String in RallyContentCatalog.VEHICLES:
  var definition := RallyContentCatalog.vehicle(id)
  var expected_names := {"F160":"大众 GTI", "R200":"宝马 M3 E30", "A240":"奥迪 quattro S1"}
  check(definition.short_title()==expected_names[id],"Reference name reaches selection and confirmation: "+id)
  var body := RallyVehicleAppearance.build(definition)
  root.add_child(body)
  check(body.get_child_count()==3,"Three body LODs: "+id)
  check(RallyVehicleAppearance.mount(body,"CameraCockpit",Vector3.INF).is_equal_approx(definition.cockpit_offset),"Cockpit mount preserves camera position: "+id)
  check(RallyVehicleAppearance.mount(body,"CameraHood",Vector3.INF).is_equal_approx(definition.hood_offset),"Hood mount preserves camera position: "+id)
  var mount := RallyVehicleAppearance.mount(body,"PlateRear",Vector3.ZERO)
  check(mount.z>definition.body_size.z*.5,"Rear plate sits outside body: "+id)
  var left := RallyVehicleAppearance.mount(body,"TailLeft",Vector3.ZERO)
  var right := RallyVehicleAppearance.mount(body,"TailRight",Vector3.ZERO)
  check(left.x<0 and right.x>0 and is_equal_approx(left.z,right.z),"Paired lamp edge mounts: "+id)
  for part: Node in body.find_children("*","MeshInstance3D",true,false):
   if str(part.name).begins_with("Outline_"):
    check(part.material_override is ShaderMaterial,"Car outline uses dedicated shader")
  for tier: int in range(3):
   var challenge := RallyContentCatalog.challenge("sunset_ridge",id,tier)
   check(not "screenprint" in challenge.key(),"Art revision does not invalidate ghosts: "+id+str(tier))
  body.free()
 var wheel_faces: int=manifest["assets/screenprint/props/wheel_tire.glb"].triangles+2*manifest["assets/screenprint/props/wheel_rim.glb"].triangles
 check(wheel_faces*4<=12000,"Four authored AT tires and rims fit 12k triangle budget")
 var parent := Node3D.new()
 root.add_child(parent)
 for name_id: String in ["cabin","lighthouse","medical","sailboat","helicopter","arch","bridge_post"]:
  var prop := RallyScreenprintProps.add(parent,name_id)
  check(prop!=null,"World prop loaded: "+name_id)
  check(prop.find_children("*","CollisionObject3D",true,false).is_empty(),"Visual prop never changes collision: "+name_id)
  check(prop.find_children("Outline*","MeshInstance3D",true,false).is_empty(),"Environment has no ink outlines: "+name_id)
 parent.free()
 finish()
