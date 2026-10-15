class_name RallyWheelContactSample
extends RefCounted

var hit: bool = false
var supported: bool = false
var point := Vector3.ZERO
var normal := Vector3.UP
var local := Vector2.ZERO
var support_length: float = INF
var shape_weight: float = 0.0
var pressure_weight: float = 0.0
var collider: Object
var surface := RallySurfaceSample.new()


func reset() -> void:
	hit = false
	supported = false
	point = Vector3.ZERO
	normal = Vector3.UP
	local = Vector2.ZERO
	support_length = INF
	shape_weight = 0.0
	pressure_weight = 0.0
	collider = null
