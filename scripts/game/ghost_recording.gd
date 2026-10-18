class_name RallyGhostRecording
extends RefCounted

const VERSION := 1
const SAMPLE_INTERVAL := 1.0/30.0
const MAX_FRAMES := 108000
# Frame: score time, position XYZ, rotation XYZW, steer, four spin angles,
# then four suspension lengths. Recovery gaps use the same score clock.
const FRAME_SIZE := 17
var frames: Array = []
var gaps: Array = []
var next_sample: float = 0
var overflowed: bool = false


func reset() -> void:
	frames.clear()
	gaps.clear()
	next_sample = 0
	overflowed = false


func capture(time: float,car: RallyVehicle,force: bool = false) -> void:
	if time+0.00001<next_sample and not force: return
	if not frames.is_empty() and time<=float(frames[-1][0]): return
	if frames.size()>=MAX_FRAMES:
		overflowed = true
		return
	var p := car.global_position
	var q := car.global_basis.get_rotation_quaternion()
	var frame := [time,p.x,p.y,p.z,q.x,q.y,q.z,q.w,car.wheels[0].steer]
	for wheel: RallyWheelState in car.wheels: frame.append(wheel.spin)
	for wheel: RallyWheelState in car.wheels: frame.append(wheel.length)
	frames.append(frame)
	next_sample = time+SAMPLE_INTERVAL


func recovery(start: float,end: float) -> void:
	# Even a zero-penalty practice recovery must not interpolate through terrain.
	gaps.append([start,maxf(start+0.001,end)])
	next_sample = end


func payload(key: String,duration: float) -> Dictionary:
	return {"version":VERSION,"key":key,"duration":duration,"frames":frames.duplicate(true),"gaps":gaps.duplicate(true),"complete":not overflowed}


static func valid(value: Variant,key: String) -> bool:
	if value is not Dictionary: return false
	if value.get("version",0)!=VERSION or value.get("key","")!=key or not value.get("complete",false): return false
	var duration: Variant = value.get("duration",null)
	if not numeric(duration) or float(duration)<=0: return false
	var samples: Variant = value.get("frames",null)
	var breaks: Variant = value.get("gaps",null)
	if samples is not Array or breaks is not Array or samples.size()<2 or samples.size()>MAX_FRAMES: return false
	var previous := -1.0
	for frame: Variant in samples:
		if frame is not Array or frame.size()!=FRAME_SIZE: return false
		for number: Variant in frame:
			if not numeric(number): return false
		if float(frame[0])<=previous or float(frame[0])>float(duration)+0.05: return false
		var q := Quaternion(frame[4],frame[5],frame[6],frame[7])
		if absf(q.length_squared()-1)>0.02: return false
		previous = float(frame[0])
	for gap: Variant in breaks:
		if gap is not Array or gap.size()!=2 or not numeric(gap[0]) or not numeric(gap[1]): return false
		if float(gap[0])<0 or float(gap[1])<float(gap[0]) or float(gap[1])>float(duration)+0.05: return false
	return absf(float(samples[-1][0])-float(duration))<0.1


static func numeric(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func sample(recording: Dictionary,time: float) -> Dictionary:
	var samples: Array = recording.get("frames",[])
	if samples.size()<2 or time<float(samples[0][0]) or time>float(recording.get("duration",0)): return {}
	for gap: Array in recording.get("gaps",[]):
		if time>=float(gap[0]) and time<float(gap[1]): return {}
	var low := 0
	var high := samples.size()-1
	while low+1<high:
		var mid := (low+high)/2
		if float(samples[mid][0])<=time: low = mid
		else: high = mid
	var a: Array = samples[low]
	var b: Array = samples[high]
	# Skip any segment spanning a recovery; never draw its straight connection.
	for gap: Array in recording.get("gaps",[]):
		if float(a[0])<=float(gap[0]) and float(b[0])>=float(gap[1]) and time<float(b[0]): return {}
	var weight := clampf((time-float(a[0]))/maxf(float(b[0])-float(a[0]),0.00001),0,1)
	var pa := Vector3(a[1],a[2],a[3])
	var pb := Vector3(b[1],b[2],b[3])
	var qa := Quaternion(a[4],a[5],a[6],a[7]).normalized()
	var qb := Quaternion(b[4],b[5],b[6],b[7]).normalized()
	var spins: Array[float] = []
	var lengths: Array[float] = []
	for i: int in range(4):
		spins.append(lerpf(float(a[9+i]),float(b[9+i]),weight))
		lengths.append(lerpf(float(a[13+i]),float(b[13+i]),weight))
	return {"pose":Transform3D(Basis(qa.slerp(qb,weight)),pa.lerp(pb,weight)),"steer":lerpf(float(a[8]),float(b[8]),weight),"spins":spins,"lengths":lengths}
