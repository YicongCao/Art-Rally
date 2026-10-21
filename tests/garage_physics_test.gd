extends "res://tests/test_suite.gd"
func _run() -> void:
 var world:=Node3D.new()
 root.add_child(world)
 GrayboxGeometry.box(world,"Ground",Vector3(2000,1,2000),Vector3(0,-.5,0),Color.GRAY,true)
 for id: String in RallyContentCatalog.VEHICLES:
  for extreme: int in [-1,0,1]:
   var base:=RallyContentCatalog.vehicle(id)
   var setup:=RallyGarageCatalog.stock(base)
   if extreme!=0:
    setup.parts.suspension="road" if extreme<0 else "travel"
    setup.parts.tires="road" if extreme<0 else "sand"
    for row: Array in RallyGarageCatalog.tuning_rows(base,setup): setup.tune[row[0]]=row[2] if extreme<0 else row[3]
   var resolved:=RallyGarageCatalog.resolve(base,setup)
   var car:=RallyVehicle.new()
   car.config=resolved.physics_config()
   car.drivetrain.config=resolved.drivetrain_config()
   car.tire=resolved.tire_config()
   car.position=Vector3(0,1.1,0)
   world.add_child(car)
   await ticks(300)
   var equilibrium:=car.position.y
   check(is_finite(equilibrium) and equilibrium>.35 and equilibrium<1.1,id+" legal setup settles "+str(extreme))
   car.command.throttle=.8
   car.command.steer=.12
   var stable:=true
   for i: int in range(600):
    await physics_frame
    stable=stable and car.position.is_finite() and car.linear_velocity.is_finite() and car.linear_velocity.length()<150 and car.angular_velocity.length()<30
   check(stable and car.position.y<2,id+" boundary remains finite under load "+str(extreme))
   car.free()
 world.queue_free()
 await process_frame
 finish()
