extends "res://tests/test_suite.gd"
func _run() -> void:
 var world:=Node3D.new()
 root.add_child(world)
 var ground:=GrayboxGeometry.box(world,"Ground",Vector3(2000,1,2000),Vector3(0,-.5,0),Color.GRAY,true)
 var speeds: Dictionary={}
 for surface: int in [4,5]:
  ground.set_meta("surface_id",surface)
  var car:=RallyVehicle.new()
  var base:=RallyContentCatalog.vehicle("R200")
  car.config=base.physics_config()
  car.drivetrain.config=base.drivetrain_config()
  car.tire=base.tire_config()
  car.position=Vector3(0,1,0)
  world.add_child(car)
  await ticks(300)
  car.drivetrain.gear=0
  car.linear_velocity=Vector3(0,0,-15)
  for wheel: RallyWheelState in car.wheels: wheel.omega=15/car.config.wheel_radius
  await ticks(480)
  speeds[surface]=car.linear_velocity.length()
  check(car.wheels[0].surface.surface_id==surface,"Contact preserves sand surface "+str(surface))
  car.free()
 print("SAND COAST SPEEDS ",speeds)
 check(float(speeds[5])<float(speeds[4])-1,"Soft shoulder loses more actual speed than packed route")
 var generator:=RallyStageGenerator.new()
 generator.definition=RallyContentCatalog.stage("redrock_canyon")
 generator.route.build(generator.definition)
 var previous:=generator._surface_at_coordinates(1100,3.0)
 var continuous:=true
 for i: int in range(1,25):
  var sample:=generator._surface_at_coordinates(1100,3.0+i*.1)
  continuous=continuous and absf(sample.friction_scale-previous.friction_scale)<.15
  previous=sample
 check(continuous,"Road-to-shoulder grip changes continuously")
 var setup:=RallyGarageCatalog.stock(RallyContentCatalog.vehicle("R200"))
 setup.parts.tires="road"
 var tire:=RallyGarageCatalog.resolve(RallyContentCatalog.vehicle("R200"),setup).tire_config()
 var packed:=RallySurfaceSample.from_profile(RallySurfaceQuery.PROFILES[4])
 var soft:=RallySurfaceSample.from_profile(RallySurfaceQuery.PROFILES[5])
 var blend:=RallySurfaceSample.weighted_average([packed,soft],PackedFloat64Array([.25,.75]))
 check(is_equal_approx(tire.grip_for(blend),.25*tire.grip_factor(4)+.75*tire.grip_factor(5)),"Tire compound follows continuous surface weights")
 generator.free()
 world.queue_free()
 await process_frame
 finish()
