class_name TestGround
extends Node3D

const SPAWN := Vector3(0, 0.8, 12)
const CIRCLE_CENTER := Vector3(65, 0, -80)
const CIRCLE_RADIUS := 25.0


func _ready() -> void:
	GrayboxGeometry.box(self, "Asphalt", Vector3(280, 1, 850), Vector3(0, -0.5, -280), Color("41484b"), true)
	for x: float in [-9.0, 9.0]:
		GrayboxGeometry.box(self, "LaneEdge", Vector3(0.16, 0.01, 720), Vector3(x, 0.008, -280), Color("e7dfb8"))
	for meter: int in range(0, 601, 25):
		GrayboxGeometry.box(self, "DistanceMark", Vector3(1.4, 0.01, 0.18), Vector3(10, 0.01, -meter), Color("dcbf69"))
		if meter % 100 == 0:
			GrayboxGeometry.label(self, "%d m" % meter, Vector3(14, 1.4, -meter))
	for i: int in range(96):
		var angle := TAU * i / 96.0
		var at := CIRCLE_CENTER + Vector3(cos(angle), 0.001, sin(angle)) * CIRCLE_RADIUS
		at.y = 0.015
		GrayboxGeometry.box(self, "CircleMark", Vector3(0.2, 0.015, 1.0), at, Color("dcbf69"), false, Vector3(0, -rad_to_deg(angle), 0))
	for i: int in range(9):
		GrayboxGeometry.box(self, "SlalomMarker", Vector3(0.35, 0.65, 0.35), Vector3(-35 + (3 if i % 2 else -3), 0.325, -12.0 * i), Color("e77837"))
	GrayboxGeometry.box(self, "SpeedBump", Vector3(8, 0.10, 1.0), Vector3(-65, 0.04, -30), Color("c99b4c"), true)
	GrayboxGeometry.box(self, "Ramp", Vector3(8, 0.4, 14), Vector3(-65, 0.85, -65), Color("858b7e"), true, Vector3(8, 0, 0))
	for i: int in range(6):
		GrayboxGeometry.box(self, "Undulation", Vector3(8, 0.08, 1.8), Vector3(-90, 0.025, -25.0 - i * 6), Color("8d8669"), true)
	GrayboxGeometry.label(self, "01 / BRAKING STRAIGHT", Vector3(0, 3, -10))
	GrayboxGeometry.label(self, "02 / 25 m SKIDPAD", CIRCLE_CENTER + Vector3(0, 3, 0))
	GrayboxGeometry.label(self, "03 / SLALOM", Vector3(-35, 3, 6))
	GrayboxGeometry.label(self, "04 / BUMP + JUMP", Vector3(-65, 3, 6))
	GrayboxGeometry.label(self, "05 / UNDULATIONS", Vector3(-90, 3, 6))
	_build_surface_lanes()


func _build_surface_lanes() -> void:
	var field := RallySurfaceField.new()
	add_child(field)
	field.attach($Asphalt)
	for lane: int in range(3):
		var x := -95.0 + lane * 35.0
		var id := lane + 1
		var bounds := AABB(Vector3(x - 12, -2, -520), Vector3(24, 4, 200))
		field.patches.append({"bounds": bounds, "id": id})
		GrayboxGeometry.box(self, "SurfaceLane", Vector3(24, 0.008, 200), Vector3(x, 0.006, -420), RallySurfaceQuery.PROFILES[id].color)
		GrayboxGeometry.label(self, "%s / 200 m" % RallySurfaceQuery.PROFILES[id].label, Vector3(x, 3, -312))
	field.water = [{"bounds": AABB(Vector3(20, -2, -470), Vector3(24, 4, 45)), "depth": 0.10}]
	GrayboxGeometry.box(self, "WaterLayer", Vector3(24, 0.01, 45), Vector3(32, 0.018, -447.5), Color("456e78"))
	GrayboxGeometry.label(self, "WATER / 0.10 m", Vector3(32, 3, -418))
