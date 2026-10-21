extends "res://tests/test_suite.gd"
func _run() -> void:
 check(RallySurfaceQuery.PROFILES.size()==6,"Surface IDs append without changing legacy IDs")
 var packed: RallySurfaceProfile=RallySurfaceQuery.PROFILES[4]
 var soft: RallySurfaceProfile=RallySurfaceQuery.PROFILES[5]
 check(soft.rolling_extra>packed.rolling_extra and soft.friction_scale<packed.friction_scale,"Soft sand reduces grip and increases resistance")
 var track:=RallyContentCatalog.stage("redrock_canyon")
 var route:=RallyStageRoute.new()
 route.build(track)
 var errors:=route.validate()
 print("Canyon geometry: ",errors)
 check(errors.is_empty(),"Canyon route does not intersect")
 check(absf(route.length-3600)<10,"Canyon is 3.6 km")
 for id: String in RallyContentCatalog.VEHICLES:
  var car:=RallyContentCatalog.vehicle(id)
  var setup:=RallyGarageCatalog.stock(car)
  check(RallyGarageCatalog.valid(setup,car),id+" stock setup validates")
  var resolved:=RallyGarageCatalog.resolve(car,setup)
  check(is_equal_approx(resolved.physics_config().spring_rate(),car.physics_config().spring_rate()),id+" stock spring preserved")
  check(resolved.drivetrain_config().ratios==car.drivetrain_config().ratios,id+" gear count preserved")
  setup.tune.spring=1.25
  setup.tune.height=30.0
  var changed:=RallyGarageCatalog.resolve(car,setup).physics_config()
  var base:=car.physics_config()
  var old_height:=base.suspension_rest-base.static_compression/base.spring_multiplier
  var new_height:=changed.suspension_rest-changed.static_compression/changed.spring_multiplier
  check(absf(new_height-old_height-.03)<.0001,id+" height is independent of spring rate")
  check(car.physics_config().spring_multiplier==1,id+" tuning does not mutate stock resources")
  for stage: String in RallyContentCatalog.STAGES:
   for tier: int in range(3): check(RallyContentCatalog.challenge(stage,id,tier)!=null,"Challenge "+stage+"/"+id+"/"+str(tier))
 var p7:=RallyContentCatalog.vehicle("P7")
 check(p7.electric and p7.drivetrain_config().ratios.size()==1,"P7 uses single-speed EV drivetrain")
 check(absf(p7.power_ps*735.49875-437000)<1,"P7 AWD nominal 437 kW")
 var preview:=Node3D.new()
 root.add_child(preview)
 var mesa:=RallyRedrockScenery._rock(preview,Vector3.ZERO,Vector3.ONE,StandardMaterial3D.new())
 var normals: PackedVector3Array=mesa.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
 print("MESA NORMALS: ",normals[-3]," ",normals[-2]," ",normals[-1])
 check(normals[-3].y>.99,"Mesa and riverbank caps face upward, without hollow tops")
 preview.queue_free()
 await process_frame
 finish()
