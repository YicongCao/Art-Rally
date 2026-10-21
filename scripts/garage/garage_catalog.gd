class_name RallyGarageCatalog
extends RefCounted

const VERSION := "garage-1"
const CATEGORIES := ["tires","suspension","gearbox","engine"]
const TITLES := {"tires":"轮胎","suspension":"悬架","gearbox":"变速箱","engine":"动力"}
const PARTS := {
 "tires":[["stock","原厂","保持原厂轮胎"],["road","公路","柏油抓地更强，松软路面较弱"],["mixed","混合","兼顾柏油与砂石"],["sand","砂石／沙地","松软路面牵引更强，牺牲柏油精度"]],
 "suspension":[["stock","原厂","保持原厂行程与支撑"],["road","公路","低车身、强支撑，起伏余量较少"],["rally","拉力","增加行程，兼顾转向与起伏"],["travel","长行程","更大起伏余量，车身运动更明显"]],
 "gearbox":[["stock","原厂","保持原厂齿比"],["short","短齿比","强化加速，降低各挡速度范围"],["long","长齿比","延长速度范围，降低轮上扭矩"]],
 "engine":[["stock","原厂","保持原厂输出"],["torque","宽扭矩","强化中低转速响应"],["rev","高转速","强化高速输出，中低段较弱"]]
}
const SLIDERS := [
 ["height","车高偏移",-30.0,40.0,5.0,"mm"],
 ["spring","弹簧硬度",0.80,1.25,0.05,"×"],
 ["compression","压缩阻尼",0.70,1.40,0.05,"×"],
 ["rebound","回弹阻尼",0.70,1.40,0.05,"×"],
 ["lock","差速器锁止强度",0.0,100.0,5.0,"%"],
 ["final_drive","终传比",0.85,1.15,0.025,"×"],
 ["brake_bias","前轮制动比例",52.0,70.0,1.0,"%"]
]

static func stock(car: RallyVehicleDefinition) -> Dictionary:
 return {"version":VERSION,"vehicle":car.vehicle_id,"name":"原厂方案","parts":{"tires":"stock","suspension":"stock","gearbox":"stock","engine":"stock"},"tune":{"height":0.0,"spring":1.0,"compression":1.0,"rebound":1.0,"lock":50.0,"final_drive":1.0,"brake_bias":car.physics_config().front_brake_bias*100}}

# Relative ranges are engineering limits for the current chassis and fitted parts.
static func tuning_rows(car: RallyVehicleDefinition,value: Dictionary) -> Array:
 var rows: Array=SLIDERS.duplicate(true)
 var suspension: String=value.parts.suspension
 for row: Array in rows:
  if row[0]=="height":
   row[2]=maxf(float(row[2]),-15.0 if car.electric else -30.0)
   if suspension=="road": row[3]=15.0
   elif suspension=="travel": row[2]=0.0
  elif row[0]=="compression":
   if suspension=="road": row[2]=.85
   elif suspension=="travel": row[3]=1.20
  elif row[0]=="final_drive":
   if car.electric: row[2]=.90; row[3]=1.10
   if value.parts.gearbox=="short": row[2]=maxf(float(row[2]),.90)
   elif value.parts.gearbox=="long": row[3]=minf(float(row[3]),1.10)
 return rows

static func fit_ranges(car: RallyVehicleDefinition,value: Dictionary) -> void:
 for row: Array in tuning_rows(car,value):
  value.tune[row[0]]=clampf(float(value.tune[row[0]]),float(row[2]),float(row[3]))

static func valid(value: Variant,car: RallyVehicleDefinition) -> bool:
 if value is not Dictionary or value.get("version","")!=VERSION or value.get("vehicle","")!=car.vehicle_id: return false
 if value.get("parts") is not Dictionary or value.get("tune") is not Dictionary: return false
 if str(value.get("name","")).length()>32: return false
 for category: String in CATEGORIES:
  var found := false
  for part: Array in PARTS[category]:
   if value.parts.get(category,"")==part[0]: found=true
  if not found: return false
 for row: Array in tuning_rows(car,value):
  var v: Variant=value.tune.get(row[0])
  if v is not float and v is not int: return false
  if not is_finite(float(v)) or float(v)<float(row[2])-.0001 or float(v)>float(row[3])+.0001: return false
 return true

static func fingerprint(value: Dictionary) -> String:
 var fields: Array=[VERSION,value.vehicle]
 for category: String in CATEGORIES: fields.append(value.parts[category])
 for row: Array in SLIDERS: fields.append(snappedf(float(value.tune[row[0]]),.0001))
 return JSON.stringify(fields).sha256_text()

static func resolve(car: RallyVehicleDefinition,value: Dictionary) -> RallyVehicleDefinition:
 assert(car.power_tier==0 and valid(value,car))
 var result := car.duplicate(true) as RallyVehicleDefinition
 var physics := car.physics_config()
 var drive := car.drivetrain_config()
 var tire := car.tire_config()
 var suspension: String=value.parts.suspension
 var height: float={"stock":0.0,"road":-.025,"rally":.025,"travel":.055}[suspension]+float(value.tune.height)/1000
 var spring: float={"stock":1.0,"road":1.18,"rally":.96,"travel":.86}[suspension]*float(value.tune.spring)
 # Compensate the static sag so changing spring stiffness does not move ride height.
 var original_sag := physics.static_compression/physics.spring_multiplier
 physics.spring_multiplier *= spring
 var target_sag := physics.static_compression/physics.spring_multiplier
 physics.suspension_rest += height+target_sag-original_sag
 physics.compression_damping *= float(value.tune.compression)
 physics.rebound_damping *= float(value.tune.rebound)
 physics.front_brake_bias = float(value.tune.brake_bias)/100
 drive.final_drive *= {"stock":1.0,"short":1.12,"long":.90}[str(value.parts.gearbox)]*float(value.tune.final_drive)
 var lock := float(value.tune.lock)/50.0
 drive.diff_lock_gain *= lock
 drive.axle_lock_limit *= lock
 drive.center_lock_limit *= lock
 var compound: String=value.parts.tires
 tire.compound=compound
 tire.surface_grip = {"stock":PackedFloat64Array([1,1,1,1,1,1]),"road":PackedFloat64Array([1.10,.86,.78,.82,.78,.70]),"mixed":PackedFloat64Array([.97,1.04,1.0,1.0,1.03,1.0]),"sand":PackedFloat64Array([.85,1.10,1.06,1.0,1.13,1.18])}[compound]
 if compound=="sand":
  tire.section_width *= 1.06
  tire.radial_stiffness *= .92
 var power: String=value.parts.engine
 if power!="stock":
  for i: int in range(drive.torque_values.size()):
   var t := float(i)/maxi(1,drive.torque_values.size()-1)
   drive.torque_values[i] *= lerpf(1.15,1.0,t) if power=="torque" else lerpf(.94,1.16,t)
  drive.rated_power_ps *= 1.06 if power=="torque" else 1.14
 result.power_ps=drive.rated_power_ps
 result.resolved_physics=physics
 result.resolved_drivetrain=drive
 result.resolved_tire=tire
 result.garage_setup=value.duplicate(true)
 return result

static func describe(value: Dictionary) -> String:
 var labels: Array[String]=[]
 for category: String in CATEGORIES:
  for part: Array in PARTS[category]:
   if part[0]==value.parts[category]: labels.append(TITLES[category]+" "+str(part[1]))
 labels.append("车高 %+.0f mm / 弹簧 %.2f / 压缩 %.2f / 回弹 %.2f / 锁止 %.0f%% / 终传 %.2f / 前制动 %.0f%%"%[value.tune.height,value.tune.spring,value.tune.compression,value.tune.rebound,value.tune.lock,value.tune.final_drive,value.tune.brake_bias])
 return " · ".join(labels)
