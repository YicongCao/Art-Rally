extends "res://tests/test_suite.gd"

func _run() -> void:
 var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/art-direction/screenprint/baseline/content-hashes.json"))
 for path: String in baseline:
  check(FileAccess.get_sha256("res://"+path)==baseline[path],"Mechanical resource unchanged: "+path)
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/screenprint/manifest.json"))
 for path: String in manifest:
  var item: Dictionary=manifest[path]
  check(ResourceLoader.exists("res://"+path),"Authored asset imports: "+path)
  if "/vehicles/" in path: check(int(item.triangles)<=40000,"Vehicle triangle budget: "+path)
 for id: String in RallyContentCatalog.VEHICLES:
  var definition := RallyContentCatalog.vehicle(id)
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
