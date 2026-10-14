class_name RallyWheelState
extends RefCounted

var grounded: bool = false
var point := Vector3.ZERO
var normal := Vector3.UP
var length: float = 0.48
var compression: float = 0.0
var load: float = 0.0
var omega: float = 0.0
var spin: float = 0.0
var steer: float = 0.0
var forward := Vector3.FORWARD
var right := Vector3.RIGHT
var longitudinal_speed: float = 0.0
var lateral_speed: float = 0.0
var slip: float = 0.0
var slip_angle: float = 0.0
var longitudinal_force: float = 0.0
var lateral_force: float = 0.0
var relaxed_slip: float = 0.0
var relaxed_angle: float = 0.0
var surface := RallySurfaceSample.new()
var water_force := Vector3.ZERO


func reset() -> void:
	grounded = false
	load = 0.0
	compression = 0.0
	omega = 0.0
	spin = 0.0
	slip = 0.0
	slip_angle = 0.0
	longitudinal_force = 0.0
	lateral_force = 0.0
	relaxed_slip = 0.0
	relaxed_angle = 0.0
	surface = RallySurfaceSample.new()
	water_force = Vector3.ZERO
