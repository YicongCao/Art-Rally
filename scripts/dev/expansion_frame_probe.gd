extends SceneTree
var car: RallyVehicle
var count:=0
var measurements: Dictionary={}
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
 var world:=Node3D.new()
 root.add_child(world)
 var ground:=GrayboxGeometry.box(world,"Sand",Vector3(2000,1,2000),Vector3(0,-.5,0),Color.GRAY,true)
 ground.set_meta("surface_id",4)
 var base:=RallyContentCatalog.vehicle("P7")
 var setup:=RallyGarageCatalog.stock(base)
 setup.parts.tires="sand"
 setup.parts.suspension="rally"
 setup.tune.compression=.8
 setup.tune.rebound=1.2
 var resolved:=RallyGarageCatalog.resolve(base,setup)
 car=RallyVehicle.new()
 car.config=resolved.physics_config()
 car.drivetrain.config=resolved.drivetrain_config()
 car.tire=resolved.tire_config()
 car.command_source=command
 car.position=Vector3(0,1,0)
 world.add_child(car)
func command(_speed: float,_dt: float) -> DriverCommand:
 var input:=DriverCommand.new()
 if count>=360 and count<960: input.throttle=.8
 if count>=600 and count<960: input.steer=.09
 if count==960: measurements.speed=car.linear_velocity.length(); measurements.position=[car.position.x,car.position.y,car.position.z]
 if count>=960: input.brake=1
 if count==1440:
  measurements.final=[car.position.x,car.position.y,car.position.z]
  measurements.final_speed=car.linear_velocity.length()
  print("EXPANSION_FRAME: ",JSON.stringify(measurements))
  quit.call_deferred()
 count+=1
 return input
