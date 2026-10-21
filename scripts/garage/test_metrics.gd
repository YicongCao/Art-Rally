class_name RallyGarageTestMetrics
extends RefCounted
var values: Dictionary={"straight_speed":null,"braking_distance":null,"bottom_outs":0}
var brake_start := -1.0
var previous_speed := 0.0
var previous_position := Vector3.ZERO
var brake_distance := 0.0
var bottom: Array[bool]=[false,false,false,false]
var invalid := false
func reset() -> void:
 values={"straight_speed":null,"braking_distance":null,"bottom_outs":0}
 brake_start=-1
 previous_speed=0
 brake_distance=0
 bottom=[false,false,false,false]
 invalid=false
func step(car: RallyVehicle,progress: float) -> void:
 if invalid: return
 var speed:=car.linear_velocity.length()
 if progress>=155 and progress<=175: values.straight_speed=maxf(float(values.get("straight_speed",0) if values.straight_speed!=null else 0),speed*3.6)
 if progress>=170 and progress<250 and brake_start==-1 and car.command.brake>.7 and speed>15:
  brake_start=progress
  previous_position=car.global_position
 if brake_start>=0 and values.braking_distance==null:
  brake_distance+=car.global_position.distance_to(previous_position)
  if speed<.5: values.braking_distance=brake_distance
  elif progress>260: brake_start=-2
 previous_position=car.global_position
 for i: int in range(4):
  var now:=car.wheels[i].grounded and car.wheels[i].length<=car.config.suspension_min+.005
  if now and not bottom[i]: values.bottom_outs+=1
  bottom[i]=now
 previous_speed=speed
func recovered() -> void:
 invalid=true
 values={"straight_speed":null,"braking_distance":null,"bottom_outs":null}
