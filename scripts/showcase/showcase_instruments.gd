class_name RallyShowcaseInstruments
extends RefCounted

# Symmetric 200 ms motion window: deterministic under pause, seek and frame-rate changes.
# This is kinematic body acceleration (same convention as T debug), not tire force.
static func acceleration(record: Dictionary,time: float) -> Vector3:
	var h := .1
	var t := clampf(time,h,float(record.duration)-h)
	var a: Transform3D=RallyGhostRecording.sample(record,t-h).pose
	var b: Transform3D=RallyGhostRecording.sample(record,t).pose
	var c: Transform3D=RallyGhostRecording.sample(record,t+h).pose
	return b.basis.inverse()*(c.origin-2*b.origin+a.origin)/(h*h*9.81)

static func model(world: RallyShowcaseWorld,shot: Dictionary,clock: float,row: Array) -> Dictionary:
	var t := float(shot.source_in)+clock-float(shot.start)
	return {"speed":float(row[2])*3.6,"slip":float(row[3]),"gear":int(row[7]),"rpm":float(row[8]),
		"throttle":float(row[5]),"brake":float(row[6]),"steer":-float(RallyGhostRecording.sample(world.clips[shot.clip].recording,t).steer),
		"g":acceleration(world.clips[shot.clip].recording,t),"car":world.scene.challenge.vehicle.vehicle_id,
		"drive":world.scene.vehicle.drivetrain.config}
